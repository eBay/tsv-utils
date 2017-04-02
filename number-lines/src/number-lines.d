/**
A simple version of the unix 'nl' program.

This program is a simpler version of the unix 'nl' (number lines) program. It reads
text from files or standard input and adds a line number to each line.

Copyright (c) 2015-2017, eBay Software Foundation
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)
*/
module number_lines;

import std.stdio;
import std.typecons : tuple;

auto helpText = q"EOS
Synopsis: number-lines [options] [file...]

number-lines reads from files or standard input and writes each line to standard
output preceded by a line number. It is a simplified version of the unix 'nl'
program. It supports one feature 'nl' does not: the ability to treat the first
line of files as a header. This is useful when working with tab-separated-value
files. If header processing used, a header line is written for the first file,
and the header lines are dropped from any subsequent files.

Examples:
   number-lines myfile.txt
   cat myfile.txt | number-lines --header linenum
   number-lines *.txt

Options:
EOS";

/** 
Container for command line options. 
 */
struct NumberLinesOptions
{
    enum defaultHeaderString = "line";
    
    bool hasHeader = false;       // --header
    string headerString = "";     // --header-string
    long startNum = 1;            // --start-num
    char delim = '\t';            // --delimiter

    /* Returns a tuple. First value is true if command line arguments were successfully
     * processed and execution should continue, or false if an error occurred or the user
     * asked for help. If false, the second value is the appropriate exit code (0 or 1).
     */ 
    auto processArgs (ref string[] cmdArgs)
    {
        import std.algorithm : any, each;
        import std.getopt;
        
        try
        {
            auto r = getopt(
                cmdArgs,
                std.getopt.config.caseSensitive,
                "H|header",        "     Treat the first line of each file as a header. The first input file's header is output, subsequent file headers are discarded.", &hasHeader,
                std.getopt.config.caseInsensitive,
                "s|header-string", "STR  String to use in the header row. Implies --header. Default: 'line'", &headerString,
                "n|start-number",  "NUM  Number to use for the first line. Default: 1", &startNum,
                "d|delimiter",     "CHR  Character appended to line number, preceding the rest of the line. Default: TAB (Single byte UTF-8 characters only.)", &delim
            );

            if (r.helpWanted)
            {
                defaultGetoptPrinter(helpText, r.options);
                return tuple(false, 0);
            }

            /* Derivations. */
            if (headerString.length > 0) hasHeader = true;
            else headerString = defaultHeaderString;
        }
        catch (Exception exc)
        {
            stderr.writeln("Error processing command line arguments: ", exc.msg);
            return tuple(false, 1);
        }
        return tuple(true, 0);
    }           
}

int main(string[] cmdArgs)
{
    /* When running in DMD code coverage mode, turn on report merging. */
    version(D_Coverage) version(DigitalMars)
    {
        import core.runtime : dmd_coverSetMerge;
        dmd_coverSetMerge(true);
    }
    
    NumberLinesOptions cmdopt;
    auto r = cmdopt.processArgs(cmdArgs);
    if (!r[0]) return r[1];
    try numberLines(cmdopt, cmdArgs[1..$]);
    catch (Exception exc)
    {
        stderr.writeln("Error: ", exc.msg);
        return 1;
    }

    return 0;
}

void numberLines(in NumberLinesOptions cmdopt, in string[] inputFiles)
{
    import std.range;
    
    long lineNum = cmdopt.startNum;
    bool headerWritten = false;
    foreach (filename; (inputFiles.length > 0) ? inputFiles : ["-"])
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (fileLineNum, line; inputStream.byLine(KeepTerminator.yes).enumerate(1))
        {
            if (cmdopt.hasHeader && fileLineNum == 1)
            {
                if (!headerWritten)
                {
                    write(cmdopt.headerString, cmdopt.delim, line);
                    headerWritten = true;
                }
            }
            else
            {
                write(lineNum, cmdopt.delim, line);
                lineNum++;
            }
        }
    }
}
