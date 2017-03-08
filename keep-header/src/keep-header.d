/**
Command line tool that executes a command while preserving header lines.

Copyright (c) 2017, eBay Software Foundation
Initially written by Jon Degenhardt

License: Boost License 1.0 (http://boost.org/LICENSE_1_0.txt) 
*/
module keep_header;

auto helpText = q"EOS
Execute a command against one or more files in a header aware fashion.
The first line of each file is assumed to be a header. The first header
is output unchanged. Remaining lines are sent to the given command via
standard input, excluding the header lines of subsequent files. Output
from the command is appended to the initial header line.

A double dash (--) delimits the command, similar to how the pipe
operator (|) delimits commands. Examples:

    $ keep-header file1.txt -- sort
    $ keep-header file1.txt file2.txt -- sort -k1,1nr

These sort the files as usual, but preserve the header as the first line
output. Data can also be read from from standard input. Example:

    $ keep-header file1.txt -- sort | keep-header -- uniq
EOS";

int main(string[] args)
{
    import std.algorithm : findSplit, joiner;
    import std.path : baseName, stripExtension;
    import std.process : pipeProcess, ProcessPipes, Redirect, wait;
    import std.range;
    import std.stdio;
    import std.typecons : tuple; 

    auto programName = (args.length > 0) ? args[0].stripExtension.baseName : "Unknown_program_name";
    auto splitArgs = findSplit(args, ["--"]);

    if (splitArgs[1].length == 0 || splitArgs[2].length == 0)
    {
        auto cmdArgs = splitArgs[0][1 .. $];
        stderr.writefln("Synopsis: %s [file...] -- program [args]", programName);
        if (cmdArgs.length > 0 && 
            (cmdArgs[0] == "-h" || cmdArgs[0] == "--help" || cmdArgs[0] == "--help-verbose"))
        {
            stderr.writeln();
            stderr.writeln(helpText);
        }
        return 0;
    }

    ProcessPipes pipe;
    try pipe = pipeProcess(splitArgs[2], Redirect.stdin);
    catch (Exception exc)
    {
        stderr.writefln("[%s] Command failed: '%s'", programName, splitArgs[2].joiner(" "));
        stderr.writeln(exc.msg);
        return 1;
    }

    int status = 0;
    {
        scope(exit)
        {
            auto pipeStatus = wait(pipe.pid);
            if (pipeStatus != 0) status = pipeStatus;
        }
        
        bool headerWritten = false;
        foreach (filename; splitArgs[0].length > 1 ? splitArgs[0][1..$] : ["-"])
        {
            File inputStream;
            if (filename == "-") inputStream = stdin;
            else
            {
                try inputStream = filename.File();
                catch (Exception exc)
                {
                    stderr.writefln("[%s] Unable to open file: '%s'", programName, filename);
                    stderr.writeln(exc.msg);
                    status = 1;
                    break;
                }
            }

            foreach (lineNum, line; inputStream.byLine(KeepTerminator.yes).enumerate(1))
            {
                if (lineNum == 1)
                {
                    if (!headerWritten)
                    {
                        write(line);
                        stdout.flush;
                        headerWritten = true;
                    }
                }
                else
                {
                    pipe.stdin.write(line);
                }
            }
            pipe.stdin.flush;
        }
        pipe.stdin.close;
    }
    return status;
}
