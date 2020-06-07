/**
Command line tool that joins tab-separated value files based on a common key.

This tool joins lines from tab-delimited files based on a common key. One file, the 'filter'
file, contains the records (lines) being matched. The other input files are searched for
matching records. Matching records are written to standard output, along with any designated
fields from the 'filter' file. In database parlance this is a 'hash semi-join'.

Copyright (c) 2015-2020, eBay Inc.
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)
*/
module tsv_utils.tsv_join;

import std.exception : enforce;
import std.stdio;
import std.format : format;
import std.range;
import std.typecons : tuple;

auto helpText = q"EOS
Synopsis: tsv-join --filter-file file [options] file [file...]

tsv-join matches input lines against lines from a 'filter' file. The match is
based on fields or the entire line. Use '--help-verbose' for more details.

Options:
EOS";

auto helpTextVerbose = q"EOS
Synopsis: tsv-join --filter-file file [options] file [file...]

tsv-join matches input lines against lines from a 'filter' file. The match is
based on exact match comparison of one or more 'key' fields. Fields are TAB
delimited by default. Matching lines are written to standard output, along with
any additional fields from the key file that have been specified. An example:

  tsv-join --filter-file filter.tsv --key-fields 1 --append-fields 5,6 data.tsv

This reads filter.tsv, creating a hash table keyed on field 1. Lines from data.tsv
are read one at a time. If field 1 is found in the hash table, the line is written
to standard output with fields 5 and 6 from the filter file appended. In database
parlance this is a "hash semi join". Note the asymmetric relationship: Records in
the filter file should be unique, but data.tsv lines can repeat.

tsv-join can also work as a simple filter, this is the default behavior. Example:

  tsv-join --filter-file filter.tsv data.tsv

This outputs all lines from data.tsv found in filter.tsv. --key-fields can still
be used to define the match key. The --exclude option can be used to exclude
matched lines rather than keep them.

Multiple fields can be specified as keys and append fields. Field numbers start
at one, zero represents the whole line. Fields are comma separated and ranges
can be used. Example:

  tsv-join -f filter.tsv -k 1,2 --append-fields 3-7 data.tsv

Options:
EOS";

/** Container for command line options.
 */
struct TsvJoinOptions
{
    import tsv_utils.common.utils : byLineSourceRange, ByLineSourceRange,
        inputSourceRange, InputSourceRange, ReadHeader;

    /* Data available the main program. Variables used only command line argument
     * processing are local to processArgs.
     */
    string programName;                /// Program name
    InputSourceRange inputSources;     /// Input Files
    ByLineSourceRange!() filterSource; /// Derived: --filter
    size_t[] keyFields;                /// Derived: --key-fields
    size_t[] dataFields;               /// Derived: --data-fields
    size_t[] appendFields;             /// Derived: --append-fields
    bool hasHeader = false;            // --H|header
    string appendHeaderPrefix = "";    // --append-header-prefix
    bool writeAll = false;             // --write-all
    string writeAllValue;              // --write-all
    bool exclude = false;              // --exclude
    char delim = '\t';                 // --delimiter
    bool allowDupliateKeys = false;    // --allow-duplicate-keys
    bool keyIsFullLine = false;        // Derived: --key-fields 0
    bool dataIsFullLine = false;       // Derived: --data-fields 0
    bool appendFullLine = false;       // Derived: --append-fields 0

    /* Returns a tuple. First value is true if command line arguments were successfully
     * processed and execution should continue, or false if an error occurred or the user
     * asked for help. If false, the second value is the appropriate exit code (0 or 1).
     *
     * Returning true (execution continues) means args have been validated and derived
     * values calculated. In addition, field indices have been converted to zero-based.
     * If the whole line is the key, the individual fields lists will be cleared.
     */
    auto processArgs (ref string[] cmdArgs)
    {
        import std.array : split;
        import std.conv : to;
        import std.getopt;
        import std.path : baseName, stripExtension;
        import std.typecons : Yes, No;
        import tsv_utils.common.fieldlist;

        bool helpVerbose = false;        // --help-verbose
        bool versionWanted = false;      // --V|version
        string filterFile;               // --filter
        string keyFieldsArg;             // --key-fields
        string dataFieldsArg;            // --data-fields
        string appendFieldsArg;          // --append-fields

        string keyFieldsOptionString = "k|key-fields";
        string dataFieldsOptionString = "d|data-fields";
        string appendFieldsOptionString = "a|append-fields";

        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

        /* Handler for --write-all. Special handler so two values can be set. */
        void writeAllHandler(string option, string value)
        {
            debug stderr.writeln("[writeAllHandler] |", option, "|  |", value, "|");
            writeAll = true;
            writeAllValue = value;
        }

        try
        {
            arraySep = ",";    // Use comma to separate values in command line options
            auto r = getopt(
                cmdArgs,
                "help-verbose",    "              Print full help.", &helpVerbose,
                "f|filter-file",   "FILE          (Required) File with records to use as a filter.", &filterFile,

                keyFieldsOptionString,
                "<field-list>  Fields to use as join key. Default: 0 (entire line).",
                &keyFieldsArg,

                dataFieldsOptionString,
                "<field-list>  Data record fields to use as join key, if different than --key-fields.",
                &dataFieldsArg,

                appendFieldsOptionString,
                "<field-list>  Filter fields to append to matched records.",
                &appendFieldsArg,

                std.getopt.config.caseSensitive,
                "H|header",        "              Treat the first line of each file as a header.", &hasHeader,
                std.getopt.config.caseInsensitive,
                "p|prefix",        "STR           String to use as a prefix for --append-fields when writing a header line.", &appendHeaderPrefix,
                "w|write-all",     "STR           Output all data records. STR is the --append-fields value when writing unmatched records.", &writeAllHandler,
                "e|exclude",       "              Exclude matching records.", &exclude,
                "delimiter",       "CHR           Field delimiter. Default: TAB. (Single byte UTF-8 characters only.)", &delim,
                "z|allow-duplicate-keys",
                                   "              Allow duplicate keys with different append values (last entry wins).", &allowDupliateKeys,
                std.getopt.config.caseSensitive,
                "V|version",       "              Print version information and exit.", &versionWanted,
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
                writeln(tsvutilsVersionNotice("tsv-join"));
                return tuple(false, 0);
            }

            /* File arguments.
             *   *  --filter-file required, converted to a one-element ByLineSourceRange
             *   *  Remaining command line args are input files.
             */
            enforce(filterFile.length != 0,
                    "Required option --filter-file was not supplied.");

            enforce(!(filterFile == "-" && cmdArgs.length == 1),
                    "A data file is required when standard input is used for the filter file (--f|filter-file -).");

            filterSource = byLineSourceRange([filterFile]);

            string[] filepaths = (cmdArgs.length > 1) ? cmdArgs[1 .. $] : ["-"];
            cmdArgs.length = 1;
            ReadHeader readHeader = hasHeader ? Yes.readHeader : No.readHeader;
            inputSources = inputSourceRange(filepaths, readHeader);

            /* Field-list args (--k|key-fields, --d|data-fields --a|append-fields are
             * parsed after header lines from the filter file and first data file have
             * been read. The files were opened in the previous step, when setting up
             * the 'filterSource' and 'inputSources' ranges.
             *
             * The field-list parsing step translates any named fields to one-based
             * field numbers. Note that a named field may have different field
             * numbers in the filter file and data files.
             *
             * The 'derivations()' method works off the one-based indices, converting
             * them to zero-based. It also handles the full-line cases.
             */

            string[] filterFileHeaderFields;
            string[] inputSourceHeaderFields;

            if (hasHeader && !filterSource.front.byLine.empty)
            {
                filterFileHeaderFields = filterSource.front.byLine.front.split(delim).to!(string[]);
            }

            if (hasHeader) inputSourceHeaderFields = inputSources.front.header.split(delim).to!(string[]);

            if (!keyFieldsArg.empty)
            {
                keyFields =
                    keyFieldsArg
                    .parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero)
                    (hasHeader, filterFileHeaderFields, keyFieldsOptionString)
                    .array;
            }

            if (!dataFieldsArg.empty)
            {
                dataFields =
                    dataFieldsArg
                    .parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero)
                    (hasHeader, inputSourceHeaderFields, dataFieldsOptionString)
                    .array;
            }
            else if (!keyFieldsArg.empty)
            {
                dataFields =
                    keyFieldsArg
                    .parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero)
                    (hasHeader, inputSourceHeaderFields, dataFieldsOptionString)
                    .array;
            }

            if (!appendFieldsArg.empty)
            {
                appendFields =
                    appendFieldsArg
                    .parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero)
                    (hasHeader, filterFileHeaderFields, appendFieldsOptionString)
                    .array;
            }

            consistencyValidations(cmdArgs);
            derivations();
        }
        catch (Exception exc)
        {
            stderr.writefln("[%s] Error processing command line arguments: %s", programName, exc.msg);
            return tuple(false, 1);
        }
        return tuple(true, 0);
    }

    /* This routine does validations not handled by getopt, usually because they
     * involve interactions between multiple parameters.
     */
    private void consistencyValidations(ref string[] processedCmdArgs)
    {
        import std.algorithm : all;

        if (writeAll)
        {
            enforce(appendFields.length != 0,
                    "Use --a|append-fields when using --w|write-all.");

            enforce(!(appendFields.length == 1 && appendFields[0] == 0),
                    "Cannot use '--a|append-fields 0' (whole line) when using --w|write-all.");
        }

        enforce(!(appendFields.length > 0 && exclude),
                "--e|exclude cannot be used with --a|append-fields.");

        enforce(appendHeaderPrefix.length == 0 || hasHeader,
                "Use --header when using --p|prefix.");

        enforce(dataFields.length == 0 || keyFields.length == dataFields.length,
                "Different number of --k|key-fields and --d|data-fields.");

        enforce(keyFields.length != 1 ||
                dataFields.length != 1 ||
                (keyFields[0] == 0 && dataFields[0] == 0) ||
                (keyFields[0] != 0 && dataFields[0] != 0),
                "If either --k|key-field or --d|data-field is zero both must be zero.");

        enforce((keyFields.length <= 1 || all!(a => a != 0)(keyFields)) &&
                (dataFields.length <= 1 || all!(a => a != 0)(dataFields)) &&
                (appendFields.length <= 1 || all!(a => a != 0)(appendFields)),
                "Field 0 (whole line) cannot be combined with individual fields (non-zero).");
    }

    /* Post-processing derivations. */
    void derivations()
    {
        import std.algorithm : each;
        import std.range;

        // Convert 'full-line' field indexes (index zero) to boolean flags.
        if (keyFields.length == 0)
        {
            assert(dataFields.length == 0);
            keyIsFullLine = true;
            dataIsFullLine = true;
        }
        else if (keyFields.length == 1 && keyFields[0] == 0)
        {
            keyIsFullLine = true;
            keyFields.popFront;
            dataIsFullLine = true;

            if (dataFields.length == 1)
            {
                assert(dataFields[0] == 0);
                dataFields.popFront;
            }
        }

        if (appendFields.length == 1 && appendFields[0] == 0)
        {
            appendFullLine = true;
            appendFields.popFront;
        }

        assert(!(keyIsFullLine && keyFields.length > 0));
        assert(!(dataIsFullLine && dataFields.length > 0));
        assert(!(appendFullLine && appendFields.length > 0));

        // Switch to zero-based field indexes.
        keyFields.each!((ref a) => --a);
        dataFields.each!((ref a) => --a);
        appendFields.each!((ref a) => --a);
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

    TsvJoinOptions cmdopt;
    auto r = cmdopt.processArgs(cmdArgs);
    if (!r[0]) return r[1];
    try tsvJoin(cmdopt);
    catch (Exception exc)
    {
        stderr.writefln("Error [%s]: %s", cmdopt.programName, exc.msg);
        return 1;
    }
    return 0;
}

/** tsvJoin does the primary work of the tsv-join program.
 */
void tsvJoin(ref TsvJoinOptions cmdopt)
{
    import tsv_utils.common.utils : ByLineSourceRange, bufferedByLine, BufferedOutputRange,
        InputFieldReordering, InputSourceRange, throwIfWindowsNewlineOnUnix;
    import std.algorithm : splitter;
    import std.array : join;
    import std.range;
    import std.conv : to;

    /* Check that the input files were setup correctly. Should have one filter file as a
     * ByLineSourceRange. There should be at least one input file as an InputSourceRange.
     */
    assert(cmdopt.filterSource.length == 1);
    static assert(is(typeof(cmdopt.filterSource) == ByLineSourceRange!(No.keepTerminator)));

    assert(!cmdopt.inputSources.empty);
    static assert(is(typeof(cmdopt.inputSources) == InputSourceRange));

    /* State, variables, and convenience derivations.
     *
     * Combinations of individual fields and whole line (field zero) are convenient for the
     * user, but create complexities for the program. Many combinations are disallowed by
     * command line processing, but the remaining combos still leave several states. Also,
     * this code optimizes by doing only necessary operations, further complicating state
     * Here's a guide to variables and state.
     * - cmdopt.keyFields, cmdopt.dataFields arrays - Individual field indexes used as keys.
     *      Empty if the  whole line is used as a key. Must be the same length.
     * - cmdopt.keyIsFullLine, cmdopt.dataIsFullLine - True when the whole line is used key.
     * - cmdopt.appendFields array - Indexes of individual filter file fields being appended.
     *      Empty if appending the full line, or if not appending anything.
     * - cmdopt.appendFullLine - True when the whole line is being appended.
     * - isAppending - True is something is being appended.
     * - cmdopt.writeAll - True if all lines are being written
     */
    /* Convenience derivations. */
    auto numKeyFields = cmdopt.keyFields.length;
    auto numAppendFields = cmdopt.appendFields.length;
    bool isAppending = (cmdopt.appendFullLine || numAppendFields > 0);

    /* Mappings from field indexes in the input lines to collection arrays. */
    auto filterKeysReordering = new InputFieldReordering!char(cmdopt.keyFields);
    auto dataKeysReordering = (cmdopt.dataFields.length == 0) ?
        filterKeysReordering : new InputFieldReordering!char(cmdopt.dataFields);
    auto appendFieldsReordering = new InputFieldReordering!char(cmdopt.appendFields);

    /* The master filter hash. The key is the delimited fields concatenated together
     * (including separators). The value is the appendFields concatenated together, as
     * they will be appended to the input line. Both the keys and append fields are
     * assembled in the order specified, though this only required for append fields.
     */
    string[string] filterHash;
    string appendFieldsHeader;

    /* The append values for unmatched records. */
    char[] appendFieldsUnmatchedValue;

    if (cmdopt.writeAll)
    {
        assert(cmdopt.appendFields.length > 0);  // Checked in consistencyValidations

        // reserve space for n values and n-1 delimiters
        appendFieldsUnmatchedValue.reserve(cmdopt.appendFields.length * (cmdopt.writeAllValue.length + 1) - 1);

        appendFieldsUnmatchedValue ~= cmdopt.writeAllValue;
        for (size_t i = 1; i < cmdopt.appendFields.length; ++i)
        {
            appendFieldsUnmatchedValue ~= cmdopt.delim;
            appendFieldsUnmatchedValue ~= cmdopt.writeAllValue;
        }
    }

    /* Read the filter file. */
    {
        bool needPerFieldProcessing = (numKeyFields > 0) || (numAppendFields > 0);
        auto filterStream = cmdopt.filterSource.front;
        foreach (lineNum, line; filterStream.byLine.enumerate(1))
        {
            debug writeln("[filter line] |", line, "|");
            if (needPerFieldProcessing)
            {
                filterKeysReordering.initNewLine;
                appendFieldsReordering.initNewLine;

                foreach (fieldIndex, fieldValue; line.splitter(cmdopt.delim).enumerate)
                {
                    filterKeysReordering.processNextField(fieldIndex,fieldValue);
                    appendFieldsReordering.processNextField(fieldIndex,fieldValue);

                    if (filterKeysReordering.allFieldsFilled && appendFieldsReordering.allFieldsFilled)
                    {
                        break;
                    }
                }

                // Processed all fields in the line.
                enforce(filterKeysReordering.allFieldsFilled && appendFieldsReordering.allFieldsFilled,
                        format("Not enough fields in line. File: %s, Line: %s",
                               filterStream.name, lineNum));
            }

            string key = cmdopt.keyIsFullLine ?
                line.to!string : filterKeysReordering.outputFields.join(cmdopt.delim).to!string;
            string appendValues = cmdopt.appendFullLine ?
                line.to!string : appendFieldsReordering.outputFields.join(cmdopt.delim).to!string;

            debug writeln("  --> [key]:[append] => [", key, "]:[", appendValues, "]");

            if (lineNum == 1) throwIfWindowsNewlineOnUnix(line, filterStream.name, lineNum);

            if (lineNum == 1 && cmdopt.hasHeader)
            {
                if (cmdopt.appendHeaderPrefix.length == 0)
                {
                    appendFieldsHeader = appendValues;
                }
                else
                {
                    foreach (fieldIndex, fieldValue; appendValues.splitter(cmdopt.delim).enumerate)
                    {
                        if (fieldIndex > 0) appendFieldsHeader ~= cmdopt.delim;
                        appendFieldsHeader ~= cmdopt.appendHeaderPrefix;
                        appendFieldsHeader ~= fieldValue;
                    }
                }
            }
            else
            {
                if (isAppending && !cmdopt.allowDupliateKeys)
                {
                    string* currAppendValues = (key in filterHash);

                    enforce(currAppendValues is null || *currAppendValues == appendValues,
                            format("Duplicate keys with different append values (use --z|allow-duplicate-keys to ignore)\n   [key 1][values]: [%s][%s]\n   [key 2][values]: [%s][%s]",
                                   key, *currAppendValues, key, appendValues));
                }
                filterHash[key] = appendValues;
            }
        }

        /* popFront here closes the filter file. */
        cmdopt.filterSource.popFront;
    }

    /* Now process each input file, one line at a time. */

    auto bufferedOutput = BufferedOutputRange!(typeof(stdout))(stdout);

    /* First header is read during command line argument processing. */
    if (cmdopt.hasHeader && !cmdopt.inputSources.front.isHeaderEmpty)
    {
        auto inputStream = cmdopt.inputSources.front;
        throwIfWindowsNewlineOnUnix(inputStream.header, inputStream.name, 1);

        bufferedOutput.append(inputStream.header);
        if (isAppending)
        {
            bufferedOutput.append(cmdopt.delim);
            bufferedOutput.append(appendFieldsHeader);
        }
        bufferedOutput.appendln;
    }

    immutable size_t fileBodyStartLine = cmdopt.hasHeader ? 2 : 1;

    foreach (inputStream; cmdopt.inputSources)
    {
        if (cmdopt.hasHeader) throwIfWindowsNewlineOnUnix(inputStream.header, inputStream.name, 1);

        foreach (lineNum, line; inputStream.file.bufferedByLine.enumerate(fileBodyStartLine))
        {
            debug writeln("[input line] |", line, "|");

            if (lineNum == 1) throwIfWindowsNewlineOnUnix(line, inputStream.name, lineNum);

            /*
             * Next block checks if the input line matches a hash entry. Two cases:
             *   a) The whole line is the key. Simply look it up in the hash.
             *   b) Individual fields are used as the key - Assemble key and look it up.
             *
             * At the end of the appendFields will contain the result of hash lookup.
             */
            string* appendFields;
            if (cmdopt.keyIsFullLine)
            {
                appendFields = (line in filterHash);
            }
            else
            {
                dataKeysReordering.initNewLine;
                foreach (fieldIndex, fieldValue; line.splitter(cmdopt.delim).enumerate)
                {
                    dataKeysReordering.processNextField(fieldIndex, fieldValue);
                    if (dataKeysReordering.allFieldsFilled) break;
                }
                // Processed all fields in the line.
                enforce(dataKeysReordering.allFieldsFilled,
                        format("Not enough fields in line. File: %s, Line: %s",
                               inputStream.name, lineNum));

                appendFields = (dataKeysReordering.outputFields.join(cmdopt.delim) in filterHash);
            }

            bool matched = (appendFields !is null);
            debug writeln("   --> matched? ", matched);
            if (cmdopt.writeAll || (matched && !cmdopt.exclude) || (!matched && cmdopt.exclude))
            {
                bufferedOutput.append(line);
                if (isAppending)
                {
                    bufferedOutput.append(cmdopt.delim);
                    bufferedOutput.append(matched ? *appendFields : appendFieldsUnmatchedValue);
                }
                bufferedOutput.appendln();
            }
        }
    }
}
