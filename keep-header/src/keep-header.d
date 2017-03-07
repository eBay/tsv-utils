/**
Command line tool that executes a command, but preserves the header line
of the first file.

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
from the command follows the initial header line.

A double dash (--) delimits the command. It will behave similarly to a
pipe operator (|), except for the header behavior.

    $ keep-header file1.txt file2.txt -- sort
    $ keep-header file1.txt file2.txt -- sort -k1,1nr

These commands run sort, but keep the header as the first line output.
Data can also be read from from standard input. Example:

    $ keep-header file1.txt -- sort | keep-header -- uniq
EOS";

int main(string[] args)
{
    import std.algorithm : findSplit, joiner;
    import std.process : pipeProcess, ProcessPipes, Redirect, wait;
    import std.range;
    import std.stdio;
    import std.typecons : tuple; 

    auto programName = (args.length >= 1) ? args[0] : "";
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
        
        auto files = splitArgs[0].length > 1 ? splitArgs[0][1..$] : ["-"];
        foreach (fileNum, filename; files.enumerate(1))
        {
            /**** TODO
             * Need to catch file open failures, terminate the pipe, and exit with status==1.
             */
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
                    if (fileNum == 1)
                    {
                        write(line);
                        stdout.flush;
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
