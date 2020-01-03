/**
This tool converts D code coverage files from absolute to relative paths.

D code coverage files are generated based on absolute path names if absolute paths are
used in the build command. This is reflected in the file's actual name, which reflects all
the path components. The absolute path is also listed at the end of the code coverage
report.

This tool checks a coverage file to see if absolute names where used. If so, it renames
the file and updates the report to use a relative path.

Copyright (c) 2017-2020, eBay Inc.
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)

**/
module buildtools.codecov_to_relative_paths;

import std.algorithm : findSplit;
import std.array : appender;
import std.conv : to;
import std.file : exists, isDir, isFile, remove, rename;
import std.path : absolutePath, baseName, buildPath, buildNormalizedPath, dirName, extension,
    isAbsolute, stripExtension;
import std.range : empty;
import std.stdio;
import std.string : tr;

/** Convert a D code coverage file to use relative paths.
 *
 * Files provides on the command line are checked to see if the name represents an
 * absolute path. If so, the file is renamed to reflect the relative name and the
 * last line of the coverage report is changed to reflect this as well.
 */
int main(string[] cmdArgs)
{
    auto programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

    if (cmdArgs.length < 2)
    {
        writefln("Synopsis: %s coverage-file [coverage-file...]", programName);
        return 1;
    }

    auto coverageFiles = cmdArgs[1..$];

    foreach (cf; coverageFiles)
    {
        if (!cf.exists || !cf.isFile)
        {
            writefln("%s is not a file", cf);
            return 1;
        }
    }

    foreach (cf; coverageFiles)
    {
        auto rootDir = cf.absolutePath.buildNormalizedPath.dirName;
        auto fileName = cf.baseName;
        auto fileNameNoExt = fileName.stripExtension;
        auto lines = appender!(string[])();
        foreach (l; cf.File.byLine) lines ~= l.to!string;
        if (lines.data.length > 0)
        {
            /* Check that the last line matches our file name. */
            auto lastLine = lines.data[$ - 1];
            auto lastLineSplit = lastLine.findSplit(" ");
            auto lastLinePath = lastLineSplit[1].empty ? "" : lastLineSplit[0];
            auto lastLinePathNoExt = lastLinePath.stripExtension;
            if (lastLinePath.isAbsolute &&
                lastLinePathNoExt.tr("\\/", "--") == fileNameNoExt &&
                rootDir.length + 1 <= lastLine.length &&
                rootDir.length + 1 <= fileName.length)
            {
                auto updatedLastLine = lastLine[rootDir.length + 1 .. $];
                auto newFileName = fileName[rootDir.length + 1 .. $];
                if (newFileName != fileName)
                {
                    auto ofile = newFileName.File("w");
                    foreach (l; lines.data[0 .. $ - 1]) ofile.writeln(l);
                    ofile.writeln(updatedLastLine);
                    fileName.remove;
                }
            }
        }
    }

    return 0;
}
