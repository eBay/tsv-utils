/**
This tool concatenates all the files in a directory, with a line at the start of each
new file giving the name of the file. This is used for testing tools generating
multiple output files. It is similar to 'tail -n +1 dir/*'. The main difference is
that it assembles files in the same order on all platforms, a characteristic
necessary for testing.

Copyright (c) 2020-2021, eBay Inc.
Initially written by Jon Degenhardt

License: Boost License 1.0 (http://boost.org/LICENSE_1_0.txt)

*/
module buildtools.dircat;

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

        DirCatOptions cmdopt;
        auto r = cmdopt.processArgs(cmdArgs);
        if (!r[0]) return r[1];

        try concatenateDirectoryFiles(cmdopt);
        catch (Exception e)
        {
            stderr.writefln("Error [%s]: %s", cmdopt.programName, e.msg);
            return 1;
        }
        return 0;
    }
}

auto helpText = q"EOS
Synopsis: dircat [options] <directory>

This tool concatenates all files in a directory, writing the contents to
standard output. The contents of each file is preceded with a line
containing the path of the file.

The current features are very simple. The directory must contain only
regular files. It is an error if the directory contains subdirectories
or symbolic links.

Exit status is '0' on success, '1' if an error occurred.

Options:
EOS";

struct DirCatOptions
{
    string programName;
    string dir;                          // Required argument

    /* Returns a tuple. First value is true if command line arguments were successfully
     * processed and execution should continue, or false if an error occurred or the user
     * asked for help. If false, the second value is the appropriate exit code (0 or 1).
     *
     * Returning true (execution continues) means args have been validated and derived
     * values calculated.
     */
    auto processArgs (ref string[] cmdArgs)
    {
        import std.getopt;
        import std.path : baseName, stripExtension;

        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

        try
        {
            auto r = getopt(cmdArgs);

            if (r.helpWanted)
            {
                defaultGetoptPrinter(helpText, r.options);
                return tuple(false, 0);
            }

            /* Get the directory path. Should be the one command line arg remaining. */
            if (cmdArgs.length == 2) dir = cmdArgs[1];
            else if (cmdArgs.length < 2) throw new Exception("A directory is required.");
            else throw new Exception("Unexpected arguments.");
        }
        catch (Exception exc)
        {
            stderr.writefln("[%s] Error processing command line arguments: %s", programName, exc.msg);
            return tuple(false, 1);
        }
        return tuple(true, 0);
    }
}

void concatenateDirectoryFiles(DirCatOptions cmdopt)
{
    import std.algorithm : copy, sort;
    import std.conv : to;
    import std.exception : enforce;
    import std.file : dirEntries, DirEntry, exists, isDir, SpanMode;
    import std.format : format;
    import std.path;

    string[] filepaths;

    enforce(cmdopt.dir.exists, format("Directory '%s' does not exist.", cmdopt.dir));
    enforce(cmdopt.dir.isDir, format("File path '%s' is not a directory.", cmdopt.dir));

    foreach (DirEntry de; dirEntries(cmdopt.dir, SpanMode.shallow))
    {
        enforce(!de.isDir, format("Directory member '%s' is a directory.", de.name));
        enforce(!de.isSymlink, format("Directory member '%s' is a symbolic link.", de.name));
        enforce(de.isFile, format("Directory member '%s' is not a file.", de.name));

        filepaths ~= de.name;
    }
    filepaths.sort;
    foreach (filenum, path; filepaths)
    {
        if (filenum > 0) writeln;
        writefln("==> %s <==", path);
        path.File.byChunk(1024L * 128L).copy(stdout.lockingTextWriter);
    }
}
