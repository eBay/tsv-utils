/**
A simple version of the unix 'nl' program.

This program is a simpler version of the unix 'nl' (number lines) program. It reads
text from files or standard input and adds a line number to each line.

Copyright (c) 2015-2021, eBay Inc.
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)
*/
module tsv_utils.number_lines;

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

/** Container for command line options.
 */
struct NumberLinesOptions
{
    enum defaultHeaderString = "line";

    string programName;
    bool hasHeader = false;       /// --H|header
    string headerString = "";     /// --s|header-string
    long startNum = 1;            /// --n|start-num
    char delim = '\t';            /// --d|delimiter
    bool lineBuffered = false;    /// --line-buffered
    bool versionWanted = false;   /// --V|version

    /* Returns a tuple. First value is true if command line arguments were successfully
     * processed and execution should continue, or false if an error occurred or the user
     * asked for help. If false, the second value is the appropriate exit code (0 or 1).
     */
    auto processArgs (ref string[] cmdArgs)
    {
        import std.algorithm : any, each;
        import std.getopt;
        import std.path : baseName, stripExtension;

        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

        try
        {
            auto r = getopt(
                cmdArgs,
                std.getopt.config.caseSensitive,
                "H|header",        "     Treat the first line of each file as a header. The first input file's header is output, subsequent file headers are discarded.", &hasHeader,
                std.getopt.config.caseInsensitive,
                "s|header-string", "STR  String to use in the header row. Implies --header. Default: 'line'", &headerString,
                "n|start-number",  "NUM  Number to use for the first line. Default: 1", &startNum,
                "d|delimiter",     "CHR  Character appended to line number, preceding the rest of the line. Default: TAB (Single byte UTF-8 characters only.)", &delim,
                "line-buffered",   "     Immediately output every line.", &lineBuffered,
                std.getopt.config.caseSensitive,
                "V|version",       "     Print version information and exit.", &versionWanted,
                std.getopt.config.caseInsensitive,
            );

            if (r.helpWanted)
            {
                defaultGetoptPrinter(helpText, r.options);
                return tuple(false, 0);
            }
            else if (versionWanted)
            {
                import tsv_utils.common.tsvutils_version;
                writeln(tsvutilsVersionNotice("number-lines"));
                return tuple(false, 0);
            }

            /* Derivations. */
            if (headerString.length > 0) hasHeader = true;
            else headerString = defaultHeaderString;
        }
        catch (Exception exc)
        {
            stderr.writefln("[%s] Error processing command line arguments: %s", programName, exc.msg);
            return tuple(false, 1);
        }
        return tuple(true, 0);
    }
}

static if (__VERSION__ >= 2085) extern(C) __gshared string[] rt_options = [ "gcopt=cleanup:none" ];

/** Main program. */
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
        stderr.writefln("Error [%s]: %s", cmdopt.programName, exc.msg);
        return 1;
    }

    return 0;
}

/** Implements the primary logic behind number lines.
 *
 * Reads lines lines from each file, outputing each with a line number prepended. The
 * header from the first file is written, the header from subsequent files is dropped.
 */
void numberLines(const NumberLinesOptions cmdopt, const string[] inputFiles)
{
    import std.conv : to;
    import std.range;
    import tsv_utils.common.utils : BufferedOutputRange, BufferedOutputRangeDefaults,
        bufferedByLine, LineBuffered, ReadHeader;

    immutable size_t flushSize = cmdopt.lineBuffered ?
        BufferedOutputRangeDefaults.lineBufferedFlushSize :
        BufferedOutputRangeDefaults.flushSize;
    auto bufferedOutput = BufferedOutputRange!(typeof(stdout))(stdout, flushSize);

    long lineNum = cmdopt.startNum;
    bool headerWritten = false;
    immutable LineBuffered isLineBuffered = cmdopt.lineBuffered ? Yes.lineBuffered : No.lineBuffered;
    immutable ReadHeader useReadHeader = cmdopt.hasHeader ? Yes.readHeader : No.readHeader;

    foreach (filename; (inputFiles.length > 0) ? inputFiles : ["-"])
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (fileLineNum, line;
                 inputStream
                 .bufferedByLine!(KeepTerminator.no)(isLineBuffered, useReadHeader)
                 .enumerate(1))
        {
            if (cmdopt.hasHeader && fileLineNum == 1)
            {
                if (!headerWritten)
                {
                    bufferedOutput.append(cmdopt.headerString);
                    bufferedOutput.append(cmdopt.delim);
                    bufferedOutput.appendln(line);
                    headerWritten = true;

                    /* Flush the header immediately. This helps tasks further on in a
                     * unix pipeline detect errors quickly, without waiting for all
                     * the data to flow through the pipeline. Note that an upstream
                     * task may have flushed its header line, so the header may
                     * arrive long before the main block of data.
                     */
                    bufferedOutput.flush;
                }
            }
            else
            {
                bufferedOutput.append(lineNum.to!string);
                bufferedOutput.append(cmdopt.delim);
                bufferedOutput.appendln(line);
                lineNum++;
            }
        }
    }
}
