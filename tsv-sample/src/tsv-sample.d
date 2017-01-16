/**
Command line tool implementing weighted reservoir sampling on delimited data files.
Weights are read from a field in the file.

Copyright (c) 2017, eBay Software Foundation
Initially written by Jon Degenhardt

License: Boost License 1.0 (http://boost.org/LICENSE_1_0.txt) 
*/
module tsv_sample;

import std.range;
import std.stdio;
import std.typecons : tuple;

version(unittest)
{
    // When running unit tests, use main from -main compiler switch.
}
else
{
    int main(string[] cmdArgs) {
        TsvSampleOptions cmdopt;
        auto r = cmdopt.processArgs(cmdArgs);
        if (!r[0]) return r[1];
        try weightedReservoirSamplingES(cmdopt, stdout.lockingTextWriter);
        catch (Exception exc)
        {
            stderr.writefln("Error [%s]: %s", cmdopt.programName, exc.msg);
            return 1;
        }
        return 0;
    }
}

auto helpText = q"EOS
Synopsis: tsv-sample [options] [file...]

Randomizes or samples input lines. By default, all lines are output in a
random order. '--n|num' can be used to limit the sample size produced. A
weighted random sample can be created with the '--f|field' option.

Options:
EOS";

auto helpTextVerbose = q"EOS
Synopsis: tsv-sample [options] [file...]

Randomizes or samples input lines. By default, all lines are output in a
random order. '--n|num' can be used to limit the sample size produced. A
weighted random sample can be created with the '--f|field' option.
Sampling is without replacement in all cases.

Reservoir sampling is used. If all input lines are included in the output,
they must all be held in memory. Memory required for large files can be
reduced significantly by specifying a sample size ('--n|num').

Weighted random sampling is done using the algorithm described by Efraimidis
and Spirakis. Weights should be positive numbers, but otherwise any values
can be used. For more information on the algorithm, see:
  * https://en.wikipedia.org/wiki/Reservoir_sampling
  * "Weighted Random Sampling over Data Streams", Pavlos S. Efraimidis
    (https://arxiv.org/abs/1012.0256)

Options:
EOS";

struct TsvSampleOptions
{
    string programName;
    string[] files;
    bool helpVerbose = false;    // --help-verbose
    size_t sampleSize = 0;       // --n|num - Size of the desired sample
    size_t weightField = 0;      // --f|field - Field holding the weight
    bool hasHeader = false;      // --H|header
    bool printRandom = false;    // --p|print-random
    bool staticSeed = false;     // --s|static-seed
    char delim = '\t';           // --d|delimiter
    bool hasWeightField = false; // Derived.
    bool sampleAllLines = true;  // Derived. 
    
    auto processArgs(ref string[] cmdArgs)
    {
        import std.getopt;
        import std.path : baseName, stripExtension;
        
        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";
        
        try
        {
            arraySep = ",";    // Use comma to separate values in command line options
            auto r = getopt(
                cmdArgs,
                "help-verbose",    "          Print full help.", &helpVerbose,
                std.getopt.config.caseSensitive,
                "H|header",        "     Treat the first line of each file as a header.", &hasHeader,
                std.getopt.config.caseInsensitive,
                "n|num",           "NUM  Number of lines to include in the output. If not provided or zero, all lines are output.", &sampleSize,
                "f|field",         "NUM  Field number containing weights. If not provided or zero, all lines get equal weight.", &weightField,
                "p|print-random",  "     Output the random values that were assigned.", &printRandom,
                "s|static-seed",   "     Use the same random seed every run. This produces consistent results every run. By default different results are produced each run.", &staticSeed,
                "d|delimiter",     "CHR  Field delimiter.", &delim,
                );

            if (r.helpWanted)
            {
                defaultGetoptPrinter(helpText, r.options);
                return tuple(false, 0);
            }
            else if (helpVerbose)
            {
                defaultGetoptPrinter(helpTextVerbose, r.options);
                return tuple(false, 0);
            }

            /* Derivations. */
            if (weightField > 0)
            {
                hasWeightField = true;
                weightField--;    // Switch to zero-based indexes.
            }

            sampleAllLines = (sampleSize == 0);

            /* Assume remaining args are files. Use standard input if files were not provided. */
            files ~= (cmdArgs.length > 1) ? cmdArgs[1..$] : ["-"];
            cmdArgs.length = 1;
        }
        catch (Exception exc)
        {
            stderr.writefln("[%s] Error processing command line arguments: %s", programName, exc.msg);
            return tuple(false, 1);
        }
        return tuple(true, 0);
    }
}

/* Implementation of Efraimidis and Spirakis algorithm for weighted reservoir sampling.
 * For more information see:
 * - https://en.wikipedia.org/wiki/Reservoir_sampling
 * - "Weighted Random Sampling over Data Streams", Pavlos S. Efraimidis
 *   (https://arxiv.org/abs/1012.0256)
 *
 * This algorithm uses a 'min' binary heap (priority queue). Every input line is read
 * and assigned a random weight. 
 */
void weightedReservoirSamplingES(OutputRange)(TsvSampleOptions cmdopt, OutputRange outputStream)
    if (isOutputRange!(OutputRange, char))
{
    import std.random : Random, unpredictableSeed, uniform01;
    import std.container.binaryheap;

    auto randomGenerator = Random(cmdopt.staticSeed ? 2438424139 : unpredictableSeed);

    struct Entry
    {
        double score;
        char[] line;
    }

    /* Use a plain array as BinaryHeap backing store in Phobos 2.072 and later. In earlier
     * versions use an Array from std.container.array. In version 2.072 BinaryHeap was
     * changed to allow re-sizing a regular array. Performance is similar, but the regular
     * array uses less memory when extended.
     */
    static if (__VERSION__ >= 2072)
    {
        auto dataStore = new Entry[](cmdopt.sampleSize);
    }
    else
    {
        import std.container.array;
        auto dataStore = Array!(Entry)();
        dataStore.reserve(cmdopt.sampleSize);
    }
    
    auto reservoir = heapify!("a.score > b.score")(dataStore, 0);

    bool headerWritten = false;
    foreach (filename; cmdopt.files)
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (fileLineNum, line; inputStream.byLine(KeepTerminator.no).enumerate(1))
        {
            if (cmdopt.hasHeader && fileLineNum == 1)
            {
                if (!headerWritten)
                {
                    if (cmdopt.printRandom)
                    {
                        outputStream.put("random_weight");
                        outputStream.put(cmdopt.delim);
                    }
                    outputStream.put(line);
                    outputStream.put("\n");
                    headerWritten = true;
                }
            }
            else {
                double lineWeight =
                    cmdopt.hasWeightField
                    ? getFieldValue!double(line, cmdopt.weightField, cmdopt.delim, filename, fileLineNum)
                    : 1.0;
                double lineScore =
                    (lineWeight > 0.0)
                    ? uniform01(randomGenerator) ^^ (1.0 / lineWeight)
                    : 0.0;

                if (cmdopt.sampleAllLines || reservoir.length < cmdopt.sampleSize)
                {
                    reservoir.insert(Entry(lineScore, line.dup));
                }
                else if (reservoir.front.score < lineScore)
                {
                    reservoir.replaceFront(Entry(lineScore, line.dup));
                }
            }
        }
    }

    size_t totalEntries = reservoir.length;
    Entry[] sortedEntries;
    sortedEntries.reserve(totalEntries);
    foreach (entry; reservoir) sortedEntries ~= entry;

    import std.range : retro;
    foreach (entry; sortedEntries.retro)
    {
        if (cmdopt.printRandom)
        {
            import std.format;
            outputStream.put(format("%.15g", entry.score));
            outputStream.put(cmdopt.delim);
        }
        outputStream.put(entry.line);
        outputStream.put("\n");
    }
}

/* A convenience function for extracting a single field from a line. See getTsvFieldValue in
 * common/src/tsvutils.d for details. This wrapper creates error text tailored for this program.
 */
import std.traits : isSomeChar;
T getFieldValue(T, C)(const C[] line, size_t fieldIndex, C delim, string filename, size_t lineNum)
    pure @safe
    if (isSomeChar!C)
{
    import std.conv;
    import std.format : format;
    import tsvutil : getTsvFieldValue;

    T val;
    try
    {
        val = getTsvFieldValue!T(line, fieldIndex, delim);
    }
    catch (ConvException exc)
    {
        throw new Exception(
            format("Could not process line: %s\n  File: %s Line: %s%s",
                   exc.msg, (filename == "-") ? "Standard Input" : filename, lineNum,
                   (lineNum == 1) ? "\n  Is this a header line? Use --H|header to skip." : ""));
    }
    catch (Exception exc)
    {
        /* Not enough fields on the line. */
        throw new Exception(
            format("Could not process line: %s\n  File: %s Line: %s",
                   exc.msg, (filename == "-") ? "Standard Input" : filename, lineNum));
    }

    return val;
}

unittest
{
    /* getFieldValue unit tests. getTsvFieldValue has it's own tests.
     * These tests make basic sanity checks on the getFieldValue wrapper.
     */
    import std.exception;
    
    assert(getFieldValue!double("123", 0, '\t', "unittest", 1) == 123);
    assert(getFieldValue!double("123.4", 0, '\t', "unittest", 1) == 123.4);
    assertThrown(getFieldValue!double("abc", 0, '\t', "unittest", 1));
    assertThrown(getFieldValue!double("abc", 0, '\t', "unittest", 2));
    assertThrown(getFieldValue!double("123", 1, '\t', "unittest", 1));
    assertThrown(getFieldValue!double("123", 1, '\t', "unittest", 2));
}
