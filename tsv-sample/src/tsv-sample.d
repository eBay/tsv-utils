/**
Command line tool implementing weighted reservoir sampling on delimited data files.
Weights are read from a field in the field.

Copyright (c) 2017, eBay Software Foundation
Initially written by Jon Degenhardt

License: Boost License 1.0 (http://boost.org/LICENSE_1_0.txt) 
*/
module tsv_sample;

import std.conv;
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
Synposis: tsv-sample [options] [file...]

Generates a weighted random sample from the input lines. The field to use
for weights are number of lines to output are specified via the `--f|field'
and '--n|num` options. All lines get the same weight if a field is not
specified. All input lines are output if a sample size is not provided.

Weights should be greater than zero. Negative weights are treated as zero.
However, any positive values can be used.

Reservoir sampling is used to limit lines held in memory to the number
requested ('--n|num' option). The entire input is held in-memory if this
is not provided.

Options:
EOS";

struct TsvSampleOptions
{
    string programName;
    string[] files;
    size_t sampleSize = 0;       // --n|num - Size of the desired sample
    size_t weightField = 0;      // --f|field - Field holding the weight
    bool hasHeader = false;      // --H|header
    bool printRandom = false;    // --p|print-random
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
                std.getopt.config.caseSensitive,
                "H|header",        "     Treat the first line of each file as a header.", &hasHeader,
                std.getopt.config.caseInsensitive,
                "n|num",           "NUM  Number of lines to include in the output. If not provided or zero, all lines are output.", &sampleSize,
                "f|field",         "NUM  Field number containing weights. If not provided or zero, all lines get equal weight.", &weightField,
                "p|print-random",  "     Output the random values that were assigned.", &printRandom,
                "d|delimiter",     "CHR  Field delimiter.", &delim,
                );

            if (r.helpWanted)
            {
                defaultGetoptPrinter(helpText, r.options);
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

/* Implementation of Efraimidis and Spirakis Algorithm for weighted reservoir sampling.
 * For more information see:
 * - https://en.wikipedia.org/wiki/Reservoir_sampling
 * - "Weighted Radom Sampling over Data Streams", Pavlos S. Efraimidis
 *   (https://arxiv.org/abs/1012.0256)
 */
void weightedReservoirSamplingES(OutputRange)(TsvSampleOptions cmdopt, OutputRange outputStream)
    if (isOutputRange!(OutputRange, char))
{
    import std.random : uniform, uniform01;
    import std.container.binaryheap;

    struct Entry
    {
        double score;
        char[] line;
    }

    auto reservoir = BinaryHeap!(Entry[], "a.score > b.score")(new Entry[](cmdopt.sampleSize), 0);

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
                    ? uniform01 ^^ (1.0 / lineWeight)
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
    foreach (entry; reservoir)
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

/* getFieldValue extracts the value of a single field from an input line. It is intended for
 * cases where only a single field in a line is needed.
 */
T getFieldValue(T)(const char[] line, size_t fieldIndex, char delim, string filename, size_t lineNum)
{
    import std.algorithm : splitter;
    import std.format : format;
    
    auto splitLine = line.splitter(delim);
    size_t atField = 0;
    
    while (atField < fieldIndex && !splitLine.empty)
    {
        splitLine.popFront;
        atField++;
    }

    T val;
    if (splitLine.empty)
    {
        if (fieldIndex == 0)
        {
            /* This is a workaround to a splitter special case - If the input is empty,
             * the returned split range is empty. This doesn't properly represent a single
             * column file. Correct be a single value representing an empty string. The
             * input line is a convenient source of an empty line. Info:
             *   Bug: https://issues.dlang.org/show_bug.cgi?id=15735
             *   Pull Request: https://github.com/D-Programming-Language/phobos/pull/4030
             */
            assert(line.empty);
            val = line.to!T;
        }
        else
        {
            throw new Exception(
                format("Not enough fields on line. Expecting %d fields.\n   File: %s, Line: %d\n  [Text] '%s'",
                       fieldIndex + 1, filename, lineNum, line));
        }
    }
    else
    {
        val = splitLine.front.to!T;
    }

    return val;
}
