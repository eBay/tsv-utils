/**
Command line tool that filters TSV files.

This tool filters tab-delimited files based on numeric or string comparisons
against specific fields. See the helpText string for details.

Copyright (c) 2015-2021, eBay Inc.
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)
*/
module tsv_utils.tsv_filter;

import std.algorithm : canFind, equal, findSplit, max, min;
import std.conv : to;
import std.exception : enforce;
import std.format : format;
import std.math : abs, isFinite, isInfinity, isNaN;
import std.range;
import std.regex;
import std.stdio;
import std.string : isNumeric;
import std.typecons;
import std.uni: asLowerCase, toLower, byGrapheme;

/* The program has two main parts, command line arg processing and processing the input
 * files. Much of the work is in command line arg processing. This sets up the tests run
 * against each input line. The tests are an array of delegates (closures) run against the
 * fields in the line. The tests are based on command line arguments, of which there is
 * a lengthy set, one for each test.
 */

static if (__VERSION__ >= 2085) extern(C) __gshared string[] rt_options = [ "gcopt=cleanup:none" ];

/** Main program. Invokes command line arg processing and tsv-filter to perform
 * the real work. Any errors are caught and reported.
 */
int main(string[] cmdArgs)
{
    /* When running in DMD code coverage mode, turn on report merging. */
    version(D_Coverage) version(DigitalMars)
    {
        import core.runtime : dmd_coverSetMerge;
        dmd_coverSetMerge(true);
    }

    TsvFilterOptions cmdopt;
    const r = cmdopt.processArgs(cmdArgs);
    if (!r[0]) return r[1];
    version(LDC_Profile)
    {
        import ldc.profile : resetAll;
        resetAll();
    }
    try tsvFilterCommand(cmdopt);
    catch (Exception e)
    {
        stderr.writefln("Error [%s]: %s", cmdopt.programName, e.msg);
        return 1;
    }
    return 0;
}

immutable helpText = q"EOS
Synopsis: tsv-filter [options] [file...]

Filter tab-delimited files for matching lines via comparison tests against
individual fields. Use '--help-verbose' for a more detailed description.

Fields are specified using field number or field name. Field names require
that the input file has a header line. Use '--help-fields' for details.

Global options:
  --help-verbose      Print full help.
  --help-options      Print the options list by itself.
  --help-fields       Print help on specifying fields.
  --V|version         Print version information and exit.
  --H|header          Treat the first line of each file as a header.
  --or                Evaluate tests as an OR rather than an AND clause.
  --v|invert          Invert the filter, printing lines that do not match.
  --c|count           Print only a count of the matched lines.
  --d|delimiter CHR   Field delimiter. Default: TAB.
  --label STR         Rather than filter, mark each record as passing the
                         filter or not. STR is the header, ignored if there
                         is no header line.
  --label-values STR1:STR2
                      The pass/no-pass values used by '--label'. Defaults
                         to '1' and '0'.
  --line-buffered     Immediately output every matched line.

Operators:
* Test if a field is empty (no characters) or blank (empty or whitespace only).
  Syntax:  --empty|not-empty|blank|not-blank  FIELD
  Example: --empty name               # True if the 'name' field is empty

* Test if a field is numeric, finite, NaN, or infinity
  Syntax:  --is-numeric|is-finite|is-nan|is-infinity FIELD
  Example: --is-numeric 5 --gt 5:100  # Ensure field 5 is numeric before --gt test.

* Compare a field to a number (integer or float)
  Syntax:  --eq|ne|lt|le|gt|ge  FIELD:NUM
  Example: --lt size:1000 --gt weight:0.5  # ('size' < 1000) and ('weight' > 0.5)

* Compare a field to a string
  Syntax:  --str-eq|str-ne|istr-eq|istr-ne  FIELD:STR
  Example: --str-eq color:red         # True if 'color' field is "red"

* Test if a field contains a string (substring search)
  Syntax:  --str-in-fld|str-not-in-fld|istr-in-fld|istr-not-in-fld  FIELD:STR
  Example: --str-in-fld color:dark    # True if 'color field contains "dark"

* Test if a field matches a regular expression.
  Syntax:  --regex|iregex|not-regex|not-iregex  FIELD:REGEX
  Example: --regex '3:ab*c'     # True if field 3 contains "ac", "abc", "abbc", etc.

* Test a field's character or byte length
  Syntax:  --char-len-[le|lt|ge|gt|eq|ne] FIELD:NUM
           --byte-len-[le|lt|ge|gt|eq|ne] FIELD:NUM
  Example: --char-len-lt 2:10   # True if field 2 is less than 10 characters long.
           --byte-len-gt 2:10   # True if field 2 is greater than 10 bytes long.

* Field to field comparisons - Similar to field vs literal comparisons, but field vs field.
  Syntax:  --ff-eq|ff-ne|ff-lt|ff-le|ff-gt|ff-ge  FIELD1:FIELD2
           --ff-str-eq|ff-str-ne|ff-istr-eq|ff-istr-ne  FIELD1:FIELD2
  Example: --ff-eq 2:4          # True if fields 2 and 4 are numerically equivalent
           --ff-str-eq 2:4      # True if fields 2 and 4 are the same strings

* Field to field difference comparisons - Absolute and relative difference
  Syntax:  --ff-absdiff-le|ff-absdiff-gt FIELD1:FIELD2:NUM
           --ff-reldiff-le|ff-reldiff-gt FIELD1:FIELD2:NUM
  Example: --ff-absdiff-lt 1:3:0.25   # True if abs(field1 - field2) < 0.25

EOS";

immutable helpTextVerbose = q"EOS
Synopsis: tsv-filter [options] [file...]

Filter lines of tab-delimited files via comparison tests against fields.
Multiple tests can be specified, by default they are evaluated as an AND
clause. Lines satisfying the tests are written to standard output.

Typical test syntax is '--op field:value', where 'op' is an operator,
'field' is a either a field name and or field number, and 'value' is the
comparison basis. For example, '--lt length:500' tests if the 'length'
field is less than 500. A more complete example:

  tsv-filter --header --gt length:50 --lt length:100 --le width:200 data.tsv

This outputs all lines from file data.tsv where the 'length' field is
greater than 50 and less than 100, and the 'width' field is less than or
equal to 200. The header line is also output.

Field numbers can also be used to identify fields, and must be used when
the input file doesn't have a header line. For example:

  tsv-filter --gt 1:50 --lt 1:100 --le 2:200 data.tsv

Field lists can be used to specify multiple fields at once. For example:

  tsv-filter --not-blank 1-10 --str-ne 1,2,5:'--' data.tsv

tests that fields 1-10 are not blank and fields 1,2,5 are not "--".

Wildcarded field names can also be used to specify multiple fields. The
following finds lines where any field name ending in '*_id' is empty:

  tsv-filter -H --or --empty '*_id'

Use '--help-fields' for details on using field names.

Tests available include:
  * Test if a field is empty (no characters) or blank (empty or whitespace only).
  * Test if a field is interpretable as a number, a finite number, NaN, or Infinity.
  * Compare a field to a number - Numeric equality and relational tests.
  * Compare a field to a string - String equality and relational tests.
  * Test if a field matches a regular expression. Case sensitive or insensitive.
  * Test if a field contains a string. Sub-string search, case sensitive or insensitive.
  * Test a field's character or byte length.
  * Field to field comparisons - Similar to the other tests, except comparing
    one field to another in the same line.

As an alternative to filtering, records can be marked to indicate if they meet
the filter criteria or not. For example, the following will add a field to each
record indicating if the 'Color' field is a primary color.

  tsv-filter -H --or --str-eq Color:Red --str-eq Color:Yellow str-eq Color:Blue \
  --label IsPrimaryColor data.tsv

Values default to '1' and '0' and can be changed using '--label-values'. The
header name pass to '--label' is ignored if headers are not being used.

Details:
  * The run is aborted if there are not enough fields in an input line.
  * Numeric tests will fail and abort the run if a field cannot be interpreted as a
    number. This includes fields with no text. To avoid this use '--is-numeric' or
    '--is-finite' prior to the numeric test. For example, '--is-numeric 5 --gt 5:100'
    ensures field 5 is numeric before running the --gt test.
  * Regular expression syntax is defined by the D programming language. They follow
    common conventions (perl, python, etc.). Most common forms work as expected.
  * Output is buffered by default to improve performance. Use '--line-buffered' to
    have each matched line immediately written out.

Options:
EOS";

immutable helpTextOptions = q"EOS
Synopsis: tsv-filter [options] [file...]

Options:
EOS";

/* The next blocks of code define the structure of the boolean tests run against input lines.
 * This includes function and delegate (closure) signatures, creation mechanisms, option
 * handlers, etc. Command line arg processing to build the test structure.
*/

/* FieldsPredicate delegate signature - Each input line is run against a set of boolean
 * tests. Each test is a 'FieldsPredicate'. A FieldsPredicate is a delegate (closure)
 * containing all info about the test except the field values of the line being tested.
 * These delegates are created as part of command line arg processing. The wrapped data
 * includes operation, field indexes, literal values, etc. At run-time the delegate is
 * passed one argument, the split input line.
 */
alias FieldsPredicate = bool delegate(const char[][] fields);

/* FieldsPredicate function signatures - These aliases represent the different function
 * signatures used in FieldsPredicate delegates. Each alias has a corresponding 'make'
 * function. The 'make' function takes a real predicate function and closure args and
 * returns a FieldsPredicate delegate. Predicates types are:
 *
 * - FieldUnaryPredicate - Test based on a single field. (e.g. --empty 4)
 * - FieldVsNumberPredicate - Test based on a field index (used to get the field value)
 *   and a fixed numeric value. For example, field 2 less than 100 (--lt 2:100).
 * - FieldVsStringPredicate - Test based on a field and a string. (e.g. --str-eq 2:abc)
 * - FieldVsIStringPredicate - Case-insensitive test based on a field and a string.
 *   (e.g. --istr-eq 2:abc)
 * - FieldVsRegexPredicate - Test based on a field and a regex. (e.g. --regex '2:ab*c')
 * - FieldVsFieldPredicate - Test based on two fields. (e.g. --ff-le 2:4).
 *
 * An actual FieldsPredicate takes the fields from the line and the closure args and
 * runs the test. For example, a function testing if a field is less than a specific
 * value would pull the specified field from the fields array, convert the string to
 * a number, then run the less-than test.
 */
alias FieldUnaryPredicate    = bool function(const char[][] fields, size_t index);
alias FieldVsNumberPredicate = bool function(const char[][] fields, size_t index, double value);
alias FieldVsStringPredicate = bool function(const char[][] fields, size_t index, string value);
alias FieldVsIStringPredicate = bool function(const char[][] fields, size_t index, dstring value);
alias FieldVsRegexPredicate  = bool function(const char[][] fields, size_t index, Regex!char value);
alias FieldVsFieldPredicate  = bool function(const char[][] fields, size_t index1, size_t index2);
alias FieldFieldNumPredicate  = bool function(const char[][] fields, size_t index1, size_t index2, double value);

FieldsPredicate makeFieldUnaryDelegate(FieldUnaryPredicate fn, size_t index)
{
    return fields => fn(fields, index);
}

FieldsPredicate makeFieldVsNumberDelegate(FieldVsNumberPredicate fn, size_t index, double value)
{
    return fields => fn(fields, index, value);
}

FieldsPredicate makeFieldVsStringDelegate(FieldVsStringPredicate fn, size_t index, string value)
{
    return fields => fn(fields, index, value);
}

FieldsPredicate makeFieldVsIStringDelegate(FieldVsIStringPredicate fn, size_t index, dstring value)
{
    return fields => fn(fields, index, value);
}

FieldsPredicate makeFieldVsRegexDelegate(FieldVsRegexPredicate fn, size_t index, Regex!char value)
{
    return fields => fn(fields, index, value);
}

FieldsPredicate makeFieldVsFieldDelegate(FieldVsFieldPredicate fn, size_t index1, size_t index2)
{
    return fields => fn(fields, index1, index2);
}

FieldsPredicate makeFieldFieldNumDelegate(FieldFieldNumPredicate fn, size_t index1, size_t index2, double value)
{
    return fields => fn(fields, index1, index2, value);
}

/* Predicate functions - These are the actual functions used in a FieldsPredicate. They
 * are a direct reflection of the operators available via command line args. Each matches
 * one of the FieldsPredicate function aliases defined above.
 */
bool fldEmpty(const char[][] fields, size_t index) { return fields[index].length == 0; }
bool fldNotEmpty(const char[][] fields, size_t index) { return fields[index].length != 0; }
bool fldBlank(const char[][] fields, size_t index) { return cast(bool) fields[index].matchFirst(ctRegex!`^\s*$`); }
bool fldNotBlank(const char[][] fields, size_t index) { return !fields[index].matchFirst(ctRegex!`^\s*$`); }

bool fldIsNumeric(const char[][] fields, size_t index) { return fields[index].isNumeric; }
bool fldIsFinite(const char[][] fields, size_t index) { return fields[index].isNumeric && fields[index].to!double.isFinite; }
bool fldIsNaN(const char[][] fields, size_t index) { return fields[index].isNumeric && fields[index].to!double.isNaN; }
bool fldIsInfinity(const char[][] fields, size_t index) { return fields[index].isNumeric && fields[index].to!double.isInfinity; }

bool numLE(const char[][] fields, size_t index, double val) { return fields[index].to!double <= val; }
bool numLT(const char[][] fields, size_t index, double val) { return fields[index].to!double  < val; }
bool numGE(const char[][] fields, size_t index, double val) { return fields[index].to!double >= val; }
bool numGT(const char[][] fields, size_t index, double val) { return fields[index].to!double  > val; }
bool numEQ(const char[][] fields, size_t index, double val) { return fields[index].to!double == val; }
bool numNE(const char[][] fields, size_t index, double val) { return fields[index].to!double != val; }

bool strLE(const char[][] fields, size_t index, string val) { return fields[index] <= val; }
bool strLT(const char[][] fields, size_t index, string val) { return fields[index]  < val; }
bool strGE(const char[][] fields, size_t index, string val) { return fields[index] >= val; }
bool strGT(const char[][] fields, size_t index, string val) { return fields[index]  > val; }
bool strEQ(const char[][] fields, size_t index, string val) { return fields[index] == val; }
bool strNE(const char[][] fields, size_t index, string val) { return fields[index] != val; }
bool strInFld(const char[][] fields, size_t index, string val) { return fields[index].canFind(val); }
bool strNotInFld(const char[][] fields, size_t index, string val) { return !fields[index].canFind(val); }

/* Note: For istr predicates, the command line value has been lower-cased by fieldVsIStringOptionHander.
 */
bool istrEQ(const char[][] fields, size_t index, dstring val) { return fields[index].asLowerCase.equal(val); }
bool istrNE(const char[][] fields, size_t index, dstring val) { return !fields[index].asLowerCase.equal(val); }
bool istrInFld(const char[][] fields, size_t index, dstring val) { return fields[index].asLowerCase.canFind(val); }
bool istrNotInFld(const char[][] fields, size_t index, dstring val) { return !fields[index].asLowerCase.canFind(val); }

/* Note: Case-sensitivity is built into the regex value, so these regex predicates are
 * used for both case-sensitive and case-insensitive regex operators.
 */
bool regexMatch(const char[][] fields, size_t index, Regex!char val) { return cast(bool) fields[index].matchFirst(val); }
bool regexNotMatch(const char[][] fields, size_t index, Regex!char val) { return !fields[index].matchFirst(val); }

bool charLenLE(const char[][] fields, size_t index, double val) { return fields[index].byGrapheme.walkLength <= val; }
bool charLenLT(const char[][] fields, size_t index, double val) { return fields[index].byGrapheme.walkLength < val; }
bool charLenGE(const char[][] fields, size_t index, double val) { return fields[index].byGrapheme.walkLength >= val; }
bool charLenGT(const char[][] fields, size_t index, double val) { return fields[index].byGrapheme.walkLength > val; }
bool charLenEQ(const char[][] fields, size_t index, double val) { return fields[index].byGrapheme.walkLength == val; }
bool charLenNE(const char[][] fields, size_t index, double val) { return fields[index].byGrapheme.walkLength != val; }

bool byteLenLE(const char[][] fields, size_t index, double val) { return fields[index].length <= val; }
bool byteLenLT(const char[][] fields, size_t index, double val) { return fields[index].length < val; }
bool byteLenGE(const char[][] fields, size_t index, double val) { return fields[index].length >= val; }
bool byteLenGT(const char[][] fields, size_t index, double val) { return fields[index].length > val; }
bool byteLenEQ(const char[][] fields, size_t index, double val) { return fields[index].length == val; }
bool byteLenNE(const char[][] fields, size_t index, double val) { return fields[index].length != val; }

bool ffLE(const char[][] fields, size_t index1, size_t index2) { return fields[index1].to!double <= fields[index2].to!double; }
bool ffLT(const char[][] fields, size_t index1, size_t index2) { return fields[index1].to!double  < fields[index2].to!double; }
bool ffGE(const char[][] fields, size_t index1, size_t index2) { return fields[index1].to!double >= fields[index2].to!double; }
bool ffGT(const char[][] fields, size_t index1, size_t index2) { return fields[index1].to!double  > fields[index2].to!double; }
bool ffEQ(const char[][] fields, size_t index1, size_t index2) { return fields[index1].to!double == fields[index2].to!double; }
bool ffNE(const char[][] fields, size_t index1, size_t index2) { return fields[index1].to!double != fields[index2].to!double; }
bool ffStrEQ(const char[][] fields, size_t index1, size_t index2) { return fields[index1] == fields[index2]; }
bool ffStrNE(const char[][] fields, size_t index1, size_t index2) { return fields[index1] != fields[index2]; }
bool ffIStrEQ(const char[][] fields, size_t index1, size_t index2)
{
    return equal(fields[index1].asLowerCase, fields[index2].asLowerCase);
}
bool ffIStrNE(const char[][] fields, size_t index1, size_t index2)
{
    return !equal(fields[index1].asLowerCase, fields[index2].asLowerCase);
}

auto AbsDiff(double v1, double v2) { return (v1 - v2).abs; }
auto RelDiff(double v1, double v2) { return (v1 - v2).abs / min(v1.abs, v2.abs); }

bool ffAbsDiffLE(const char[][] fields, size_t index1, size_t index2, double value)
{
    return AbsDiff(fields[index1].to!double, fields[index2].to!double) <= value;
}
bool ffAbsDiffGT(const char[][] fields, size_t index1, size_t index2, double value)
{
    return AbsDiff(fields[index1].to!double, fields[index2].to!double) > value;
}
bool ffRelDiffLE(const char[][] fields, size_t index1, size_t index2, double value)
{
    return RelDiff(fields[index1].to!double, fields[index2].to!double) <= value;
}
bool ffRelDiffGT(const char[][] fields, size_t index1, size_t index2, double value)
{
    return RelDiff(fields[index1].to!double, fields[index2].to!double) > value;
}

/* Command line option handlers - There is a command line option handler for each
 * predicate type. That is, one each for FieldUnaryPredicate, FieldVsNumberPredicate,
 * etc. Option handlers are passed the tests array, the predicate function, and the
 * command line option arguments. A FieldsPredicate delegate is created and appended to
 * the tests array. An exception is thrown if errors are detected while processing the
 * option, the error text is intended for the end user.
 *
 * All the option handlers have similar functionality, differing in option processing and
 * error message generation. fieldVsNumberOptionHandler is described as an example. It
 * handles command options such as '--lt 3:1000', which tests field 3 for a values less
 * than 1000. It is passed the tests array, the 'numLE' predicate function used for the
 * test, and the string "3:1000" representing the option value. It is also passed the
 * header line from the first input file and an indication of whether header processing
 * is enabled (--H|header). parseFieldList (fieldlist module) is used to parse the
 * field-list component of the option ("3" in the example). The comparison value ("1000")
 * is converted to a double. These are wrapped in a FieldsPredicate delegate which is
 * added to the tests array. An error is signaled if the option string is invalid.
 *
 * During processing, fields indexes are converted from one-based to zero-based. As an
 * optimization, the maximum field index is also tracked. This allows early termination of
 * line splitting.
 *
 * The header line from the input file is not available when std.getop processes the
 * command line option. The processing described above must be deferred. This is done
 * using a 'CmdOptionHandler' delegate. There is a 'make' function for every Command line
 * option handler that creates these. These are created during std.getopt processing.
 * They are run when the header line becomes available.
 *
 * The final setup for the '--lt' (numeric less-than) operator' is as follows:
 *   - Function 'handlerNumLE' (in TsvFilterOptions.processArgs) is associated with the
 *     command line option "--lt <val>". When called by std.getopt it creates an option
 *     hander delegate via 'makeFieldVsNumberOptionHandler'. This is appended to an
 *     array of delegates.
 *   - 'fieldVsNumberOptionHandler' is invoked via the delegate after the header line
 *     becomes available (in TsvFilterOptions.processArgs). If args are valid,
 *     'makeFieldVsNumberDelegate' is used to create a delegate invoking the 'numLE'
 *     predicate function. This delegate is added to the set of run-time tests.
 *
 * Note that in the above setup the 'numLE' predicate is specified in 'handlerNumLE'
 * and passed through all the steps. This is how the command line option gets
 * associated with the predicate function.
 */

/* CmdOptionHandler delegate signature - This is the call made to process the command
 * line option arguments after the header line has been read.
 */
alias CmdOptionHandler = void delegate(ref FieldsPredicate[] tests, ref size_t maxFieldIndex,
                                       bool hasHeader, string[] headerFields);

CmdOptionHandler makeFieldUnaryOptionHandler(FieldUnaryPredicate predicateFn, string option, string optionVal)
{
    return
        (ref FieldsPredicate[] tests, ref size_t maxFieldIndex, bool hasHeader, string[] headerFields)
        => fieldUnaryOptionHandler(tests, maxFieldIndex, hasHeader, headerFields, predicateFn, option, optionVal);
}

void fieldUnaryOptionHandler(
    ref FieldsPredicate[] tests, ref size_t maxFieldIndex, bool hasHeader, string[] headerFields,
    FieldUnaryPredicate fn, string option, string optionVal)
{
    import tsv_utils.common.fieldlist;

    try foreach (fieldNum, fieldIndex;
                 optionVal
                 .parseFieldList!(size_t, Yes.convertToZeroBasedIndex)(hasHeader, headerFields)
                 .enumerate(1))
        {
            tests ~= makeFieldUnaryDelegate(fn, fieldIndex);
            maxFieldIndex = (fieldIndex > maxFieldIndex) ? fieldIndex : maxFieldIndex;
        }
    catch (Exception e)
    {
         e.msg = format("Invalid option: [--%s %s]. %s\n   Expected: '--%s <field>' or '--%s <field-list>'.",
                        option, optionVal, e.msg, option, option);
         throw e;
    }
}

CmdOptionHandler makeFieldVsNumberOptionHandler(FieldVsNumberPredicate predicateFn, string option, string optionVal)
{
    return
        (ref FieldsPredicate[] tests, ref size_t maxFieldIndex, bool hasHeader, string[] headerFields)
        => fieldVsNumberOptionHandler(tests, maxFieldIndex, hasHeader, headerFields, predicateFn, option, optionVal);
}

void fieldVsNumberOptionHandler(
    ref FieldsPredicate[] tests, ref size_t maxFieldIndex, bool hasHeader, string[] headerFields,
    FieldVsNumberPredicate fn, string option, string optionVal)
{
    import tsv_utils.common.fieldlist;

    auto formatErrorMsg(string option, string optionVal, string errorMessage="")
    {
        string optionalSpace = (errorMessage.length == 0) ? "" : " ";
        return format(
            "Invalid option: [--%s %s].%s%s\n   Expected: '--%s <field>:<val>' or '--%s <field-list>:<val> where <val> is a number.",
            option, optionVal, optionalSpace, errorMessage, option, option);
    }

    try
    {
        auto optionValParse =
            optionVal
            .parseFieldList!(size_t, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
            (hasHeader, headerFields);

        auto fieldIndices = optionValParse.array;
        enforce(optionVal.length - optionValParse.consumed > 1, "No value after field list.");
        double value = optionVal[optionValParse.consumed + 1 .. $].to!double;

        foreach (fieldIndex; fieldIndices)
        {
            tests ~= makeFieldVsNumberDelegate(fn, fieldIndex, value);
            maxFieldIndex = (fieldIndex > maxFieldIndex) ? fieldIndex : maxFieldIndex;
        }
    }
    catch (Exception e)
    {
        e.msg = formatErrorMsg(option, optionVal, e.msg);
        throw e;
    }
}

CmdOptionHandler makeFieldVsStringOptionHandler(FieldVsStringPredicate predicateFn, string option, string optionVal)
{
    return
        (ref FieldsPredicate[] tests, ref size_t maxFieldIndex, bool hasHeader, string[] headerFields)
        => fieldVsStringOptionHandler(tests, maxFieldIndex, hasHeader, headerFields, predicateFn, option, optionVal);
}

void fieldVsStringOptionHandler(
    ref FieldsPredicate[] tests, ref size_t maxFieldIndex, bool hasHeader, string[] headerFields,
    FieldVsStringPredicate fn, string option, string optionVal)
{
    import tsv_utils.common.fieldlist;

    try
    {
        auto optionValParse =
            optionVal
            .parseFieldList!(size_t, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
            (hasHeader, headerFields);

        auto fieldIndices = optionValParse.array;
        enforce(optionVal.length - optionValParse.consumed > 1, "No value after field list.");
        string value = optionVal[optionValParse.consumed + 1 .. $].idup;

        foreach (fieldIndex; fieldIndices)
        {
            tests ~= makeFieldVsStringDelegate(fn, fieldIndex, value);
            maxFieldIndex = (fieldIndex > maxFieldIndex) ? fieldIndex : maxFieldIndex;
        }

    }
    catch (Exception e)
    {
        e.msg = format(
            "[--%s %s]. %s\n   Expected: '--%s <field>:<val>' or '--%s <field-list>:<val>' where <val> is a string.",
            option, optionVal, e.msg, option, option);
        throw e;
    }
}

CmdOptionHandler makeFieldVsIStringOptionHandler(FieldVsIStringPredicate predicateFn, string option, string optionVal)
{
    return
        (ref FieldsPredicate[] tests, ref size_t maxFieldIndex, bool hasHeader, string[] headerFields)
        => fieldVsIStringOptionHandler(tests, maxFieldIndex, hasHeader, headerFields, predicateFn, option, optionVal);
}

/* The fieldVsIStringOptionHandler lower-cases the command line argument, assuming the
 * case-insensitive comparison will be done on lower-cased values.
 */
void fieldVsIStringOptionHandler(
    ref FieldsPredicate[] tests, ref size_t maxFieldIndex, bool hasHeader, string[] headerFields,
    FieldVsIStringPredicate fn, string option, string optionVal)
{
    import tsv_utils.common.fieldlist;

    try
    {
        auto optionValParse =
            optionVal
            .parseFieldList!(size_t, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
            (hasHeader, headerFields);

        auto fieldIndices = optionValParse.array;
        enforce(optionVal.length - optionValParse.consumed > 1, "No value after field list.");
        string value = optionVal[optionValParse.consumed + 1 .. $].idup;

        foreach (fieldIndex; fieldIndices)
        {
            tests ~= makeFieldVsIStringDelegate(fn, fieldIndex, value.to!dstring.toLower);
            maxFieldIndex = (fieldIndex > maxFieldIndex) ? fieldIndex : maxFieldIndex;
        }
    }
    catch (Exception e)
    {
        e.msg = format(
            "[--%s %s]. %s\n   Expected: '--%s <field>:<val>' or '--%s <field-list>:<val>' where <val> is a string.",
            option, optionVal, e.msg, option, option);
        throw e;
    }
}

CmdOptionHandler makeFieldVsRegexOptionHandler(FieldVsRegexPredicate predicateFn, string option, string optionVal, bool caseSensitive)
{
    return
        (ref FieldsPredicate[] tests, ref size_t maxFieldIndex, bool hasHeader, string[] headerFields)
        => fieldVsRegexOptionHandler(tests, maxFieldIndex, hasHeader, headerFields, predicateFn, option, optionVal, caseSensitive);
}

void fieldVsRegexOptionHandler(
    ref FieldsPredicate[] tests, ref size_t maxFieldIndex, bool hasHeader, string[] headerFields,
    FieldVsRegexPredicate fn, string option, string optionVal, bool caseSensitive)
{
    import tsv_utils.common.fieldlist;

    try
    {
        auto optionValParse =
            optionVal
            .parseFieldList!(size_t, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
            (hasHeader, headerFields);

        auto fieldIndices = optionValParse.array;
        enforce(optionVal.length - optionValParse.consumed > 1, "No value after field list.");

        immutable modifiers = caseSensitive ? "" : "i";
        Regex!char value =
            optionVal[optionValParse.consumed + 1 .. $]
            .regex(modifiers);

        foreach (fieldIndex; fieldIndices)
        {
            tests ~= makeFieldVsRegexDelegate(fn, fieldIndex, value);
            maxFieldIndex = (fieldIndex > maxFieldIndex) ? fieldIndex : maxFieldIndex;
        }
    }
    catch (RegexException e)
    {
        e.msg = format(
            "[--%s %s]. Invalid regular expression: %s\n   Expected: '--%s <field>:<val>' or '--%s <field-list>:<val>' where <val> is a regular expression.",
            option, optionVal, e.msg, option, option);
        throw e;
    }
    catch (Exception e)
    {
        e.msg = format(
            "[--%s %s]. %s\n   Expected: '--%s <field>:<val>' or '--%s <field-list>:<val>' where <val> is a regular expression.",
            option, optionVal, e.msg, option, option);
        throw e;
    }
}


CmdOptionHandler makeFieldVsFieldOptionHandler(FieldVsFieldPredicate predicateFn, string option, string optionVal)
{
    return
        (ref FieldsPredicate[] tests, ref size_t maxFieldIndex, bool hasHeader, string[] headerFields)
        => fieldVsFieldOptionHandler(tests, maxFieldIndex, hasHeader, headerFields, predicateFn, option, optionVal);
}

void fieldVsFieldOptionHandler(
    ref FieldsPredicate[] tests, ref size_t maxFieldIndex, bool hasHeader, string[] headerFields,
    FieldVsFieldPredicate fn, string option, string optionVal)
{
    import tsv_utils.common.fieldlist;

    try
    {
        auto optionValParse =
            optionVal
            .parseFieldList!(size_t, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
            (hasHeader, headerFields);

        auto fieldIndices1 = optionValParse.array;

        enforce(fieldIndices1.length != 0, "First field argument is empty.");
        enforce(fieldIndices1.length == 1, "First field argument references multiple fields.");
        enforce(optionVal.length - optionValParse.consumed > 1, " Second field argument is empty.");

        auto fieldIndices2 =
            optionVal[optionValParse.consumed + 1 .. $]
            .parseFieldList!(size_t, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, Yes.consumeEntireFieldListString)
            (hasHeader, headerFields)
            .array;

        enforce(fieldIndices2.length != 0, "Second field argument is empty.");
        enforce(fieldIndices2.length == 1, "Second field argument references multiple fields.");

        enforce(fieldIndices1[0] != fieldIndices2[0],
                format("Invalid option: '--%s %s'. Field1 and field2 must be different fields", option, optionVal));

        tests ~= makeFieldVsFieldDelegate(fn, fieldIndices1[0], fieldIndices2[0]);
        maxFieldIndex = max(maxFieldIndex, fieldIndices1[0], fieldIndices2[0]);
    }
    catch (Exception e)
    {
        e.msg = format(
            "[--%s %s]. %s\n   Expected: '--%s <field1>:<field2>' where <field1> and <field2> are individual fields.",
            option, optionVal, e.msg, option);
        throw e;
    }
}

CmdOptionHandler makeFieldFieldNumOptionHandler(FieldFieldNumPredicate predicateFn, string option, string optionVal)
{
    return
        (ref FieldsPredicate[] tests, ref size_t maxFieldIndex, bool hasHeader, string[] headerFields)
        => fieldFieldNumOptionHandler(tests, maxFieldIndex, hasHeader, headerFields, predicateFn, option, optionVal);
}

void fieldFieldNumOptionHandler(
    ref FieldsPredicate[] tests, ref size_t maxFieldIndex, bool hasHeader, string[] headerFields,
    FieldFieldNumPredicate fn, string option, string optionVal)
{
    import tsv_utils.common.fieldlist;

    try
    {
        auto optionValParse1 =
            optionVal
            .parseFieldList!(size_t, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
            (hasHeader, headerFields);

        auto fieldIndices1 = optionValParse1.array;

        enforce(fieldIndices1.length != 0, "First field argument is empty.");
        enforce(fieldIndices1.length == 1, "First field argument references multiple fields.");
        enforce(optionVal.length - optionValParse1.consumed > 1, " Second field argument is empty.");

        auto optionValSegment2 = optionVal[optionValParse1.consumed + 1 .. $];
        auto optionValParse2 =
            optionValSegment2
            .parseFieldList!(size_t, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
            (hasHeader, headerFields);

        auto fieldIndices2 = optionValParse2.array;

        enforce(fieldIndices2.length != 0, "Second field argument is empty.");
        enforce(fieldIndices2.length == 1, "Second field argument references multiple fields.");
        enforce(optionValSegment2.length - optionValParse2.consumed > 1, "Number argument is empty.");

        size_t field1 = fieldIndices1[0];
        size_t field2 = fieldIndices2[0];
        double value = optionValSegment2[optionValParse2.consumed + 1 .. $].to!double;

        enforce(field1 != field2,
                format("Invalid option: '--%s %s'. Field1 and field2 must be different fields", option, optionVal));

        tests ~= makeFieldFieldNumDelegate(fn, field1, field2, value);
        maxFieldIndex = max(maxFieldIndex, field1, field2);
    }
    catch (Exception e)
    {
        e.msg = format(
            "[--%s %s]. %s\n   Expected: '--%s <field1>:<field2>:<num>' where <field1> and <field2> are individual fields.",
            option, optionVal, e.msg, option);
        throw e;
    }
}

/** Command line options - This struct holds the results of command line option processing.
 * It also has a method, processArgs, that invokes command line arg processing.
 */
struct TsvFilterOptions
{
    import tsv_utils.common.utils : inputSourceRange, InputSourceRange, ReadHeader;

    string programName;
    InputSourceRange inputSources;      /// Input files
    FieldsPredicate[] tests;            /// Derived from tests
    size_t maxFieldIndex = 0;           /// Derived from tests
    bool hasHeader = false;             /// --H|header
    bool invert = false;                /// --invert
    bool disjunct = false;              /// --or
    bool countMatches = false;          /// --c|count
    char delim = '\t';                  /// --delimiter
    string label;                       /// --label
    bool labelValuesOptionUsed = false; /// --label-values
    bool lineBuffered = false;          /// --line-buffered
    bool isLabeling = false;            /// Derived
    string trueLabel = "1";             /// Derived
    string falseLabel = "0";            /// Derived

    /* Returns a tuple. First value is true if command line arguments were successfully
     * processed and execution should continue, or false if an error occurred or the user
     * asked for help. If false, the second value is the appropriate exit code (0 or 1).
     *
     * Returning true (execution continues) means args have been validated and the
     * tests array has been established.
     */
    auto processArgs (ref string[] cmdArgs)
    {
        import std.algorithm : each;
        import std.array : split;
        import std.conv : to;
        import std.getopt;
        import std.path : baseName, stripExtension;
        import tsv_utils.common.getopt_inorder;
        import tsv_utils.common.utils : throwIfWindowsNewline;

        bool helpVerbose = false;        // --help-verbose
        bool helpOptions = false;        // --help-options
        bool helpFields = false;         // --help-fields
        bool versionWanted = false;      // --V|version

        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

        /* Command option handlers - One handler for each option. These conform to the
         * getopt required handler signature, and separate knowledge the specific command
         * option text from the option processing.
         */

        CmdOptionHandler[] cmdLineTestOptions;

        void handlerFldEmpty(string option, string value)    { cmdLineTestOptions ~= makeFieldUnaryOptionHandler(&fldEmpty,    option, value); }
        void handlerFldNotEmpty(string option, string value) { cmdLineTestOptions ~= makeFieldUnaryOptionHandler(&fldNotEmpty, option, value); }
        void handlerFldBlank(string option, string value)    { cmdLineTestOptions ~= makeFieldUnaryOptionHandler(&fldBlank,    option, value); }
        void handlerFldNotBlank(string option, string value) { cmdLineTestOptions ~= makeFieldUnaryOptionHandler(&fldNotBlank, option, value); }

        void handlerFldIsNumeric(string option, string value)  { cmdLineTestOptions ~= makeFieldUnaryOptionHandler(&fldIsNumeric,  option, value); }
        void handlerFldIsFinite(string option, string value)   { cmdLineTestOptions ~= makeFieldUnaryOptionHandler(&fldIsFinite,   option, value); }
        void handlerFldIsNaN(string option, string value)      { cmdLineTestOptions ~= makeFieldUnaryOptionHandler(&fldIsNaN,      option, value); }
        void handlerFldIsInfinity(string option, string value) { cmdLineTestOptions ~= makeFieldUnaryOptionHandler(&fldIsInfinity, option, value); }

        void handlerNumLE(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&numLE, option, value); }
        void handlerNumLT(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&numLT, option, value); }
        void handlerNumGE(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&numGE, option, value); }
        void handlerNumGT(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&numGT, option, value); }
        void handlerNumEQ(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&numEQ, option, value); }
        void handlerNumNE(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&numNE, option, value); }

        void handlerStrLE(string option, string value) { cmdLineTestOptions ~= makeFieldVsStringOptionHandler(&strLE, option, value); }
        void handlerStrLT(string option, string value) { cmdLineTestOptions ~= makeFieldVsStringOptionHandler(&strLT, option, value); }
        void handlerStrGE(string option, string value) { cmdLineTestOptions ~= makeFieldVsStringOptionHandler(&strGE, option, value); }
        void handlerStrGT(string option, string value) { cmdLineTestOptions ~= makeFieldVsStringOptionHandler(&strGT, option, value); }
        void handlerStrEQ(string option, string value) { cmdLineTestOptions ~= makeFieldVsStringOptionHandler(&strEQ, option, value); }
        void handlerStrNE(string option, string value) { cmdLineTestOptions ~= makeFieldVsStringOptionHandler(&strNE, option, value); }

        void handlerStrInFld(string option, string value)    { cmdLineTestOptions ~= makeFieldVsStringOptionHandler(&strInFld,    option, value); }
        void handlerStrNotInFld(string option, string value) { cmdLineTestOptions ~= makeFieldVsStringOptionHandler(&strNotInFld, option, value); }

        void handlerIStrEQ(string option, string value)       { cmdLineTestOptions ~= makeFieldVsIStringOptionHandler(&istrEQ,       option, value); }
        void handlerIStrNE(string option, string value)       { cmdLineTestOptions ~= makeFieldVsIStringOptionHandler(&istrNE,       option, value); }
        void handlerIStrInFld(string option, string value)    { cmdLineTestOptions ~= makeFieldVsIStringOptionHandler(&istrInFld,    option, value); }
        void handlerIStrNotInFld(string option, string value) { cmdLineTestOptions ~= makeFieldVsIStringOptionHandler(&istrNotInFld, option, value); }

        void handlerRegexMatch(string option, string value)     { cmdLineTestOptions ~= makeFieldVsRegexOptionHandler(&regexMatch,    option, value, true); }
        void handlerRegexNotMatch(string option, string value)  { cmdLineTestOptions ~= makeFieldVsRegexOptionHandler(&regexNotMatch, option, value, true); }
        void handlerIRegexMatch(string option, string value)    { cmdLineTestOptions ~= makeFieldVsRegexOptionHandler(&regexMatch,    option, value, false); }
        void handlerIRegexNotMatch(string option, string value) { cmdLineTestOptions ~= makeFieldVsRegexOptionHandler(&regexNotMatch, option, value, false); }

        void handlerCharLenLE(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&charLenLE, option, value); }
        void handlerCharLenLT(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&charLenLT, option, value); }
        void handlerCharLenGE(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&charLenGE, option, value); }
        void handlerCharLenGT(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&charLenGT, option, value); }
        void handlerCharLenEQ(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&charLenEQ, option, value); }
        void handlerCharLenNE(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&charLenNE, option, value); }

        void handlerByteLenLE(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&byteLenLE, option, value); }
        void handlerByteLenLT(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&byteLenLT, option, value); }
        void handlerByteLenGE(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&byteLenGE, option, value); }
        void handlerByteLenGT(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&byteLenGT, option, value); }
        void handlerByteLenEQ(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&byteLenEQ, option, value); }
        void handlerByteLenNE(string option, string value) { cmdLineTestOptions ~= makeFieldVsNumberOptionHandler(&byteLenNE, option, value); }

        void handlerFFLE(string option, string value) { cmdLineTestOptions ~= makeFieldVsFieldOptionHandler(&ffLE, option, value); }
        void handlerFFLT(string option, string value) { cmdLineTestOptions ~= makeFieldVsFieldOptionHandler(&ffLT, option, value); }
        void handlerFFGE(string option, string value) { cmdLineTestOptions ~= makeFieldVsFieldOptionHandler(&ffGE, option, value); }
        void handlerFFGT(string option, string value) { cmdLineTestOptions ~= makeFieldVsFieldOptionHandler(&ffGT, option, value); }
        void handlerFFEQ(string option, string value) { cmdLineTestOptions ~= makeFieldVsFieldOptionHandler(&ffEQ, option, value); }
        void handlerFFNE(string option, string value) { cmdLineTestOptions ~= makeFieldVsFieldOptionHandler(&ffNE, option, value); }

        void handlerFFStrEQ(string option, string value)  { cmdLineTestOptions ~= makeFieldVsFieldOptionHandler(&ffStrEQ,  option, value); }
        void handlerFFStrNE(string option, string value)  { cmdLineTestOptions ~= makeFieldVsFieldOptionHandler(&ffStrNE,  option, value); }
        void handlerFFIStrEQ(string option, string value) { cmdLineTestOptions ~= makeFieldVsFieldOptionHandler(&ffIStrEQ, option, value); }
        void handlerFFIStrNE(string option, string value) { cmdLineTestOptions ~= makeFieldVsFieldOptionHandler(&ffIStrNE, option, value); }

        void handlerFFAbsDiffLE(string option, string value) { cmdLineTestOptions ~= makeFieldFieldNumOptionHandler(&ffAbsDiffLE, option, value); }
        void handlerFFAbsDiffGT(string option, string value) { cmdLineTestOptions ~= makeFieldFieldNumOptionHandler(&ffAbsDiffGT, option, value); }
        void handlerFFRelDiffLE(string option, string value) { cmdLineTestOptions ~= makeFieldFieldNumOptionHandler(&ffRelDiffLE, option, value); }
        void handlerFFRelDiffGT(string option, string value) { cmdLineTestOptions ~= makeFieldFieldNumOptionHandler(&ffRelDiffGT, option, value); }

        /* The handleLabelValuesOption is different from the other handlers in that it is
         * not generic. Instead it simply parses and validates the argument passed to the
         * --label-values option. If the option is valid, it populates the `trueLabel`
         * and `falseLabel` member variables. Otherwise an exception is thrown.
         */
        void handleLabelValuesOption(string option, string optionVal)
        {
            immutable valSplit = optionVal.findSplit(":");

            enforce(valSplit && !valSplit[2].canFind(":") && valSplit[0] != valSplit[2],
                    format("Invalid option: '--%s %s'.\n" ~
                           "  Expected: '--%s STR1:STR2'. STR1 and STR2 must be different strings.\n" ~
                           "  The colon (':') is required, niether string can contain a colon.",
                           option, optionVal, option));

            labelValuesOptionUsed = true;
            trueLabel = valSplit[0];
            falseLabel = valSplit[2];
        }

        try
        {
            arraySep = ",";    // Use comma to separate values in command line options
            auto r = getoptInorder(
                cmdArgs,
                "help-verbose",    "     Print full help.", &helpVerbose,
                "help-options",    "     Print the options list by itself.", &helpOptions,
                "help-fields",     "     Print help on specifying fields.", &helpFields,
                 std.getopt.config.caseSensitive,
                "V|version",       "     Print version information and exit.", &versionWanted,
                "H|header",        "     Treat the first line of each file as a header.", &hasHeader,
                std.getopt.config.caseInsensitive,
                "or",              "     Evaluate tests as an OR rather than an AND.", &disjunct,
                std.getopt.config.caseSensitive,
                "v|invert",        "     Invert the filter, printing lines that do not match.", &invert,
                std.getopt.config.caseInsensitive,
                "c|count",         "     Print only a count of the matched lines, excluding the header.", &countMatches,
                "d|delimiter",     "CHR  Field delimiter. Default: TAB. (Single byte UTF-8 characters only.)", &delim,

                "label",
                "STR  Do not filter. Instead, mark each record as passing the filter or not. STR is the header, ignored if there is no header line.",
                &label,

                "label-values",
                                   "STR1:STR2   The pass/no-pass values used by '--label'. Defaults to '1' and '0'.",
                &handleLabelValuesOption,

                "line-buffered",   "     Immediately output every matched line.", &lineBuffered,

                "empty",           "<field-list>       True if FIELD is empty.", &handlerFldEmpty,
                "not-empty",       "<field-list>       True if FIELD is not empty.", &handlerFldNotEmpty,
                "blank",           "<field-list>       True if FIELD is empty or all whitespace.", &handlerFldBlank,
                "not-blank",       "<field-list>       True if FIELD contains a non-whitespace character.", &handlerFldNotBlank,

                "is-numeric",      "<field-list>       True if FIELD is interpretable as a number.", &handlerFldIsNumeric,
                "is-finite",       "<field-list>       True if FIELD is interpretable as a number and is not NaN or infinity.", &handlerFldIsFinite,
                "is-nan",          "<field-list>       True if FIELD is NaN.", &handlerFldIsNaN,
                "is-infinity",     "<field-list>       True if FIELD is infinity.", &handlerFldIsInfinity,

                "le",              "<field-list>:NUM   FIELD <= NUM (numeric).", &handlerNumLE,
                "lt",              "<field-list>:NUM   FIELD <  NUM (numeric).", &handlerNumLT,
                "ge",              "<field-list>:NUM   FIELD >= NUM (numeric).", &handlerNumGE,
                "gt",              "<field-list>:NUM   FIELD >  NUM (numeric).", &handlerNumGT,
                "eq",              "<field-list>:NUM   FIELD == NUM (numeric).", &handlerNumEQ,
                "ne",              "<field-list>:NUM   FIELD != NUM (numeric).", &handlerNumNE,

                "str-le",          "<field-list>:STR   FIELD <= STR (string).", &handlerStrLE,
                "str-lt",          "<field-list>:STR   FIELD <  STR (string).", &handlerStrLT,
                "str-ge",          "<field-list>:STR   FIELD >= STR (string).", &handlerStrGE,
                "str-gt",          "<field-list>:STR   FIELD >  STR (string).", &handlerStrGT,
                "str-eq",          "<field-list>:STR   FIELD == STR (string).", &handlerStrEQ,
                "istr-eq",         "<field-list>:STR   FIELD == STR (string, case-insensitive).", &handlerIStrEQ,
                "str-ne",          "<field-list>:STR   FIELD != STR (string).", &handlerStrNE,
                "istr-ne",         "<field-list>:STR   FIELD != STR (string, case-insensitive).", &handlerIStrNE,
                "str-in-fld",      "<field-list>:STR   FIELD contains STR (substring search).", &handlerStrInFld,
                "istr-in-fld",     "<field-list>:STR   FIELD contains STR (substring search, case-insensitive).", &handlerIStrInFld,
                "str-not-in-fld",  "<field-list>:STR   FIELD does not contain STR (substring search).", &handlerStrNotInFld,
                "istr-not-in-fld", "<field-list>:STR   FIELD does not contain STR (substring search, case-insensitive).", &handlerIStrNotInFld,

                "regex",           "<field-list>:REGEX   FIELD matches regular expression.", &handlerRegexMatch,
                "iregex",          "<field-list>:REGEX   FIELD matches regular expression, case-insensitive.", &handlerIRegexMatch,
                "not-regex",       "<field-list>:REGEX   FIELD does not match regular expression.", &handlerRegexNotMatch,
                "not-iregex",      "<field-list>:REGEX   FIELD does not match regular expression, case-insensitive.", &handlerIRegexNotMatch,

                "char-len-le",     "<field-list>:NUM   character-length(FIELD) <= NUM.", &handlerCharLenLE,
                "char-len-lt",     "<field-list>:NUM   character-length(FIELD) < NUM.", &handlerCharLenLT,
                "char-len-ge",     "<field-list>:NUM   character-length(FIELD) >= NUM.", &handlerCharLenGE,
                "char-len-gt",     "<field-list>:NUM   character-length(FIELD) > NUM.", &handlerCharLenGT,
                "char-len-eq",     "<field-list>:NUM   character-length(FIELD) == NUM.", &handlerCharLenEQ,
                "char-len-ne",     "<field-list>:NUM   character-length(FIELD) != NUM.", &handlerCharLenNE,

                "byte-len-le",     "<field-list>:NUM   byte-length(FIELD) <= NUM.", &handlerByteLenLE,
                "byte-len-lt",     "<field-list>:NUM   byte-length(FIELD) < NUM.", &handlerByteLenLT,
                "byte-len-ge",     "<field-list>:NUM   byte-length(FIELD) >= NUM.", &handlerByteLenGE,
                "byte-len-gt",     "<field-list>:NUM   byte-length(FIELD) > NUM.", &handlerByteLenGT,
                "byte-len-eq",     "<field-list>:NUM   byte-length(FIELD) == NUM.", &handlerByteLenEQ,
                "byte-len-ne",     "<field-list>:NUM   byte-length(FIELD) != NUM.", &handlerByteLenNE,

                "ff-le",           "FIELD1:FIELD2   FIELD1 <= FIELD2 (numeric).", &handlerFFLE,
                "ff-lt",           "FIELD1:FIELD2   FIELD1 <  FIELD2 (numeric).", &handlerFFLT,
                "ff-ge",           "FIELD1:FIELD2   FIELD1 >= FIELD2 (numeric).", &handlerFFGE,
                "ff-gt",           "FIELD1:FIELD2   FIELD1 >  FIELD2 (numeric).", &handlerFFGT,
                "ff-eq",           "FIELD1:FIELD2   FIELD1 == FIELD2 (numeric).", &handlerFFEQ,
                "ff-ne",           "FIELD1:FIELD2   FIELD1 != FIELD2 (numeric).", &handlerFFNE,
                "ff-str-eq",       "FIELD1:FIELD2   FIELD1 == FIELD2 (string).", &handlerFFStrEQ,
                "ff-istr-eq",      "FIELD1:FIELD2   FIELD1 == FIELD2 (string, case-insensitive).", &handlerFFIStrEQ,
                "ff-str-ne",       "FIELD1:FIELD2   FIELD1 != FIELD2 (string).", &handlerFFStrNE,
                "ff-istr-ne",      "FIELD1:FIELD2   FIELD1 != FIELD2 (string, case-insensitive).", &handlerFFIStrNE,

                "ff-absdiff-le",   "FIELD1:FIELD2:NUM   abs(FIELD1 - FIELD2) <= NUM", &handlerFFAbsDiffLE,
                "ff-absdiff-gt",   "FIELD1:FIELD2:NUM   abs(FIELD1 - FIELD2) >  NUM", &handlerFFAbsDiffGT,
                "ff-reldiff-le",   "FIELD1:FIELD2:NUM   abs(FIELD1 - FIELD2) / min(abs(FIELD1), abs(FIELD2)) <= NUM", &handlerFFRelDiffLE,
                "ff-reldiff-gt",   "FIELD1:FIELD2:NUM   abs(FIELD1 - FIELD2) / min(abs(FIELD1), abs(FIELD2)) >  NUM", &handlerFFRelDiffGT,
                );

            /* Both help texts are a bit long. In this case, for "regular" help, don't
             * print options, just the text. The text summarizes the options.
             */
            if (r.helpWanted)
            {
                stdout.write(helpText);
                return tuple(false, 0);
            }
            else if (helpVerbose)
            {
                defaultGetoptPrinter(helpTextVerbose, r.options);
                return tuple(false, 0);
            }
            else if (helpOptions)
            {
                defaultGetoptPrinter(helpTextOptions, r.options);
                return tuple(false, 0);
            }
            else if (helpFields)
            {
                import tsv_utils.common.fieldlist : fieldListHelpText ;
                writeln(fieldListHelpText);
                return tuple(false, 0);
            }
            else if (versionWanted)
            {
                import tsv_utils.common.tsvutils_version;
                writeln(tsvutilsVersionNotice("tsv-filter"));
                return tuple(false, 0);
            }

            /* Input files. Remaining command line args are files. */
            string[] filepaths = (cmdArgs.length > 1) ? cmdArgs[1 .. $] : ["-"];
            cmdArgs.length = 1;

            /* Validations and derivations. Currently all are related to label mode. */
            if (!label.empty || labelValuesOptionUsed)
            {
                enforce(!label.empty || !hasHeader,
                        "--label is required when using --label-values and --H|header.");

                isLabeling = true;
            }

            enforce (!isLabeling || !countMatches,
                     format("--c|count cannot be used with --label or --label-values."));

            string[] headerFields;

            /* FieldListArgProcessing encapsulates the field list processing. It is
             * called prior to reading the header line if headers are not being used,
             * and after if headers are being used.
             */
            void fieldListArgProcessing()
            {
                cmdLineTestOptions.each!(dg => dg(tests, maxFieldIndex, hasHeader, headerFields));
            }

            if (!hasHeader) fieldListArgProcessing();

            ReadHeader readHeader = hasHeader ? Yes.readHeader : No.readHeader;
            inputSources = inputSourceRange(filepaths, readHeader);

            if (hasHeader)
            {
                throwIfWindowsNewline(inputSources.front.header, inputSources.front.name, 1);
                headerFields = inputSources.front.header.split(delim).to!(string[]);
                fieldListArgProcessing();
            }
        }
        catch (Exception e)
        {
            stderr.writefln("[%s] Error processing command line arguments: %s", programName, e.msg);
            return tuple(false, 1);
        }
        return tuple(true, 0);
    }
}

enum FilterMode { filter, count, label };

void tsvFilterCommand(ref TsvFilterOptions cmdopt)
{
    if (cmdopt.countMatches) tsvFilter!(FilterMode.count)(cmdopt);
    else if (cmdopt.isLabeling) tsvFilter!(FilterMode.label)(cmdopt);
    else tsvFilter!(FilterMode.filter)(cmdopt);
}

/** tsvFilter processes the input files and runs the tests.
 */
void tsvFilter(FilterMode mode)(ref TsvFilterOptions cmdopt)
{
    import std.algorithm : all, any, splitter;
    import std.format : formattedWrite;
    import std.range;
    import tsv_utils.common.utils : bufferedByLine, BufferedOutputRange, InputSourceRange,
        LineBuffered, throwIfWindowsNewline;

    static if (mode != FilterMode.count) assert(!cmdopt.countMatches);
    static if (mode != FilterMode.label) assert(!cmdopt.isLabeling);

    /* inputSources must be an InputSourceRange and include at least stdin. */
    assert(!cmdopt.inputSources.empty);
    static assert(is(typeof(cmdopt.inputSources) == InputSourceRange));

    static if (mode == FilterMode.label)
    {
        immutable string delimString = cmdopt.delim.to!string;
    }

    /* BufferedOutputRange improves performance on narrow files with high percentages of
     * writes.
     */
    static if (mode == FilterMode.count)
    {
        immutable LineBuffered isLineBuffered = No.lineBuffered;
    }
    else
    {
        immutable LineBuffered isLineBuffered =
            cmdopt.lineBuffered ? Yes.lineBuffered : No.lineBuffered;

        auto bufferedOutput = BufferedOutputRange!(typeof(stdout))(stdout, isLineBuffered);
    }

    static if (mode == FilterMode.count) size_t matchedLines = 0;

     /* First header is read during command line argument processing. Immediately
      * flush it so subsequent processes in a unix command pipeline see it early.
      * This helps provide timely error messages.
      */
    static if (mode != FilterMode.count)
    {
        if (cmdopt.hasHeader && !cmdopt.inputSources.front.isHeaderEmpty)
        {
            auto inputStream = cmdopt.inputSources.front;

            static if (mode == FilterMode.label)
            {
                bufferedOutput.appendln(inputStream.header, delimString, cmdopt.label);
            }
            else
            {
                bufferedOutput.appendln(inputStream.header);
            }

            bufferedOutput.flush;
        }
    }

    /* Process each input file, one line at a time. */
    immutable size_t fileBodyStartLine = cmdopt.hasHeader ? 2 : 1;
    auto lineFields = new char[][](cmdopt.maxFieldIndex + 1);

    foreach (inputStream; cmdopt.inputSources)
    {
        if (cmdopt.hasHeader) throwIfWindowsNewline(inputStream.header, inputStream.name, 1);

        foreach (lineNum, line; inputStream.file.bufferedByLine(isLineBuffered).enumerate(fileBodyStartLine))
        {
            if (lineNum == 1) throwIfWindowsNewline(line, inputStream.name, lineNum);

            /* Copy the needed number of fields to the fields array. */
            long fieldIndex = -1;
            foreach (fieldValue; line.splitter(cmdopt.delim))
            {
                if (fieldIndex == cast(long) cmdopt.maxFieldIndex) break;
                fieldIndex++;
                lineFields[fieldIndex] = fieldValue;
            }

            if (fieldIndex == -1)
            {
                assert(line.length == 0);
                /* Bug work-around. Currently empty lines are not handled properly by splitter.
                 *   Bug: https://issues.dlang.org/show_bug.cgi?id=15735
                 *   Pull Request: https://github.com/D-Programming-Language/phobos/pull/4030
                 * Work-around: Point to the line. It's an empty string.
                 */
                fieldIndex++;
                lineFields[fieldIndex] = line;
            }

            enforce(fieldIndex >= cast(long) cmdopt.maxFieldIndex,
                    format("Not enough fields in line. File: %s, Line: %s",
                           inputStream.name, lineNum));

            /* Run the tests. Tests will fail (throw) if a field cannot be converted
             * to the expected type.
             */
            try
            {
                bool passed = cmdopt.disjunct ?
                    cmdopt.tests.any!(x => x(lineFields)) :
                    cmdopt.tests.all!(x => x(lineFields));
                if (cmdopt.invert) passed = !passed;

                static if (mode == FilterMode.count)
                {
                    if (passed) ++matchedLines;
                }
                else static if (mode == FilterMode.label)
                {
                    bufferedOutput.appendln(line, delimString,
                                            passed ? cmdopt.trueLabel : cmdopt.falseLabel);
                }
                else
                {
                    if (passed) bufferedOutput.appendln(line);
                }
            }
            catch (Exception e)
            {
                static if (mode != FilterMode.count) bufferedOutput.flush;
                throw new Exception(
                    format("Could not process line or field: %s\n  File: %s Line: %s%s",
                           e.msg, inputStream.name, lineNum,
                           (lineNum == 1) ? "\n  Is this a header line? Use --header to skip." : ""));
            }
        }
    }

    static if (mode == FilterMode.count) writeln(matchedLines);
}
