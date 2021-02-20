/**
Helper functions for tsv-utils unit tests.

Copyright (c) 2017-2021, eBay Inc.
Initially written by Jon Degenhardt

License: Boost License 1.0 (http://boost.org/LICENSE_1_0.txt)
*/

module tsv_utils.common.unittest_utils;

version(unittest)
{
    /* Creates a temporary directory for writing unit test files. The path of the created
     * directory is returned. The 'toolDirName' argument will be included in the directory
     * name, and should consist of generic filename characters. e.g. "tsv_append". This
     * name will also be used in assert error messages.
     *
     * The caller should delete the temporary directory and all its contents when tests
     * are finished. This can be done using std.file.rmdirRecurse. For example:
     *
     *     unittest
     *     {
     *         import std.file : rmdirRecurse;
     *         auto testDir = makeUnittestTempDir("tsv_append");
     *         scope(exit) testDir.rmdirRecurse;
     *         ... test code
     *     }
     *
     * An assert is triggered if the directory cannot be created. There are two typical
     * reasons:
     * - Unable to find an available directory name. A number of unique names are tried
     *   (currently 1000). If they are all taken, it will normally be because the directories
     *   haven't been properly cleaned up from previous unit test runs.
     * - Directory creation failed. e.g. Permission denied.
     *
     * This routine is intended to be run in 'unittest' mode, so that an assert is triggered
     * on failure. However, if run with asserts disabled, the returned path will be empty in
     * event of a failure.
     */
    string makeUnittestTempDir(string toolDirName) @safe
    {
        import std.conv : to;
        import std.file : exists, mkdir, tempDir;
        import std.format : format;
        import std.path : buildPath;
        import std.range;

        string dirNamePrefix = "ebay_tsv_utils__" ~ toolDirName ~ "_unittest_";
        string systemTempDirPath = tempDir();
        string newTempDirPath = "";

        for (auto i = 0; i < 1000 && newTempDirPath.empty; i++)
        {
            string path = buildPath(systemTempDirPath, dirNamePrefix ~ i.to!string);
            if (!path.exists) newTempDirPath = path;
        }
        assert (!newTempDirPath.empty,
                format("Unable to obtain a new temp directory, paths tried already exist.\nPath prefix: %s",
                       buildPath(systemTempDirPath, dirNamePrefix)));

        if (!newTempDirPath.empty)
        {
            try mkdir(newTempDirPath);
            catch (Exception exc)
            {
                assert(false, format("Failed to create temp directory: %s\n   Error: %s",
                                     newTempDirPath, exc.msg));
            }
        }

        return newTempDirPath;
    }

    /* Write a TSV file. The 'tsvData' argument is a 2-dimensional array of rows and
     * columns. Asserts if the file cannot be written.
     *
     * This routine is intended to be run in 'unittest' mode, so that it will assert
     * if the write fails. However, if run in a mode with asserts disabled, it will
     * return false if the write failed.
     */
    bool writeUnittestTsvFile(string filepath, string[][] tsvData, char delimiter = '\t') @safe
    {
        import std.algorithm : each, joiner, map;
        import std.conv : to;
        import std.format: format;
        import std.stdio : File;

        try
        {
            auto file = File(filepath, "wb");
            tsvData
                .map!(row => row.joiner(delimiter.to!string))
                .each!(str => file.writeln(str));
            file.close;
        }
        catch (Exception exc)
        {
            assert(false, format("Failed to write TSV file: %s.\n  Error: %s",
                                 filepath, exc.msg));
            return false;
        }

        return true;
    }

    /* Convert a 2-dimensional array of values to an in-memory string. */
    string tsvDataToString(string[][] tsvData, char delimiter = '\t') @safe
    {
        import std.algorithm : joiner, map;
        import std.conv : to;

        return tsvData
            .map!(row => row.joiner(delimiter.to!string).to!string ~ "\n")
            .joiner
            .to!string;
    }
 }
