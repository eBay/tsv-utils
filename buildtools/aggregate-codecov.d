/**
This tool aggregates D coverage files to a common directory.

D code coverage files are written to the directory where the test was initiated. When
multiple tests are run from different directories, multiple output files are produced.
This tool moves these files to a common directory, aggregating them in the process.

Copyright (c) 2017, eBay Software Foundation
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)

**/
module aggregate_codecov;

import std.file : exists, isDir, isFile, remove, rename;
import std.path : baseName, buildPath, stripExtension;
import std.stdio;

int main(string[] cmdArgs)
{
    auto programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

    if (cmdArgs.length < 3)
    {
        writefln("Synopsis: %s target-dir coverage-file [coverage-file...]", programName);
        return 1;
    }

    auto targetDir = cmdArgs[1];
    auto coverageFiles = cmdArgs[2..$];

    if (!targetDir.exists || !targetDir.isDir)
    {
        writefln("%s is not a directory", targetDir);
        return 1;
    }

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
        auto targetFile = buildPath(targetDir, cf.baseName);
        if (!targetFile.exists) cf.rename(targetFile);
        else mergeCoverageFiles(cf, targetFile);
    }

    return 0;
}

void mergeCoverageFiles(string fromFile, string toFile)
{
    import std.algorithm : find, findSplit, max;
    import std.array : appender;
    import std.conv : to;
    import std.format : format;
    import std.math : log10;
    import std.range : empty, lockstep, StoppingPolicy;

    struct LineCounter
    {
        long count;
        string line;
    }

    auto lines = appender!(LineCounter[])();
    string lastLine = "";
    long maxCounter = -1;
    
    {   // Scope for file opens
        auto toInput = toFile.File;
        auto fromInput = fromFile.File;

        foreach (lineNum, f1, f2; lockstep(toInput.byLine, fromInput.byLine, StoppingPolicy.requireSameLength))
        {
            if (!lastLine.empty)
                throw new Exception(format("Unexpected file input. File: %s; File: %s; Line: %d",
                                           fromFile, toFile, lineNum));

            auto f1Split = f1.findSplit("|");
            auto f2Split = f2.findSplit("|");

            if (f1Split[0].empty)
                throw new Exception(format("Unexpected input. File: %s, %d", toFile, lineNum));
            if (f2Split[0].empty)
                throw new Exception(format("Unexpected input. File: %s, %d", fromFile, lineNum));

            if ((f1Split[2].empty && !f2Split[2].empty) ||
                (!f1Split[2].empty && f2Split[2].empty) ||
                (!f1Split[2].empty && !f2Split[2].empty && f1Split[2] != f2Split[2]))
            {
                throw new Exception(format("Inconsistent file code line. File: %s; File: %s; Line: %d",
                                           fromFile, toFile, lineNum));
            }

            if (f1Split[1].empty)
            {
                lastLine = f1.to!string;
                continue;
            }
            auto f1CounterStr = f1Split[0].find!(c => c != ' ');
            auto f2CounterStr = f2Split[0].find!(c => c != ' ');

            long f1Counter = f1CounterStr.empty ? -1 : f1CounterStr.to!long;
            long f2Counter = f2CounterStr.empty ? -1 : f2CounterStr.to!long;
            long counter =
                (f1Counter == -1) ? f2Counter :
                (f2Counter == -1) ? f1Counter :
                f1Counter + f2Counter;
            
            auto lc = LineCounter(counter, f1Split[2].to!string);
            lines ~= lc;
            if (counter > maxCounter) maxCounter = counter;
        }
    }

    auto toBackup = toFile ~ ".backup";
    toFile.rename(toBackup);

    size_t minDigits = max(7, (maxCounter <= 0) ? 1 : log10(maxCounter).to!long + 1);
    string blanks;
    string zeros;
    foreach (i; 0 .. minDigits)
    {
        blanks ~= ' ';
        zeros ~= '0';
    }
    
    size_t codeLines = 0;
    size_t coveredCodeLines = 0;
    auto ofile = toFile.File("w");
    foreach (lc; lines.data)
    {
        if (lc.count >= 0) codeLines++;
        if (lc.count > 0) coveredCodeLines++;
        ofile.writeln(
            (lc.count < 0) ? blanks :
            (lc.count == 0) ? zeros :
            format("%*d", minDigits, lc.count),
            '|', lc.line);
    }
    auto lastLineSplit = lastLine.findSplit(" ");
    ofile.write(lastLineSplit[0]);
    if (codeLines == 0) ofile.writeln(" has no code");
    else ofile.writefln(
        " is %d%% covered",
        ((coveredCodeLines.to!double / codeLines.to!double) * 100.0).to!size_t);
    toBackup.remove;
    fromFile.remove;
}
