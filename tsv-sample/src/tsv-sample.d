/**
Command line tool implementing weighted reservoir sampling on delimited data files.
Weights are read from a field in the file.

Copyright (c) 2017-2018, eBay Software Foundation
Initially written by Jon Degenhardt

License: Boost License 1.0 (http://boost.org/LICENSE_1_0.txt)
*/
module tsv_sample;

import std.range;
import std.stdio;
import std.typecons : tuple, Flag;

version(unittest)
{
    // When running unit tests, use main from -main compiler switch.
}
else
{
    int main(string[] cmdArgs)
    {
        /* When running in DMD code coverage mode, turn on report merging. */
        version(D_Coverage) version(DigitalMars)
        {
            import core.runtime : dmd_coverSetMerge;
            dmd_coverSetMerge(true);
        }

        TsvSampleOptions cmdopt;
        auto r = cmdopt.processArgs(cmdArgs);
        if (!r[0]) return r[1];
        try
        {
            if (cmdopt.useStreamSampling)
            {
                streamSampling(cmdopt, stdout.lockingTextWriter);
            }
            else if (cmdopt.sampleSize == 0)
            {
                reservoirSampling!(Yes.permuteAll)(cmdopt, stdout.lockingTextWriter);
            }
            else
            {
                reservoirSampling!(No.permuteAll)(cmdopt, stdout.lockingTextWriter);
            }
        }
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

Samples or randomizes input lines. There are several modes of operation:
* Randomization (Default): Input lines are output in random order.
* Stream sampling (--r|rate): Input lines are sampled based on a sampling
  rate. The order of the input is unchanged.
* Weighted sampling (--f|field): Input lines are selected using weighted
  random sampling, with the weight taken from a field. Input lines are
  output in the order selected, reordering the lines.

The '--n|num' option limits the sample sized produced. It speeds up the
randomization and weighted sampling cases significantly.

Use '--help-verbose' for detailed information.

Options:
EOS";

auto helpTextVerbose = q"EOS
Synopsis: tsv-sample [options] [file...]

Samples or randomizes input lines. There are several modes of operation:
* Randomization (Default): Input lines are output in random order.
* Stream sampling (--r|rate): Input lines are sampled based on a sampling
  rate. The order of the input is unchanged.
* Weighted sampling (--f|field): Input lines are selected using weighted
  random sampling, with the weight taken from a field. Input lines are
  output in the order selected, reordering the lines. See 'Weighted
  sampling and field weights' below for info on field weights.

Sample size: The '--n|num' option limits the sample sized produced. This
speeds up randomization and weighted sampling significantly (details below).

Controlling randomization: Each run produces a different randomization.
Using '--s|static-seed' changes this so multiple runs produce the same
randomization. This works by using the same random seed each run. The
random seed can be specified using '--v|seed-value'. This takes a
non-zero, 32-bit positive integer. (A zero value is a no-op and ignored.)

Generating random weights: The random weight assigned to each line can
output using the '--p|print-random' option. This can be used with
'--rate 1' to assign a random weight to each line. The random weight
is prepended line as field one (separated by TAB or --d|delimiter char).
Weights are in the interval [0,1]. The open/closed aspects of the
interval (including/excluding 0.0 and 1.0) are subject to change and
should not be relied on.

Reservoir sampling: The randomization and weighted sampling cases are
implemented using reservoir sampling. This means all lines output must be
held in memory. Memory needed for large input streams can reduced
significantly using a sample size. Both 'tsv-sample -n 1000' and
'tsv-sample | head -n 1000' produce the same results, but the former is
quite a bit faster.

Weighted sampling and field weights: Weighted random sampling is done
using an algorithm described by Efraimidis and Spirakis. Weights should
be positive values representing the relative weight of the entry in the
collection. Negative values are not meaningful and given the value zero.
However, any positive real values can be used. Lines are output ordered
by the randomized weight that was assigned. This means, for example, that
a smaller sample can be produced by taking the first N lines of output.
For more info on the sampling approach see:
* Wikipedia: https://en.wikipedia.org/wiki/Reservoir_sampling
* "Weighted Random Sampling over Data Streams", Pavlos S. Efraimidis
  (https://arxiv.org/abs/1012.0256)

Options:
EOS";

struct TsvSampleOptions
{
    string programName;
    string[] files;
    bool helpVerbose = false;        // --help-verbose
    double sampleRate = double.nan;  // --r|rate - Sampling rate
    size_t sampleSize = 0;           // --n|num - Size of the desired sample
    size_t weightField = 0;          // --f|field - Field holding the weight
    bool hasHeader = false;          // --H|header
    bool printRandom = false;        // --p|print-random
    bool staticSeed = false;         // --s|static-seed
    uint seedValue = 0;              // --v|seed-value
    char delim = '\t';               // --d|delimiter
    bool versionWanted = false;      // --V|version
    bool hasWeightField = false;     // Derived.
    bool useStreamSampling = false;  // Derived.

    auto processArgs(ref string[] cmdArgs)
    {
        import std.getopt;
        import std.math : isNaN;
        import std.path : baseName, stripExtension;

        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

        try
        {
            arraySep = ",";    // Use comma to separate values in command line options
            auto r = getopt(
                cmdArgs,
                "help-verbose",    "     Print more detailed help.", &helpVerbose,
                std.getopt.config.caseSensitive,
                "H|header",        "     Treat the first line of each file as a header.", &hasHeader,
                std.getopt.config.caseInsensitive,
                "r|rate",          "NUM  Sampling rating (0.0 < NUM <= 1.0). This sampling mode outputs a random fraction of lines, in the input order.", &sampleRate,
                "n|num",           "NUM  Number of lines to output. All lines are output if not provided or zero.", &sampleSize,
                "f|field",         "NUM  Field containing weights. All lines get equal weight if not provided or zero.", &weightField,
                "p|print-random",  "     Output the random values that were assigned.", &printRandom,
                "s|static-seed",   "     Use the same random seed every run.", &staticSeed,

                std.getopt.config.caseSensitive,
                "v|seed-value",    "NUM  Sets the initial random seed. Use a non-zero, 32 bit positive integer. Zero is a no-op.", &seedValue,
                std.getopt.config.caseInsensitive,

                "d|delimiter",     "CHR  Field delimiter.", &delim,

                std.getopt.config.caseSensitive,
                "V|version",       "     Print version information and exit.", &versionWanted,
                std.getopt.config.caseInsensitive,
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
            else if (versionWanted)
            {
                import tsvutils_version;
                writeln(tsvutilsVersionNotice("tsv-sample"));
                return tuple(false, 0);
            }

            /* Derivations and validations. */
            if (weightField > 0)
            {
                hasWeightField = true;
                weightField--;    // Switch to zero-based indexes.
            }

            if (!sampleRate.isNaN)
            {
                useStreamSampling = true;

                if (sampleRate <= 0.0 || sampleRate > 1.0)
                {
                    import std.format : format;
                    throw new Exception(
                        format("Invalid --r|rate option: %g. Must satisfy 0.0 < rate <= 1.0.", sampleRate));
                }

                if (hasWeightField) throw new Exception("--f|field and --r|rate cannot be used together.");
            }

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

/* streamSampling does simple bernoulli sampling on the input stream. Each input line
 * is a assigned a random value and output if less than the sampling rate.
 */
void streamSampling(OutputRange)(TsvSampleOptions cmdopt, OutputRange outputStream)
    if (isOutputRange!(OutputRange, char))
{
    import std.random : Random, unpredictableSeed, uniform01;
    import tsvutil : throwIfWindowsNewlineOnUnix;

    uint seed =
        (cmdopt.seedValue != 0) ? cmdopt.seedValue
        : cmdopt.staticSeed ? 2438424139
        : unpredictableSeed;

    auto randomGenerator = Random(seed);

    /* Process each line. */
    bool headerWritten = false;
    size_t numLinesWritten = 0;
    foreach (filename; cmdopt.files)
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (fileLineNum, line; inputStream.byLine(KeepTerminator.no).enumerate(1))
        {
            if (fileLineNum == 1) throwIfWindowsNewlineOnUnix(line, filename, fileLineNum);
            if (fileLineNum == 1 && cmdopt.hasHeader)
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
            else
            {
                double lineScore = uniform01(randomGenerator);
                if (lineScore < cmdopt.sampleRate)
                {
                    if (cmdopt.printRandom)
                    {
                        import std.format;
                        outputStream.put(format("%.15g", lineScore));
                        outputStream.put(cmdopt.delim);
                    }
                    outputStream.put(line);
                    outputStream.put("\n");

                    if (cmdopt.sampleSize != 0)
                    {
                        ++numLinesWritten;
                        if (numLinesWritten == cmdopt.sampleSize) return;
                    }
                }
            }
        }
    }
}

/* An implementation of reservior sampling. Both weighted and unweighted sampling are
 * supported. Both are implemented using the one-pass algorithm described by Efraimidis
 * and Spirakis ("Weighted Random Sampling over Data Streams", Pavlos S. Efraimidis,
 * https://arxiv.org/abs/1012.0256). In the unweighted case weights are simply set to one.
 *
 * Both sampling and full permutation of the input are supported, but the implementations
 * differ. Both use a heap (priority queue). A "max" heap is used when permuting all lines,
 * as it leaves the heap in the correct order for output. However, a "min" heap is used
 * when sampling. When sampling the case the role of the heap is to indentify the top-k
 * elements. Adding a new items means dropping the "min" item. When done reading all lines,
 * the "min" heap is in the opposite order needed for output. The desired order is obtained
 * by removing each element one at at time from the heap. The underlying data store will
 * have the elements in correct order. The other notable difference is that the backing
 * store can be pre-allocated when sampling, but must be grown when permuting all lines.
 */
void reservoirSampling(Flag!"permuteAll" permuteAll, OutputRange)
    (TsvSampleOptions cmdopt, OutputRange outputStream)
    if (isOutputRange!(OutputRange, char))
{
    import std.random : Random, unpredictableSeed, uniform01;
    import std.container.binaryheap;
    import tsvutil : throwIfWindowsNewlineOnUnix;

    /* Ensure the correct version of the template was called. */
    static if (permuteAll) assert(cmdopt.sampleSize == 0);
    else assert(cmdopt.sampleSize > 0);

    uint seed =
        (cmdopt.seedValue != 0) ? cmdopt.seedValue
        : cmdopt.staticSeed ? 2438424139
        : unpredictableSeed;

    auto randomGenerator = Random(seed);

    struct Entry
    {
        double score;
        char[] line;
    }

    /* Create the heap and backing data store. A min or max heap is used as described
     * above. The backing store has some complications resulting from the current
     * standard library implementation:
     * - Built-in arrays appear to have better memory bevavior when appending than
     *   std.container.array Arrays. However, built-in arrays cannot be used with
     *   binaryheaps until Phobos version 2.072.
     * - std.container.array Arrays with pre-allocated storage can be used to
     *   efficiently reverse the heap, but a bug prevents this from working for other
     *   data store use cases. Info: https://issues.dlang.org/show_bug.cgi?id=17094
     * - Result: Use a built-in array if request is for permuteAll and Phobos version
     *   is 2.072 or later. Otherwise use a std.container.array Array.
     */

    static if (permuteAll && __VERSION__ >= 2072)
    {
        Entry[] dataStore;
    }
    else
    {
        import std.container.array;
        Array!Entry dataStore;
    }

    dataStore.reserve(cmdopt.sampleSize);

    static if (permuteAll)
    {
        auto reservoir = dataStore.heapify!("a.score < b.score")(0);  // Max binaryheap
    }
    else
    {
        auto reservoir = dataStore.heapify!("a.score > b.score")(0);  // Min binaryheap
    }

    /* Process each line. */
    bool headerWritten = false;
    foreach (filename; cmdopt.files)
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (fileLineNum, line; inputStream.byLine(KeepTerminator.no).enumerate(1))
        {
            if (fileLineNum == 1) throwIfWindowsNewlineOnUnix(line, filename, fileLineNum);
            if (fileLineNum == 1 && cmdopt.hasHeader)
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
            else
            {
                double lineWeight =
                    cmdopt.hasWeightField
                    ? getFieldValue!double(line, cmdopt.weightField, cmdopt.delim, filename, fileLineNum)
                    : 1.0;
                double lineScore =
                    (lineWeight > 0.0)
                    ? uniform01(randomGenerator) ^^ (1.0 / lineWeight)
                    : 0.0;

                static if (permuteAll)
                {
                    reservoir.insert(Entry(lineScore, line.dup));
                }
                else
                {
                    if (reservoir.length < cmdopt.sampleSize)
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
    }

    /* All entries are in the reservoir. Time to print. Entries are printed ordered
     * by assigned weights. In the sampling/top-k cases this could sped up a little
     * by simply printing the backing store array. However, there is real value in
     * having a weighted order. This is especially true for weighted sampling, but
     * there is also value in the unweighted case, especially when using static seeds.
     */

    void printEntry(Entry entry)
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

    static if (permuteAll)
    {
        foreach (entry; reservoir) printEntry(entry);  // Walk the max-heap
    }
    else
    {
        /* Sampling/top-n case: Reorder the data store by extracting all the elements.
         * Note: Asserts are chosen to avoid issues in the current binaryheap implementation.
         */
        size_t numLines = reservoir.length;
        assert(numLines == dataStore.length);

        while (!reservoir.empty) reservoir.removeFront;
        assert(numLines == dataStore.length);
        foreach (entry; dataStore) printEntry(entry);
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
    import std.conv : ConvException, to;
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

/* Unit tests for the main program start here.
 *
 * Portability note: Many of the tests here rely on generating consistent random numbers
 * across different platforms when using the same random seed. So far this has succeeded
 * on several different platorm, compiler, and library versions. However, it is certainly
 * possible this condition will not hold on other platforms.
 *
 * For tsv-sample, this portability implies generating the same results on different
 * platforms when using the same random seed. This is NOT part of tsv-sample guarantees,
 * but it is convenient for testing. If platforms are identified that do not generate
 * the same results these tests will need to be adjusted.
 */
version(unittest)
{
    /* Unit test helper functions. */

    import unittest_utils;   // tsv unit test helpers, from common/src/.
    import std.conv : to;

    void testTsvSample(string[] cmdArgs, string[][] expected)
    {
        import std.array : appender;
        import std.format : format;

        assert(cmdArgs.length > 0, "[testTsvSample] cmdArgs must not be empty.");

        auto formatAssertMessage(T...)(string msg, T formatArgs)
        {
            auto formatString = "[testTsvSample] %s: " ~ msg;
            return format(formatString, cmdArgs[0], formatArgs);
        }

        TsvSampleOptions cmdopt;
        auto savedCmdArgs = cmdArgs.to!string;
        auto r = cmdopt.processArgs(cmdArgs);
        assert(r[0], formatAssertMessage("Invalid command lines arg: '%s'.", savedCmdArgs));
        auto output = appender!(char[])();

        if (cmdopt.sampleSize == 0)
        {
            reservoirSampling!(Yes.permuteAll)(cmdopt, output);
        }
        else
        {
            reservoirSampling!(No.permuteAll)(cmdopt, output);
        }

        auto expectedOutput = expected.tsvDataToString;

        assert(output.data == expectedOutput,
               formatAssertMessage(
                   "Result != expected:\n=====Expected=====\n%s=====Actual=======\n%s==================",
                   expectedOutput.to!string, output.data.to!string));
    }
 }

unittest
{
    import std.path : buildPath;
    import std.file : rmdirRecurse;
    import std.format : format;

    auto testDir = makeUnittestTempDir("tsv_sample");
    scope(exit) testDir.rmdirRecurse;

    /* Tabular data sets and expected results use the built-in static seed.
     * Tests are run by writing the data set to a file, then calling the main
     * routine to process. The function testTsvSample plays the role of the
     * main program. Rather than writing to expected output, the results are
     * matched against expected. The expected results were verified by hand
     * prior to inclusion in the test.
     *
     * The initial part of this section is simply setting up data files and
     * expected results.
     */

    /* Empty file. */
    string[][] dataEmpty = [];
    string fpath_dataEmpty = buildPath(testDir, "dataEmpty.tsv");
    writeUnittestTsvFile(fpath_dataEmpty, dataEmpty);

    /* 3x1, header only. */
    string[][] data3x0 = [["field_a", "field_b", "field_c"]];
    string fpath_data3x0 = buildPath(testDir, "data3x0.tsv");
    writeUnittestTsvFile(fpath_data3x0, data3x0);

    /* 3x1 */
    string[][] data3x1 =
        [["field_a", "field_b", "field_c"],
         ["tan", "タン", "8.5"]];

    string fpath_data3x1 = buildPath(testDir, "data3x1.tsv");
    string fpath_data3x1_noheader = buildPath(testDir, "data3x1_noheader.tsv");
    writeUnittestTsvFile(fpath_data3x1, data3x1);
    writeUnittestTsvFile(fpath_data3x1_noheader, data3x1[1..$]);

    string[][] data3x2 =
        [["field_a", "field_b", "field_c"],
         ["brown", "褐色", "29.2"],
         ["gray", "グレー", "6.2"]];

    /* 3x2 */
    string fpath_data3x2 = buildPath(testDir, "data3x2.tsv");
    string fpath_data3x2_noheader = buildPath(testDir, "data3x2_noheader.tsv");
    writeUnittestTsvFile(fpath_data3x2, data3x2);
    writeUnittestTsvFile(fpath_data3x2_noheader, data3x2[1..$]);

    string[][] data3x2ExpectedNoWt =
        [["field_a", "field_b", "field_c"],
         ["gray", "グレー", "6.2"],
         ["brown", "褐色", "29.2"]];

    /* 3x3 */
    string[][] data3x3 =
        [["field_a", "field_b", "field_c"],
         ["orange", "オレンジ", "2.5"],
         ["pink", "ピンク", "1.1"],
         ["purple", "紫の", "42"]];

    string fpath_data3x3 = buildPath(testDir, "data3x3.tsv");
    string fpath_data3x3_noheader = buildPath(testDir, "data3x3_noheader.tsv");
    writeUnittestTsvFile(fpath_data3x3, data3x3);
    writeUnittestTsvFile(fpath_data3x3_noheader, data3x3[1..$]);

    string[][] data3x3ExpectedNoWt =
        [["field_a", "field_b", "field_c"],
         ["purple", "紫の", "42"],
         ["pink", "ピンク", "1.1"],
         ["orange", "オレンジ", "2.5"]];

    /* 3x6 */
    string[][] data3x6 =
        [["field_a", "field_b", "field_c"],
         ["red", "赤", "23.8"],
         ["green", "緑", "0.0072"],
         ["white", "白", "1.65"],
         ["yellow", "黄", "12"],
         ["blue", "青", "12"],
         ["black", "黒", "0.983"]];
    string fpath_data3x6 = buildPath(testDir, "data3x6.tsv");
    string fpath_data3x6_noheader = buildPath(testDir, "data3x6_noheader.tsv");
    writeUnittestTsvFile(fpath_data3x6, data3x6);
    writeUnittestTsvFile(fpath_data3x6_noheader, data3x6[1..$]);

    string[][] data3x6ExpectedNoWt =
        [["field_a", "field_b", "field_c"],
         ["yellow", "黄", "12"],
         ["black", "黒", "0.983"],
         ["blue", "青", "12"],
         ["white", "白", "1.65"],
         ["green", "緑", "0.0072"],
         ["red", "赤", "23.8"]];

    string[][] data3x6ExpectedNoWtProbs =
        [["random_weight", "field_a", "field_b", "field_c"],
         ["0.960555462865159", "yellow", "黄", "12"],
         ["0.757101539289579", "black", "黒", "0.983"],
         ["0.525259808870032", "blue", "青", "12"],
         ["0.492878549499437", "white", "白", "1.65"],
         ["0.159293440869078", "green", "緑", "0.0072"],
         ["0.010968807619065", "red", "赤", "23.8"]];

    string[][] data3x6ExpectedWt3Probs =
        [["random_weight", "field_a", "field_b", "field_c"],
         ["0.996651987576454", "yellow", "黄", "12"],
         ["0.947758848098367", "blue", "青", "12"],
         ["0.827282346822867", "red", "赤", "23.8"],
         ["0.75346697377182", "black", "黒", "0.983"],
         ["0.651301034964225", "white", "白", "1.65"],
         ["1.56369437128799e-111", "green", "緑", "0.0072"]];

    string[][] data3x6ExpectedWt3 =
        [["field_a", "field_b", "field_c"],
         ["yellow", "黄", "12"],
         ["blue", "青", "12"],
         ["red", "赤", "23.8"],
         ["black", "黒", "0.983"],
         ["white", "白", "1.65"],
         ["green", "緑", "0.0072"]];

    /* Using a different static seed. */
    string[][] data3x6ExpectedNoWtV41Probs =
        [["random_weight", "field_a", "field_b", "field_c"],
         ["0.680572726530954", "green", "緑", "0.0072"],
         ["0.676816243678331", "blue", "青", "12"],
         ["0.32097338931635", "yellow", "黄", "12"],
         ["0.250923618674278", "red", "赤", "23.8"],
         ["0.155359342927113", "black", "黒", "0.983"],
         ["0.0460958210751414", "white", "白", "1.65"]];

    string[][] data3x6ExpectedWt3V41Probs =
        [["random_weight", "field_a", "field_b", "field_c"],
         ["0.967993774989107", "blue", "青", "12"],
         ["0.943562457925736", "red", "赤", "23.8"],
         ["0.90964601024272", "yellow", "黄", "12"],
         ["0.154916584092601", "white", "白", "1.65"],
         ["0.15043620392537", "black", "黒", "0.983"],
         ["6.13946748307015e-24", "green", "緑", "0.0072"]];


    /* Combo 1: 3x3, 3x1, 3x6, 3x2. No data files, only expected results. */
    string[][] combo1ExpectedNoWt =
        [["field_a", "field_b", "field_c"],
         ["yellow", "黄", "12"],
         ["tan", "タン", "8.5"],
         ["brown", "褐色", "29.2"],
         ["green", "緑", "0.0072"],
         ["red", "赤", "23.8"],
         ["purple", "紫の", "42"],
         ["black", "黒", "0.983"],
         ["white", "白", "1.65"],
         ["gray", "グレー", "6.2"],
         ["blue", "青", "12"],
         ["pink", "ピンク", "1.1"],
         ["orange", "オレンジ", "2.5"]];

    string[][] combo1ExpectedNoWtProbs =
        [["random_weight", "field_a", "field_b", "field_c"],
         ["0.970885202754289", "yellow", "黄", "12"],
         ["0.960555462865159", "tan", "タン", "8.5"],
         ["0.817568943137303", "brown", "褐色", "29.2"],
         ["0.757101539289579", "green", "緑", "0.0072"],
         ["0.525259808870032", "red", "赤", "23.8"],
         ["0.492878549499437", "purple", "紫の", "42"],
         ["0.470815070671961", "black", "黒", "0.983"],
         ["0.383881829213351", "white", "白", "1.65"],
         ["0.292159906122833", "gray", "グレー", "6.2"],
         ["0.240332160145044", "blue", "青", "12"],
         ["0.159293440869078", "pink", "ピンク", "1.1"],
         ["0.010968807619065", "orange", "オレンジ", "2.5"]];

    string[][] combo1ExpectedWt3Probs =
        [["random_weight", "field_a", "field_b", "field_c"],
         ["0.997540775237188", "yellow", "黄", "12"],
         ["0.995276654400888", "tan", "タン", "8.5"],
         ["0.993125789457417", "brown", "褐色", "29.2"],
         ["0.983296025533894", "purple", "紫の", "42"],
         ["0.973309619380837", "red", "赤", "23.8"],
         ["0.887975515217396", "blue", "青", "12"],
         ["0.819992304890418", "gray", "グレー", "6.2"],
         ["0.559755692042509", "white", "白", "1.65"],
         ["0.464721356092057", "black", "黒", "0.983"],
         ["0.188245827041913", "pink", "ピンク", "1.1"],
         ["0.164461318532999", "orange", "オレンジ", "2.5"],
         ["1.64380869310205e-17", "green", "緑", "0.0072"]];

    string[][] combo1ExpectedWt3 =
        [["field_a", "field_b", "field_c"],
         ["yellow", "黄", "12"],
         ["tan", "タン", "8.5"],
         ["brown", "褐色", "29.2"],
         ["purple", "紫の", "42"],
         ["red", "赤", "23.8"],
         ["blue", "青", "12"],
         ["gray", "グレー", "6.2"],
         ["white", "白", "1.65"],
         ["black", "黒", "0.983"],
         ["pink", "ピンク", "1.1"],
         ["orange", "オレンジ", "2.5"],
         ["green", "緑", "0.0072"]];

    /* 1x10 - Simple 1-column file. */
    string[][] data1x10 =
        [["field_a"], ["1"], ["2"], ["3"], ["4"], ["5"], ["6"], ["7"], ["8"], ["9"], ["10"]];
    string fpath_data1x10 = buildPath(testDir, "data1x10.tsv");
    string fpath_data1x10_noheader = buildPath(testDir, "data1x10_noheader.tsv");
    writeUnittestTsvFile(fpath_data1x10, data1x10);
    writeUnittestTsvFile(fpath_data1x10_noheader, data1x10[1..$]);

    string[][] data1x10ExpectedNoWt =
        [["field_a"], ["8"], ["4"], ["6"], ["5"], ["3"], ["10"], ["7"], ["9"], ["2"], ["1"]];

    string[][] data1x10ExpectedWt1 =
        [["field_a"], ["8"], ["4"], ["6"], ["10"], ["5"], ["7"], ["9"], ["3"], ["2"], ["1"]];

    /* 2x10a - Uniform distribution [0,1]. */
    string[][] data2x10a =
        [["line", "weight"],
         ["1", "0.26788837"],
         ["2", "0.06601298"],
         ["3", "0.38627527"],
         ["4", "0.47379424"],
         ["5", "0.02966641"],
         ["6", "0.05636231"],
         ["7", "0.70529242"],
         ["8", "0.91836862"],
         ["9", "0.99103720"],
         ["10", "0.31401740"]];

    string fpath_data2x10a = buildPath(testDir, "data2x10a.tsv");
    writeUnittestTsvFile(fpath_data2x10a, data2x10a);

    string[][] data2x10aExpectedWt2Probs =
        [["random_weight", "line", "weight"],
         ["0.968338654945437", "8", "0.91836862"],
         ["0.918568420544139", "4", "0.47379424"],
         ["0.257308320877951", "7", "0.70529242"],
         ["0.237253179070181", "9", "0.99103720"],
         ["0.160160967018722", "3", "0.38627527"],
         ["0.0908196626672434", "10", "0.31401740"],
         ["0.00717645392443612", "6", "0.05636231"],
         ["4.83186429516301e-08", "1", "0.26788837"],
         ["3.75256929665355e-10", "5", "0.02966641"],
         ["8.21232478800958e-13", "2", "0.06601298"]];

    /* 2x10b - Uniform distribution [0,1000]. */
    string[][] data2x10b =
        [["line", "weight"],
         ["1", "761"],
         ["2", "432"],
         ["3", "103"],
         ["4", "448"],
         ["5", "750"],
         ["6", "711"],
         ["7", "867"],
         ["8", "841"],
         ["9", "963"],
         ["10", "784"]];

    string fpath_data2x10b = buildPath(testDir, "data2x10b.tsv");
    writeUnittestTsvFile(fpath_data2x10b, data2x10b);

    string[][] data2x10bExpectedWt2Probs =
        [["random_weight", "line", "weight"],
         ["0.99996486739068", "8", "841"],
         ["0.999910174671372", "4", "448"],
         ["0.999608715248737", "6", "711"],
         ["0.999141885371438", "5", "750"],
         ["0.999039632502748", "10", "784"],
         ["0.998896318259319", "7", "867"],
         ["0.998520583151911", "9", "963"],
         ["0.995756696791589", "2", "432"],
         ["0.994087587320506", "1", "761"],
         ["0.993154677612124", "3", "103"]];

    /* 2x10c - Logarithmic distribution in random order. */
    string[][] data2x10c =
        [["line", "weight"],
         ["1", "31.85"],
         ["2", "17403.31"],
         ["3", "653.84"],
         ["4", "8.23"],
         ["5", "2671.04"],
         ["6", "26226.08"],
         ["7", "1.79"],
         ["8", "354.56"],
         ["9", "35213.81"],
         ["10", "679.29"]];

    string fpath_data2x10c = buildPath(testDir, "data2x10c.tsv");
    writeUnittestTsvFile(fpath_data2x10c, data2x10c);

    string[][] data2x10cExpectedWt2Probs =
        [["random_weight", "line", "weight"],
         ["0.999989390087097", "6", "26226.08"],
         ["0.999959512916955", "9", "35213.81"],
         ["0.999916669076135", "8", "354.56"],
         ["0.999894450521864", "2", "17403.31"],
         ["0.999758976028616", "5", "2671.04"],
         ["0.998918527698776", "3", "653.84"],
         ["0.998891677527825", "10", "679.29"],
         ["0.995122075068501", "4", "8.23"],
         ["0.86789371584259", "1", "31.85"],
         ["0.585744381629156", "7", "1.79"]];

    /* 2x10d. Logarithmic distribution in ascending order. */
    string[][] data2x10d =
        [["line", "weight"],
         ["1", "1.79"],
         ["2", "8.23"],
         ["3", "31.85"],
         ["4", "354.56"],
         ["5", "653.84"],
         ["6", "679.29"],
         ["7", "2671.04"],
         ["8", "17403.31"],
         ["9", "26226.08"],
         ["10", "35213.81"]];

    string fpath_data2x10d = buildPath(testDir, "data2x10d.tsv");
    writeUnittestTsvFile(fpath_data2x10d, data2x10d);

    string[][] data2x10dExpectedWt2Probs =
        [["random_weight", "line", "weight"],
         ["0.999998302218464", "8", "17403.31"],
         ["0.999978608340414", "10", "35213.81"],
         ["0.999945638289867", "9", "26226.08"],
         ["0.999886503635757", "4", "354.56"],
         ["0.999641619391901", "7", "2671.04"],
         ["0.999590453389486", "6", "679.29"],
         ["0.999015744906398", "5", "653.84"],
         ["0.978031633047474", "3", "31.85"],
         ["0.799947918069109", "2", "8.23"],
         ["0.0803742612399491", "1", "1.79"]];

    /* 2x10e. Logarithmic distribution in descending order. */
    string[][] data2x10e =
        [["line", "weight"],
         ["1", "35213.81"],
         ["2", "26226.08"],
         ["3", "17403.31"],
         ["4", "2671.04"],
         ["5", "679.29"],
         ["6", "653.84"],
         ["7", "354.56"],
         ["8", "31.85"],
         ["9", "8.23"],
         ["10", "1.79"]];
    string fpath_data2x10e = buildPath(testDir, "data2x10e.tsv");
    writeUnittestTsvFile(fpath_data2x10e, data2x10e);

    string[][] data2x10eExpectedWt2Probs =
        [["random_weight", "line", "weight"],
         ["0.999984933489752", "4", "2671.04"],
         ["0.999959348072026", "3", "17403.31"],
         ["0.999929957397275", "2", "26226.08"],
         ["0.999871856792456", "1", "35213.81"],
         ["0.999574515631739", "6", "653.84"],
         ["0.999072736502096", "8", "31.85"],
         ["0.999052603129689", "5", "679.29"],
         ["0.997303336505164", "7", "354.56"],
         ["0.840939024352278", "9", "8.23"],
         ["0.6565001592629", "10", "1.79"]];

    /*
     * Enough setup! Actually run some tests!
     */

    /* Basic tests. Headers and static seed. With weights and without. */
    testTsvSample(["test-a1", "--header", "--static-seed", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-a2", "--header", "--static-seed", fpath_data3x0], data3x0);
    testTsvSample(["test-a3", "-H", "-s", fpath_data3x1], data3x1);
    testTsvSample(["test-a4", "-H", "-s", fpath_data3x2], data3x2ExpectedNoWt);
    testTsvSample(["test-a5", "-H", "-s", fpath_data3x3], data3x3ExpectedNoWt);
    testTsvSample(["test-a6", "-H", "-s", fpath_data3x6], data3x6ExpectedNoWt);
    testTsvSample(["test-a7", "-H", "-s", "--print-random", fpath_data3x6], data3x6ExpectedNoWtProbs);
    testTsvSample(["test-a8", "-H", "-s", "--field", "3", fpath_data3x6], data3x6ExpectedWt3);
    testTsvSample(["test-a9", "-H", "-s", "-p", "-f", "3", fpath_data3x6], data3x6ExpectedWt3Probs);
    testTsvSample(["test-a10", "-H", "--seed-value", "41", "-p", fpath_data3x6], data3x6ExpectedNoWtV41Probs);
    testTsvSample(["test-a11", "-H", "-s", "-v", "41", "-p", fpath_data3x6], data3x6ExpectedNoWtV41Probs);
    testTsvSample(["test-a12", "-H", "-s", "-v", "0", "-p", fpath_data3x6], data3x6ExpectedNoWtProbs);
    testTsvSample(["test-a13", "-H", "-v", "41", "-f", "3", "-p", fpath_data3x6], data3x6ExpectedWt3V41Probs);

    /* Basic tests, without headers. */
    testTsvSample(["test-b1", "-s", fpath_data3x1_noheader], data3x1[1..$]);
    testTsvSample(["test-b2", "-s", fpath_data3x2_noheader], data3x2ExpectedNoWt[1..$]);
    testTsvSample(["test-b3", "-s", fpath_data3x3_noheader], data3x3ExpectedNoWt[1..$]);
    testTsvSample(["test-b4", "-s", fpath_data3x6_noheader], data3x6ExpectedNoWt[1..$]);
    testTsvSample(["test-b5", "-s", "--print-random", fpath_data3x6_noheader], data3x6ExpectedNoWtProbs[1..$]);
    testTsvSample(["test-b6", "-s", "--field", "3", fpath_data3x6_noheader], data3x6ExpectedWt3[1..$]);
    testTsvSample(["test-b7", "-s", "-p", "-f", "3", fpath_data3x6_noheader], data3x6ExpectedWt3Probs[1..$]);
    testTsvSample(["test-b8", "-v", "41", "-p", fpath_data3x6_noheader], data3x6ExpectedNoWtV41Probs[1..$]);
    testTsvSample(["test-b9", "-v", "41", "-f", "3", "-p", fpath_data3x6_noheader], data3x6ExpectedWt3V41Probs[1..$]);

    /* Multi-file tests. */
    testTsvSample(["test-c1", "--header", "--static-seed",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedNoWt);
    testTsvSample(["test-c2", "--header", "--static-seed", "--print-random",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedNoWtProbs);
    testTsvSample(["test-c3", "--header", "--static-seed", "--print-random", "--field", "3",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedWt3Probs);
    testTsvSample(["test-c4", "--header", "--static-seed", "--field", "3",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedWt3);

    /* Multi-file, no headers. */
    testTsvSample(["test-c5", "--static-seed",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedNoWt[1..$]);
    testTsvSample(["test-c6", "--static-seed", "--print-random",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedNoWtProbs[1..$]);
    testTsvSample(["test-c7", "--static-seed", "--print-random", "--field", "3",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedWt3Probs[1..$]);
    testTsvSample(["test-c8", "--static-seed", "--field", "3",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedWt3[1..$]);

    /* Single column file. */
    testTsvSample(["test-d1", "-H", "-s", fpath_data1x10], data1x10ExpectedNoWt);
    testTsvSample(["test-d1", "-H", "-s", fpath_data1x10], data1x10ExpectedNoWt);

    /* Distributions. */
    testTsvSample(["test-e1", "-H", "-s", "-f", "2", "-p", fpath_data2x10a], data2x10aExpectedWt2Probs);
    testTsvSample(["test-e1", "-H", "-s", "-f", "2", "-p", fpath_data2x10b], data2x10bExpectedWt2Probs);
    testTsvSample(["test-e1", "-H", "-s", "-f", "2", "-p", fpath_data2x10c], data2x10cExpectedWt2Probs);
    testTsvSample(["test-e1", "-H", "-s", "-f", "2", "-p", fpath_data2x10d], data2x10dExpectedWt2Probs);
    testTsvSample(["test-e1", "-H", "-s", "-f", "2", "-p", fpath_data2x10e], data2x10eExpectedWt2Probs);

    /* Tests of subset sample (--n|num) field.
     *
     * Note: The way these tests are done ensures that subset length does not affect
     * output order.
     */
    import std.algorithm : min;
    for (size_t n = data3x6.length + 2; n >= 1; n--)
    {
        size_t expectedLength = min(data3x6.length, n + 1);
        testTsvSample([format("test-f1_%d", n), "-s", "-n", n.to!string,
                       "-H", fpath_data3x6], data3x6ExpectedNoWt[0..expectedLength]);

        testTsvSample([format("test-f2_%d", n), "-s", "-n", n.to!string,
                       "-H", "-p", fpath_data3x6], data3x6ExpectedNoWtProbs[0..expectedLength]);

        testTsvSample([format("test-f3_%d", n), "-s", "-n", n.to!string,
                       "-H", "-f", "3", fpath_data3x6], data3x6ExpectedWt3[0..expectedLength]);

        testTsvSample([format("test-f4_%d", n), "-s", "-n", n.to!string,
                       "-H", "-p", "-f", "3", fpath_data3x6], data3x6ExpectedWt3Probs[0..expectedLength]);

        testTsvSample([format("test-f5_%d", n), "-s", "-n", n.to!string,
                       fpath_data3x6_noheader], data3x6ExpectedNoWt[1..expectedLength]);

        testTsvSample([format("test-f6_%d", n), "-s", "-n", n.to!string,
                       "-p", fpath_data3x6_noheader], data3x6ExpectedNoWtProbs[1..expectedLength]);

        testTsvSample([format("test-f7_%d", n), "-s", "-n", n.to!string,
                       "-f", "3", fpath_data3x6_noheader], data3x6ExpectedWt3[1..expectedLength]);

        testTsvSample([format("test-f8_%d", n), "-s", "-n", n.to!string,
                       "-p", "-f", "3", fpath_data3x6_noheader], data3x6ExpectedWt3Probs[1..expectedLength]);
    }

    /* Similar tests with the 1x10 data set. */
    for (size_t n = data1x10.length + 2; n >= 1; n--)
    {
        size_t expectedLength = min(data1x10.length, n + 1);
        testTsvSample([format("test-g1_%d", n), "-s", "-n", n.to!string,
                       "-H", fpath_data1x10], data1x10ExpectedNoWt[0..expectedLength]);

        testTsvSample([format("test-g2_%d", n), "-s", "-n", n.to!string,
                       "-H", "-f", "1", fpath_data1x10], data1x10ExpectedWt1[0..expectedLength]);

        testTsvSample([format("test-g3_%d", n), "-s", "-n", n.to!string,
                       fpath_data1x10_noheader], data1x10ExpectedNoWt[1..expectedLength]);

        testTsvSample([format("test-g4_%d", n), "-s", "-n", n.to!string,
                       "-f", "1", fpath_data1x10_noheader], data1x10ExpectedWt1[1..expectedLength]);
    }
}
