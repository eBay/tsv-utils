/**
A variant of the unix 'cut' program, with the ability to reorder fields.

tsv-select is a variation on the Unix 'cut' utility, with the added ability to reorder
fields. Lines are read from files or standard input and split on a delimiter character.
Fields are written to standard output in the order listed. Fields can be listed more
than once, and fields not listed can be written out as a group.

This program is intended both as a useful utility and a D programming language example.
Functionality and constructs used include command line argument processing, file I/O,
exception handling, ranges, tuples and strings, templates, universal function call syntax
(UFCS), lambdas and functional programming constructs. Comments are more verbose than
typical to shed light on D programming constructs, but not to the level of a tutorial.

Copyright (c) 2015-2020, eBay Inc.
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)
*/

module tsv_utils.tsv_select;   // Module name defaults to file name, but hyphens not allowed, so set it here.

// Imports used by multiple routines. Others imports made in local context.
import std.exception : enforce;
import std.stdio;
import std.typecons : tuple, Tuple;
import tsv_utils.common.utils : ByLineSourceRange;

// 'Heredoc' style help text. When printed it is followed by a getopt formatted option list.
immutable helpText = q"EOS
Synopsis: tsv-select [options] [file...]

tsv-select reads files or standard input and writes selected fields to
standard output. Fields are written in the order listed. This is similar
to Unix 'cut', but with the ability to reorder fields.

Fields numbers start with one. They are comma separated and ranges can be
used. Fields can be repeated, and fields not included in the '--f|fields'
option can be selected as a group using '--r|rest'. Fields can be dropped
using '--e|exclude'. Multiple files with header lines can be managed with
'--H|header', which retains the header of the first file only.

Examples:

   # Output fields 2 and 1, in that order
   tsv-select -f 2,1 data.tsv

   # Drop the first field, keep everything else.
   tsv-select --exclude 1 file.tsv

   # Move the first field to the end
   tsv-select -f 1 --rest first data.tsv

   # Multiple files with header lines. Keep only one header.
   tsv-select data*.tsv -H --fields 1,2,4-7,14

Use '--help-verbose' for detailed information.

Options:
EOS";

immutable helpTextVerbose = q"EOS
Synopsis: tsv-select [options] [file...]

tsv-select reads files or standard input and writes selected fields to
standard output. Fields are written in the order listed. This is similar
to Unix 'cut', but with the ability to reorder fields.

Fields numbers start with one. They are comma separated and ranges can be
used. Fields can be repeated, and fields not included in the '--f|fields'
option can be selected as a group using '--r|rest'. Use '--H|header' to
retain the header line from only the first file.

Fields can be excluded using '--e|exclude'. All fields not excluded are
output. '--f|fields' and '--r|rest' can be used with '--e|exclude' to
reorder non-excluded fields.

Examples:

   # Keep the first field from two files
   tsv-select -f 1 file1.tsv file2.tsv

   # Keep fields 1 and 2, retain the header from the first file
   tsv-select -H -f 1,2 file1.tsv file2.tsv

   # Field reordering and field ranges
   tsv-select -f 3,2,1 file.tsv
   tsv-select -f 1,4-7,11 file.tsv
   tsv-select -f 1,7-4,11 file.tsv

   # Repeating fields
   tsv-select -f 1,2,1 file.tsv
   tsv-select -f 1-3,3-1 file.tsv

   # Move field 5 to the front
   tsv-select -f 5 --rest last file.tsv

   # Move fields 4 and 5 to the end
   tsv-select -f 4,5 --rest first file.tsv

   # Drop the first field, keep everything else
   tsv-select --exclude 1 file.tsv

   # Move field 2 to the front and drop fields 10-15
   tsv-select -f 2 -e 10-15 file.tsv

   # Move field 2 to the end, dropping fields 10-15
   tsv-select -f 2 -rest first -e 10-15 file.tsv

Notes:
* One of '--f|fields' or '--e|exclude' is required.
* Fields specified by '--f|fields' and '--e|exclude' cannot overlap.
* When '--f|fields' and '--e|exclude' are used together, the effect is to
  specify '--rest last'. This can be overridden by using '--rest first'.
* Each input line must be long enough to contain all fields specified with
  '--f|fields'. This is not necessary for '--e|exclude' fields.

Options:
EOS";

/** Container for command line options.
 */
struct TsvSelectOptions
{
    // The allowed values for the --rest option.
    enum RestOption { none, first, last};

    string programName;                 /// Program name
    ByLineSourceRange!() inputSources;  /// Input Files
    bool helpVerbose = false;           /// --help-verbose
    bool hasHeader = false;             /// --H|header
    char delim = '\t';                  /// --d|delimiter
    size_t[] fields;                    /// --f|fields
    size_t[] excludedFieldsArg;         /// --e|exclude
    RestOption restArg;                 /// --rest first|last (none is hidden default)
    bool versionWanted = false;         /// --V|version
    bool[] excludedFieldsTable;         /// Derived. Lookup table for excluded fields.

    /** Process command line arguments (getopt cover).
     *
     * processArgs calls getopt to process command line arguments. It does any additional
     * validation and parameter derivations needed. A tuple is returned. First value is
     * true if command line arguments were successfully processed and execution should
     * continue, or false if an error occurred or the user asked for help. If false, the
     * second value is the appropriate exit code (0 or 1).
     *
     * Returning true (execution continues) means args have been validated and derived
     * values calculated. In addition, field indices have been converted to zero-based.
     */
    auto processArgs (ref string[] cmdArgs)
    {
        import std.algorithm : any, each, maxElement;
        import std.format : format;
        import std.getopt;
        import std.path : baseName, stripExtension;
        import std.typecons : Yes, No;
        import tsv_utils.common.utils :  makeFieldListOptionHandler;

        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

        try
        {
            arraySep = ",";    // Use comma to separate values in command line options
            auto r = getopt(
                cmdArgs,
                "help-verbose",    "     Print more detailed help.", &helpVerbose,

                std.getopt.config.caseSensitive,
                "H|header",    "              Treat the first line of each file as a header.", &hasHeader,
                std.getopt.config.caseInsensitive,

                "f|fields",    "<field-list>  Fields to retain. Fields are output in the order listed.",
                fields.makeFieldListOptionHandler!(size_t, Yes.convertToZeroBasedIndex),

                "e|exclude",   "<field-list>  Fields to exclude.",
                excludedFieldsArg.makeFieldListOptionHandler!(size_t, Yes.convertToZeroBasedIndex),

                "r|rest",      "first|last    Output location for fields not included in '--f|fields'.", &restArg,
                "d|delimiter", "CHR           Character to use as field delimiter. Default: TAB. (Single byte UTF-8 characters only.)", &delim,
                std.getopt.config.caseSensitive,
                "V|version",   "              Print version information and exit.", &versionWanted,
                std.getopt.config.caseInsensitive,
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
                writeln(tsvutilsVersionNotice("tsv-select"));
                return tuple(false, 0);
            }

            /*
             * Consistency checks and derivations.
             */

            enforce(fields.length != 0 || excludedFieldsArg.length != 0,
                    "One of '--f|fields' or '--e|exclude' is required.");

            /* Remaining command line args are files. Use standard input if files
             * were not provided. Truncate cmdArgs to consume the arguments.
             */
            string[] filepaths = (cmdArgs.length > 1) ? cmdArgs[1 .. $] : ["-"];
            cmdArgs.length = 1;
            inputSources = ByLineSourceRange!()(filepaths);

            if (excludedFieldsArg.length > 0)
            {
                /* Make sure selected and excluded fields do not overlap. */
                foreach (e; excludedFieldsArg)
                {
                    foreach (f; fields)
                    {
                        enforce(e != f, "'--f|fields' and '--e|exclude' have overlapping fields.");
                    }
                }

                /* '--exclude' changes '--rest' default to 'last'. */
                if (restArg == RestOption.none) restArg = RestOption.last;

                /* Build the excluded field lookup table.
                 *
                 * Note: Users won't have any reason to expect memory is allocated based
                 * on the max field number. However, users might pick arbitrarily large
                 * numbers when trimming fields. So, limit the max field number to something
                 * big but reasonable (more than 1 million). The limit can be raised if use
                 * cases arise.
                 */
                size_t maxExcludedField = excludedFieldsArg.maxElement;
                size_t maxAllowedExcludedField = 1024 * 1024;

                enforce(maxExcludedField < maxAllowedExcludedField,
                        format("Maximum allowed '--e|exclude' field number is %d.",
                               maxAllowedExcludedField));

                excludedFieldsTable.length = maxExcludedField + 1;          // Initialized to false
                foreach (e; excludedFieldsArg) excludedFieldsTable[e] = true;
            }
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

/** Main program.
 */
int main(string[] cmdArgs)
{
    /* When running in DMD code coverage mode, turn on report merging. */
    version(D_Coverage) version(DigitalMars)
    {
        import core.runtime : dmd_coverSetMerge;
        dmd_coverSetMerge(true);
    }

    TsvSelectOptions cmdopt;
    const r = cmdopt.processArgs(cmdArgs);
    if (!r[0]) return r[1];
    version(LDC_Profile)
    {
        import ldc.profile : resetAll;
        resetAll();
    }
    try
    {
        /* Invoke the tsvSelect template matching the --rest option chosen. Option args
         * are removed by command line processing (getopt). The program name and any files
         * remain. Pass the files to tsvSelect.
         */
        final switch (cmdopt.restArg)
        {
        case TsvSelectOptions.RestOption.none:
            tsvSelect!(RestLocation.none)(cmdopt);
            break;
        case TsvSelectOptions.RestOption.first:
            tsvSelect!(RestLocation.first)(cmdopt);
            break;
        case TsvSelectOptions.RestOption.last:
            tsvSelect!(RestLocation.last)(cmdopt);
            break;
        }
    }
    catch (Exception exc)
    {
        stderr.writefln("Error [%s]: %s", cmdopt.programName, exc.msg);
        return 1;
    }

    return 0;
}

// tsvSelect

/** Enumeration of the different specializations of the tsvSelect template.
 *
 * RestLocation is logically equivalent to the TsvSelectOptions.RestOption enum. It
 * is used by main to choose the appropriate tsvSelect template instantiation to call. It
 * is distinct from the TsvSelectOptions enum to separate it from the end-user UI. The
 * TsvSelectOptions version specifies the text of allowed values in command line arguments.
 */
enum RestLocation { none, first, last };

/** tsvSelect does the primary work of the tsv-select program.
 *
 * Input is read line by line, extracting the listed fields and writing them out in the order
 * specified. An exception is thrown on error.
 *
 * This function is templatized with instantiations for the different --rest options. This
 * avoids repeatedly running the same if-tests inside the inner loop. The main function
 * instantiates this function three times, once for each of the --rest options. It results
 * in a larger program, but is faster. Run-time improvements of 25% were measured compared
 * to the non-templatized version. (Note: 'cte' stands for 'compile time evaluation'.)
 */

void tsvSelect(RestLocation rest)(ref TsvSelectOptions cmdopt)
{
    import tsv_utils.common.utils: BufferedOutputRange, InputFieldReordering, throwIfWindowsNewlineOnUnix;
    import std.algorithm: splitter;
    import std.array : appender, Appender;
    import std.format: format;
    import std.range;

    // Ensure the correct template instantiation was called.
    static if (rest == RestLocation.none)
        assert(cmdopt.restArg == TsvSelectOptions.RestOption.none);
    else static if (rest == RestLocation.first)
        assert(cmdopt.restArg == TsvSelectOptions.RestOption.first);
    else static if (rest == RestLocation.last)
        assert(cmdopt.restArg == TsvSelectOptions.RestOption.last);
    else
        static assert(false, "rest template argument does not match cmdopt.restArg.");

    /* Check that the input files were setup as expected. Should at least have one
     * input, stdin if nothing else, and newlines removed from the byLine range.
     */
    assert(!cmdopt.inputSources.empty);
    static assert(is(typeof(cmdopt.inputSources) == ByLineSourceRange!(No.keepTerminator)));

    /* The algorithm here assumes RestOption.none is not used with --exclude-fields. */
    assert(cmdopt.excludedFieldsTable.length == 0 || rest != RestLocation.none);

    /* InputFieldReordering copies select fields from an input line to a new buffer.
     * The buffer is reordered in the process.
     */
    auto fieldReordering = new InputFieldReordering!char(cmdopt.fields);

    /* Fields not on the --fields list are added to a separate buffer so they can be
     * output as a group (the --rest option). This is done using an 'Appender', which
     * is faster than the ~= operator. The Appender is passed a GC allocated buffer
     * that grows as needed and is reused for each line. Typically it'll grow only
     * on the first line.
     */
    static if (rest != RestLocation.none)
    {
        auto leftOverFieldsAppender = appender!(char[][]);
    }

    /* BufferedOutputRange (from tsvutils.d) is a performance improvement over writing
     * directly to stdout.
     */
    auto bufferedOutput = BufferedOutputRange!(typeof(stdout))(stdout);

    /* Read each input file (or stdin) and iterate over each line.
     */
    foreach (fileNum, inputStream; cmdopt.inputSources.enumerate)
    {
        foreach (lineNum, line; inputStream.byLine.enumerate(1))
        {
            if (lineNum == 1) throwIfWindowsNewlineOnUnix(line, inputStream.name, lineNum);

            if (lineNum == 1 && fileNum > 0 && cmdopt.hasHeader)
            {
                continue;   // Drop the header line from all but the first file.
            }

            static if (rest != RestLocation.none)
            {
                leftOverFieldsAppender.clear;

                /* Track the field location in the line. This enables bulk appending
                 * after the last specified field has been processed.
                 */
                size_t nextFieldStart = 0;
            }

            fieldReordering.initNewLine;

            foreach (fieldIndex, fieldValue; line.splitter(cmdopt.delim).enumerate)
            {
                static if (rest == RestLocation.none)
                {
                    fieldReordering.processNextField(fieldIndex, fieldValue);
                    if (fieldReordering.allFieldsFilled) break;
                }
                else
                {
                    /* Processing with 'rest' fields. States:
                     *  - Excluded fields and specified fields remain
                     *  - Only specified fields remain
                     *  - Only excluded fields remain
                     */

                    nextFieldStart += fieldValue.length + 1;
                    bool excludedFieldsRemain = fieldIndex < cmdopt.excludedFieldsTable.length;
                    immutable isExcluded = excludedFieldsRemain && cmdopt.excludedFieldsTable[fieldIndex];

                    if (!isExcluded)
                    {
                        immutable numMatched = fieldReordering.processNextField(fieldIndex, fieldValue);

                        if (numMatched == 0) leftOverFieldsAppender.put(fieldValue);
                    }
                    else if (fieldIndex + 1 == cmdopt.excludedFieldsTable.length)
                    {
                        excludedFieldsRemain = false;
                    }

                    if (fieldReordering.allFieldsFilled && !excludedFieldsRemain)
                    {
                        /* Processed all specified fields. Bulk append any fields
                         * remaining on the line. Cases:
                         * - Current field is last field:
                         */
                        if (nextFieldStart <= line.length)
                        {
                            leftOverFieldsAppender.put(line[nextFieldStart .. $]);
                        }

                        break;
                    }
                }
            }

            // Finished with all fields in the line.
            enforce(fieldReordering.allFieldsFilled,
                    format("Not enough fields in line. File: %s,  Line: %s",
                           inputStream.name, lineNum));

            // Write the re-ordered line.

            static if (rest == RestLocation.first)
            {
                if (leftOverFieldsAppender.data.length > 0)
                {
                    bufferedOutput.joinAppend(leftOverFieldsAppender.data, cmdopt.delim);
                    if (cmdopt.fields.length > 0) bufferedOutput.append(cmdopt.delim);
                }
            }

            bufferedOutput.joinAppend(fieldReordering.outputFields, cmdopt.delim);

            static if (rest == RestLocation.last)
            {
                if (leftOverFieldsAppender.data.length > 0)
                {
                    if (cmdopt.fields.length > 0) bufferedOutput.append(cmdopt.delim);
                    bufferedOutput.joinAppend(leftOverFieldsAppender.data, cmdopt.delim);
                }
            }

            bufferedOutput.appendln;
        }
    }
}
