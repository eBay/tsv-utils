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

/* Unit tests for the main program start here.
 */
version(unittest)
{
    /* Unit test helper functions. */

    import unittest_utils;   // tsv unit test helpers, from common/src/.
    import std.conv;

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
        weightedReservoirSamplingES(cmdopt, output);
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

    /* Basic tests, without headers. */
    testTsvSample(["test-b1", "-s", fpath_data3x1_noheader], data3x1[1..$]);
    testTsvSample(["test-b2", "-s", fpath_data3x2_noheader], data3x2ExpectedNoWt[1..$]);
    testTsvSample(["test-b3", "-s", fpath_data3x3_noheader], data3x3ExpectedNoWt[1..$]);
    testTsvSample(["test-b4", "-s", fpath_data3x6_noheader], data3x6ExpectedNoWt[1..$]);
    testTsvSample(["test-b5", "-s", "--print-random", fpath_data3x6_noheader], data3x6ExpectedNoWtProbs[1..$]);
    testTsvSample(["test-b6", "-s", "--field", "3", fpath_data3x6_noheader], data3x6ExpectedWt3[1..$]);
    testTsvSample(["test-b7", "-s", "-p", "-f", "3", fpath_data3x6_noheader], data3x6ExpectedWt3Probs[1..$]);

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

    /* Tests of subset requested lengths (--n|num) field. */
    import std.algorithm : min;
    for (size_t n = data3x6.length + 2; n >= 1; n--)
    {
        size_t expectedLength = min(data3x6.length, n + 1);
        testTsvSample([format("test-f1_%d", n), "-s", "-n", n.to!string, "-H", fpath_data3x6], data3x6ExpectedNoWt[0..expectedLength]);
        testTsvSample([format("test-f2_%d", n), "-s", "-n", n.to!string, "-H", "-p", fpath_data3x6], data3x6ExpectedNoWtProbs[0..expectedLength]);
        testTsvSample([format("test-f3_%d", n), "-s", "-n", n.to!string, "-H", "-f", "3", fpath_data3x6], data3x6ExpectedWt3[0..expectedLength]);
        testTsvSample([format("test-f4_%d", n), "-s", "-n", n.to!string, "-H", "-p", "-f", "3", fpath_data3x6], data3x6ExpectedWt3Probs[0..expectedLength]);

        testTsvSample([format("test-f5_%d", n), "-s", "-n", n.to!string, fpath_data3x6_noheader], data3x6ExpectedNoWt[1..expectedLength]);
        testTsvSample([format("test-f6_%d", n), "-s", "-n", n.to!string, "-p", fpath_data3x6_noheader], data3x6ExpectedNoWtProbs[1..expectedLength]);
        testTsvSample([format("test-f7_%d", n), "-s", "-n", n.to!string, "-f", "3", fpath_data3x6_noheader], data3x6ExpectedWt3[1..expectedLength]);
        testTsvSample([format("test-f8_%d", n), "-s", "-n", n.to!string, "-p", "-f", "3", fpath_data3x6_noheader], data3x6ExpectedWt3Probs[1..expectedLength]);
    }


    /* TODO - Error condition tests. */
}
