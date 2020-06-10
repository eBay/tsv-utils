/**
Command line tool that identifies equivalent lines in an input stream. Equivalent
lines are identified using either the full line or a set of fields as the key. By
default, input is written to standard output, retaining only the first occurrence of
equivalent lines. There are also options for marking and numbering equivalent lines
rather, without filtering out duplicates.

This tool is similar in spirit to the Unix 'uniq' tool, with some key differences.
First, the key can be composed of individual fields, not just the full line. Second,
input does not need to be sorted. (Unix 'uniq' only detects equivalent lines when
they are adjacent, hence the usual need for sorting.)

There are a couple alternative to uniq'ing the input lines. One is to mark lines with
an equivalence ID, which is a one-upped counter. The other is to number lines, with
each unique key have its own set of numbers.

Copyright (c) 2015-2020, eBay Inc.
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)
*/
module tsv_utils.tsv_uniq;

import std.exception : enforce;
import std.format : format;
import std.range;
import std.stdio;
import std.typecons : tuple;

auto helpText = q"EOS
Synopsis: tsv-uniq [options] [file...]

tsv-uniq filters out duplicate lines using fields as a key. Filtering is
based on the entire line when key fields are not provided. Options are
also available for assigning a unique id to each key and numbering the
occurrences of each key. Use '--help-verbose' for more details.

Options:
EOS";

auto helpTextVerbose = q"EOS
Synopsis: tsv-uniq [options] [file...]

tsv-uniq identifies equivalent lines in tab-separated value files. Input
is read line by line, recording a key for each line based on one or more
of the fields. Two lines are equivalent if they have the same key. The
first time a key is seen its line is written to standard output.
Subsequent lines containing the same key are discarded. This command
uniq's a file on fields 2 and 3:

   tsv-uniq -f 2,3 file.tsv

This is similar to the Unix 'uniq' program, but based on individual
fields and without requiring sorted data.

tsv-uniq can be run without specifying a key field. In this case the
whole line is used as a key, same as the Unix 'uniq' program. This works
on any line-oriented text file, not just TSV files.

The above is the default behavior ('uniq' mode). The alternates to 'uniq'
mode are 'number' mode and 'equiv-class' mode. In 'equiv-class' mode, all
lines are written to standard output, but with a field appended marking
equivalent entries with an ID. The ID is a one-upped counter. Example:

   tsv-uniq --header -f 2,3 --equiv file.tsv

'Number' mode also writes all lines to standard output, but with a field
appended numbering the occurrence count for the line's key. The first line
with a specific key is assigned the number '1', the second with the key is
assigned number '2', etc. 'Number' and 'equiv-class' modes can be combined.

The '--r|repeated' option can be used to print only lines occurring more
than once. Specifically, the second occurrence of a key is printed. The
'--a|at-least N' option is similar, printing lines occurring at least N
times. (Like repeated, the Nth line with the key is printed.)

The '--m|max MAX' option changes the behavior to output the first MAX
lines for each key, rather than just the first line for each key.

If both '--a|at-least' and '--m|max' are specified, the occurrences
starting with 'at-least' and ending with 'max' are output.

Options:
EOS";

/** Container for command line options.
 */
struct TsvUniqOptions
{
    import tsv_utils.common.utils : inputSourceRange, InputSourceRange, ReadHeader;

    enum defaultEquivHeader = "equiv_id";
    enum defaultEquivStartID = 1;
    enum defaultNumberHeader = "equiv_line";

    string programName;
    InputSourceRange inputSources;            /// Input files
    size_t[] fields;                          /// Derived: --f|fields
    bool hasHeader = false;                   /// --H|header
    bool onlyRepeated = false;                /// --r|repeated. Shorthand for '--atleast 2'
    size_t atLeast = 0;                       /// --a|at-least. Zero implies default behavior.
    size_t max = 0;                           /// --m|max. Zero implies default behavior.
    bool numberMode = false;                  /// --z|number
    string numberHeader = defaultNumberHeader;  /// --number-header
    bool equivMode = false;                   /// --e|equiv
    string equivHeader = defaultEquivHeader;  /// --equiv-header
    long equivStartID = defaultEquivStartID;  /// --equiv-start
    bool ignoreCase = false;                  /// --i|ignore-case
    char delim = '\t';                        /// --d|delimiter
    bool keyIsFullLine = false;               /// Derived. True if no fields specified or '--f|fields 0'

    /* Returns a tuple. First value is true if command line arguments were successfully
     * processed and execution should continue, or false if an error occurred or the user
     * asked for help. If false, the second value is the appropriate exit code (0 or 1).
     *
     * Returning true (execution continues) means args have been validated and derived
     * values calculated. In addition, field indices have been converted to zero-based.
     * If the whole line is the key, the individual fields list will be cleared.
     *
     * Repeat count control variables 'atLeast' and max' - These values are left at zero
     * if no repeat count options are specified. They are set if repeat count options
     * are specified, as follows:
     *   * atLeast - Will be zero unless --r|repeated or --a|at-least is specified.
     *     --r|repeated option sets it 2, --a|at-least sets it to the specified value.
     *   * max - Default to zero. Is set to the --m|max value if provided. Is set to
     *    'atLeast' if --r|repeated or --a|at-least is provided.
     *
     * An exception to the above: If --e|equiv-mode is specified, then (max == 0)
     * represents the default "output all values" case. In this case max may be less
     * than the at-least value.
     */
    auto processArgs (ref string[] cmdArgs)
    {
        import std.algorithm : all, each;
        import std.conv : to;
        import std.getopt;
        import std.path : baseName, stripExtension;
        import std.typecons : Yes, No;
        import tsv_utils.common.fieldlist;

        bool helpVerbose = false;         // --h|help-verbose
        bool versionWanted = false;       // --V|version
        string fieldsArg;                 // --f|fields

        string fieldsOptionString = "f|fields";

        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

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

                fieldsOptionString,      "<field-list>  Fields to use as the key. Default: 0 (entire line).", &fieldsArg,

                "i|ignore-case", "              Ignore case when comparing keys.", &ignoreCase,
                "r|repeated",    "              Output only lines that are repeated (based on the key).", &onlyRepeated,
                "a|at-least",    "INT           Output only lines that are repeated INT times (based on the key). Zero and one are ignored.", &atLeast,
                "m|max",         "INT           Max number of each unique key to output (zero is ignored).", &max,
                "e|equiv",       "              Output equivalence class IDs rather than uniq'ing entries.", &equivMode,
                "equiv-header",  "STR           Use STR as the equiv-id field header (when using '-H --equiv'). Default: 'equiv_id'.", &equivHeader,
                "equiv-start",   "INT           Use INT as the first equiv-id. Default: 1.", &equivStartID,
                "z|number",      "              Output equivalence class occurrence counts rather than uniq'ing entries.", &numberMode,
                "number-header", "STR           Use STR as the '--number' field header (when using '-H --number)'. Default: 'equiv_line'.", &numberHeader,
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
                import tsv_utils.common.tsvutils_version;
                writeln(tsvutilsVersionNotice("tsv-uniq"));
                return tuple(false, 0);
            }

            /* Input files. Remaining command line args are files. */
            string[] filepaths = (cmdArgs.length > 1) ? cmdArgs[1 .. $] : ["-"];
            cmdArgs.length = 1;
            ReadHeader readHeader = hasHeader ? Yes.readHeader : No.readHeader;
            inputSources = inputSourceRange(filepaths, readHeader);

            string[] headerFields;

            if (hasHeader) headerFields = inputSources.front.header.split(delim).to!(string[]);

            if (!fieldsArg.empty)
            {
                fields =
                    fieldsArg
                    .parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero)
                    (hasHeader, headerFields, fieldsOptionString)
                    .array;
            }

            /* Consistency checks */
            if (!equivMode)
            {
                enforce(equivHeader == defaultEquivHeader, "--equiv-header requires --e|equiv");
                enforce(equivStartID == defaultEquivStartID, "--equiv-start requires --e|equiv");
            }

            enforce(numberMode || numberHeader == defaultNumberHeader,
                    "--number-header requires --z|number");

            enforce(fields.length <= 1 || fields.all!(x => x != 0),
                    "Whole line as key (--f|field 0) cannot be combined with multiple fields.");

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

            if (onlyRepeated && atLeast <= 1) atLeast = 2;
            if (atLeast >= 2 && max < atLeast)
            {
                // Don't modify max if it is zero and equivMode or numberMode is in effect.
                if (max != 0 || (!equivMode && !numberMode)) max = atLeast;
            }

            if (!keyIsFullLine) fields.each!((ref x) => --x);  // Convert to 0-based indexing.

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

/** Main program. Processes command line arguments and calls tsvUniq which implements
 * the main processing logic.
 */
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

    version(LDC_Profile)
    {
        import ldc.profile : resetAll;
        resetAll();
    }

    try tsvUniq(cmdopt);
    catch (Exception exc)
    {
        stderr.writefln("Error [%s]: %s", cmdopt.programName, exc.msg);
        return 1;
    }
    return 0;
}

/** Outputs the unique lines from all the input files.
 *
 * Processes the lines in each input file. All lines are added to an associated array.
 * The first time a line is seen it is output. If key fields are being used these are
 * used as the basis for the associative array entries rather than the full line.
 */
void tsvUniq(ref TsvUniqOptions cmdopt)
{
    import tsv_utils.common.utils : bufferedByLine, BufferedOutputRange,
        InputFieldReordering, InputSourceRange, joinAppend, throwIfWindowsNewlineOnUnix;
    import std.algorithm : splitter;
    import std.array : appender;
    import std.conv : to;
    import std.uni : asLowerCase;
    import std.utf : byChar;

    /* inputSources must be an InputSourceRange and include at least stdin. */
    assert(!cmdopt.inputSources.empty);
    static assert(is(typeof(cmdopt.inputSources) == InputSourceRange));

    /* InputFieldReordering maps the key fields from an input line to a separate buffer. */
    auto keyFieldsReordering = cmdopt.keyIsFullLine ? null : new InputFieldReordering!char(cmdopt.fields);

    /* BufferedOutputRange is a performance enhancement for writing to stdout. */
    auto bufferedOutput = BufferedOutputRange!(typeof(stdout))(stdout);

    /* The master hash. The key is the specified fields concatenated together (including
     * separators). The value is a struct with the equiv-id and occurrence count.
     */
    static struct EquivEntry { size_t equivID; size_t count; }
    EquivEntry[string] equivHash;

    /* Reusable buffers for multi-field keys and case-insensitive keys. */
    auto multiFieldKeyBuffer = appender!(char[]);
    auto lowerKeyBuffer = appender!(char[]);

    const size_t numKeyFields = cmdopt.fields.length;
    long nextEquivID = cmdopt.equivStartID;

    /* First header is read during command line arg processing. */
    if (cmdopt.hasHeader && !cmdopt.inputSources.front.isHeaderEmpty)
    {
        auto inputStream = cmdopt.inputSources.front;
        throwIfWindowsNewlineOnUnix(inputStream.header, inputStream.name, 1);

        bufferedOutput.append(inputStream.header);

        if (cmdopt.equivMode)
        {
            bufferedOutput.append(cmdopt.delim);
            bufferedOutput.append(cmdopt.equivHeader);
        }

        if (cmdopt.numberMode)
        {
            bufferedOutput.append(cmdopt.delim);
            bufferedOutput.append(cmdopt.numberHeader);
        }

        bufferedOutput.appendln();
    }

    immutable size_t fileBodyStartLine = cmdopt.hasHeader ? 2 : 1;

    foreach (inputStream; cmdopt.inputSources)
    {
        if (cmdopt.hasHeader) throwIfWindowsNewlineOnUnix(inputStream.header, inputStream.name, 1);

        foreach (lineNum, line; inputStream.file.bufferedByLine.enumerate(fileBodyStartLine))
        {
            if (lineNum == 1) throwIfWindowsNewlineOnUnix(line, inputStream.name, lineNum);

            /* Start by finding the key. */
            typeof(line) key;
            if (cmdopt.keyIsFullLine)
            {
                key = line;
            }
            else
            {
                assert(keyFieldsReordering !is null);

                /* Copy the key fields to a new buffer. */
                keyFieldsReordering.initNewLine;
                foreach (fieldIndex, fieldValue; line.splitter(cmdopt.delim).enumerate)
                {
                    keyFieldsReordering.processNextField(fieldIndex, fieldValue);
                    if (keyFieldsReordering.allFieldsFilled) break;
                }

                enforce(keyFieldsReordering.allFieldsFilled,
                        format("Not enough fields in line. File: %s, Line: %s",
                               inputStream.name, lineNum));

                if (numKeyFields == 1)
                {
                    key = keyFieldsReordering.outputFields[0];
                }
                else
                {
                    multiFieldKeyBuffer.clear();
                    keyFieldsReordering.outputFields.joinAppend(multiFieldKeyBuffer, cmdopt.delim);
                    key = multiFieldKeyBuffer.data;
                }
            }

            if (cmdopt.ignoreCase)
            {
                /* Equivalent to key = key.toLower, but without memory allocation. */
                lowerKeyBuffer.clear();
                lowerKeyBuffer.put(key.asLowerCase.byChar);
                key = lowerKeyBuffer.data;
            }

            bool isOutput = false;
            EquivEntry currEntry;
            EquivEntry* priorEntry = (key in equivHash);
            if (priorEntry is null)
            {
                isOutput = (cmdopt.atLeast <= 1);
                currEntry.equivID = nextEquivID;
                currEntry.count = 1;
                equivHash[key.to!string] = currEntry;
                nextEquivID++;
            }
            else
            {
                (*priorEntry).count++;
                currEntry = *priorEntry;

                if ((currEntry.count <= cmdopt.max && currEntry.count >= cmdopt.atLeast) ||
                    (cmdopt.equivMode && cmdopt.max == 0) ||
                    (cmdopt.numberMode && cmdopt.max == 0))
                {
                    isOutput = true;
                }
            }

            if (isOutput)
            {
                bufferedOutput.append(line);

                if (cmdopt.equivMode)
                {
                    bufferedOutput.append(cmdopt.delim);
                    bufferedOutput.append(currEntry.equivID.to!string);
                }

                if (cmdopt.numberMode)
                {
                    bufferedOutput.append(cmdopt.delim);
                    bufferedOutput.append(currEntry.count.to!string);
                }

                bufferedOutput.appendln();
            }
        }
    }
}
