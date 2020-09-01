/**
Convert CSV formatted data to TSV format.

This program converts comma-separated value data to tab-separated format.

Copyright (c) 2016-2020, eBay Inc.
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)
*/

module tsv_utils.csv2tsv;

import std.stdio;
import std.exception : enforce;
import std.format : format;
import std.range;
import std.traits : isArray, Unqual;
import std.typecons : Nullable, tuple;

immutable helpText = q"EOS
Synopsis: csv2tsv [options] [file...]

csv2tsv converts comma-separated text (CSV) to tab-separated format (TSV). Records
are read from files or standard input, converted records written to standard output.
Use '--help-verbose' for details the CSV formats accepted.

Options:
EOS";

immutable helpTextVerbose = q"EOS
Synopsis: csv2tsv [options] [file...]

csv2tsv converts CSV (comma-separated) text to TSV (tab-separated) format. Records
are read from files or standard input, converted records written to standard output.

Both formats represent tabular data, each record on its own line, fields separated
by a delimiter character. The key difference is that CSV uses escape sequences to
represent newlines and field separators in the data, whereas TSV disallows these
characters in the data. The most common field delimiters are comma for CSV and tab
for TSV, but any character can be used.

Conversion to TSV is done by removing CSV escape syntax, changing field delimiters,
and replacing newlines and field delimiters in the data. By default, newlines and
field delimiters in the data are replaced by spaces. Most details are customizable.

There is no single spec for CSV, any number of variants can be found. The escape
syntax is common enough: fields containing newlines or field delimiters are placed
in double quotes. Inside a quoted field, a double quote is represented by a pair of
double quotes. As with field separators, the quoting character is customizable.

Behaviors of this program that often vary between CSV implementations:
  * Newlines are supported in quoted fields.
  * Double quotes are permitted in a non-quoted field. However, a field starting
    with a quote must follow quoting rules.
  * Each record can have a different numbers of fields.
  * The three common forms of newlines are supported: CR, CRLF, LF.
  * A newline will be added if the file does not end with one.
  * No whitespace trimming is done.

This program does not validate CSV correctness, but will terminate with an error
upon reaching an inconsistent state. Improperly terminated quoted fields are the
primary cause.

UTF-8 input is assumed. Convert other encodings prior to invoking this tool.

Options:
EOS";

/** Container for command line options.
 */
struct Csv2tsvOptions
{
    string programName;
    bool helpVerbose = false;          // --help-verbose
    bool hasHeader = false;            // --H|header
    char csvQuoteChar = '"';           // --q|quote
    char csvDelimChar = ',';           // --c|csv-delim
    char tsvDelimChar = '\t';          // --t|tsv-delim
    string tsvDelimReplacement = " ";  // --r|replacement
    bool versionWanted = false;        // --V|version

    auto processArgs (ref string[] cmdArgs)
    {
        import std.algorithm : canFind;
        import std.getopt;
        import std.path : baseName, stripExtension;

        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

        try
        {
            auto r = getopt(
                cmdArgs,
                "help-verbose",  "     Print full help.", &helpVerbose,
                std.getopt.config.caseSensitive,
                "H|header",      "     Treat the first line of each file as a header. Only the header of the first file is output.", &hasHeader,
                std.getopt.config.caseSensitive,
                "q|quote",       "CHR  Quoting character in CSV data. Default: double-quote (\")", &csvQuoteChar,
                "c|csv-delim",   "CHR  Field delimiter in CSV data. Default: comma (,).", &csvDelimChar,
                "t|tsv-delim",   "CHR  Field delimiter in TSV data. Default: TAB", &tsvDelimChar,
                "r|replacement", "STR  Replacement for newline and TSV field delimiters found in CSV input. Default: Space.", &tsvDelimReplacement,
                std.getopt.config.caseSensitive,
                "V|version",     "     Print version information and exit.", &versionWanted,
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
                writeln(tsvutilsVersionNotice("csv2tsv"));
                return tuple(false, 0);
            }

            /* Consistency checks. */
            enforce(csvQuoteChar != '\n' && csvQuoteChar != '\r',
                    "CSV quote character cannot be newline (--q|quote).");

            enforce(csvQuoteChar != csvDelimChar,
                    "CSV quote and CSV field delimiter characters must be different (--q|quote, --c|csv-delim).");

            enforce(csvQuoteChar != tsvDelimChar,
                    "CSV quote and TSV field delimiter characters must be different (--q|quote, --t|tsv-delim).");

            enforce(csvDelimChar != '\n' && csvDelimChar != '\r',
                    "CSV field delimiter cannot be newline (--c|csv-delim).");

            enforce(tsvDelimChar != '\n' && tsvDelimChar != '\r',
                    "TSV field delimiter cannot be newline (--t|tsv-delim).");

            enforce(!canFind!(c => (c == '\n' || c == '\r' || c == tsvDelimChar))(tsvDelimReplacement),
                    "Replacement character cannot contain newlines or TSV field delimiters (--r|replacement).");
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

version(unittest)
{
    // No main in unittest
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

        Csv2tsvOptions cmdopt;
        const r = cmdopt.processArgs(cmdArgs);
        if (!r[0]) return r[1];
        version(LDC_Profile)
        {
            import ldc.profile : resetAll;
            resetAll();
        }
        try csv2tsvFiles(cmdopt, cmdArgs[1..$]);
        catch (Exception exc)
        {
            writeln();
            stdin.flush();
            stderr.writefln("Error [%s]: %s", cmdopt.programName, exc.msg);
            return 1;
        }

        return 0;
    }
}

void csv2tsvFiles(const ref Csv2tsvOptions cmdopt, const string[] inputFiles)
{
    import tsv_utils.common.utils : BufferedOutputRange;

    ubyte[1024 * 128] fileRawBuf;
    //ubyte[] stdinRawBuf = fileRawBuf[0..1024];
    auto stdoutWriter = BufferedOutputRange!(typeof(stdout))(stdout);
    bool firstFile = true;

    foreach (filename; (inputFiles.length > 0) ? inputFiles : ["-"])
    {
        auto inputStream = (filename == "-") ? stdin : filename.File;
        auto printFileName = (filename == "-") ? "stdin" : filename;

        auto skipLines = (firstFile || !cmdopt.hasHeader) ? 0 : 1;

        csv2tsv(inputStream, stdoutWriter, fileRawBuf, printFileName, skipLines,
                cmdopt.csvQuoteChar, cmdopt.csvDelimChar,
                cmdopt.tsvDelimChar, cmdopt.tsvDelimReplacement,
                cmdopt.tsvDelimReplacement);

        firstFile = false;
    }
}

/* General buffered conversion strategy

The basic idea is to convert a buffer at a time, writing larger blocks to the output
stream rather than one character at a time. Along with this, the buffer will be
modified in-place when the only change is to convert a single character. This should
optimize the common case of converting a CSV file with no escape CSV escapes. In all
cases it should allow writing longer blocks at a time.

Handling CSV escapes will often cause the character removals and additions. These
will not be representable in a continuous stream of bytes without moving bytes
around. Instead of moving bytes, these cases are handled by immediate writing to the
output stream. This allows restarting a new block of contiguous characters.

Character growth and shrink for all replacement character lengths:
* Windows newline (CRLF) at the end of a line - Replace the CRLF with LF.
  Replace the CR with LF, add it to the current write region and terminate it. The
  next write region starts at the character after the LF.

* Double quote starting or ending a field - Drop the double quote.
  Terminate the current write region, next write region starts at the next character.

* Double quote pair inside a quoted field - Drop one of the double quotes.
  Best algo is likely to drop the first double quote and keep the second. This avoids
  lookahead and both field terminating double quote and double quote pair can handled
  the same way. Terminate the current write region without adding the double quote.
  The next write region starts at the next character.

Cases of character growth and shrink with single byte replacement characters:
* Windows newline (CRLF) in a quoted field - Replace the CR with the replacement char,
  add it to the current write region and terminate it. The next write region starts at
  the character after the LF.

Cases of character growth with multi-byte replacement sequences:
* TSV Delimiter (TAB by default) in a field - Terminate the current write region,
  writes it and the replacement. The next write region starts at the next character.
* LF, CR, or CRLF in a quoted field - Terminate the current write region, write it and
  the replacement. The next write region starts at the next character.

At the API level, it is desirable to handle at both open files and input streams.
Open files are the key requirement, but handling input streams simplifies unit
testing, and in-memory conversion is likely to be useful anyway. Internally, it
should be easy enough to encapsulate the differences between input streams and files.
Reading files can be done using File.byChunk and reading from input streams can be
done using std.range.chunks.
*/

/** Defines the 'bufferable' input sources supported by inputSourceByChunk.
 *
 * This includes std.stdio.File objects and mutable dynamic ubyte arrays (inputRange
 * with slicing).
 *
 * Note: The mutable, dynamic arrays restriction is based on what is supported by
 * std.range.chunks. This could be extended to include any type of array with ubyte
 * elements, but it would require custom code in inputSourceByChunk. A test could be
 * added as '(isArray!(R) && is(Unqual!(typeof(R.init[0])) == ubyte))'.
 */
enum bool isBufferableInputSource(R) =
    isFileHandle!(Unqual!R) ||
    (isInputRange!R && is(ElementEncodingType!R == ubyte) && hasSlicing!R);

@safe unittest
{
    static assert(isBufferableInputSource!(File));
    static assert(isBufferableInputSource!(typeof(stdin)));
    static assert(isBufferableInputSource!(ubyte[]));
    static assert(!isBufferableInputSource!(char[]));
    static assert(!isBufferableInputSource!(string));

    ubyte[10] x1;
    const ubyte[1] x2;
    immutable ubyte[1] x3;
    ubyte[] x4 = new ubyte[](10);
    const ubyte[] x5 = new ubyte[](10);
    immutable ubyte[] x6 = new ubyte[](10);

    static assert(!isBufferableInputSource!(typeof(x1)));
    static assert(!isBufferableInputSource!(typeof(x2)));
    static assert(!isBufferableInputSource!(typeof(x3)));
    static assert(isBufferableInputSource!(typeof(x4)));
    static assert(!isBufferableInputSource!(typeof(x5)));
    static assert(!isBufferableInputSource!(typeof(x6)));

    static assert(is(Unqual!(ElementType!(typeof(x1))) == ubyte));
    static assert(is(Unqual!(ElementType!(typeof(x2))) == ubyte));
    static assert(is(Unqual!(ElementType!(typeof(x3))) == ubyte));
    static assert(is(Unqual!(ElementType!(typeof(x4))) == ubyte));
    static assert(is(Unqual!(ElementType!(typeof(x5))) == ubyte));
    static assert(is(Unqual!(ElementType!(typeof(x6))) == ubyte));


    struct S1
    {
        void popFront();
        @property bool empty();
        @property ubyte front();
    }

    struct S2
    {
        @property ubyte front();
        void popFront();
        @property bool empty();
        @property auto save() { return this; }
        @property size_t length();
        S2 opSlice(size_t, size_t);
    }

    static assert(isInputRange!S1);
    static assert(!isBufferableInputSource!S1);

    static assert(isInputRange!S2);
    static assert(is(ElementEncodingType!S2 == ubyte));
    static assert(hasSlicing!S2);
    static assert(isBufferableInputSource!S2);
}

/** inputSourceByChunk returns a range that reads either a file handle (File) or a
 * ubyte[] array a chunk at a time.
 *
 * This is a cover for File.byChunk that allows passing an in-memory array as well.
 * At present the motivation is primarily to enable unit testing of chunk-based
 * algorithms using in-memory strings.
 *
 * inputSourceByChunk takes either a File open for reading or a ubyte[] array
 * containing input data. It reads a chunk at a time, either into a user provided
 * buffer or a buffer allocated based on a size provided.
 *
 * The chunks are returned as an input range.
 */

auto inputSourceByChunk(InputSource)(InputSource source, size_t size)
{
    return inputSourceByChunk(source, new ubyte[](size));
}

/// Ditto
auto inputSourceByChunk(InputSource)(InputSource source, ubyte[] buffer)
if (isBufferableInputSource!InputSource)
{
    static if (isFileHandle!(Unqual!InputSource))
    {
        return source.byChunk(buffer);
    }
    else
    {
        static struct BufferedChunk
        {
            private Chunks!InputSource _chunks;
            private ubyte[] _buffer;

            private void readNextChunk()
            {
                if (_chunks.empty)
                {
                    _buffer.length = 0;
                }
                else
                {
                    size_t len = _chunks.front.length;
                    _buffer[0 .. len] = _chunks.front[];
                    _chunks.popFront;

                    // Only the last chunk should be shorter than the buffer.
                    assert(_buffer.length == len || _chunks.empty);

                    if (_buffer.length != len) _buffer.length = len;
                }
            }

            this(InputSource source, ubyte[] buffer)
            {
                enforce(buffer.length > 0, "buffer size must be larger than 0");
                _chunks = source.chunks(buffer.length);
                _buffer = buffer;
                readNextChunk();
            }

            @property bool empty()
            {
                return (_buffer.length == 0);
            }

            @property ubyte[] front()
            {
                assert(!empty, "Attempting to fetch the front of an empty inputSourceByChunks");
                return _buffer;
            }

            void popFront()
            {
                assert(!empty, "Attempting to popFront an empty inputSourceByChunks");
                readNextChunk();
            }
        }

        return BufferedChunk(source, buffer);
    }
}

unittest  // inputSourceByChunk
{
    import tsv_utils.common.unittest_utils;   // tsv-utils unit test helpers
    import std.file : mkdir, rmdirRecurse;
    import std.path : buildPath;

    auto testDir = makeUnittestTempDir("csv2tsv_inputSourceByChunk");
    scope(exit) testDir.rmdirRecurse;

    import std.algorithm : equal, joiner;
    import std.format;
    import std.string : representation;

    auto charData = "abcde,ßÀß,あめりか物語,012345";
    ubyte[] ubyteData = charData.dup.representation;

    ubyte[1024] rawBuffer;  // Must be larger than largest bufferSize in tests.

    void writeFileData(string filePath, ubyte[] data)
    {
        import std.stdio;

        auto f = filePath.File("w");
        f.rawWrite(data);
        f.close;
    }

    foreach (size_t dataSize; 0 .. ubyteData.length)
    {
        auto data = ubyteData[0 .. dataSize];
        auto filePath = buildPath(testDir, format("data_%d.txt", dataSize));
        writeFileData(filePath, data);

        foreach (size_t bufferSize; 1 .. dataSize + 2)
        {
            assert(data.inputSourceByChunk(bufferSize).joiner.equal(data),
                   format("[Test-A] dataSize: %d, bufferSize: %d", dataSize, bufferSize));

            assert (rawBuffer.length >= bufferSize);

            ubyte[] buffer = rawBuffer[0 .. bufferSize];
            assert(data.inputSourceByChunk(buffer).joiner.equal(data),
                   format("[Test-B] dataSize: %d, bufferSize: %d", dataSize, bufferSize));

            {
                auto inputStream = filePath.File;
                assert(inputStream.inputSourceByChunk(bufferSize).joiner.equal(data),
                       format("[Test-C] dataSize: %d, bufferSize: %d", dataSize, bufferSize));
                inputStream.close;
            }

            {
                auto inputStream = filePath.File;
                assert(inputStream.inputSourceByChunk(buffer).joiner.equal(data),
                       format("[Test-D] dataSize: %d, bufferSize: %d", dataSize, bufferSize));
                inputStream.close;
            }
        }
    }
}

/** Read CSV from an input source, covert to TSV and write to an output source.
 *
 * Params:
 *   inputSource           =  A "bufferable" input source, either a file open for read, or a
 *                            dynamic ubyte array.
 *   outputStream          =  An output range to write TSV text to.
 *   readBuffer            =  A buffer to use for reading.
 *   filename              =  Name of file to use when reporting errors. A descriptive
 *                            name can be used in lieu of a file name.
 *   skipLines             =  Number of lines to skip before outputting records. Used
 *                            for header line processing.
 *   csvQuote              =  The quoting character used in the input CSV file.
 *   csvDelim              =  The field delimiter character used in the input CSV file.
 *   tsvDelim              =  The field delimiter character to use in the generated TSV file.
 *   tsvDelimReplacement   =  A string to use when replacing newlines and TSV field delimiters
 *                            occurring in CSV fields.
 *   tsvNewlineReplacement =  A string to use when replacing newlines and TSV field delimiters
 *                            occurring in CSV fields.
 *
 * Throws: Exception on finding inconsistent CSV. Exception text includes the filename and
 *         line number where the error was identified.
 */
void csv2tsv(InputSource, OutputRange)(
    InputSource inputSource,
    auto ref OutputRange outputStream,
    ubyte[] readBuffer,
    string filename = "(none)",
    size_t skipLines = 0,
    const char csvQuote = '"',
    const char csvDelim = ',',
    const char tsvDelim = '\t',
    const string tsvDelimReplacement = " ",
    const string tsvNewlineReplacement = " ",
)
if (isBufferableInputSource!InputSource &&
    isOutputRange!(OutputRange, char))
{
    assert (readBuffer.length >= 1);

    enum char LF = '\n';
    enum char CR = '\r';

    /* State Information:
     *
     * Global processing state:
     *   * recordNum - The current CSV input line/record number. Starts at one.
     *   * fieldNum - Field number in current line/record. Field numbers are one upped.
     *     This is set to zero at the start of a new record, prior to processing the
     *     first character of the first field on the record.
     *   * byteIndex - Read buffer index of the current byte being processed.
     *   * writeRegionStart - Read buffer index where the next write starts from.
     *   * currState - The current state of CSV processing.
     */

    enum State
    {
     FieldEnd,           // Start of input or after consuming a field or record delimiter.
     NonQuotedField,     // Processing a non-quoted field
     QuotedField,        // Processing a quoted field
     QuoteInQuotedField, // Last char was a quote in a quoted field
     CRAtFieldEnd,       // Last char was a CR terminating a record/line
     CRInQuotedField,    // Last char was a CR in a quoted field
    }

    State currState = State.FieldEnd;
    size_t recordNum = 1;
    size_t fieldNum = 0;

    foreach (inputChunk; inputSource.inputSourceByChunk(readBuffer))
    {
        size_t writeRegionStart = 0;

        void flushCurrentRegion(size_t regionEnd, size_t skipChars, const char[] extraChars = "")
        {
            assert(regionEnd <= inputChunk.length);

            if (recordNum > skipLines)
            {
                if (regionEnd > writeRegionStart)
                {
                    outputStream.put(inputChunk[writeRegionStart .. regionEnd]);
                }
                if (extraChars.length > 0)
                {
                    outputStream.put(extraChars);
                }
            }

            writeRegionStart = regionEnd + skipChars;
        }

        foreach (size_t nextIndex, char nextChar; inputChunk)
        {
        OuterSwitch: final switch (currState)
            {
            case State.FieldEnd:
                /* Start of input or after consuming a field terminator. */
                ++fieldNum;

                /* Note: Can't use switch due to the 'goto case' to the OuterSwitch.  */
                if (nextChar == csvQuote)
                {
                    flushCurrentRegion(nextIndex, 1);
                    currState = State.QuotedField;
                    break OuterSwitch;
                }
                else
                {
                    /* Processing state change only. Don't consume the character. */
                    currState = State.NonQuotedField;
                    goto case State.NonQuotedField;
                }

            case State.NonQuotedField:
                switch (nextChar)
                {
                default:
                    break OuterSwitch;
                case csvDelim:
                    inputChunk[nextIndex] = tsvDelim;
                    currState = State.FieldEnd;
                    break OuterSwitch;
                case LF:
                    if (recordNum == skipLines) flushCurrentRegion(nextIndex, 1);
                    ++recordNum;
                    fieldNum = 0;
                    currState = State.FieldEnd;
                    break OuterSwitch;
                case CR:
                    inputChunk[nextIndex] = LF;
                    if (recordNum == skipLines) flushCurrentRegion(nextIndex, 1);
                    ++recordNum;
                    fieldNum = 0;
                    currState = State.CRAtFieldEnd;
                    break OuterSwitch;
                case tsvDelim:
                    if (tsvDelimReplacement.length == 1)
                    {
                        inputChunk[nextIndex] = tsvDelimReplacement[0];
                    }
                    else
                    {
                        flushCurrentRegion(nextIndex, 1, tsvDelimReplacement);
                    }
                    break OuterSwitch;
                }

            case State.QuotedField:
                switch (nextChar)
                {
                default:
                    break OuterSwitch;
                case csvQuote:
                    /* The old algo. */
                    version(none)
                    {
                        /* Quote in a quoted field. Need to look at the next character.*/
                        if (!inputStream.empty)
                        {
                            currState = State.QuoteInQuotedField;
                        }
                        else
                        {
                            /* End of input. A rare case: Quoted field on last line with no
                             * following trailing newline. Reset the state to avoid triggering
                             * an invalid quoted field exception, plus adding additional newline.
                             */
                            currState = State.FieldEnd;
                        }
                        break OuterSwitch;
                    }

                    /* The new algo
                     *
                     * Flush the current region, without the double quote.
                     * Switch the state to QuoteInQuotedField, which determines whether to output a quote.
                     */
                    flushCurrentRegion(nextIndex, 1);
                    currState = State.QuoteInQuotedField;
                    break OuterSwitch;

                case tsvDelim:
                    if (tsvDelimReplacement.length == 1)
                    {
                        inputChunk[nextIndex] = tsvDelimReplacement[0];
                    }
                    else
                    {
                        flushCurrentRegion(nextIndex, 1, tsvDelimReplacement);
                    }
                    break OuterSwitch;
                case LF:
                    /* Newline in a quoted field. */
                    if (tsvNewlineReplacement.length == 1)
                    {
                        inputChunk[nextIndex] = tsvNewlineReplacement[0];
                        if (recordNum == skipLines) flushCurrentRegion(nextIndex, 1);
                    }
                    else
                    {
                        flushCurrentRegion(nextIndex, 1, tsvNewlineReplacement);
                    }
                    break OuterSwitch;
                case CR:
                    /* Carriage Return in a quoted field. */
                    if (tsvNewlineReplacement.length == 1)
                    {
                        inputChunk[nextIndex] = tsvNewlineReplacement[0];
                        if (recordNum == skipLines) flushCurrentRegion(nextIndex, 1);
                    }
                    else
                    {
                        flushCurrentRegion(nextIndex, 1, tsvNewlineReplacement);
                    }
                    currState = State.CRInQuotedField;
                    break OuterSwitch;
                }

            case State.QuoteInQuotedField:
                /* Just processed a quote in a quoted field. The buffer, without the
                 * quote, was just flushed. Only legal characters here are quote,
                 * comma (field delimiter), newline (record delimiter).
                 */
                switch (nextChar)
                {
                case csvQuote:
                    currState = State.QuotedField;
                    break OuterSwitch;
                case csvDelim:
                    inputChunk[nextIndex] = tsvDelim;
                    currState = State.FieldEnd;
                    break OuterSwitch;
                case LF:
                    if (recordNum == skipLines) flushCurrentRegion(nextIndex, 1);
                    ++recordNum;
                    fieldNum = 0;
                    currState = State.FieldEnd;
                    break OuterSwitch;
                case CR:
                    inputChunk[nextIndex] = LF;
                    if (recordNum == skipLines) flushCurrentRegion(nextIndex, 1);
                    ++recordNum;
                    fieldNum = 0;
                    currState = State.CRAtFieldEnd;
                    break OuterSwitch;
                default:
                    throw new Exception(
                        format("Invalid CSV. Improperly terminated quoted field. File: %s, Line: %d",
                               (filename == "-") ? "Standard Input" : filename,
                               recordNum));
                }

            case State.CRInQuotedField:
                if (nextChar == LF)
                {
                    flushCurrentRegion(nextIndex, 1);
                    currState = State.QuotedField;
                    break OuterSwitch;
                }
                else {
                    /* Naked CR. State change only, don't consume current character. */
                    currState = State.QuotedField;
                    goto case State.QuotedField;
                }

            case State.CRAtFieldEnd:
                if (nextChar == LF)
                {
                    flushCurrentRegion(nextIndex, 1);
                    currState = State.FieldEnd;
                    break OuterSwitch;
                }
                else {
                    /* Naked CR. State change only, don't consume current character. */
                    currState = State.FieldEnd;
                    goto case State.FieldEnd;
                }
            }
        }

        /* End of buffer. */
        if (writeRegionStart < inputChunk.length && recordNum > skipLines)
        {
            outputStream.put(inputChunk[writeRegionStart .. $]);
        }

        writeRegionStart = 0;
    }

    enforce(currState != State.QuotedField,
            format("Invalid CSV. Improperly terminated quoted field. File: %s, Line: %d",
                   (filename == "-") ? "Standard Input" : filename,
                   recordNum));

    if (fieldNum > 0) put(outputStream, '\n');    // Last line w/o terminating newline.
}

unittest
{
    /* Unit tests for the csv2tsv function.
     *
     * These unit tests exercise different CSV combinations and escaping cases. The CSV
     * data content is the same for each corresponding test string, except the delimiters
     * have been changed. e.g csv6a and csv6b have the same data content.
     *
     * A property used in these tests is that changing the CSV delimiters doesn't change
     * the resulting TSV. However, changing the TSV delimiters will change the TSV result,
     * as TSV doesn't support having it's delimiters in the data. This allows having a
     * single TSV expected set that is generated by CSVs with different delimter sets.
     *
     * This test set does not test main, file handling, or error messages. These are
     * handled by tests run against the executable.
     */

    /* Default CSV. */
    auto csv1a = "a,b,c";
    auto csv2a = "a,bc,,,def";
    auto csv3a = ",a, b , cd ,";
    auto csv4a = "ß,ßÀß,あめりか物語,书名: 五色石";
    auto csv5a = "\"\n\",\"\n\n\",\"\n\n\n\"";
    auto csv6a = "\"\t\",\"\t\t\",\"\t\t\t\"";
    auto csv7a = "\",\",\",,\",\",,,\"";
    auto csv8a = "\"\",\"\"\"\",\"\"\"\"\"\"";
    auto csv9a = "\"ab, de\tfg\"\"\nhij\"";
    auto csv10a = "";
    auto csv11a = ",";
    auto csv12a = ",,";
    auto csv13a = "\"\r\",\"\r\r\",\"\r\r\r\"";
    auto csv14a = "\"\r\n\",\"\r\n\r\n\",\"\r\n\r\n\r\n\"";
    auto csv15a = "\"ab, de\tfg\"\"\rhij\"";
    auto csv16a = "\"ab, de\tfg\"\"\r\nhij\"";
    auto csv17a = "ab\",ab\"cd";
    auto csv18a = "\n\n\n";
    auto csv19a = "\t";
    auto csv20a = "\t\t";
    auto csv21a = "a\n";
    auto csv22a = "a,\n";
    auto csv23a = "a,b\n";
    auto csv24a = ",\n";
    auto csv25a = "#";
    auto csv26a = "^";
    auto csv27a = "#^#";
    auto csv28a = "^#^";
    auto csv29a = "$";
    auto csv30a = "$,$\n\"$\",\"$$\",$$\n^#$,$#^,#$^,^$#\n";
    auto csv31a = "1-1\n2-1,2-2\n3-1,3-2,3-3\n\n,5-2\n,,6-3\n";
    auto csv32a = ",1-2,\"1-3\"\n\"2-1\",\"2-2\",\n\"3-1\",,\"3-3\"";

    /* Set B has the same data and TSV results as set A, but uses # for quote and ^ for comma. */
    auto csv1b = "a^b^c";
    auto csv2b = "a^bc^^^def";
    auto csv3b = "^a^ b ^ cd ^";
    auto csv4b = "ß^ßÀß^あめりか物語^书名: 五色石";
    auto csv5b = "#\n#^#\n\n#^#\n\n\n#";
    auto csv6b = "#\t#^#\t\t#^#\t\t\t#";
    auto csv7b = "#,#^#,,#^#,,,#";
    auto csv8b = "##^#\"#^#\"\"#";
    auto csv9b = "#ab, de\tfg\"\nhij#";
    auto csv10b = "";
    auto csv11b = "^";
    auto csv12b = "^^";
    auto csv13b = "#\r#^#\r\r#^#\r\r\r#";
    auto csv14b = "#\r\n#^#\r\n\r\n#^#\r\n\r\n\r\n#";
    auto csv15b = "#ab, de\tfg\"\rhij#";
    auto csv16b = "#ab, de\tfg\"\r\nhij#";
    auto csv17b = "ab\"^ab\"cd";
    auto csv18b = "\n\n\n";
    auto csv19b = "\t";
    auto csv20b = "\t\t";
    auto csv21b = "a\n";
    auto csv22b = "a^\n";
    auto csv23b = "a^b\n";
    auto csv24b = "^\n";
    auto csv25b = "####";
    auto csv26b = "#^#";
    auto csv27b = "###^###";
    auto csv28b = "#^##^#";
    auto csv29b = "$";
    auto csv30b = "$^$\n#$#^#$$#^$$\n#^##$#^#$##^#^###$^#^#^$###\n";
    auto csv31b = "1-1\n2-1^2-2\n3-1^3-2^3-3\n\n^5-2\n^^6-3\n";
    auto csv32b = "^1-2^#1-3#\n#2-1#^#2-2#^\n#3-1#^^#3-3#";

    /* The expected results for csv sets A and B. This is for the default TSV delimiters.*/
    auto tsv1 = "a\tb\tc\n";
    auto tsv2 = "a\tbc\t\t\tdef\n";
    auto tsv3 = "\ta\t b \t cd \t\n";
    auto tsv4 = "ß\tßÀß\tあめりか物語\t书名: 五色石\n";
    auto tsv5 = " \t  \t   \n";
    auto tsv6 = " \t  \t   \n";
    auto tsv7 = ",\t,,\t,,,\n";
    auto tsv8 = "\t\"\t\"\"\n";
    auto tsv9 = "ab, de fg\" hij\n";
    auto tsv10 = "";
    auto tsv11 = "\t\n";
    auto tsv12 = "\t\t\n";
    auto tsv13 = " \t  \t   \n";
    auto tsv14 = " \t  \t   \n";
    auto tsv15 = "ab, de fg\" hij\n";
    auto tsv16 = "ab, de fg\" hij\n";
    auto tsv17 = "ab\"\tab\"cd\n";
    auto tsv18 = "\n\n\n";
    auto tsv19 = " \n";
    auto tsv20 = "  \n";
    auto tsv21 = "a\n";
    auto tsv22 = "a\t\n";
    auto tsv23 = "a\tb\n";
    auto tsv24 = "\t\n";
    auto tsv25 = "#\n";
    auto tsv26 = "^\n";
    auto tsv27 = "#^#\n";
    auto tsv28 = "^#^\n";
    auto tsv29 = "$\n";
    auto tsv30 = "$\t$\n$\t$$\t$$\n^#$\t$#^\t#$^\t^$#\n";
    auto tsv31 = "1-1\n2-1\t2-2\n3-1\t3-2\t3-3\n\n\t5-2\n\t\t6-3\n";
    auto tsv32 = "\t1-2\t1-3\n2-1\t2-2\t\n3-1\t\t3-3\n";

    /* The TSV results for CSV sets 1a and 1b, but with $ as the delimiter rather than tab.
     * This will also result in different replacements when TAB and $ appear in the CSV.
     */
    auto tsv1_x = "a$b$c\n";
    auto tsv2_x = "a$bc$$$def\n";
    auto tsv3_x = "$a$ b $ cd $\n";
    auto tsv4_x = "ß$ßÀß$あめりか物語$书名: 五色石\n";
    auto tsv5_x = " $  $   \n";
    auto tsv6_x = "\t$\t\t$\t\t\t\n";
    auto tsv7_x = ",$,,$,,,\n";
    auto tsv8_x = "$\"$\"\"\n";
    auto tsv9_x = "ab, de\tfg\" hij\n";
    auto tsv10_x = "";
    auto tsv11_x = "$\n";
    auto tsv12_x = "$$\n";
    auto tsv13_x = " $  $   \n";
    auto tsv14_x = " $  $   \n";
    auto tsv15_x = "ab, de\tfg\" hij\n";
    auto tsv16_x = "ab, de\tfg\" hij\n";
    auto tsv17_x = "ab\"$ab\"cd\n";
    auto tsv18_x = "\n\n\n";
    auto tsv19_x = "\t\n";
    auto tsv20_x = "\t\t\n";
    auto tsv21_x = "a\n";
    auto tsv22_x = "a$\n";
    auto tsv23_x = "a$b\n";
    auto tsv24_x = "$\n";
    auto tsv25_x = "#\n";
    auto tsv26_x = "^\n";
    auto tsv27_x = "#^#\n";
    auto tsv28_x = "^#^\n";
    auto tsv29_x = " \n";
    auto tsv30_x = " $ \n $  $  \n^# $ #^$# ^$^ #\n";
    auto tsv31_x = "1-1\n2-1$2-2\n3-1$3-2$3-3\n\n$5-2\n$$6-3\n";
    auto tsv32_x = "$1-2$1-3\n2-1$2-2$\n3-1$$3-3\n";

    /* The TSV results for CSV sets 1a and 1b, but with $ as the delimiter rather than tab,
     * and with the delimiter/newline replacement string being |--|. Basically, newlines
     * and '$' in the original data are replaced by |--|.
     */
    auto tsv1_y = "a$b$c\n";
    auto tsv2_y = "a$bc$$$def\n";
    auto tsv3_y = "$a$ b $ cd $\n";
    auto tsv4_y = "ß$ßÀß$あめりか物語$书名: 五色石\n";
    auto tsv5_y = "|--|$|--||--|$|--||--||--|\n";
    auto tsv6_y = "\t$\t\t$\t\t\t\n";
    auto tsv7_y = ",$,,$,,,\n";
    auto tsv8_y = "$\"$\"\"\n";
    auto tsv9_y = "ab, de\tfg\"|--|hij\n";
    auto tsv10_y = "";
    auto tsv11_y = "$\n";
    auto tsv12_y = "$$\n";
    auto tsv13_y = "|--|$|--||--|$|--||--||--|\n";
    auto tsv14_y = "|--|$|--||--|$|--||--||--|\n";
    auto tsv15_y = "ab, de\tfg\"|--|hij\n";
    auto tsv16_y = "ab, de\tfg\"|--|hij\n";
    auto tsv17_y = "ab\"$ab\"cd\n";
    auto tsv18_y = "\n\n\n";
    auto tsv19_y = "\t\n";
    auto tsv20_y = "\t\t\n";
    auto tsv21_y = "a\n";
    auto tsv22_y = "a$\n";
    auto tsv23_y = "a$b\n";
    auto tsv24_y = "$\n";
    auto tsv25_y = "#\n";
    auto tsv26_y = "^\n";
    auto tsv27_y = "#^#\n";
    auto tsv28_y = "^#^\n";
    auto tsv29_y = "|--|\n";
    auto tsv30_y = "|--|$|--|\n|--|$|--||--|$|--||--|\n^#|--|$|--|#^$#|--|^$^|--|#\n";
    auto tsv31_y = "1-1\n2-1$2-2\n3-1$3-2$3-3\n\n$5-2\n$$6-3\n";
    auto tsv32_y = "$1-2$1-3\n2-1$2-2$\n3-1$$3-3\n";

    auto csvSet1a = [csv1a, csv2a, csv3a, csv4a, csv5a, csv6a, csv7a, csv8a, csv9a, csv10a,
                     csv11a, csv12a, csv13a, csv14a, csv15a, csv16a, csv17a, csv18a, csv19a, csv20a,
                     csv21a, csv22a, csv23a, csv24a, csv25a, csv26a, csv27a, csv28a, csv29a, csv30a,
                     csv31a, csv32a];

    auto csvSet1b = [csv1b, csv2b, csv3b, csv4b, csv5b, csv6b, csv7b, csv8b, csv9b, csv10b,
                     csv11b, csv12b, csv13b, csv14b, csv15b, csv16b, csv17b, csv18b, csv19b, csv20b,
                     csv21b, csv22b, csv23b, csv24b, csv25b, csv26b, csv27b, csv28b, csv29b, csv30b,
                     csv31b, csv32b];

    auto tsvSet1  = [tsv1, tsv2, tsv3, tsv4, tsv5, tsv6, tsv7, tsv8, tsv9, tsv10,
                     tsv11, tsv12, tsv13, tsv14, tsv15, tsv16, tsv17, tsv18, tsv19, tsv20,
                     tsv21, tsv22, tsv23, tsv24, tsv25, tsv26, tsv27, tsv28, tsv29, tsv30,
                     tsv31, tsv32];

    auto tsvSet1_x  = [tsv1_x, tsv2_x, tsv3_x, tsv4_x, tsv5_x, tsv6_x, tsv7_x, tsv8_x, tsv9_x, tsv10_x,
                       tsv11_x, tsv12_x, tsv13_x, tsv14_x, tsv15_x, tsv16_x, tsv17_x, tsv18_x, tsv19_x, tsv20_x,
                       tsv21_x, tsv22_x, tsv23_x, tsv24_x, tsv25_x, tsv26_x, tsv27_x, tsv28_x, tsv29_x, tsv30_x,
                       tsv31_x, tsv32_x];

    auto tsvSet1_y  = [tsv1_y, tsv2_y, tsv3_y, tsv4_y, tsv5_y, tsv6_y, tsv7_y, tsv8_y, tsv9_y, tsv10_y,
                       tsv11_y, tsv12_y, tsv13_y, tsv14_y, tsv15_y, tsv16_y, tsv17_y, tsv18_y, tsv19_y, tsv20_y,
                       tsv21_y, tsv22_y, tsv23_y, tsv24_y, tsv25_y, tsv26_y, tsv27_y, tsv28_y, tsv29_y, tsv30_y,
                       tsv31_y, tsv32_y];


    ubyte[8] readBuffer;

    foreach (i, csva, csvb, tsv, tsv_x, tsv_y; lockstep(csvSet1a, csvSet1b, tsvSet1, tsvSet1_x, tsvSet1_y))
    {
        import std.conv : to;

        /* Byte streams for csv2tsv. Consumed by csv2tsv, so need to be reset when re-used. */
        ubyte[] csvInputA = cast(ubyte[])csva;
        ubyte[] csvInputB = cast(ubyte[])csvb;

        /* CSV Set A vs TSV expected. */
        auto tsvResultA = appender!(char[])();
        csv2tsv(csvInputA, tsvResultA, readBuffer, "csvInputA_defaultTSV");
        assert(tsv == tsvResultA.data,
               format("Unittest failure. tsv != tsvResultA.data. Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csva, tsv, tsvResultA.data));

        /* CSV Set B vs TSV expected. Different CSV delimiters, same TSV results as CSV Set A.*/
        auto tsvResultB = appender!(char[])();
        csv2tsv(csvInputB, tsvResultB, readBuffer, "csvInputB_defaultTSV", 0, '#', '^');
        assert(tsv == tsvResultB.data,
               format("Unittest failure. tsv != tsvResultB.data.  Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csvb, tsv, tsvResultB.data));

        /* CSV Set A and TSV with $ separator.*/
        csvInputA = cast(ubyte[])csva;
        auto tsvResult_XA = appender!(char[])();
        csv2tsv(csvInputA, tsvResult_XA, readBuffer, "csvInputA_TSV_WithDollarDelimiter", 0, '"', ',', '$');
        assert(tsv_x == tsvResult_XA.data,
               format("Unittest failure. tsv_x != tsvResult_XA.data. Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csva, tsv_x, tsvResult_XA.data));

        /* CSV Set B and TSV with $ separator. Same TSV results as CSV Set A.*/
        csvInputB = cast(ubyte[])csvb;
        auto tsvResult_XB = appender!(char[])();
        csv2tsv(csvInputB, tsvResult_XB, readBuffer, "csvInputB__TSV_WithDollarDelimiter", 0, '#', '^', '$');
        assert(tsv_x == tsvResult_XB.data,
               format("Unittest failure. tsv_x != tsvResult_XB.data.  Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csvb, tsv_x, tsvResult_XB.data));

        /* CSV Set A and TSV with $ separator and tsv delimiter/newline replacement. */
        csvInputA = cast(ubyte[])csva;
        auto tsvResult_YA = appender!(char[])();
        csv2tsv(csvInputA, tsvResult_YA, readBuffer, "csvInputA_TSV_WithDollarAndDelimReplacement", 0, '"', ',', '$', "|--|", "|--|");
        assert(tsv_y == tsvResult_YA.data,
               format("Unittest failure. tsv_y != tsvResult_YA.data. Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csva, tsv_y, tsvResult_YA.data));

        /* CSV Set A and TSV with $ separator and tsv delimiter/newline replacement. Same TSV as CSV Set A.*/
        csvInputB = cast(ubyte[])csvb;
        auto tsvResult_YB = appender!(char[])();
        csv2tsv(csvInputB, tsvResult_YB, readBuffer, "csvInputB__TSV_WithDollarAndDelimReplacement", 0, '#', '^', '$', "|--|", "|--|");
        assert(tsv_y == tsvResult_YB.data,
               format("Unittest failure. tsv_y != tsvResult_YB.data.  Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csvb, tsv_y, tsvResult_YB.data));

    }
}

version(none) {
unittest
{
    /* Unit tests for 'maxRecords' feature of the csv2tsv function.
     */

    /* Input CSV. */
    auto csv1 = "";
    auto csv2 = ",";
    auto csv3 = "a";
    auto csv4 = "a\n";
    auto csv5 = "a\nb";
    auto csv6 = "a\nb\n";
    auto csv7 = "a\nb\nc";
    auto csv8 = "a\nb\nc\n";
    auto csv9 = "a,aa";
    auto csv10 = "a,aa\n";
    auto csv11 = "a,aa\nb,bb";
    auto csv12 = "a,aa\nb,bb\n";
    auto csv13 = "a,aa\nb,bb\nc,cc";
    auto csv14 = "a,aa\nb,bb\nc,cc\n";

    auto csv15 = "\"a\",\"aa\"";
    auto csv16 = "\"a\",\"aa\"\n";
    auto csv17 = "\"a\",\"aa\"\n\"b\",\"bb\"";
    auto csv18 = "\"a\",\"aa\"\n\"b\",\"bb\"\n";
    auto csv19 = "\"a\",\"aa\"\n\"b\",\"bb\"\n\"c\",\"cc\"";
    auto csv20 = "\"a\",\"aa\"\n\"b\",\"bb\"\n\"c\",\"cc\"\n";

    /* TSV with max 1 record. */
    auto tsv1_max1 = "";
    auto tsv2_max1 = "\t\n";
    auto tsv3_max1 = "a\n";
    auto tsv4_max1 = "a\n";
    auto tsv5_max1 = "a\n";
    auto tsv6_max1 = "a\n";
    auto tsv7_max1 = "a\n";
    auto tsv8_max1 = "a\n";
    auto tsv9_max1 = "a\taa\n";
    auto tsv10_max1 = "a\taa\n";
    auto tsv11_max1 = "a\taa\n";
    auto tsv12_max1 = "a\taa\n";
    auto tsv13_max1 = "a\taa\n";
    auto tsv14_max1 = "a\taa\n";

    auto tsv15_max1 = "a\taa\n";
    auto tsv16_max1 = "a\taa\n";
    auto tsv17_max1 = "a\taa\n";
    auto tsv18_max1 = "a\taa\n";
    auto tsv19_max1 = "a\taa\n";
    auto tsv20_max1 = "a\taa\n";

    /* Remaining TSV converted after first call. */
    auto tsv1_max1_rest = "";
    auto tsv2_max1_rest = "";
    auto tsv3_max1_rest = "";
    auto tsv4_max1_rest = "";
    auto tsv5_max1_rest = "b\n";
    auto tsv6_max1_rest = "b\n";
    auto tsv7_max1_rest = "b\nc\n";
    auto tsv8_max1_rest = "b\nc\n";
    auto tsv9_max1_rest = "";
    auto tsv10_max1_rest = "";
    auto tsv11_max1_rest = "b\tbb\n";
    auto tsv12_max1_rest = "b\tbb\n";
    auto tsv13_max1_rest = "b\tbb\nc\tcc\n";
    auto tsv14_max1_rest = "b\tbb\nc\tcc\n";

    auto tsv15_max1_rest = "";
    auto tsv16_max1_rest = "";
    auto tsv17_max1_rest = "b\tbb\n";
    auto tsv18_max1_rest = "b\tbb\n";
    auto tsv19_max1_rest = "b\tbb\nc\tcc\n";
    auto tsv20_max1_rest = "b\tbb\nc\tcc\n";

    /* TSV with max 2 records. */
    auto tsv1_max2 = "";
    auto tsv2_max2 = "\t\n";
    auto tsv3_max2 = "a\n";
    auto tsv4_max2 = "a\n";
    auto tsv5_max2 = "a\nb\n";
    auto tsv6_max2 = "a\nb\n";
    auto tsv7_max2 = "a\nb\n";
    auto tsv8_max2 = "a\nb\n";
    auto tsv9_max2 = "a\taa\n";
    auto tsv10_max2 = "a\taa\n";
    auto tsv11_max2 = "a\taa\nb\tbb\n";
    auto tsv12_max2 = "a\taa\nb\tbb\n";
    auto tsv13_max2 = "a\taa\nb\tbb\n";
    auto tsv14_max2 = "a\taa\nb\tbb\n";

    auto tsv15_max2 = "a\taa\n";
    auto tsv16_max2 = "a\taa\n";
    auto tsv17_max2 = "a\taa\nb\tbb\n";
    auto tsv18_max2 = "a\taa\nb\tbb\n";
    auto tsv19_max2 = "a\taa\nb\tbb\n";
    auto tsv20_max2 = "a\taa\nb\tbb\n";

    /* Remaining TSV converted after first call. */
    auto tsv1_max2_rest = "";
    auto tsv2_max2_rest = "";
    auto tsv3_max2_rest = "";
    auto tsv4_max2_rest = "";
    auto tsv5_max2_rest = "";
    auto tsv6_max2_rest = "";
    auto tsv7_max2_rest = "c\n";
    auto tsv8_max2_rest = "c\n";
    auto tsv9_max2_rest = "";
    auto tsv10_max2_rest = "";
    auto tsv11_max2_rest = "";
    auto tsv12_max2_rest = "";
    auto tsv13_max2_rest = "c\tcc\n";
    auto tsv14_max2_rest = "c\tcc\n";

    auto tsv15_max2_rest = "";
    auto tsv16_max2_rest = "";
    auto tsv17_max2_rest = "";
    auto tsv18_max2_rest = "";
    auto tsv19_max2_rest = "c\tcc\n";
    auto tsv20_max2_rest = "c\tcc\n";

    auto csvSet1 =
        [csv1, csv2, csv3, csv4, csv5, csv6, csv7,
         csv8, csv9, csv10, csv11, csv12, csv13, csv14,
         csv15, csv16, csv17, csv18, csv19, csv20 ];

    auto tsvMax1Set1 =
        [tsv1_max1, tsv2_max1, tsv3_max1, tsv4_max1, tsv5_max1, tsv6_max1, tsv7_max1,
         tsv8_max1, tsv9_max1, tsv10_max1, tsv11_max1, tsv12_max1, tsv13_max1, tsv14_max1,
         tsv15_max1, tsv16_max1, tsv17_max1, tsv18_max1, tsv19_max1, tsv20_max1];

    auto tsvMax1RestSet1 =
        [tsv1_max1_rest, tsv2_max1_rest, tsv3_max1_rest, tsv4_max1_rest, tsv5_max1_rest, tsv6_max1_rest, tsv7_max1_rest,
         tsv8_max1_rest, tsv9_max1_rest, tsv10_max1_rest, tsv11_max1_rest, tsv12_max1_rest, tsv13_max1_rest, tsv14_max1_rest,
         tsv15_max1_rest, tsv16_max1_rest, tsv17_max1_rest, tsv18_max1_rest, tsv19_max1_rest, tsv20_max1_rest];

    auto tsvMax2Set1 =
        [tsv1_max2, tsv2_max2, tsv3_max2, tsv4_max2, tsv5_max2, tsv6_max2, tsv7_max2,
         tsv8_max2, tsv9_max2, tsv10_max2, tsv11_max2, tsv12_max2, tsv13_max2, tsv14_max2,
         tsv15_max2, tsv16_max2, tsv17_max2, tsv18_max2, tsv19_max2, tsv20_max2];

    auto tsvMax2RestSet1 =
        [tsv1_max2_rest, tsv2_max2_rest, tsv3_max2_rest, tsv4_max2_rest, tsv5_max2_rest, tsv6_max2_rest, tsv7_max2_rest,
         tsv8_max2_rest, tsv9_max2_rest, tsv10_max2_rest, tsv11_max2_rest, tsv12_max2_rest, tsv13_max2_rest, tsv14_max2_rest,
         tsv15_max2_rest, tsv16_max2_rest, tsv17_max2_rest, tsv18_max2_rest, tsv19_max2_rest, tsv20_max2_rest];

    foreach (i, csv, tsv_max1, tsv_max1_rest, tsv_max2, tsv_max2_rest;
             lockstep(csvSet1, tsvMax1Set1, tsvMax1RestSet1, tsvMax2Set1, tsvMax2RestSet1))
    {
        /* Byte stream for csv2tsv. Consumed by csv2tsv, so need to be reset when re-used. */
        ubyte[] csvInput = cast(ubyte[])csv;

        /* Call with maxRecords == 1. */
        auto tsvMax1Result = appender!(char[])();
        csv2tsv(csvInput, tsvMax1Result, "maxRecords-one", i, '"', ',', '\t', " ", NullableSizeT(1));
        assert(tsv_max1 == tsvMax1Result.data,
               format("Unittest failure. tsv_max1 != tsvMax1Result.data. Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csv, tsv_max1, tsvMax1Result.data));

        /* Follow-up call getting all records remaining after the maxRecords==1 call. */
        auto tsvMax1RestResult = appender!(char[])();
        csv2tsv(csvInput, tsvMax1RestResult, "maxRecords-one-followup", i);
        assert(tsv_max1_rest == tsvMax1RestResult.data,
               format("Unittest failure. tsv_max1_rest != tsvMax1RestResult.data. Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csv, tsv_max1_rest, tsvMax1RestResult.data));

        /* Reset the input stream for maxRecords == 2. */
        csvInput = cast(ubyte[])csv;

        /* Call with maxRecords == 2. */
        auto tsvMax2Result = appender!(char[])();
        csv2tsv(csvInput, tsvMax2Result, "maxRecords-two", i, '"', ',', '\t', " ", NullableSizeT(2));
        assert(tsv_max2 == tsvMax2Result.data,
               format("Unittest failure. tsv_max2 != tsvMax2Result.data. Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csv, tsv_max2, tsvMax2Result.data));

        /* Follow-up call getting all records remaining after the maxRecords==2 call. */
        auto tsvMax2RestResult = appender!(char[])();
        csv2tsv(csvInput, tsvMax2RestResult, "maxRecords-two-followup", i);
        assert(tsv_max2_rest == tsvMax2RestResult.data,
               format("Unittest failure. tsv_max2_rest != tsvMax2RestResult.data. Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csv, tsv_max2_rest, tsvMax2RestResult.data));
    }
}

} // version(none)
