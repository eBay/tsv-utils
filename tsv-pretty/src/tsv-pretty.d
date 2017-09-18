/**
Command line tool that prints TSV data aligned for easier reading on consoles
and traditional command-line environments.

Copyright (c) 2017, eBay Software Foundation
Initially written by Jon Degenhardt

License: Boost License 1.0 (http://boost.org/LICENSE_1_0.txt)
*/
module tsv_pretty;

import std.range;
import std.stdio;
import std.typecons : Flag, Yes, No, tuple;

version(unittest)
{
    // When running unit tests, use main from -main compiler switch.
}
else
{
    int main(string[] cmdArgs)
    {
        /* When running in DMD code coverage mode, turn on report merging. */
        version(D_Coverage) version(DigitalMars)
        {
            import core.runtime : dmd_coverSetMerge;
            dmd_coverSetMerge(true);
        }

        TsvPrettyOptions options;
        auto r = options.processArgs(cmdArgs);
        if (!r[0]) return r[1];
        try tsvPretty(options, cmdArgs[1 .. $]);
        catch (Exception exc)
        {
            stderr.writefln("Error [%s]: %s", options.programName, exc.msg);
            return 1;
        }
        return 0;
    }
}

auto helpTextVerbose = q"EOS
Synopsis: tsv-pretty [options] [file...]

tsv-pretty outputs TSV data in a format intended to be more human readable when
working on the command line. This is done primarily by lining up data into
fixed-width columns. Text is left aligned, numbers are right aligned. Floating
points numbers are aligned on the decimal point when feasible.

tsv-pretty starts by reading an initial set of lines (defaults to 1000) to
determine field widths and data types. Lines are written as they are recieved
after this. This field information is used for the remainder of the output.
There are a number of options for controlling formatting.

By default, the text of the input values is not changed. There are a couple
options that change this:

* Floating point number formatting - Floats can be reformatted using the
  '--f|format-floats' or '--p|precision NUM' options. Both print floats
  favoring a fixed precision over exponential notation for smaller numbers.
  The main difference is that '--f|format-floats' uses a default precision.

* Missing values - A substitute value can be used, this is often less
  confusing than spaces. Use the '--e|replace-empty' or
  '--E|empty-replacement <string>' options.

Limitations: This program assumes fixed width fonts, as commonly found in
command-line environments. Alignment will be off when variable width fonts
are used. However, even fixed width fonts can be tricky for certain character
sets. Notably, ideographic characters common in asian languages use double-
width characters in many fixed-width fonts. This program estimates print
length assuming CJK characters are rendered double-width. This works well in
many cases, but incorrect alignment can still occur.

Options:
EOS";

auto helpText = q"EOS
Synopsis: tsv-pretty [options] [file...]

tsv-pretty outputs TSV data in a more human readable format. This is done by lining
up data into fixed-width columns. Text is left aligned, numbers are right aligned.
Floating points numbers are aligned on the decimal point when feasible.

Options:
EOS";

/* TsvPrettyOptions is used to process and store command line options. */
struct TsvPrettyOptions
{
    string programName;
    bool helpVerbose = false;           // --help-verbose
    bool hasHeader = false;             // --H|header (Note: Default false assumed by validation code)
    bool autoDetectHeader = true;       // Derived (Note: Default true assumed by validation code)
    bool noHeader = false;              // --x|no-header (Note: Default false assumed by validation code)
    size_t lookahead = 1000;            // --l|lookahead
    size_t repeatHeader = 0;            // --r|repeat-header num (zero means no repeat)
    bool underlineHeader = false;       // --u|underline-header
    bool formatFloats = false;          // --f|format-floats
    size_t floatPrecision = 9;          // --p|precision num (max precision when formatting floats)
    bool replaceEmpty = false;          // --e|replace-empty
    string emptyReplacement = "";       // --E|empty-replacement
    size_t emptyReplacementPrintWidth = 0;    // Derived
    char delim = '\t';                  // --d|delimiter
    size_t spaceBetweenFields = 2;      // --s|space-between-fields num
    size_t maxFieldPrintWidth = 24;     // --m|max-text-width num; Max width for variable width text fields.
    bool versionWanted = false;         // --V|version

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
        import std.path : baseName, stripExtension;

        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

        try
        {
            arraySep = ",";    // Use comma to separate values in command line options
            auto r = getopt(
                cmdArgs,
                "help-verbose",           "       Print full help.", &helpVerbose,
                std.getopt.config.caseSensitive,
                "H|header",               "       Treat the first line of each file as a header.", &hasHeader,
                std.getopt.config.caseInsensitive,
                "x|no-header",            "       Assume no header. Turns off automatic header detection.", &noHeader,
                "l|lookahead",            "NUM    Lines to read to interpret data before generating output. Default: 1000)", &lookahead,

                "r|repeat-header",        "NUM    (Not implemented) Lines to print before repeating the header. Default: No repeating", &repeatHeader,

                "u|underline-header",     "       Underline the header.", &underlineHeader,
                "f|format-floats",        "       Format floats for better readability. Default: No", &formatFloats,
                "p|precision",            "NUM    Floating point precision. Implies --format-floats", &floatPrecisionOptionHandler,
                std.getopt.config.caseSensitive,
                "e|replace-empty",        "       Replace empty fields with '--'.", &replaceEmpty,
                "E|empty-replacement",    "STR    Replace empty fields with a string.", &emptyReplacement,
                std.getopt.config.caseInsensitive,
                "d|delimiter",            "CHR    Field delimiter. Default: TAB. (Single byte UTF-8 characters only.)", &delim,
                "s|space-between-fields", "NUM    Spaces between each field (Default: 2)", &spaceBetweenFields,
                "m|max-text-width",       "NUM     Max reserved field width for variable width text fields. Default: 24", &maxFieldPrintWidth,
                std.getopt.config.caseSensitive,
                "V|version",              "       Print version information and exit.", &versionWanted,
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
                import tsvutils_version;
                writeln(tsvutilsVersionNotice("tsv-pretty"));
                return tuple(false, 0);
            }

            /* Validation and derivations. */
            if (noHeader && hasHeader) throw new Exception("Cannot specify both --H|header and --x|no-header.");

            if (noHeader || hasHeader) autoDetectHeader = false;

            /* Zero lookahead has limited utility unless the first line is known to
             * be a header. Good chance the user will get an unintended behavior.
             */
            if (lookahead == 0 && autoDetectHeader)
            {
                assert (!noHeader && !hasHeader);
                throw new Exception("Cannot auto-detect header with zero lookahead. Specify either '--H|header' or '--x|no-header' when using '--l|lookahead 0'.");
            }

            if (emptyReplacement.length != 0) replaceEmpty = true;
            else if (replaceEmpty) emptyReplacement = "--";

            if (emptyReplacement.length != 0)
            {
                emptyReplacementPrintWidth = emptyReplacement.monospacePrintWidth;
            }
        }
        catch (Exception exc)
        {
            stderr.writefln("[%s] Error processing command line arguments: %s", programName, exc.msg);
            return tuple(false, 1);
        }
        return tuple(true, 0);
    }

    /* Option handler for --p|precision. It also sets --f|format-floats. */
    private void floatPrecisionOptionHandler(string option, string optionVal)
    {
        import std.conv : to;
        floatPrecision = optionVal.to!size_t;
        formatFloats = true;
    }
}

/* Header Auto-Detect algorithm
 *
 * Definition: First line is declared a header if any column is identified as numeric
 * when considering all rows but the first in the lookahead cache, and the first row
 * cannot be parsed as numeric.
 *
 * Multiple files: A decision is made on the header after the first file has been
 * processed, even if the lookahead cache has not been filled. This is to enable
 * disposition of first line of subsequent files without additional complications to
 * the algorithm. In this case, one additional check is made, which is that the first
 * line of both files is identical.
 *
 */

void tsvPretty(in ref TsvPrettyOptions options, string[] files)
{
    auto tpp = TsvPrettyProcessor(options);
    foreach (filename; (files.length > 0) ? files : ["-"])
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (lineNum, line; inputStream.byLine.enumerate(1))
        {
            if (lineNum == 1)
            {
                tpp.processFileFirstLine(outputRangeObject!(char, char[])(stdout.lockingTextWriter), line);
            }
            else
            {
                tpp.processLine(outputRangeObject!(char, char[])(stdout.lockingTextWriter), line);
            }
        }
    }
    tpp.finish(outputRangeObject!(char, char[])(stdout.lockingTextWriter));
}

/* TsvPrettyProcessor maintains state of processing and exposes operations for
 * processing individual lines. TsvPrettyProcessor knows that input is file
 * oriented, but doesn't deal with actual files or reading lines from input.
 * That is the job of the caller.
 *
 * The caller is expected to pass each line to TsvPrettyProcessor in the order
 * recieved, that is an assumption built-into the its processing.
 */

/* Processing algorithms:
 *
 * === Processing the first line of each file ====
 * 1) _options.noHeader: Process as a normal data line
 * 2) _options.hasHeader:
 *    a) First file: Set-as-header for the line.
 *       i) _options.lookahead == 0:
 *          Output lookahead cache (finalizes field formats, outputs header, sets not caching)
 *       j) _options.lookahead > 0: Nothing
 *    b) 2nd+ file: Ignore the line (do nothing)
 * 3) _options.autoDetectHeader
 *    a) Detected-as-no-header: Process as normal data line
 *    b) Detected-as-header: Assert: 2nd+ file; Ignore the line (do nothing)
 *    c) No detection yet
 *       Assert: Still doing lookahead caching
 *       Assert: First or second file
 *       i) First file: Set as candidate header
 *       j) Second file: Compare to first candidate header
 *          p) Equal to first candidate header:
 *             Set detected-as-header
 *             Set-as-header for the line
 *          q) !Equal to first candidate header:
 *             Set detected-as-no-header
 *             Add-fields-to-line format for first candidate-header
 *             Process line as data line
 *       IMPLIES: Header detection can occur prior to lookahead completion.
 *
 * === Process data line ===
 * 1) Not caching: Output data line
 * 2) Still caching
 *    Append data line to cache
 *    if cache is full: output lookahead cache (finalized field formats, outputs header, sets not caching)
 *
 * === Finish all processing ===
 * 1) Not caching: Do nothing (done)
 * 2) Still caching: Output lookahead cache
 *
 * === Output lookahead cache ===
 * All:
 *    if _options.autoDetectHeader && not-detected-yet:
 *       Compare field formats to candidate field formats
 *       1) Looks-like-header: Set detected-as-header
 *       2) Look-like-not-header:
 *          Set detected-as-no-header
 *          Add-field-to-line-format for candidate header
 * All:
 *    Finalize field formatting
 *
 * 1) _options.hasHeader || detected-as-header: output header
 * 2) _options.autoDetectHeader && detected-as-not-header && candidate-header filled in:
 *    Output candidate header as data line
 *
 * All:
 *    Output data line cache
 *    Set as not caching
 *
 */
struct TsvPrettyProcessor
{
    import std.array : appender;

private:
    private enum AutoDetectHeaderResult { none, hasHeader, noHeader };

    private TsvPrettyOptions _options;
    private size_t _fileCount = 0;
    private size_t _dataLineOutputCount = 0;
    private bool _stillCaching = true;
    private string _candidateHeaderLine;
    private auto _lookaheadCache = appender!(string[])();
    private FieldFormat[] _fieldVector;
    private AutoDetectHeaderResult _autoDetectHeaderResult = AutoDetectHeaderResult.none;

    this(const TsvPrettyOptions options)
    {
        _options = options;
        if (options.noHeader && options.lookahead == 0) _stillCaching = false;
    }

    invariant
    {
        assert(_options.hasHeader || _options.noHeader || _options.autoDetectHeader);
        assert((_options.lookahead == 0 && _lookaheadCache.data.length == 0) ||
               _lookaheadCache.data.length < _options.lookahead);
    }

    void processFileFirstLine(OutputRange!char outputStream, const char[] line)
    {
        debug writefln("[processFileFirstLine]");
        import std.conv : to;

        _fileCount++;

        if (_options.noHeader)
        {
            processLine(outputStream, line);
        }
        else if (_options.hasHeader)
        {
            if (_fileCount == 1)
            {
                setHeaderLine(line);
                if (_options.lookahead == 0) outputLookaheadCache(outputStream);
            }
        }
        else
        {
            assert(_options.autoDetectHeader);

            final switch (_autoDetectHeaderResult)
            {
            case AutoDetectHeaderResult.noHeader:
                debug writefln("[processFileFirstLine] AutoDetectHeaderResult.no Header; file: %d", _fileCount);
                assert(_fileCount > 1);
                processLine(outputStream, line);
                break;

            case AutoDetectHeaderResult.hasHeader:
                debug writefln("[processFileFirstLine] AutoDetectHeaderResult.hasHeader; file: %d", _fileCount);
                assert(_fileCount > 1);
                break;

            case AutoDetectHeaderResult.none:
                debug writefln("[processFileFirstLine] AutoDetectHeaderResult.none; file: %d", _fileCount);
                if (_fileCount == 1)
                {
                    assert(_candidateHeaderLine.length == 0);
                    _candidateHeaderLine = line.to!string;
                }
                else if (_fileCount == 2)
                {
                    if (_candidateHeaderLine == line)
                    {
                        _autoDetectHeaderResult = AutoDetectHeaderResult.hasHeader;
                        setHeaderLine(_candidateHeaderLine);

                        /* Edge case: First file has only a header line and lookahead set to zero. */
                        if (_stillCaching && _options.lookahead == 0) outputLookaheadCache(outputStream);
                    }
                    else
                    {
                        _autoDetectHeaderResult = AutoDetectHeaderResult.noHeader;
                        updateFieldFormatsForLine(_candidateHeaderLine);
                        processLine(outputStream, line);
                    }
                }
                break;
            }
        }
    }

    void processLine(OutputRange!char outputStream, const char[] line)
    {
        debug writefln("[processLine]");
        if (_stillCaching) cacheDataLine(outputStream, line);
        else outputDataLine(outputStream, line);
    }

    void finish(OutputRange!char outputStream)
    {
        debug writefln("[finish]");
        if (_stillCaching) outputLookaheadCache(outputStream);
    }

private:
    void outputLookaheadCache(OutputRange!char outputStream)
    {
        import std.algorithm : splitter;

        debug writefln("[outputLookaheadCache]");
        assert(_stillCaching);

        if (_options.autoDetectHeader &&
            _autoDetectHeaderResult == AutoDetectHeaderResult.none &&
            _candidateHeaderLine.length != 0)
        {
            if (candidateHeaderLooksLikeHeader())
            {
                _autoDetectHeaderResult = AutoDetectHeaderResult.hasHeader;
                setHeaderLine(_candidateHeaderLine);
            }
            else
            {
                _autoDetectHeaderResult = AutoDetectHeaderResult.noHeader;
            }
        }


        if (_options.hasHeader ||
            (_options.autoDetectHeader && _autoDetectHeaderResult == AutoDetectHeaderResult.hasHeader))
        {
            finalizeFieldFormatting();
            outputHeader(outputStream);
        }
        else if (_options.autoDetectHeader && _autoDetectHeaderResult == AutoDetectHeaderResult.noHeader &&
                 _candidateHeaderLine.length != 0)
        {
            updateFieldFormatsForLine(_candidateHeaderLine);
            finalizeFieldFormatting();
            outputDataLine(outputStream, _candidateHeaderLine);
        }
        else
        {
            finalizeFieldFormatting();
        }

        foreach(line; _lookaheadCache.data) outputDataLine(outputStream, line);
        _lookaheadCache.clear;
        _stillCaching = false;
    }

    bool candidateHeaderLooksLikeHeader()
    {
        debug writefln("[candidateHeaderLooksLikeHeader]");

        import std.algorithm : splitter;
        /* The candidate header is declared as the header if the lookahead cache has at least
         * one numeric field that is text in the candidate header.
         */
        foreach(fieldIndex, fieldValue; _candidateHeaderLine.splitter(_options.delim).enumerate)
        {
            auto candidateFieldFormat = FieldFormat(fieldIndex);
            candidateFieldFormat.updateForFieldValue(fieldValue, _options);
            if (_fieldVector.length > fieldIndex &&
                candidateFieldFormat.fieldType == FieldType.text &&
                (_fieldVector[fieldIndex].fieldType == FieldType.integer ||
                 _fieldVector[fieldIndex].fieldType == FieldType.floatingPoint ||
                 _fieldVector[fieldIndex].fieldType == FieldType.exponent))
            {
                return true;
            }
        }

        return false;
    }

    void setHeaderLine(const char[] line)
    {
        debug writefln("[setHeaderLine]");
        import std.algorithm : splitter;

        foreach(fieldIndex, header; line.splitter(_options.delim).enumerate)
        {
            if (_fieldVector.length == fieldIndex) _fieldVector ~= FieldFormat(fieldIndex);
            assert(_fieldVector.length > fieldIndex);
            _fieldVector[fieldIndex].setHeader(header);
        }
    }

    void cacheDataLine(OutputRange!char outputStream, const char[] line)
    {
        debug writefln("[cacheDataLine]");
        import std.conv : to;

        assert(_lookaheadCache.data.length < _options.lookahead);

        _lookaheadCache ~= line.to!string;
        updateFieldFormatsForLine(line);
        if (_lookaheadCache.data.length == _options.lookahead) outputLookaheadCache(outputStream);
    }

    void updateFieldFormatsForLine(const char[] line)
    {
        debug writefln("[updateFieldFormatsForLine]");
        import std.algorithm : splitter;

        foreach(fieldIndex, fieldValue; line.splitter(_options.delim).enumerate)
        {
            if (_fieldVector.length == fieldIndex) _fieldVector ~= FieldFormat(fieldIndex);
            assert(_fieldVector.length > fieldIndex);
            _fieldVector[fieldIndex].updateForFieldValue(fieldValue, _options);
        }

    }

    void finalizeFieldFormatting()
    {
        debug writefln("[finalizeFieldFormatting]");
        size_t nextFieldStart = 0;
        foreach(ref field; _fieldVector)
        {
            nextFieldStart = field.finalizeFormatting(nextFieldStart, _options) + _options.spaceBetweenFields;
        }
    }

    void outputHeader(OutputRange!char outputStream)
    {
        debug writefln("[outputHeader]");
        foreach(ref field; _fieldVector) field.writeHeader(outputStream, _options);
        put(outputStream, '\n');

        if (_options.underlineHeader)
        {
            foreach(ref field; _fieldVector) field.writeHeader!(Yes.writeUnderline)(outputStream, _options);
            put(outputStream, '\n');
        }
    }

    void outputDataLine(OutputRange!char outputStream, const char[] line)
    {
        debug writefln("[outputDataLine]");
        import std.algorithm : splitter;

        /* Repeating header option. */
        if (_options.repeatHeader != 0 && _dataLineOutputCount != 0 &&
            (_options.hasHeader || (_options.autoDetectHeader &&
                                    _autoDetectHeaderResult == AutoDetectHeaderResult.hasHeader)) &&
            _dataLineOutputCount % _options.repeatHeader == 0)
        {
            put(outputStream, '\n');
            outputHeader(outputStream);
        }

        _dataLineOutputCount++;

        size_t nextOutputPosition = 0;
        foreach(fieldIndex, fieldValue; line.splitter(_options.delim).enumerate)
        {
            if (fieldIndex == _fieldVector.length)
            {
                /* Line is longer than any seen while caching. Add a new FieldFormat entry
                 * and set the line formatting based on this field value.
                 */
                _fieldVector ~= FieldFormat(fieldIndex);
                size_t startPosition = (fieldIndex == 0) ?
                    0 :
                    _fieldVector[fieldIndex - 1].endPosition + _options.spaceBetweenFields;

                _fieldVector[fieldIndex].updateForFieldValue(fieldValue, _options);
                _fieldVector[fieldIndex].finalizeFormatting(startPosition, _options);
            }

            assert(fieldIndex < _fieldVector.length);

            FieldFormat fieldFormat = _fieldVector[fieldIndex];
            size_t nextFieldStart = fieldFormat.startPosition;
            size_t spacesNeeded = (nextOutputPosition < nextFieldStart) ?
                nextFieldStart - nextOutputPosition :
                (fieldIndex == 0) ? 0 : 1;  // Previous field went long. One space between fields

            put(outputStream, repeat(" ", spacesNeeded));
            nextOutputPosition += spacesNeeded;
            nextOutputPosition += fieldFormat.writeFieldValue(outputStream, nextOutputPosition, fieldValue, _options);
        }
        put(outputStream, '\n');
    }
}

/* Field Formatting and alignment
 * - Text columns: Values always left-aligned, unchanged.
 * - Integer columns: Values always right-aligned, unchanged.
 * - Floating point columns, not formatted
 *   - Floating point values aligned on decimal point
 *   - Integer values aligned on decimal point
 *   - Exponential values right aligned
 *   - Text values right aligned
 * - Exponential columns, not formatted:
 *      Values always right-aligned, unchanged.
 * - Floating point columns, formatted
 *   - Floating point value
 *     - Raw precision <= column precision:
 *         Zero-pad raw value to precision
 *     - Raw precision > column precision: Format with %f
 *   - Integer value: Format with %f
 *   - Text value: Right align
 *   - Exponent: Right align
 * - Exponential columns, formatted
 *   - Exponential value:
 *     - Raw precision <= column precision:
 *          Zero-pad raw value to precision
 *     - Raw precision > column precision: Format with %e
 *   - Floating point value: Format with %e
 *   - Integer value: Format with %e
 *   - Text value: Right align
 */

/** FieldFormat holds all the formatting info needed to format data values in a specific
 * column. e.g. Field 1 may be text, field 2 may be a float, etc. This is calculated
 * during the caching phase. Each FieldFormat instance is part of a vector representing
 * the full row, so each includes the start position on the line and similar data.
 *
 * APIs used during the caching phase to gather field value samples
 * - this - Initial construction. Takes the field index.
 * - setHeader - Used to set the header text.
 * - updateForFieldValue - Used to add the next field value sample.
 * - finalizeFormatting - Used at the end of caching to finalize the format choices.
 *
 * APIs used after caching is finished (after finalizeFormatting):
 * - startPosition - Returns the expected start position for the field.
 * - endPosition - Returns the expected end position for the field.
 * - writeHeader - Outputs the header, properly aligned.
 * - writeFieldValue - Outputs the current field value, properly aligned.
 */

enum FieldType { unknown, text, integer, floatingPoint, exponent };
enum FieldAlignment { left, right };

struct FieldFormat
{
private:
    size_t _fieldIndex;                  // Zero-based index in the line
    string _header = "";                 // Original field header
    size_t _headerPrintWidth = 0;
    FieldType _type = FieldType.unknown;
    FieldAlignment _alignment = FieldAlignment.left;
    size_t _startPosition = 0;
    size_t _printWidth = 0;
    size_t _precision = 0;          // Number of digits after the decimal point

    /* These are used while doing initial type and print format detection. */
    size_t _minRawPrintWidth = 0;
    size_t _maxRawPrintWidth = 0;
    size_t _maxDigitsBeforeDecimal = 0;
    size_t _maxDigitsAfterDecimal = 0;
    size_t _maxSignificantDigits = 0;  // Digits to include in exponential notation

public:
    this(size_t fieldIndex)
    {
        _fieldIndex = fieldIndex;
    }

    /* setHeader is called to set the header text. */
    void setHeader(const char[] header) @safe
    {
        import std.conv : to;

        _header = header.to!string;
        _headerPrintWidth = _header.monospacePrintWidth;
    }

    size_t startPosition() nothrow pure @safe @property
    {
        return _startPosition;
    }

    size_t endPosition() nothrow pure @safe @property
    {
        return _startPosition + _printWidth;
    }

    FieldType fieldType() nothrow pure @safe @property
    {
        return _type;
    }

    /* writeHeader writes the field header or underline characters to the output stream.
     * Any previous fields on line should have been written without trailing spaces.
     * Unlike data values, headers should always be written on the correct offsets.
     */
    void writeHeader(Flag!"writeUnderline" writeUnderline = No.writeUnderline)
        (OutputRange!char outputStream, in ref TsvPrettyOptions options)
    {
        import std.range : repeat;

        if (_headerPrintWidth > 0)
        {
            if (_fieldIndex > 0)
            {
                put(outputStream, repeat(" ", options.spaceBetweenFields));
            }

            if (_alignment == FieldAlignment.right)
            {
                put(outputStream, repeat(" ", _printWidth - _headerPrintWidth));
            }

            static if (writeUnderline)
            {
                put(outputStream, repeat("-", _headerPrintWidth));
            }
            else
            {
                put(outputStream, _header);
            }

            if (_alignment == FieldAlignment.left)
            {
                put(outputStream, repeat(" ", _printWidth - _headerPrintWidth));
            }
        }
    }

private:
    /* Formatting floats - A simple approach is taken. Floats with a readable number of trailing
     * digits are printed as fixed point (%f). Floats with a longer number of digits are printed
     * as variable length, including use of exponential notion (%g). Calculating the length
     * requires knowing which was used.
     */
    enum defaultReadablePrecisionMax = 6;


public:
    /* writeFieldValue writes the field value for the current column The caller needs
     * to generate output at least to the column's start position, but can go beyond
     * if previous fields have run long.
     *
     * The field value is aligned properly in the field. Either left aligned (text) or
     * right aligned (numeric). Floating point fields are both right aligned and
     * decimal point aligned. The number of bytes written is returned. Trailing spaces
     * are not added, the caller must add any necessary trailing spaces prior to
     * printing the next field.
     */
    size_t writeFieldValue(OutputRange!char outputStream, size_t currPosition,
                           const char[] fieldValue, in ref TsvPrettyOptions options)
    in
    {
        assert(currPosition >= _startPosition);   // Caller resposible for advancing to field start position.
        assert(_type == FieldType.text || _type == FieldType.integer ||
               _type == FieldType.floatingPoint || _type == FieldType.exponent);
    }
    body
    {
        import std.algorithm : find, max, min;
        import std.conv : to, ConvException;
        import std.format : format;

        /* Create the print version of the string. Either the raw value or a formatted
         * version of a float.
         */
        string printValue;
        if (!options.formatFloats || _type == FieldType.text || _type == FieldType.integer)
        {
            printValue = fieldValue.to!string;
        }
        else
        {
            assert(options.formatFloats);
            assert(_type == FieldType.exponent || _type == FieldType.floatingPoint);

            if (_type == FieldType.exponent)
            {
                printValue = fieldValue.formatExponentValue(_precision);
            }
            else
            {
                printValue = fieldValue.formatFloatingPointValue(_precision);
            }
        }

        if (printValue.length == 0 && options.replaceEmpty) printValue = options.emptyReplacement;
        size_t printValuePrintWidth = printValue.monospacePrintWidth;

        /* Calculate leading spaces needed for right alignment. */
        size_t leadingSpaces = 0;
        if (_alignment == FieldAlignment.right)
        {
            /* Target width adjusts the column width to account for overrun by the previous field. */
            size_t targetWidth;
            if (currPosition == _startPosition)
            {
                targetWidth = _printWidth;
            }
            else
            {
                size_t startGap = currPosition - _startPosition;
                targetWidth = max(printValuePrintWidth,
                                  startGap < _printWidth ? _printWidth - startGap : 0);
            }

            leadingSpaces = (printValuePrintWidth < targetWidth) ?
                targetWidth - printValuePrintWidth : 0;

            /* The above calculation assumes the print value is fully right aligned.
             * This is not correct when raw value floats are being used rather than
             * formatted floats, as different values will have different precision.
             * The next adjustment accounts for this, dropping leading spaces as
             * needed to align the decimal point. Note that text and exponential
             * values get aligned strictly against right boundaries.
             */
            if (leadingSpaces > 0 && _precision > 0 &&
                _type == FieldType.floatingPoint && !options.formatFloats)
            {
                import std.algorithm : canFind, findSplit;
                import std.string : isNumeric;

                if (printValue.isNumeric && !printValue.canFind!(x => x == 'e' || x == 'E'))
                {
                    size_t decimalAndDigitsLength = printValue.find(".").length;
                    size_t trailingSpaces =
                        (decimalAndDigitsLength == 0) ? _precision + 1 :
                        (decimalAndDigitsLength > _precision) ? 0 :
                        _precision + 1 - decimalAndDigitsLength;

                    leadingSpaces = (leadingSpaces > trailingSpaces) ?
                        leadingSpaces - trailingSpaces : 0;
                }
            }
        }
        put(outputStream, repeat(' ', leadingSpaces));
        put(outputStream, printValue);
        return printValuePrintWidth + leadingSpaces;
    }

    /* updateForFieldValue updates type and format given a new field value.
     */
    void updateForFieldValue(size_t readablePrecisionMax = defaultReadablePrecisionMax)
        (const char[] fieldValue, in ref TsvPrettyOptions options)
    {
        import std.algorithm : findAmong, findSplit, max, min;
        import std.conv : to, ConvException;
        import std.string : isNumeric;
        import tsv_numerics : formatNumber;

        debug writef("updateForFieldValue(%s)] CurrType: %s", fieldValue, _type);

        size_t fieldValuePrintWidth = fieldValue.monospacePrintWidth;
        size_t fieldValuePrintWidthWithEmpty =
            (fieldValuePrintWidth == 0 && options.replaceEmpty) ?
            options.emptyReplacementPrintWidth :
            fieldValuePrintWidth;

        _maxRawPrintWidth = max(_maxRawPrintWidth, fieldValuePrintWidthWithEmpty);
        _minRawPrintWidth = (_minRawPrintWidth == 0) ?
            fieldValuePrintWidthWithEmpty :
            min(_minRawPrintWidth, fieldValuePrintWidthWithEmpty);

        if (_type == FieldType.text)
        {
            /* Already text, can't become anything else. */
        }
        else if (fieldValuePrintWidth == 0)
        {
            /* Don't let an empty field override a numeric field type. */
        }
        else if (!fieldValue.isNumeric)
        {
            /* Not parsable as a number. Switch from unknown or numeric type to text. */
            _type = FieldType.text;
        }
        else
        {
            /* Field type is currently unknown or numeric, and current field parses as numeric.
             * See if it parses as integer or float. Integers will parse as floats, so try
             * integer types first.
             */
            FieldType parsesAs = FieldType.unknown;
            long longValue;
            ulong ulongValue;
            double doubleValue;
            try
            {
                longValue = fieldValue.to!long;
                parsesAs = FieldType.integer;
            }
            catch (ConvException)
            {
                try
                {
                    ulongValue = fieldValue.to!ulong;
                    parsesAs = FieldType.integer;
                }
                catch (ConvException)
                {
                    try
                    {
                        doubleValue = fieldValue.to!double;
                        import std.algorithm : findAmong;
                        parsesAs = (fieldValue.findAmong("eE").length == 0) ?
                            FieldType.floatingPoint : FieldType.exponent;
                    }
                    catch (ConvException)
                    {
                        /* Note: This means isNumeric thinks it's a number, but conversions all failed. */
                        parsesAs = FieldType.text;
                    }
                }
            }

            if (parsesAs == FieldType.text)
            {
                /* Not parsable as a number (despite isNumeric result). Switch to text type. */
                _type = FieldType.text;
            }
            else if (parsesAs == FieldType.exponent)
            {
                /* Exponential notion supercedes both vanilla floats and integers. */
                _type = FieldType.exponent;
                _maxSignificantDigits = max(_maxSignificantDigits, fieldValue.significantDigits);

                if (auto decimalSplit = fieldValue.findSplit("."))
                {
                    auto fromExponent = decimalSplit[2].findAmong("eE");
                    size_t numDigitsAfterDecimal = decimalSplit[2].length - fromExponent.length;
                    _maxDigitsBeforeDecimal = max(_maxDigitsBeforeDecimal, decimalSplit[0].length);
                    _maxDigitsAfterDecimal = max(_maxDigitsAfterDecimal, numDigitsAfterDecimal);
                }
                else
                {
                    /* Exponent without a decimal point. */
                    auto fromExponent = fieldValue.findAmong("eE");
                    assert(fromExponent.length > 0);
                    size_t numDigits = fieldValue.length - fromExponent.length;
                    _maxDigitsBeforeDecimal = max(_maxDigitsBeforeDecimal, numDigits);
                }
            }
            else if (parsesAs == FieldType.floatingPoint)
            {
                /* Even if currently integer it becomes a float. */
                _type = FieldType.floatingPoint;
                _maxSignificantDigits = max(_maxSignificantDigits, fieldValue.significantDigits);

                if (auto decimalSplit = fieldValue.findSplit("."))
                {
                    _maxDigitsBeforeDecimal = max(_maxDigitsBeforeDecimal, decimalSplit[0].length);
                    _maxDigitsAfterDecimal = max(_maxDigitsAfterDecimal, decimalSplit[2].length);
                }
            }
            else
            {
                assert(parsesAs == FieldType.integer);
                if (_type != FieldType.floatingPoint) _type = FieldType.integer;
                _maxSignificantDigits = max(_maxSignificantDigits, fieldValue.significantDigits);
                _maxDigitsBeforeDecimal = max(_maxDigitsBeforeDecimal, fieldValue.length);
            }
        }
        debug writefln(" -> %s", _type);
    }

    /* finalizeFormatting updates field formatting info based on the current state. It is
     * expected to be called after adding field entries via updateForFieldValue(). It
     * returns its new end position.
     */
    size_t finalizeFormatting (size_t startPosition, in ref TsvPrettyOptions options)
    {
        import std.algorithm : max, min;
        _startPosition = startPosition;
        if (_type == FieldType.unknown) _type = FieldType.text;
        _alignment = (_type == FieldType.integer || _type == FieldType.floatingPoint
                      || _type == FieldType.exponent) ?
            FieldAlignment.right :
            FieldAlignment.left;

        if (_type == FieldType.floatingPoint)
        {
            size_t precision = min(options.floatPrecision, _maxDigitsAfterDecimal);
            size_t maxValueWidth = _maxDigitsBeforeDecimal + precision;
            if (precision > 0) maxValueWidth++;  // Account for the decimal point.
            _printWidth = max(1, _headerPrintWidth, maxValueWidth);
            _precision = precision;
        }
        else if (_type == FieldType.exponent)
        {
            _printWidth = max(1, _headerPrintWidth, _maxRawPrintWidth);
            _precision = (_maxSignificantDigits > 0) ? _maxSignificantDigits - 1 : 0;
        }
        else if (_type == FieldType.integer)
        {
            _printWidth = max(1, _headerPrintWidth, _minRawPrintWidth, _maxRawPrintWidth);
            _precision = 0;
        }
        else
        {
            _printWidth = max(1, _headerPrintWidth, _minRawPrintWidth,
                              min(options.maxFieldPrintWidth, _maxRawPrintWidth));
            _precision = 0;
        }

        debug writefln("[finalizeFormatting] %s", this);
        return _startPosition + _printWidth;
    }
}

auto formatExponentValue(const char[] fieldValue, size_t precision)
{
    // TODO - Do this correctly
    import std.conv : to;
    import std.format : format;
    return format("%.*e", precision, fieldValue.to!double);
}

auto formatFloatingPointValue(const char[] fieldValue, size_t precision)
{
    // TODO - Do this correctly
    import std.conv : to;
    import std.format : format;
    return format("%.*f", precision, fieldValue.to!double);
}

size_t significantDigits(const char[] numericString)
{
    import std.algorithm : canFind, find, findAmong, findSplit, stripRight;
    import std.ascii : isDigit;
    import std.math : isFinite;
    import std.string : isNumeric;
    import std.conv : to;
    assert (numericString.isNumeric);

    size_t significantDigits = 0;
    if (numericString.to!double.isFinite)
    {
        auto digitsPart = numericString.find!(x => x.isDigit && x != '0');
        auto exponentPart = digitsPart.findAmong("eE");
        digitsPart = digitsPart[0 .. $ - exponentPart.length];

        if (digitsPart.canFind('.'))
        {
            digitsPart.stripRight('0');
            significantDigits = digitsPart.length - 1;
        }
        else
        {
            significantDigits = digitsPart.length;
        }

        if (significantDigits == 0) significantDigits = 1;
    }

    return significantDigits;
}

/* Printing floats without formatting
 *   - No change to field value string
 *   - Decimal point is aligned
 *   - Exponential notion without a decimal point - Exponent aligned on decimal point
 * Printing floats with formatting
 *   - Consistent use of exponential notion. If any numbers use it, have all numbers use it.
 *   - Default to a high precision
 */

/* Print length calculations: This programs aligns data assuming fixed width
 * characters. Input data is assumed to be utf-8. In utf-8, many characters are
 * represented with multiple bytes. Unicode also includes "combining characters",
 * characters that modify the print representation of an adjacent character. A
 * grapheme is a base character plus any adjacent combining characters. A string's
 * grapheme length can be calculated as:
 *
 *     import std.uni : byGrapheme;
 *     import std.range : walkLength;
 *     size_t graphemeLength = myUtf8String.byGrapheme.walkLength;
 *
 * The grapheme length is a good measure of the number of user percieved characters
 * printed. For europian character sets this is a good measure of print width.
 * However, this is still not correct, as many asian characters are printed as a
 * double-width by many monospace fonts. This program uses a hack to get a better
 * approximation: It checks the first code point in a grapheme is a CJK character.
 * (The first code point is normally the "grapheme-base".) If the first character is
 * CJK, a print width of two is assumed. This is hardly foolproof, and should not be
 * used if higher accuracy is needed. However, it does do well enough to properly
 * handle many common alignments, and is much better than doing nothing.
 *
 * Note: A more accurate approach would be to use wcwidth/wcswidth. This is a POSIX
 * function available on many systems. This could be used when available.
 */

size_t monospacePrintWidth(const char[] str) @safe
{
    bool isCJK(dchar c)
    {
        return c >= '\u3000' && c <= '\u9fff';
    }

    import std.uni : byGrapheme;

    size_t width = 0;
    try foreach (g; str.byGrapheme) width += isCJK(g[0]) ? 2 : 1;
    catch (Exception) width = str.length;  // Invalid utf-8 sequence. Catch avoids program failure.

    return width;
}
