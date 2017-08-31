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
  '--f|format-floats' or '--p|float-precision NUM' options. Both print floats
  favoring a fixed  precision over exponential notation for smaller numbers.
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
    bool hasHeader = false;             // --H|header
    size_t lookahead = 1000;            // --l|lookahead
    size_t repeatHeader = 0;            // --r|repeat-header num (zero means no repeat)
    bool underlineHeader = false;       // --u|underline-header
    bool formatFloats = false;          // --f|format-floats
    size_t floatPrecision = 9;          // --p|float-precision num (max precision when formatting floats)
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
                "help-verbose",    "          Print full help.", &helpVerbose,
                std.getopt.config.caseSensitive,
                "H|header",        "          Treat the first line of each file as a header.", &hasHeader,
                std.getopt.config.caseInsensitive,

                "l|lookahead",            "NUM    Lines to read to interpret data before generating output. Default: 1000)", &lookahead,

                /* Not implemented yet.
                 * "r|repeat-header",        "NUM    Lines to print before repeating the header. Default: No repeating", &repeatHeader,
                 */

                "u|underline-header",     "       Underline the header.", &underlineHeader,
                "f|format-floats",        "       Format floats for better readability. Default: No", &formatFloats,
                "p|float-precision",      "NUM    Floating point precision. Implies --format-floats", &floatPrecisionOptionHandler,
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

    /* Option handler for --p|float-precision. It also sets --f|format-floats. */
    private void floatPrecisionOptionHandler(string option, string optionVal)
    {
        import std.conv : to;
        floatPrecision = optionVal.to!size_t;
        formatFloats = true;
    }
}

/* tsvPretty is the main control loop. */
void tsvPretty(in ref TsvPrettyOptions options, string[] files)
{
    auto tpp = TsvPrettyProcessor(options);
    bool headerProcessed = false;
    foreach (filename; (files.length > 0) ? files : ["-"])
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (lineNum, line; inputStream.byLine.enumerate(1))
        {
            if (options.hasHeader && lineNum == 1)
            {
                if (!headerProcessed)
                {
                    tpp.processHeaderLine(outputRangeObject!(char, char[])(stdout.lockingTextWriter), line);
                    headerProcessed = true;
                }
            }
            else
            {
                tpp.processDataLine(outputRangeObject!(char, char[])(stdout.lockingTextWriter), line);
            }
        }
    }
    tpp.finish(outputRangeObject!(char, char[])(stdout.lockingTextWriter));
}

/* TsvPrettyProcessor maintains the state of processing and exposes the key operations. */
struct TsvPrettyProcessor
{
    import std.array : appender;

public:
    this(const TsvPrettyOptions options)
    {
        _options = options;
        _stillCaching = options.lookahead > 0 || options.hasHeader;
    }

    void processHeaderLine(OutputRange!char outputStream, const char[] line)
    {
        import std.algorithm : splitter;

        foreach(fieldIndex, header; line.splitter(_options.delim).enumerate)
        {
            if (_fieldVector.length == fieldIndex) _fieldVector ~= FieldFormat(fieldIndex);
            assert(_fieldVector.length > fieldIndex);
            _fieldVector[fieldIndex].setHeader(header);
        }

        if (stillCaching && _options.lookahead == 0)
        {
            finalizeFieldFormatting();
            outputHeader(outputStream);
            _stillCaching = false;
        }
    }

    void processDataLine(OutputRange!char outputStream, const char[] line)
    {
        _dataLineCount++;

        if (stillCaching) cacheDataLine(outputStream, line);
        else outputDataLine(outputStream, line);
    }

    void finish(OutputRange!char outputStream)
    {
        if (stillCaching)
        {
            finalizeFieldFormatting();
            outputDataLineCache(outputStream);
            _stillCaching = false;
        }
    }

private:
    TsvPrettyOptions _options;
    auto _dataLineCache = appender!(string[])();
    FieldFormat[] _fieldVector;
    size_t _dataLineCount = 0;
    bool _stillCaching = true;

    bool stillCaching()
    {
        return _stillCaching;
    }

    void cacheDataLine(OutputRange!char outputStream, const char[] line)
    {
        import std.algorithm : splitter;
        import std.conv : to;

        assert(_dataLineCache.data.length < _options.lookahead);

        _dataLineCache ~= line.to!string;

        foreach(fieldIndex, fieldValue; line.splitter(_options.delim).enumerate)
        {
            if (_fieldVector.length == fieldIndex) _fieldVector ~= FieldFormat(fieldIndex);
            assert(_fieldVector.length > fieldIndex);
            _fieldVector[fieldIndex].updateForFieldValue(fieldValue, _options);
        }

        if (_dataLineCache.data.length == _options.lookahead)
        {
            _stillCaching = false;
            finalizeFieldFormatting();
            outputDataLineCache(outputStream);
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
        if (_options.hasHeader)
        {
            foreach(ref field; _fieldVector) field.writeHeader(outputStream, _options);
            put(outputStream, '\n');

            if (_options.underlineHeader)
            {
                foreach(ref field; _fieldVector) field.writeHeader!(Yes.writeUnderline)(outputStream, _options);
                put(outputStream, '\n');
            }
        }
    }

    void outputDataLineCache(OutputRange!char outputStream)
    {
        import std.algorithm : splitter;

        outputHeader(outputStream);

        foreach(line; _dataLineCache.data)
        {
            size_t nextOutputPosition = 0;
            foreach(fieldIndex, fieldValue; line.splitter(_options.delim).enumerate)
            {
                assert(fieldIndex < _fieldVector.length);  // Ensured by cacheDataLine

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

        _dataLineCache.clear;
    }

    void outputDataLine(OutputRange!char outputStream, const char[] line)
    {
        import std.algorithm : splitter;

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

enum FieldType { unknown, text, integer, floatingPoint };
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
    size_t _floatPrecision = 0;

    /* These are used while doing initial type and print format detection. */
    size_t _minRawPrintWidth = 0;
    size_t _maxRawPrintWidth = 0;
    size_t _maxDigitsBeforeDecimal = 0;
    size_t _maxDigitsAfterDecimal = 0;

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

    /* writeHeader writes the field header or underline characters to the output stream.
     * Any previous fields on line should have been written without trailing spaces.
     * Unlike data values, headers should always be written on the correct offsets.
     */
    void writeHeader(Flag!"writeUnderline" writeUnderline = No.writeUnderline)
        (OutputRange!char outputStream, in ref TsvPrettyOptions options)
    in
    {
        assert(_header.length > 0);   // writeHeader should only be called if there is a header.
    }
    body
    {
        import std.range : repeat;

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

private:
    /* Formatting floats - A simple approach is taken. Floats with a readable number of trailing
     * digits are printed as fixed point (%f). Floats with a longer number of digits are printed
     * as variable length, including use of exponential notion (%g). Calculating the length
     * requires knowing which was used.
     */
    enum defaultReadablePrecisionMax = 6;

    bool formattedFloatsAreFixedPoint(size_t readablePrecisionMax = defaultReadablePrecisionMax)
    {
        return _floatPrecision <= readablePrecisionMax;
    }

    auto formatFloatingPoint(double value)
    {
        import std.format : format;

        return formattedFloatsAreFixedPoint() ?
            format("%.*f", _floatPrecision, value) :
            format("%.*g", _floatPrecision, value);
    }

public:
    size_t writeFieldValue(OutputRange!char outputStream, size_t currPosition,
                           const char[] fieldValue, in ref TsvPrettyOptions options)
    in
    {
        assert(currPosition >= _startPosition);   // Caller resposible for advancing to field start position.
        assert(_type == FieldType.text || _type == FieldType.integer || _type == FieldType.floatingPoint);
    }
    body
    {
        import std.algorithm : find, max, min;
        import std.conv : to, ConvException;

        /* Create the print version of the string. Either the raw value or a formatted
         * version of a float. Need to track whether it's an unformatted float, these
         * have to be manually aligned on the decimal point.
         */
        string printValue;
        bool printValueIsFixedPointFloat = false;
        if (_type == FieldType.floatingPoint)
        {
            if (options.formatFloats)
            {
                try
                {
                    printValue = formatFloatingPoint(fieldValue.to!double);
                    printValueIsFixedPointFloat = formattedFloatsAreFixedPoint();
                }
                catch (ConvException) printValue = fieldValue.to!string;
            }
            else
            {
                printValue = fieldValue.to!string;
            }
        }
        else
        {
            printValue = fieldValue.to!string;
        }

        if (printValue.length == 0 && options.replaceEmpty) printValue = options.emptyReplacement;

        /* Calculate the number of spaces to be included with the value. Basically, the
         * expected field width minus the value's print width. The expected field width
         * needs to be adjusted if the prior field on the line ran long.
         */
        size_t printValuePrintWidth = printValue.monospacePrintWidth;
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

        size_t numSpacesNeeded = (printValuePrintWidth < targetWidth) ?
            targetWidth - printValuePrintWidth : 0;

        /* Split the needed spaces into leading and trailing spaces. If the field is
         * left-aligned all spaces are trailing. If right aligned, then spaces are leading,
         * unless the field is a float with a variable number of trailing digits. In the
         * latter case, trailing spaces are used to align the decimal point, the rest are
         * leading.
         */
        size_t leadingSpaces = 0;
        size_t trailingSpaces = 0;

        if (numSpacesNeeded > 0)
        {
            if (_alignment == FieldAlignment.left)
            {
                trailingSpaces = numSpacesNeeded;
            }
            else
            {
                assert(_alignment == FieldAlignment.right);

                if (_type == FieldType.floatingPoint && !printValueIsFixedPointFloat && _floatPrecision > 0)
                {
                    size_t decimalAndDigitsLength = printValue.find(".").length;
                    if (decimalAndDigitsLength <= _floatPrecision + 1)
                    {
                        trailingSpaces =
                            min(numSpacesNeeded, (_floatPrecision + 1) - decimalAndDigitsLength);
                    }
                }

                leadingSpaces = numSpacesNeeded - trailingSpaces;
            }
        }

        put(outputStream, repeat(' ', leadingSpaces));
        put(outputStream, printValue);
        put(outputStream, repeat(' ', trailingSpaces));

        return printValuePrintWidth + numSpacesNeeded;
    }

    /* updateForFieldValue updates type and format given a new field value.
     */
    void updateForFieldValue(size_t readablePrecisionMax = defaultReadablePrecisionMax)
        (const char[] fieldValue, in ref TsvPrettyOptions options)
    {
        import std.algorithm : findSplit, max, min;
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
                        parsesAs = FieldType.floatingPoint;
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
            else if (parsesAs == FieldType.floatingPoint)
            {
                /* Even if currently integer it becomes a float. */
                _type = FieldType.floatingPoint;

                /* Use tsv_numerics.formatNumber to get length for formatted printing. It drops
                 * trailing zeros and decimal point, helping record the max precision needed.
                 */
                string printString = options.formatFloats ?
                    doubleValue.formatNumber!(double, readablePrecisionMax)(options.floatPrecision) :
                    fieldValue.to!string;

                auto split = printString.findSplit(".");
                _maxDigitsBeforeDecimal = max(_maxDigitsBeforeDecimal, split[0].length);
                _maxDigitsAfterDecimal = max(_maxDigitsAfterDecimal, split[2].length);
            }
            else
            {
                assert(parsesAs == FieldType.integer);
                if (_type != FieldType.floatingPoint) _type = FieldType.integer;
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
        _alignment = (_type == FieldType.integer || _type == FieldType.floatingPoint) ?
            FieldAlignment.right :
            FieldAlignment.left;

        if (_type == FieldType.floatingPoint)
        {
            size_t precision = min(options.floatPrecision, _maxDigitsAfterDecimal);
            size_t maxValueWidth = _maxDigitsBeforeDecimal + precision;
            if (precision > 0) maxValueWidth++;  // Account for the decimal point.
            _printWidth = max(1, _headerPrintWidth, maxValueWidth);
            _floatPrecision = precision;
        }
        else if (_type == FieldType.integer)
        {
            _printWidth = max(1, _headerPrintWidth, _minRawPrintWidth, _maxRawPrintWidth);
            _floatPrecision = 0;
        }
        else
        {
            _printWidth = max(1, _headerPrintWidth, _minRawPrintWidth,
                              min(options.maxFieldPrintWidth, _maxRawPrintWidth));
            _floatPrecision = 0;
        }

       debug  writefln("[finalizeFormatting] %s", this);

        return _startPosition + _printWidth;
    }
}

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
 */

size_t monospacePrintWidth(const char[] str) @safe
{
    bool isCJK(dchar c)
    {
        return c >= '\u3000' && c <= '\u9fff';
    }

    import std.uni : byGrapheme;

    size_t width = 0;
    foreach (g; str.byGrapheme) width += isCJK(g[0]) ? 2 : 1;
    return width;
}
