/**
Command line tool that appends multiple TSV files. It is header aware and supports
tracking the original source file of each row.

Copyright (c) 2017, eBay Software Foundation
Initially written by Jon Degenhardt

License: Boost License 1.0 (http://boost.org/LICENSE_1_0.txt) 
*/
module tsv_append;

import std.conv : to;
import std.range;
import std.stdio;
import std.typecons : tuple;

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
    
        TsvAppendOptions cmdopt;
        auto r = cmdopt.processArgs(cmdArgs);
        if (!r[0]) return r[1];
        try tsvAppend(cmdopt, stdout.lockingTextWriter);
        catch (Exception exc)
        {
            stderr.writefln("Error [%s]: %s", cmdopt.programName, exc.msg);
            return 1;
        }
        return 0;
    }
}

auto helpTextVerbose = q"EOS
Synopsis: tsv-append [options] [file...]

tsv-append concatenates multiple TSV files, similar to the Unix 'cat' utility.
Unlike 'cat', it is header aware ('--H|header'), writing the header from only
the first file. It also supports source tracking, adding a column indicating
the original file to each row. Results are written to standard output.

Concatenation with header support is useful when preparing data for traditional
Unix utilities like 'sort' and 'sed' or applications that read a single file.

Source tracking is useful when creating long/narrow form tabular data, a format
used by many statistics and data mining packages. In this scenario, files have
been used to capture related data sets, the difference between data sets being a
condition represented by the file. For example, results from different variants
of an experiment might each be recorded in their own files. Retaining the source
file as an output column preserves the condition represented by the file.

The file-name (without extension) is used as the source value. This can
customized using the --f|file option.

Example: Header processing:

   $ tsv-append -H file1.tsv file2.tsv file3.tsv

Example: Header processing and source tracking:

   $ tsv-append -H -t file1.tsv file2.tsv file3.tsv

Example: Source tracking with custom values:

   $ tsv-append -H -s test_id -f test1=file1.tsv -f test2=file2.tsv

Options:
EOS";

auto helpText = q"EOS
Synopsis: tsv-append [options] [file...]

tsv-append concatenates multiple TSV files, reading from files or standard input
and writing to standard output. It is header aware ('--H|header'), writing the
header from only the first file. It also supports source tracking, adding an
indicator of original file to each row of input.

Options:
EOS";

struct TsvAppendOptions
{
    string programName;
    string[] files;                    // Input files 
    string[string] fileSourceNames;    // Maps file path to the 'source' value
    bool helpVerbose = false;          // --help-verbose
    string sourceHeader;               // --s|source-header
    bool trackSource = false;          // --t|track-source
    bool hasHeader = false;            // --H|header
    char delim = '\t';                 // --d|delimiter
    bool versionWanted = false;        // --V|version

    /* fileOptionHandler processes the '--f|file source=file' option. */
    private void fileOptionHandler(string option, string optionVal)
    {
        import std.algorithm : findSplit;
        import std.format : format;

        auto valSplit = findSplit(optionVal, "=");
        if (valSplit[0].empty || valSplit[2].empty)
            throw new Exception(
                format("Invalid option value: '--%s %s'. Expected: '--%s <source>=<file>'.",
                       option, optionVal, option));

        auto source = valSplit[0];
        auto filepath = valSplit[2];
        files ~= filepath;
        fileSourceNames[filepath] = source;
    }
    
    /* Returns a tuple. First value is true if command line arguments were successfully
     * processed and execution should continue, or false if an error occurred or the user
     * asked for help. If false, the second value is the appropriate exit code (0 or 1).
     *
     * Returning true (execution continues) means args have been validated and derived
     * values calculated. In addition, field indices have been converted to zero-based.
     * If the whole line is the key, the individual fields list will be cleared.
     */
    auto processArgs (ref string[] cmdArgs)
    {
        import std.algorithm : any, each;
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
                "H|header",        "          Treat the first line of each file as a header.", &hasHeader,
                std.getopt.config.caseInsensitive,
                "t|track-source",  "          Track the source file. Adds an column with the source name.", &trackSource,
                "s|source-header", "STR       Use STR as the header for the source column. Implies --H|header and --t|track-source. Default: 'file'", &sourceHeader,
                "f|file",          "STR=FILE  Read file FILE, using STR as the 'source' value. Implies --t|track-source.", &fileOptionHandler, 
                "d|delimiter",     "CHR       Field delimiter. Default: TAB. (Single byte UTF-8 characters only.)", &delim,
                std.getopt.config.caseSensitive,
                "V|version",       "          Print version information and exit.", &versionWanted,
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
                writeln(tsvutilsVersionNotice("tsv-append"));
                return tuple(false, 0);
            }

            /* Derivations and consistency checks. */
            if (files.length > 0 || !sourceHeader.empty) trackSource = true;
            if (!sourceHeader.empty) hasHeader = true;
            if (hasHeader && sourceHeader.empty) sourceHeader = "file";
            
            /* Assume the remaing arguments are filepaths. */
            foreach (fp; cmdArgs[1 .. $])
            {
                import std.path : baseName, stripExtension;
                files ~= fp;
                fileSourceNames[fp] = fp.stripExtension.baseName;
            }

            /* Add a name mapping for dash ('-') unless it was included in the --file option. */
            if ("-" !in fileSourceNames) fileSourceNames["-"] = "stdin";
        }
        catch (Exception exc)
        {
            stderr.writefln("[%s] Error processing command line arguments: %s", programName, exc.msg);
            return tuple(false, 1);
        }
        return tuple(true, 0);
    }
}

void tsvAppend(OutputRange)(TsvAppendOptions cmdopt, OutputRange outputStream)
    if (isOutputRange!(OutputRange, char))
{
    bool headerWritten = false;
    foreach (filename; (cmdopt.files.length > 0) ? cmdopt.files : ["-"])
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        auto sourceName = cmdopt.fileSourceNames[filename];
        foreach (fileLineNum, line; inputStream.byLine(KeepTerminator.yes).enumerate(1))
        {
            if (cmdopt.hasHeader && fileLineNum == 1)
            {
                if (!headerWritten)
                {
                    if (cmdopt.trackSource)
                    {
                        outputStream.put(cmdopt.sourceHeader);
                        outputStream.put(cmdopt.delim);
                    }
                    outputStream.put(line);
                    headerWritten = true;
                }
            }
            else
            {
                if (cmdopt.trackSource)
                {
                    outputStream.put(sourceName);
                    outputStream.put(cmdopt.delim);
                }
                outputStream.put(line);
            }
        }
    }
}

version(unittest)
{
    /* Unit test helper functions. */

    import unittest_utils;   // tsv unit test helpers, from common/src/.

    void testTsvAppend(string[] cmdArgs, string[][] expected)
    {
        import std.array : appender;
        import std.format : format;
        
        assert(cmdArgs.length > 0, "[testTsvAppend] cmdArgs must not be empty.");

        auto formatAssertMessage(T...)(string msg, T formatArgs)
        {
            auto formatString = "[testTsvAppend] %s: " ~ msg;
            return format(formatString, cmdArgs[0], formatArgs);
        }

        TsvAppendOptions cmdopt;
        auto savedCmdArgs = cmdArgs.to!string;
        auto r = cmdopt.processArgs(cmdArgs);
        assert(r[0], formatAssertMessage("Invalid command lines arg: '%s'.", savedCmdArgs));

        auto output = appender!(char[])();
        tsvAppend(cmdopt, output);
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
    
    auto testDir = makeUnittestTempDir("tsv_append");
    scope(exit) testDir.rmdirRecurse;

    string[][] data1 =
        [["field_a", "field_b", "field_c"],
         ["red", "17", "κόκκινος"],
         ["blue", "12", "άσπρο"]];

    string[][] data2 =
        [["field_a", "field_b", "field_c"],
         ["green", "13.5", "κόκκινος"],
         ["blue", "15", "πράσινος"]];

    string[][] data3 =
        [["field_a", "field_b", "field_c"],
         ["yellow", "9", "κίτρινος"]];

    string[][] dataHeaderRowOnly =
        [["field_a", "field_b", "field_c"]];

    string[][] dataEmpty = [[]];

    string filepath1 = buildPath(testDir, "file1.tsv");
    string filepath2 = buildPath(testDir, "file2.tsv");
    string filepath3 = buildPath(testDir, "file3.tsv");
    string filepathHeaderRowOnly = buildPath(testDir, "fileHeaderRowOnly.tsv");
    string filepathEmpty = buildPath(testDir, "fileEmpty.tsv");

    writeUnittestTsvFile(filepath1, data1);
    writeUnittestTsvFile(filepath2, data2);
    writeUnittestTsvFile(filepath3, data3);
    writeUnittestTsvFile(filepathHeaderRowOnly, dataHeaderRowOnly);
    writeUnittestTsvFile(filepathEmpty, dataEmpty);

    testTsvAppend(["test-1", filepath1], data1);
    testTsvAppend(["test-2", "--header", filepath1], data1);
    testTsvAppend(["test-3", filepath1, filepath2], data1 ~ data2);

    testTsvAppend(["test-4", "--header", filepath1, filepath2],
                  [["field_a", "field_b", "field_c"],
                   ["red", "17", "κόκκινος"],
                   ["blue", "12", "άσπρο"],
                   ["green", "13.5", "κόκκινος"],
                   ["blue", "15", "πράσινος"]]);

    testTsvAppend(["test-5", "--header", filepath1, filepath2, filepath3],
                  [["field_a", "field_b", "field_c"],
                   ["red", "17", "κόκκινος"],
                   ["blue", "12", "άσπρο"],
                   ["green", "13.5", "κόκκινος"],
                   ["blue", "15", "πράσινος"],                   
                   ["yellow", "9", "κίτρινος"]]);

    testTsvAppend(["test-6", filepath1, filepathEmpty, filepath2, filepathHeaderRowOnly, filepath3],
                  data1 ~ dataEmpty ~ data2 ~ dataHeaderRowOnly ~ data3);

    testTsvAppend(["test-7", "--header", filepath1, filepathEmpty, filepath2, filepathHeaderRowOnly, filepath3],
                  [["field_a", "field_b", "field_c"],
                   ["red", "17", "κόκκινος"],
                   ["blue", "12", "άσπρο"],
                   ["green", "13.5", "κόκκινος"],
                   ["blue", "15", "πράσινος"],                   
                   ["yellow", "9", "κίτρινος"]]);

    testTsvAppend(["test-8", "--track-source", filepath1, filepath2],
                  [["file1", "field_a", "field_b", "field_c"],
                   ["file1", "red", "17", "κόκκινος"],
                   ["file1", "blue", "12", "άσπρο"],
                   ["file2", "field_a", "field_b", "field_c"],
                   ["file2", "green", "13.5", "κόκκινος"],
                   ["file2", "blue", "15", "πράσινος"]]);

    testTsvAppend(["test-9", "--header", "--track-source", filepath1, filepath2],
                  [["file", "field_a", "field_b", "field_c"],
                   ["file1", "red", "17", "κόκκινος"],
                   ["file1", "blue", "12", "άσπρο"],
                   ["file2", "green", "13.5", "κόκκινος"],
                   ["file2", "blue", "15", "πράσινος"]]);

    testTsvAppend(["test-10", "-H", "-t", "--source-header", "source",
                   filepath1, filepathEmpty, filepath2, filepathHeaderRowOnly, filepath3],
                  [["source", "field_a", "field_b", "field_c"],
                   ["file1", "red", "17", "κόκκινος"],
                   ["file1", "blue", "12", "άσπρο"],
                   ["file2", "green", "13.5", "κόκκινος"],
                   ["file2", "blue", "15", "πράσινος"],
                   ["file3", "yellow", "9", "κίτρινος"]]);

    testTsvAppend(["test-11", "-H", "-t", "-s", "id", "--file", format("1a=%s", filepath1),
                   "--file", format("1b=%s", filepath2), "--file", format("1c=%s", filepath3)],
                  [["id", "field_a", "field_b", "field_c"],
                   ["1a", "red", "17", "κόκκινος"],
                   ["1a", "blue", "12", "άσπρο"],
                   ["1b", "green", "13.5", "κόκκινος"],
                   ["1b", "blue", "15", "πράσινος"],
                   ["1c", "yellow", "9", "κίτρινος"]]);

    testTsvAppend(["test-12", "-s", "id", "-f", format("1a=%s", filepath1),
                   "-f", format("1b=%s", filepath2), filepath3],
                  [["id", "field_a", "field_b", "field_c"],
                   ["1a", "red", "17", "κόκκινος"],
                   ["1a", "blue", "12", "άσπρο"],
                   ["1b", "green", "13.5", "κόκκινος"],
                   ["1b", "blue", "15", "πράσινος"],
                   ["file3", "yellow", "9", "κίτρινος"]]);
}
