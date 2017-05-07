/**
Command line tool using fields in a tab-separated value file to identify equivalent
lines. Can either remove the duplicate entries or mark as equivalence classes.

This tool reads a tab-separated value file line by line, using one or more fields to
record a key. If the same key is found in a subsequent line, it is identified as
equivalent. When operating in 'uniq' mode, the first time a key is seen the line is
written to standard output, but subsequent matching lines are discarded.

The alternate to 'uniq' is 'equiv-class' identification. In this mode, all lines
written to standard output, but a new field is added marking equivalent entries with
with an ID. The ID is simply a one-upped counter.

Copyright (c) 2015-2017, eBay Software Foundation
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)
*/
module tsv_uniq;

import std.stdio;
import std.format : format;
import std.typecons : tuple;

auto helpText = q"EOS
Synopsis: tsv-uniq [options] [file...]

tsv-uniq filters out duplicate lines using fields as a key. Filtering is based
on the entire line if a key is not provided.

Options:
EOS";

auto helpTextVerbose = q"EOS
Synopsis: tsv-uniq [options] [file...]

tsv-uniq identifies equivalent lines in tab-separated value files. Input is read
line by line, recording a key based on one or more of the fields. Two lines are
equivalent if they have the same key. When operating in 'uniq' mode, the first
time a key is seen the line is written to standard output, but subsequent lines
are discarded. This is similar to the unix 'uniq' program, but based on individual
fields and without requiring sorted data. This command uniq's on fields 2 and 3:

   tsv-uniq -f 2,3 file.tsv

The alternate to 'uniq' mode is 'equiv-class' identification. In this mode, all
lines are written to standard output, but with a new field added marking
equivalent entries with an ID. The ID is simply a one-upped counter. Example:

   tsv-uniq --header -f 2,3 --equiv file.tsv

Options:
EOS";

/**
Container for command line options.
 */
struct TsvUniqOptions
{
    enum defaultEquivHeader = "equiv_id";
    enum defaultEquivStartID = 1;

    bool helpVerbose = false;                 // --help-verbose
    bool versionWanted = false;               // --V|version
    size_t[] fields;                          // --fields
    bool hasHeader = false;                   // --header
    bool equivMode = false;                   // --equiv
    string equivHeader = defaultEquivHeader;  // --equiv-header
    long equivStartID = defaultEquivStartID;  // --equiv-start
    bool ignoreCase = false;                  // --ignore-case
    char delim = '\t';                        // --delimiter
    bool keyIsFullLine = false;               // Derived. True if no fields specified or '--f|fields 0'

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
        import std.algorithm : any, each;
        import std.getopt;
        import std.typecons : Yes, No;
        import tsvutil :  makeFieldListOptionHandler;

        try
        {
            arraySep = ",";    // Use comma to separate values in command line options
            auto r = getopt(
                cmdArgs,
                "help-verbose",  "              Print full help.", &helpVerbose,
                std.getopt.config.caseSensitive,
                "V|version",     "              Print version information and exit.", &versionWanted,
                "H|header",      "              Treat the first line of each file as a header.", &hasHeader,
                std.getopt.config.caseInsensitive,

                "f|fields",      "<field-list>  Fields to use as the key. Default: 0 (entire line).",
                fields.makeFieldListOptionHandler!(size_t, No.convertToZeroBasedIndex,Yes.allowFieldNumZero),

                "i|ignore-case", "              Ignore case when comparing keys.", &ignoreCase,
                "e|equiv",       "              Output equiv class IDs rather than uniq'ing entries.", &equivMode,
                "equiv-header",  "STR           Use STR as the equiv-id field header. Applies when using '--header --equiv'. Default: 'equiv_id'.", &equivHeader,
                "equiv-start",   "INT           Use INT as the first equiv-id. Default: 1.", &equivStartID,
                "d|delimiter",   "CHR           Field delimiter. Default: TAB. (Single byte UTF-8 characters only.)", &delim,
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
            else if (versionWanted)
            {
                import tsvutils_version;
                writeln(tsvutilsVersionNotice("tsv-uniq"));
                return tuple(false, 0);
            }

            /* Consistency checks */
            if (!equivMode)
            {
                if (equivHeader != defaultEquivHeader)
                {
                    throw new Exception("--equiv-header requires --e|equiv");
                }
                else if (equivStartID != defaultEquivStartID)
                {
                    throw new Exception("--equiv-start requires --e|equiv");
                }
            }

            if (fields.length > 1 && fields.any!(x => x == 0))
            {
                throw new Exception("Whole line as key (--f|field 0) cannot be combined with multiple fields.");
            }

            /* Derivations */
            if (fields.length == 0)
            {
                keyIsFullLine = true;
            }
            else if (fields.length == 1 && fields[0] == 0)
            {
                keyIsFullLine = true;
                fields.length = 0;
            }

            fields.each!((ref x) => --x);  // Convert to 1-based indexing.

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

    TsvUniqOptions cmdopt;
    auto r = cmdopt.processArgs(cmdArgs);
    if (!r[0]) return r[1];
    try tsvUniq(cmdopt, cmdArgs[1..$]);
    catch (Exception exc)
    {
        stderr.writeln("Error: ", exc.msg);
        return 1;
    }
    return 0;
}

void tsvUniq(in TsvUniqOptions cmdopt, in string[] inputFiles)
{
    import tsvutil : InputFieldReordering;
    import std.algorithm : splitter;
    import std.array : join;
    import std.conv : to;
    import std.range;
    import std.uni : toLower;

    /* InputFieldReordering maps the key fields from an input line to a separate buffer. */
    auto keyFieldsReordering = new InputFieldReordering!char(cmdopt.fields);

    /* The master hash. The key is the specified fields concatenated together (including
     * separators). The value is the equiv-id.
     */
    long[string] equivHash;

    size_t numFields = cmdopt.fields.length;
    long nextEquivID = cmdopt.equivStartID;
    bool headerWritten = false;
    foreach (filename; (inputFiles.length > 0) ? inputFiles : ["-"])
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (lineNum, line; inputStream.byLine.enumerate(1))
        {
            if (cmdopt.hasHeader && lineNum == 1)
            {
                /* Header line. */
                if (!headerWritten)
                {
                    write(line);
                    if (cmdopt.equivMode) write(cmdopt.delim, cmdopt.equivHeader);
                    writeln();
                    headerWritten = true;
                }
            }
            else
            {
                /* Regular line (not header). Start by finding the key. */
                typeof(line) key;
                if (cmdopt.keyIsFullLine)
                {
                    key = line;
                }
                else
                {
                    /* Copy the key fields to a new buffer. */
                    keyFieldsReordering.initNewLine;
                    foreach (fieldIndex, fieldValue; line.splitter(cmdopt.delim).enumerate)
                    {
                        keyFieldsReordering.processNextField(fieldIndex, fieldValue);
                        if (keyFieldsReordering.allFieldsFilled) break;
                    }

                    if (!keyFieldsReordering.allFieldsFilled)
                    {
                        throw new Exception(
                            format("Not enough fields in line. File: %s, Line: %s",
                                   (filename == "-") ? "Standard Input" : filename, lineNum));
                    }

                    key = keyFieldsReordering.outputFields.join(cmdopt.delim);
                }

                if (cmdopt.ignoreCase) key = key.toLower;

                bool isUniq;
                long currEquivID;
                long* priorEquivID = (key in equivHash);
                if (priorEquivID is null)
                {
                    isUniq = true;
                    currEquivID = nextEquivID;
                    equivHash[key.to!string] = nextEquivID;
                    nextEquivID++;
                }
                else
                {
                    isUniq = false;
                    currEquivID = *priorEquivID;
                }

                if (isUniq || cmdopt.equivMode)
                {
                    write(line);
                    if (cmdopt.equivMode) write(cmdopt.delim, currEquivID);
                    writeln();
                }
            }
        }
    }
}
