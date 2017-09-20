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

Processing begins by reading the initial set of lines into memory to determine
the field widths and data types of each column. This look-ahead buffer is used
for header detection as well. Output begins after this processing is complete.

By default, the only the alignment is changed, the actual values are not
modified. Several of the formatting options do modify the values.

Features:

* Floating point numbers: Floats can be printed in fixed-width precision, using
  the same precision for all floats in a column. This makes then line up nicely.
  Precision is determined by values seen during look-ahead processing. The max
  precision defaults to 9, this can be changed when smaller or larger values are
  desired. See the '--f|format-floats' and '--p|precision' options.

* Header lines: Headers are detected automatically when possible. This can be
  overridden when automatic detection doesn't work as desired. Headers can be
  underlined and repeated at regular intervals.

* Missing values: A substitute value can be used for empty fields. This is often
  less confusing than spaces. See '--e|replace-empty' and '--E|empty-replacement'.

* Exponential notion: As part float formatting, '--f|format-floats' re-formats
  columns where exponential notation is found so all the values in the column
  are displayed using exponential notation with the same precision.

* Fonts: Fixed-width fonts are assumed. CJK characters are assumed to be double
  width. This is not always correct, but works well in most cases.

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
    size_t floatPrecision = 9;          // --p|precision num (max precision when formatting floats.)
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
                "l|lookahead",            "NUM    Lines to read to interpret data before generating output. Default: 1000", &lookahead,

                "r|repeat-header",        "NUM    Lines to print before repeating the header. Default: No repeating header", &repeatHeader,

                "u|underline-header",     "       Underline the header.", &underlineHeader,
                "f|format-floats",        "       Format floats for better readability. Default: No", &formatFloats,
                "p|precision",            "NUM    Max floating point precision. Implies --format-floats. Default: 9", &floatPrecisionOptionHandler,
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

            /* Zero look-ahead has limited utility unless the first line is known to
             * be a header. Good chance the user will get an unintended behavior.
             */
            if (lookahead == 0 && autoDetectHeader)
            {
                assert (!noHeader && !hasHeader);
                throw new Exception("Cannot auto-detect header with zero look-ahead. Specify either '--H|header' or '--x|no-header' when using '--l|lookahead 0'.");
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

/** tsvPretty - Main loop, operating on input files and passing control to a
 * TSVPrettyProccessor instance. This separates physical I/O sources and sinks
 * from the underlying processing algorithm, which operates on generic ranges.
 *
 * A lockingTextWriter is created and released on every input line. This has
 * effect flushing standard output every line, desirable in command line tools.
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

/** TsvPrettyProcessor - Maintains state of processing and exposes operations for
 * processing individual input lines.
 *
 * TsvPrettyProcessor knows that input is file-based, but doesn't deal with actual
 * files or reading lines from input. That is the job of the caller. Output is
 * written to an output range. The caller is expected to pass each line to in the
 * order received, that is an assumption built-into the its processing.
 *
 * In addition to the constructor, there are three API methods:
 *   * processFileFirstLine - Called to process the first line of each file. This
 *     enables header processing.
 *   * processLine - Called to process all lines except for the first line a file.
 *   * finish - Called at the end of all processing. This is needed in case the
 *     look-ahead cache is still being filled when input terminates.
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
                assert(_fileCount > 1);
                processLine(outputStream, line);
                break;

            case AutoDetectHeaderResult.hasHeader:
                assert(_fileCount > 1);
                break;

            case AutoDetectHeaderResult.none:
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

                        /* Edge case: First file has only a header line and look-ahead set to zero. */
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
        if (_stillCaching) cacheDataLine(outputStream, line);
        else outputDataLine(outputStream, line);
    }

    void finish(OutputRange!char outputStream)
    {
        if (_stillCaching) outputLookaheadCache(outputStream);
    }

private:
    /* outputLookaheadCache finalizes processing of the lookahead cache. This includes
     * Setting the type and width of each field, finalizing the auto-detect header
     * decision, and outputing all lines in the cache.
     */
    void outputLookaheadCache(OutputRange!char outputStream)
    {
        import std.algorithm : splitter;

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
        import std.algorithm : splitter;

        /* The candidate header is declared as the header if the look-ahead cache has at least
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
        import std.conv : to;

        assert(_lookaheadCache.data.length < _options.lookahead);

        _lookaheadCache ~= line.to!string;
        updateFieldFormatsForLine(line);
        if (_lookaheadCache.data.length == _options.lookahead) outputLookaheadCache(outputStream);
    }

    void updateFieldFormatsForLine(const char[] line)
    {
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
        size_t nextFieldStart = 0;
        foreach(ref field; _fieldVector)
        {
            nextFieldStart = field.finalizeFormatting(nextFieldStart, _options) + _options.spaceBetweenFields;
        }
    }

    void outputHeader(OutputRange!char outputStream)
    {
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
                /* Exponential notion supersedes both vanilla floats and integers. */
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
                /* Floating point supercedes integer but not exponential. */
                if (_type != FieldType.exponent) _type = FieldType.floatingPoint;
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
            size_t maxPrecision = (_maxSignificantDigits > 0) ? _maxSignificantDigits - 1 : 0;
            _precision = min(options.floatPrecision, maxPrecision);

            size_t maxValuePrintWidth = !options.formatFloats ? _maxRawPrintWidth : _precision + 7;
            _printWidth = max(1, _headerPrintWidth, maxValuePrintWidth);
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

        return _startPosition + _printWidth;
    }
}

/** formatFloatingPointValue - Returns the printed representation of a raw value
 * formatted as a fixed precision floating number. This includes zero padding or
 * truncation of trailing digits as necessary to meet the desired precision.
 *
 * If the value cannot be interpreted as a double then the raw value is returned.
 * Similarly, values in exponential notion are returned without reformatting.
 *
 * This routine is used to format values in columns identified as floating point.
 */
string formatFloatingPointValue(const char[] value, size_t precision)
{
    import std.algorithm : canFind, find;
    import std.array : join;
    import std.conv : to, ConvException;
    import std.format : format;
    import std.math : isFinite;
    import std.range : repeat;

    string printValue;

    if (value.canFind!(x => x == 'e' || x == 'E'))
    {
        /* Exponential notion. Use the raw value. */
        printValue = value.to!string;
    }
    else
    {
        try
        {
            double doubleValue = value.to!double;
            if (doubleValue.isFinite)
            {
                size_t numPrecisionDigits = value.precisionDigits;
                if (numPrecisionDigits >= precision)
                {
                    printValue = format("%.*f", precision, doubleValue);
                }
                else if (numPrecisionDigits == 0)
                {
                    printValue = format("%.*f", numPrecisionDigits, doubleValue) ~ "." ~ repeat("0", precision).join;
                }
                else
                {
                    printValue = format("%.*f", numPrecisionDigits, doubleValue) ~ repeat("0", precision - numPrecisionDigits).join;
                }
            }
            else printValue = value.to!string;  // NaN or Infinity
        }
        catch (ConvException) printValue = value.to!string;
    }
    return printValue;
}

/** formatExponentValue - Returns the printed representation of a raw value formatted
 * using exponential notation and a specific precision. If the value cannot be interpreted
 * as a double then the a copy of the original value is returned.
 *
 * This routine is used to format values in columns identified as having exponent format.
 */
string formatExponentValue(const char[] value, size_t precision)
{
    import std.algorithm : canFind, find, findSplit;
    import std.array : join;
    import std.conv : to, ConvException;
    import std.format : format;
    import std.math : isFinite;
    import std.range : repeat;

    string printValue;
    try
    {
        double doubleValue = value.to!double;
        if (doubleValue.isFinite)
        {
            size_t numSignificantDigits = value.significantDigits;
            size_t numPrecisionDigits = (numSignificantDigits == 0) ? 0 : numSignificantDigits - 1;
            if (numPrecisionDigits >= precision)
            {
                printValue = format("%.*e", precision, doubleValue);
            }
            else
            {
                string unpaddedPrintValue = format("%.*e", numPrecisionDigits, doubleValue);
                auto exponentSplit = unpaddedPrintValue.findSplit("e");   // Uses the same exponent case as format call.
                if (numPrecisionDigits == 0)
                {
                    assert(precision != 0);
                    assert(!exponentSplit[0].canFind("."));
                    printValue = exponentSplit[0] ~ "." ~ repeat("0", precision).join ~ exponentSplit[1] ~ exponentSplit[2];
                }
                else
                {
                    printValue = exponentSplit[0] ~ repeat("0", precision - numPrecisionDigits).join ~ exponentSplit[1] ~ exponentSplit[2];
                }
            }
        }
        else printValue = value.to!string;  // NaN or Infinity
    }
    catch (ConvException) printValue = value.to!string;

    return printValue;
}

/** significantDigits - Returns the number of significant digits in a numeric string.
 *
 * Significant digits are those needed to represent a number in exponential notation.
 * Examples:
 *   22.345 - 5 digits
 *   10.010 - 4 digits
 *   0.0032 - 2 digits
 */
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

/* precisionDigits - Returns the number of digits to the right of the decimal point in
 * a numeric string. This routine includes trailing zeros in the count.
 */
size_t precisionDigits(const char[] numericString)
{
    import std.algorithm : canFind, find, findAmong, findSplit, stripRight;
    import std.ascii : isDigit;
    import std.math : isFinite;
    import std.string : isNumeric;
    import std.conv : to;
    assert (numericString.isNumeric);

    size_t precisionDigits = 0;
    if (numericString.to!double.isFinite)
    {
        if (auto decimalSplit = numericString.findSplit("."))
        {
            auto exponentPart = decimalSplit[2].findAmong("eE");
            precisionDigits = decimalSplit[2].length - exponentPart.length;
        }
    }

    return precisionDigits;
}

/** monospacePrintWidth - Calculates the expected print width of a string in monospace
 *  (fixed-width) fonts.
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
