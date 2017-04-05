/**
This tool coverts D code coverage files from absolute to relative paths.

D code coverage files are written using absolute path names if absolute paths are
used in the build command. (This enables running coverage tests from a directory
other than the original build directory.) This tool converts the files to relative
paths. This includes the file name and the name included in the file.

Copyright (c) 2017, eBay Software Foundation
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)

**/
module codecov_to_relative_path;

import std.algorithm : findSplit;
import std.array : appender;
import std.conv : to;
import std.file : exists, isDir, isFile, remove, rename;
import std.path : absolutePath, baseName, buildPath, buildNormalizedPath, dirName, extension,
    isAbsolute, stripExtension;
import std.range : empty;
import std.stdio;
import std.string : tr;

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
