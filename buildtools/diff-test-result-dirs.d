/**
This tool runs diff comparisons of command line test output files.

This tool supports a common TSV Utilities testing paradigm: Running command line
tests on the built executables to produce a set of outputs from an existing set
of tests. Test results are written to a files in a directory and compared to a
"gold" set of outputs known to be correct.

This tool runs a version of directory diff support multiple correct output versions.
This is to handle the case where different compiler/library versions have different
valid outputs. The most common case is changes to error message text.

Copyright (c) 2018-2020, eBay Inc.
Initially written by Jon Degenhardt

License: Boost License 1.0 (http://boost.org/LICENSE_1_0.txt)

*/
module buildtools.diff_test_result_dirs;

import std.conv : to;
import std.range;
import std.stdio;
import std.file;
import std.typecons : tuple;
import std.process : ProcessException;

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

        DiffOptions cmdopt;
        auto r = cmdopt.processArgs(cmdArgs);
        if (!r[0]) return r[1];

        int result = 0;
        try result = diffTestResultDirs(cmdopt);
        catch (Exception e)
        {
            stderr.writefln("Error [%s]: %s", cmdopt.programName, e.msg);
            result = 1;
        }
        return result;
    }
}

auto helpText = q"EOS
Synopsis: diff-test-result-files [options] <test-dir>

This tool runs diff comparisons of test output files. It is a modified form of
directory diff, comparing output files from a test run to output files from a known
good outputs (a "gold" set). The primary difference from a normal directory diff is
that the gold set may include multiple versions of a result file. A test output file
is considered correct if it matches any of the variants. Variants are specified in a
JSON config file and are used to support compiler multiple versions.

This tool was developed for TSV Utilities tests and the default arguments support
this. The one required argument is <test-dir> and is usually 'latest_debug' or
'latest_release' corresponding to the types of test runs used in TSV Utilities tests.

The exit status provides the result status. Zero indicates success (no differences),
one indicates failure (differences).

Options:
EOS";

auto helpTextVerbose = q"EOS
Synopsis: diff-test-result-dirs [options] <test-dir>

This tool runs diff comparisons of test result files. The exit status gives the diff
status. Zero indicates success (no differences), one indicates failure (differences).

This tool was developed for TSV Utilities command line tests. Command line tests work
by running a tool against a set of command line test inputs. Results are written to
files and compared to a "gold" set of correct results. Tests generate one or more
output files; all written to a single directory. The resulting comparison is a "test"
directory vs a "gold" directory.

A directory level 'diff' is sufficient in many cases. This is the default behavior of
this tool. In some cases the corrent results depend on the compiler version. The main
case is error tests, where the output message may differ between runtime library
versions. (TSV Utilities often include exception message text in error output.)

The latter case is what this tool was developed for. It allows for multiple versions
of an output file in the gold set. The files used in the test are read from a JSON
config file. The config file also contains the set of version files available. The
effect is to run a modified form of directory diff, comparing the "test" directory
against the "gold" directory, allowing for the presence of version files.

The presence of the config file triggers the version-aware diff. A plain directory
diff is run if there is no config file.

An example JSON config file is shown below. Each output file has an entry with one
required element, "name", and one optional element, "versions". If present,
"versions" contains a list of alternate test files.

    ==== test-config.json ====
    {
        "output_files" : [
            {
                "name" : "test_1.txt"
            },
            {
                "name" : "test_2.txt"
            },
            {
                "name" : "test_3.txt",
                "versions" : [
                    "test_3.2081.txt",
                    "test_3.2079.txt"
                ]
            }
        ]
    }

Options:
EOS";

struct DiffOptions
{
    string programName;
    string testDir;                            // Required argument
    bool helpVerbose = false;                  // --help-verbose
    string rootDir = "";                       // --d|root-dir
    string configFile = "test-config.json";    // --c|config-file
    string goldDir = "gold";                   // --g|gold-dir
    bool quiet = false;                        // --q|quiet
    size_t maxDiffLines = 500;                  // --n|max-diff-lines
    string diffProg = "diff";                  // --diff-prog

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
        import std.getopt;
        import std.path : baseName, stripExtension;

        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

        try
        {
            auto r = getopt(
                cmdArgs,
                "help-verbose",      "       Print full help.", &helpVerbose,
                "d|root-dir",        " DIR   Root directory for tests. Default: current directory", &rootDir,
                "c|config-file",     " FILE  Config file name. A directory diff is done if the config file doesn't exist. Default: test-config.json", &configFile,
                "g|gold-dir",        " DIR   Gold directory name. Default: gold", &goldDir,
                "q|quiet",           "       Print only the exit status, no diff output.", &quiet,
                "n|max-diff-lines",  " NUM   Number of diff lines to display. Zero means display all. Default: 40.", &maxDiffLines,
                "diff-prog",         " STR   Diff program to use. Default: diff", &diffProg,
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

            /* Get the test directory. Should be the one command line arg remaining. */
            if (cmdArgs.length == 2)
            {
                testDir = cmdArgs[1];
            }
            else if (cmdArgs.length < 2)
            {
                throw new Exception("A test directory is required.");
            }
            else
            {
                throw new Exception("Unexpected arguments.");
            }
        }
        catch (Exception exc)
        {
            stderr.writefln("[%s] Error processing command line arguments: %s", programName, exc.msg);
            return tuple(false, 1);
        }
        return tuple(true, 0);
    }
}

int diffTestResultDirs(DiffOptions cmdopt)
{
    import std.json;
    import std.file : dirEntries, readText;
    import std.path : absolutePath, baseName, buildNormalizedPath;
    import std.process : escapeShellCommand, executeShell;
    import std.string : KeepTerminator, lineSplitter;
    import std.format : format;
    import std.algorithm : any;
    import std.array : join;

    int testResultStatus = 0;
    string diffOutput = "";

    auto configFilePath = (cmdopt.rootDir.length == 0)
        ? cmdopt.configFile.absolutePath.buildNormalizedPath
        : [cmdopt.rootDir, cmdopt.configFile].buildNormalizedPath.absolutePath;

    auto testDirPath = (cmdopt.rootDir.length == 0)
        ? cmdopt.testDir.absolutePath.buildNormalizedPath
        : [cmdopt.rootDir, cmdopt.testDir].buildNormalizedPath.absolutePath;

    auto goldDirPath = (cmdopt.rootDir.length == 0)
        ? cmdopt.goldDir.absolutePath.buildNormalizedPath
        : [cmdopt.rootDir, cmdopt.goldDir].buildNormalizedPath.absolutePath;

    auto useDirectoryDiff = !configFilePath.exists;

    if (!testDirPath.exists || !goldDirPath.exists || !testDirPath.isDir || !goldDirPath.isDir)
    {
        testResultStatus = 1;
        if (!cmdopt.quiet)
        {
            if (!testDirPath.exists) diffOutput ~= format("Test directory not found: '%s'\n", testDirPath);
            else if (!testDirPath.isDir) diffOutput ~= format("Test directory not a directory: '%s'\n", testDirPath);

            if (!goldDirPath.exists) diffOutput ~= format("Gold directory not found: '%s'\n", goldDirPath);
            else if (!goldDirPath.isDir) diffOutput ~= format("Gold directory not a directory: '%s'\n", goldDirPath);
        }
    }
    else if (useDirectoryDiff)
    {
        auto diffCmdArgs = [cmdopt.diffProg, testDirPath, goldDirPath];
        auto diffResult = diffCmdArgs.escapeShellCommand.executeShell;
        testResultStatus = diffResult.status;
        if (diffResult.status != 0 && !cmdopt.quiet) diffOutput ~= diffResult.output;
    }
    else
    {
        /* These AAs keep the test output file names found in the config file. At the
         * of end of processing the test and gold directories are walked to see that
         * every file in the directory is accounted for by the config file.
         */
        bool[string] outputFileNames;
        bool[string] versionFileNames;

        JSONValue configData;
        try configData = configFilePath.readText.parseJSON;
        catch (Exception e) throw new Exception(format("Could not processing config file '%s': %s", configFilePath, e.msg));

        foreach (outputFileJSON; configData["output_files"].array)
        {
            int fileStatus = 0;
            auto outputFileName = outputFileJSON["name"].str;
            auto testFilePath = buildNormalizedPath(testDirPath, outputFileName);
            auto goldFilePath = buildNormalizedPath(goldDirPath, outputFileName);

            if (!testFilePath.exists || !goldFilePath.exists)
            {
                fileStatus = 1;
                if (!cmdopt.quiet)
                {
                    diffOutput ~= format("->>> Comparsion failed for config entry: '%s'\n", outputFileName);
                    if (!testFilePath.exists) diffOutput ~= format("  Test file not found: '%s'\n", testFilePath);
                    if (!goldFilePath.exists) diffOutput ~= format("  Gold file not found: '%s'\n", goldFilePath);
                }
            }
            else
            {
                bool fileMatch = true;
                auto diffCmdArgs = [cmdopt.diffProg, testFilePath, goldFilePath];
                auto diffResult = diffCmdArgs.escapeShellCommand.executeShell;

                if (diffResult.status != 0)
                {
                    fileMatch = false;
                    if ("versions" in outputFileJSON)
                    {
                        bool versionFileDiff(JSONValue versionFileNameJSON)
                        {
                            auto versionFileName = versionFileNameJSON.str;
                            auto versionFilePath = buildNormalizedPath(goldDirPath, versionFileName);
                            auto versionDiffCmdArgs = [cmdopt.diffProg, testFilePath, versionFilePath];
                            auto versionDiffResult = versionDiffCmdArgs.escapeShellCommand.executeShell;
                            return (versionDiffResult.status == 0);
                        }

                        auto versionFiles = outputFileJSON["versions"].array;
                        fileMatch = versionFiles.any!versionFileDiff;
                    }
                }

                if (!fileMatch)
                {
                    fileStatus = diffResult.status;
                    if (!cmdopt.quiet)
                    {
                        diffOutput ~= format("->>> Diff failed for config entry: '%s'", outputFileName);
                        auto numVersions = ("versions" !in outputFileJSON) ? 0 : outputFileJSON["versions"].array.length;
                        if (numVersions > 0) diffOutput ~= format(" (including %d alternate version files)", numVersions);
                        diffOutput ~= "\n\n";
                        diffOutput ~= format("%s %s %s\n", cmdopt.diffProg, testFilePath, goldFilePath);
                        diffOutput ~= diffResult.output;
                        diffOutput ~= "\n";
                    }
                }
            }
            if (testResultStatus == 0 && fileStatus != 0) testResultStatus = fileStatus;
        }

        /* Add confile entries to the list of AAs of file names. Also check that version
         * files exist in the gold directory. The base entry has already been checked.
         */
        foreach (outputFileJSON; configData["output_files"].array)
        {
            auto outputFileName = outputFileJSON["name"].str;
            outputFileNames[outputFileName] = true;
            if ("versions" in outputFileJSON)
            {
                foreach (versionFileJSON; outputFileJSON["versions"].array)
                {
                    auto versionFileName = versionFileJSON.str;
                    versionFileNames[versionFileName] = true;
                    auto versionFilePath = buildNormalizedPath(goldDirPath, versionFileName);
                    if (!versionFilePath.exists)
                    {
                        if (testResultStatus == 0) testResultStatus = 1;
                        if (!cmdopt.quiet) diffOutput ~= format("->>> Invalid config entry '%s', version file does not exist: '%s'\n", outputFileName, versionFilePath);
                    }
                }
            }
        }

        /* Check that all files in test and gold directories are in the config file. */
        foreach (string filePath; dirEntries(testDirPath, SpanMode.shallow))
        {
            auto fileName = filePath.baseName;
            if (fileName !in outputFileNames)
            {
                if (testResultStatus == 0) testResultStatus = 1;
                if (!cmdopt.quiet) diffOutput ~= format("->>> Test directory file not referenced in config: '%s'\n", filePath);
            }
        }

        foreach (string filePath; dirEntries(goldDirPath, SpanMode.shallow))
        {
            auto fileName = filePath.baseName;
            if (fileName !in outputFileNames && fileName !in versionFileNames)
            {
                if (testResultStatus == 0) testResultStatus = 1;
                if (!cmdopt.quiet) diffOutput ~= format("->>> Gold directory file not referenced in config: '%s'\n", filePath);
            }
        }
    }

    if (testResultStatus != 0 && !cmdopt.quiet)
    {
        write(
            (cmdopt.maxDiffLines == 0)
            ? diffOutput
            : diffOutput.lineSplitter!(Yes.keepTerminator).take(cmdopt.maxDiffLines).join
            );
    }

    return testResultStatus;
}
