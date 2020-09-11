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
import std.typecons : tuple;

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
  * The three common forms of newlines are supported: CR, CRLF, LF. Output is
    written using Unix newlines (LF).
  * A newline will be added if the file does not end with one.
  * A UTF-8 Byte Order Mark (BOM) at the start of a file will be removed.
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
    string tsvDelimReplacement = " ";  // --r|tab-replacement
    string newlineReplacement = " ";   // --n|newline-replacement
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
                "help-verbose",          "     Print full help.", &helpVerbose,
                std.getopt.config.caseSensitive,
                "H|header",              "     Treat the first line of each file as a header. Only the header of the first file is output.", &hasHeader,
                std.getopt.config.caseSensitive,
                "q|quote",               "CHR  Quoting character in CSV data. Default: double-quote (\")", &csvQuoteChar,
                "c|csv-delim",           "CHR  Field delimiter in CSV data. Default: comma (,).", &csvDelimChar,
                "t|tsv-delim",           "CHR  Field delimiter in TSV data. Default: TAB", &tsvDelimChar,
                "r|tab-replacement",     "STR  Replacement for TSV field delimiters (typically TABs) found in CSV input. Default: Space.", &tsvDelimReplacement,
                "n|newline-replacement", "STR  Replacement for newlines found in CSV input. Default: Space.", &newlineReplacement,
                std.getopt.config.caseSensitive,
                "V|version",             "     Print version information and exit.", &versionWanted,
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
                    "Replacement character cannot contain newlines or TSV field delimiters (--r|tab-replacement).");

            enforce(!canFind!(c => (c == '\n' || c == '\r' || c == tsvDelimChar))(newlineReplacement),
                    "Replacement character cannot contain newlines or TSV field delimiters (--n|newline-replacement).");
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
    auto stdoutWriter = BufferedOutputRange!(typeof(stdout))(stdout, 1024 * 10, 1024 * 129, 1024 * 128);
    bool firstFile = true;

    foreach (filename; (inputFiles.length > 0) ? inputFiles : ["-"])
    {
        auto inputStream = (filename == "-") ? stdin : filename.File;
        auto printFileName = (filename == "-") ? "stdin" : filename;

        auto skipLines = (firstFile || !cmdopt.hasHeader) ? 0 : 1;

        csv2tsv(inputStream, stdoutWriter, fileRawBuf, printFileName, skipLines,
                cmdopt.csvQuoteChar, cmdopt.csvDelimChar,
                cmdopt.tsvDelimChar, cmdopt.tsvDelimReplacement,
                cmdopt.newlineReplacement);

        firstFile = false;
    }
}

/* csv2tsv buffered conversion approach

This version of csv2tsv uses a buffered approach to csv-to-tsv conversion. This is a
change from the original version, which used a character-at-a-time approach, with
characters coming from an infinite stream of characters. The character-at-a-time
approach was nice from a simplicity perspective, but the approach didn't optimize well.
Note that the original version read input in blocks and wrote to stdout in blocks, it
was the conversion algorithm itself that was character oriented.

The idea is to convert a buffer at a time, writing larger blocks to the output stream
rather than one character at a time. In addition, the read buffer is modified in-place
when the only change is to convert a single character. The notable case is converting
the field delimiter character, typically comma to TAB. The result is writing longer
blocks to the output stream (BufferedOutputRange).

Performance improvements from the new algorithm are notable. This is especially true
versus the previous version 2.0.0. Note though that the more recent versions of
csv2tsv were slower due to degradations coming from compiler and/or language version.
Version 1.1.19 was quite a bit faster. Regardless of version, the performance
improvement is especially good when run against "simple" CSV files, with limited
amounts of CSV escape syntax. In these files the main change is converting the field
delimiter character, typically comma to TAB.

In some benchmarks on Mac OS, the new version was 40% faster than csv2tsv 2.0.0 on
files with significant CSV escapes, and 60% faster on files with limited CSV escapes.
Versus csv2tsv version 1.1.19, the new version is 10% and 40% faster on the same
files. On the "simple CSV" file, where Unix 'tr' is an option, 'tr' was still faster,
by about 20%. But getting into the 'tr' ballpark while retaining safety of correct
csv2tsv conversion is a good result.

Algorithm notes:

The algorithm works by reading an input block, then examining each byte in-order to
identify needed modifications. The region of consecutive characters without a change
is tracked. Single character changes are done in-place, in the read buffer. This
allows assembling longer blocks before write is needed. The region being tracked is
written to the output stream when it can no longer be extended in a continuous
fashion. At this point a new region is started. When the current read buffer has
been processed the current region is written out and a new block of data read in.

The read buffer uses fixed size blocks. This means the algorithm is actually
operating on bytes (UTF-8 code units), and not characters. This works because all
delimiters and CSV escape syntax characters are single byte UTF-8 characters. These
are the only characters requiring interpretation. The main nuisance is the 2-byte
CRLF newline sequence, as this might be split across two read buffers. This is
handled by embedding 'CR' states in the finite state machine.

Processing CSV escapes will often cause the character removals and additions. These
will not be representable in a continuous stream of bytes without moving bytes around
Instead of moving bytes, these cases are handled by immediately  writing to the output
stream. This allows restarting a new block of contiguous characters. Handling by the
new algorithm is described below. Note that the length of the replacement characters
for TSV field and record delimiters (e.g. TAB, newline) affects the processing.

All replacement character lengths:

* Windows newline (CRLF) at the end of a line - Replace the CRLF with LF.

  Replace the CR with LF, add it to the current write region and terminate it. The
  next write region starts at the character after the LF.

* Double quote starting or ending a field - Drop the double quote.

  Terminate the current write region, next write region starts at the next character.

* Double quote pair inside a quoted field - Drop one of the double quotes.

  The algorithm drops the first double quote and keep the second. This avoids
  look-ahead and both field terminating double quote and double quote pair can
  handled the same way. Terminate the current write region without adding the double
  quote. The next write region starts at the next character.

Single byte replacement characters:

* Windows newline (CRLF) in a quoted field

  Replace the CR with the replacement char, add it to the current write region and
  terminate it. The next write region starts at the character after the LF.

Multi-byte replacement sequences:

* TSV Delimiter (TAB by default) in a field

  Terminate the current write region, write it out and the replacement. The next
  write region starts at the next character.

* LF, CR, or CRLF in a quoted field

  Terminate the current write region, write it and the replacement. The next write
  region starts at the next character.

csv2tsv API

At the API level, it is desirable to handle at both open files and input streams.
Open files are the key requirement, but handling input streams simplifies unit
testing, and in-memory conversion is likely to be useful anyway. Internally, it
should be easy enough to encapsulate the differences between input streams and files.
Reading files can be done using File.byChunk and reading from input streams can be
done using std.range.chunks.

This has been handled by creating a new range that can iterate either files or
input streams chunk-by-chunk.
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

    /* For code coverage. */
    S2 s2;
    auto x = s2.save;
}

/** inputSourceByChunk returns a range that reads either a file handle (File) or a
 * ubyte[] array a chunk at a time.
 *
 * This is a cover for File.byChunk that allows passing an in-memory array as well.
 * At present the motivation is primarily to enable unit testing of chunk-based
 * algorithms using in-memory strings. At present the in-memory input types are
 * limited. In the future this may be changed to accept any type of character or
 * ubyte array.
 *
 * inputSourceByChunk takes either a File open for reading or a ubyte[] array
 * containing input data. Data is read a buffer at a time. The buffer can be
 * user provided, or allocated by inputSourceByChunk based on a caller provided
 * buffer size.
 *
 * A ubyte[] input source must satisfy isBufferableInputSource, which at present
 * means that it is a dynamic, mutable ubyte[].
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

                    /* Only the last chunk should be shorter than the buffer. */
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
 *   inputSource           =  A "bufferable" input source, either a file open for
 *                            read, or a dynamic, mutable ubyte array.
 *   outputStream          =  An output range to write TSV bytes to.
 *   readBuffer            =  A buffer to use for reading.
 *   filename              =  Name of file to use when reporting errors. A descriptive
 *                            name can be used in lieu of a file name.
 *   skipLines             =  Number of lines to skip before outputting records.
 *                            Typically used to skip writing header lines.
 *   csvQuote              =  The quoting character used in the CSV input.
 *   csvDelim              =  The field delimiter character used in the CSV input.
 *   tsvDelim              =  The field delimiter character to use in the TSV output.
 *   tsvDelimReplacement   =  String to use when replacing TSV field delimiters
 *                            (e.g. TABs) found in the CSV data fields.
 *   tsvNewlineReplacement =  String to use when replacing newlines found in the CSV
 *                            data fields.
 *   discardBOM            =  If true (the default), a UTF-8 Byte Order Mark found at the
 *                            start of the input stream will be dropped.
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
    bool discardBOM = true,
)
if (isBufferableInputSource!InputSource &&
    isOutputRange!(OutputRange, char))
{
    import std.conv: hexString;

    assert (readBuffer.length >= 1);

    enum char LF = '\n';
    enum char CR = '\r';

    enum ubyte[3] UTF8_BOM = cast(ubyte[3])hexString!"efbbbf";

    /* Process state information - These variables are defined either in the outer
     * context or within one of the foreach loops.
     *
     *   * recordNum - The current CSV input line/record number. Starts at one.
     *   * fieldNum - Field number in the current line/record. Field numbers are
     *     one-upped. The field number set to zero at the start of a new record,
     *     prior to processing the first character of the first field on the record.
     *   * byteIndex - Read buffer index of the current byte being processed.
     *   * csvState - The current state of CSV processing. In particular, the state
     *     of the finite state machine.
     *   * writeRegionStart - Read buffer index where the next write starts from.
     *   * nextIndex - The index of the current input ubyte being processed. The
     *     current write region extends from the writeRegionStart to nextIndex.
     *   * nextChar - The current input ubyte. The ubyte/char at nextIndex.
     */

    enum CSVState
    {
     FieldEnd,           // Start of input or after consuming a field or record delimiter.
     NonQuotedField,     // Processing a non-quoted field
     QuotedField,        // Processing a quoted field
     QuoteInQuotedField, // Last char was a quote in a quoted field
     CRAtFieldEnd,       // Last char was a CR terminating a record/line
     CRInQuotedField,    // Last char was a CR in a quoted field
    }

    CSVState csvState = CSVState.FieldEnd;
    size_t recordNum = 1;
    size_t fieldNum = 0;

    foreach (chunkIndex, inputChunkComplete; inputSource.inputSourceByChunk(readBuffer).enumerate)
    {
        size_t writeRegionStart = 0;

        /* Discard byte order marks at the start of input.
         * Note: Slicing the chunk in this fashion generates very good code, better
         * other approaches like manipulating indices.
         */
        auto inputChunk =
            (discardBOM &&
             chunkIndex == 0 &&
             inputChunkComplete.length >= UTF8_BOM.length &&
             inputChunkComplete[0 .. UTF8_BOM.length] == UTF8_BOM
            )
            ? inputChunkComplete[UTF8_BOM.length .. $]
            : inputChunkComplete[];

        /* flushCurrentRegion flushes the current write region and moves the start of
         * the next write region one byte past the end of the current region. If
         * appendChars are provided they are ouput as well.
         *
         * This routine is called when the current character (byte) terminates the
         * current write region and should not itself be output. That is why the next
         * write region always starts one byte past the current region end.
         *
         * This routine is also called when the 'skiplines' region has been processed.
         * This is done to flush the region without actually writing it. This is done
         * by explicit checks in the finite state machine when newline characters
         * that terminate a record are processed. It would be nice to refactor this.
         */
        void flushCurrentRegion(size_t regionEnd, const char[] appendChars = "")
        {
            assert(regionEnd <= inputChunk.length);

            if (recordNum > skipLines)
            {
                if (regionEnd > writeRegionStart)
                {
                    outputStream.put(inputChunk[writeRegionStart .. regionEnd]);
                }
                if (appendChars.length > 0)
                {
                    outputStream.put(appendChars);
                }
            }

            writeRegionStart = regionEnd + 1;
        }

        foreach (size_t nextIndex, char nextChar; inputChunk)
        {
        OuterSwitch: final switch (csvState)
            {
            case CSVState.FieldEnd:
                /* Start of input or after consuming a field terminator. */
                ++fieldNum;

                /* Note: Can't use switch due to the 'goto case' to the OuterSwitch.  */
                if (nextChar == csvQuote)
                {
                    flushCurrentRegion(nextIndex);
                    csvState = CSVState.QuotedField;
                    break OuterSwitch;
                }
                else
                {
                    /* Processing state change only. Don't consume the character. */
                    csvState = CSVState.NonQuotedField;
                    goto case CSVState.NonQuotedField;
                }

            case CSVState.NonQuotedField:
                switch (nextChar)
                {
                default:
                    break OuterSwitch;
                case csvDelim:
                    inputChunk[nextIndex] = tsvDelim;
                    csvState = CSVState.FieldEnd;
                    break OuterSwitch;
                case LF:
                    if (recordNum == skipLines) flushCurrentRegion(nextIndex);
                    ++recordNum;
                    fieldNum = 0;
                    csvState = CSVState.FieldEnd;
                    break OuterSwitch;
                case CR:
                    inputChunk[nextIndex] = LF;
                    if (recordNum == skipLines) flushCurrentRegion(nextIndex);
                    ++recordNum;
                    fieldNum = 0;
                    csvState = CSVState.CRAtFieldEnd;
                    break OuterSwitch;
                case tsvDelim:
                    if (tsvDelimReplacement.length == 1)
                    {
                        inputChunk[nextIndex] = tsvDelimReplacement[0];
                    }
                    else
                    {
                        flushCurrentRegion(nextIndex, tsvDelimReplacement);
                    }
                    break OuterSwitch;
                }

            case CSVState.QuotedField:
                switch (nextChar)
                {
                default:
                    break OuterSwitch;
                case csvQuote:
                    /*
                     * Flush the current region, without the double quote. Switch state
                     * to QuoteInQuotedField, which determines whether to output a quote.
                     */
                    flushCurrentRegion(nextIndex);
                    csvState = CSVState.QuoteInQuotedField;
                    break OuterSwitch;

                case tsvDelim:
                    if (tsvDelimReplacement.length == 1)
                    {
                        inputChunk[nextIndex] = tsvDelimReplacement[0];
                    }
                    else
                    {
                        flushCurrentRegion(nextIndex, tsvDelimReplacement);
                    }
                    break OuterSwitch;
                case LF:
                    /* Newline in a quoted field. */
                    if (tsvNewlineReplacement.length == 1)
                    {
                        inputChunk[nextIndex] = tsvNewlineReplacement[0];
                    }
                    else
                    {
                        flushCurrentRegion(nextIndex, tsvNewlineReplacement);
                    }
                    break OuterSwitch;
                case CR:
                    /* Carriage Return in a quoted field. */
                    if (tsvNewlineReplacement.length == 1)
                    {
                        inputChunk[nextIndex] = tsvNewlineReplacement[0];
                    }
                    else
                    {
                        flushCurrentRegion(nextIndex, tsvNewlineReplacement);
                    }
                    csvState = CSVState.CRInQuotedField;
                    break OuterSwitch;
                }

            case CSVState.QuoteInQuotedField:
                /* Just processed a quote in a quoted field. The buffer, without the
                 * quote, was just flushed. Only legal characters here are quote,
                 * comma (field delimiter), newline (record delimiter).
                 */
                switch (nextChar)
                {
                case csvQuote:
                    csvState = CSVState.QuotedField;
                    break OuterSwitch;
                case csvDelim:
                    inputChunk[nextIndex] = tsvDelim;
                    csvState = CSVState.FieldEnd;
                    break OuterSwitch;
                case LF:
                    if (recordNum == skipLines) flushCurrentRegion(nextIndex);
                    ++recordNum;
                    fieldNum = 0;
                    csvState = CSVState.FieldEnd;
                    break OuterSwitch;
                case CR:
                    inputChunk[nextIndex] = LF;
                    if (recordNum == skipLines) flushCurrentRegion(nextIndex);
                    ++recordNum;
                    fieldNum = 0;
                    csvState = CSVState.CRAtFieldEnd;
                    break OuterSwitch;
                default:
                    throw new Exception(
                        format("Invalid CSV. Improperly terminated quoted field. File: %s, Line: %d",
                               (filename == "-") ? "Standard Input" : filename,
                               recordNum));
                }

            case CSVState.CRInQuotedField:
                if (nextChar == LF)
                {
                    flushCurrentRegion(nextIndex);
                    csvState = CSVState.QuotedField;
                    break OuterSwitch;
                }
                else {
                    /* Naked CR. State change only, don't consume current character. */
                    csvState = CSVState.QuotedField;
                    goto case CSVState.QuotedField;
                }

            case CSVState.CRAtFieldEnd:
                if (nextChar == LF)
                {
                    flushCurrentRegion(nextIndex);
                    csvState = CSVState.FieldEnd;
                    break OuterSwitch;
                }
                else {
                    /* Naked CR. State change only, don't consume current character. */
                    csvState = CSVState.FieldEnd;
                    goto case CSVState.FieldEnd;
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

    enforce(csvState != CSVState.QuotedField,
            format("Invalid CSV. Improperly terminated quoted field. File: %s, Line: %d",
                   (filename == "-") ? "Standard Input" : filename,
                   recordNum));

    /* Output a newline if the CSV input did not have a terminating newline. */
    if (fieldNum > 0 && recordNum > skipLines) put(outputStream, '\n');
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
     *
     * Note: unittest is non @safe due to the casts from string to ubyte[]. This can
     * probably be rewritten to use std.string.representation instead, which is @safe.
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

    // Newlines terminating a line ending a non-quoted field
    auto csv33a = "\rX\r\nX\n\r\nX\r\n";

    // Newlines inside a quoted field and terminating a line following a quoted field
    auto csv34a = "\"\r\",\"X\r\",\"X\rY\",\"\rY\"\r\"\r\n\",\"X\r\n\",\"X\r\nY\",\"\r\nY\"\r\n\"\n\",\"X\n\",\"X\nY\",\"\nY\"\n";

    // CR at field end
    auto csv35a = "abc,def\r\"ghi\",\"jkl\"\r\"mno\",pqr\r";

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
    auto csv33b = "\rX\r\nX\n\r\nX\r\n";
    auto csv34b = "#\r#^#X\r#^#X\rY#^#\rY#\r#\r\n#^#X\r\n#^#X\r\nY#^#\r\nY#\r\n#\n#^#X\n#^#X\nY#^#\nY#\n";
    auto csv35b = "abc^def\r#ghi#^#jkl#\r#mno#^pqr\r";

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
    auto tsv33 = "\nX\nX\n\nX\n";
    auto tsv34 = " \tX \tX Y\t Y\n \tX \tX Y\t Y\n \tX \tX Y\t Y\n";
    auto tsv35 = "abc\tdef\nghi\tjkl\nmno\tpqr\n";

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
    auto tsv33_x = "\nX\nX\n\nX\n";
    auto tsv34_x = " $X $X Y$ Y\n $X $X Y$ Y\n $X $X Y$ Y\n";
    auto tsv35_x = "abc$def\nghi$jkl\nmno$pqr\n";

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
    auto tsv33_y = "\nX\nX\n\nX\n";
    auto tsv34_y = "|--|$X|--|$X|--|Y$|--|Y\n|--|$X|--|$X|--|Y$|--|Y\n|--|$X|--|$X|--|Y$|--|Y\n";
    auto tsv35_y = "abc$def\nghi$jkl\nmno$pqr\n";

    /* The TSV results for CSV sets 1a and 1b, but with the TAB replacement as |TAB|
     * and newline replacement |NL|.
     */
    auto tsv1_z = "a\tb\tc\n";
    auto tsv2_z = "a\tbc\t\t\tdef\n";
    auto tsv3_z = "\ta\t b \t cd \t\n";
    auto tsv4_z = "ß\tßÀß\tあめりか物語\t书名: 五色石\n";
    auto tsv5_z = "<NL>\t<NL><NL>\t<NL><NL><NL>\n";
    auto tsv6_z = "<TAB>\t<TAB><TAB>\t<TAB><TAB><TAB>\n";
    auto tsv7_z = ",\t,,\t,,,\n";
    auto tsv8_z = "\t\"\t\"\"\n";
    auto tsv9_z = "ab, de<TAB>fg\"<NL>hij\n";
    auto tsv10_z = "";
    auto tsv11_z = "\t\n";
    auto tsv12_z = "\t\t\n";
    auto tsv13_z = "<NL>\t<NL><NL>\t<NL><NL><NL>\n";
    auto tsv14_z = "<NL>\t<NL><NL>\t<NL><NL><NL>\n";
    auto tsv15_z = "ab, de<TAB>fg\"<NL>hij\n";
    auto tsv16_z = "ab, de<TAB>fg\"<NL>hij\n";
    auto tsv17_z = "ab\"\tab\"cd\n";
    auto tsv18_z = "\n\n\n";
    auto tsv19_z = "<TAB>\n";
    auto tsv20_z = "<TAB><TAB>\n";
    auto tsv21_z = "a\n";
    auto tsv22_z = "a\t\n";
    auto tsv23_z = "a\tb\n";
    auto tsv24_z = "\t\n";
    auto tsv25_z = "#\n";
    auto tsv26_z = "^\n";
    auto tsv27_z = "#^#\n";
    auto tsv28_z = "^#^\n";
    auto tsv29_z = "$\n";
    auto tsv30_z = "$\t$\n$\t$$\t$$\n^#$\t$#^\t#$^\t^$#\n";
    auto tsv31_z = "1-1\n2-1\t2-2\n3-1\t3-2\t3-3\n\n\t5-2\n\t\t6-3\n";
    auto tsv32_z = "\t1-2\t1-3\n2-1\t2-2\t\n3-1\t\t3-3\n";
    auto tsv33_z = "\nX\nX\n\nX\n";
    auto tsv34_z = "<NL>\tX<NL>\tX<NL>Y\t<NL>Y\n<NL>\tX<NL>\tX<NL>Y\t<NL>Y\n<NL>\tX<NL>\tX<NL>Y\t<NL>Y\n";
    auto tsv35_z = "abc\tdef\nghi\tjkl\nmno\tpqr\n";

    /* Aggregate the test data into parallel arrays. */
    auto csvSet1a = [csv1a, csv2a, csv3a, csv4a, csv5a, csv6a, csv7a, csv8a, csv9a, csv10a,
                     csv11a, csv12a, csv13a, csv14a, csv15a, csv16a, csv17a, csv18a, csv19a, csv20a,
                     csv21a, csv22a, csv23a, csv24a, csv25a, csv26a, csv27a, csv28a, csv29a, csv30a,
                     csv31a, csv32a, csv33a, csv34a, csv35a];

    auto csvSet1b = [csv1b, csv2b, csv3b, csv4b, csv5b, csv6b, csv7b, csv8b, csv9b, csv10b,
                     csv11b, csv12b, csv13b, csv14b, csv15b, csv16b, csv17b, csv18b, csv19b, csv20b,
                     csv21b, csv22b, csv23b, csv24b, csv25b, csv26b, csv27b, csv28b, csv29b, csv30b,
                     csv31b, csv32b, csv33b, csv34b, csv35b];

    auto tsvSet1  = [tsv1, tsv2, tsv3, tsv4, tsv5, tsv6, tsv7, tsv8, tsv9, tsv10,
                     tsv11, tsv12, tsv13, tsv14, tsv15, tsv16, tsv17, tsv18, tsv19, tsv20,
                     tsv21, tsv22, tsv23, tsv24, tsv25, tsv26, tsv27, tsv28, tsv29, tsv30,
                     tsv31, tsv32, tsv33, tsv34, tsv35];

    auto tsvSet1_x  = [tsv1_x, tsv2_x, tsv3_x, tsv4_x, tsv5_x, tsv6_x, tsv7_x, tsv8_x, tsv9_x, tsv10_x,
                       tsv11_x, tsv12_x, tsv13_x, tsv14_x, tsv15_x, tsv16_x, tsv17_x, tsv18_x, tsv19_x, tsv20_x,
                       tsv21_x, tsv22_x, tsv23_x, tsv24_x, tsv25_x, tsv26_x, tsv27_x, tsv28_x, tsv29_x, tsv30_x,
                       tsv31_x, tsv32_x, tsv33_x, tsv34_x, tsv35_x];

    auto tsvSet1_y  = [tsv1_y, tsv2_y, tsv3_y, tsv4_y, tsv5_y, tsv6_y, tsv7_y, tsv8_y, tsv9_y, tsv10_y,
                       tsv11_y, tsv12_y, tsv13_y, tsv14_y, tsv15_y, tsv16_y, tsv17_y, tsv18_y, tsv19_y, tsv20_y,
                       tsv21_y, tsv22_y, tsv23_y, tsv24_y, tsv25_y, tsv26_y, tsv27_y, tsv28_y, tsv29_y, tsv30_y,
                       tsv31_y, tsv32_y, tsv33_y, tsv34_y, tsv35_y];

    auto tsvSet1_z  = [tsv1_z, tsv2_z, tsv3_z, tsv4_z, tsv5_z, tsv6_z, tsv7_z, tsv8_z, tsv9_z, tsv10_z,
                       tsv11_z, tsv12_z, tsv13_z, tsv14_z, tsv15_z, tsv16_z, tsv17_z, tsv18_z, tsv19_z, tsv20_z,
                       tsv21_z, tsv22_z, tsv23_z, tsv24_z, tsv25_z, tsv26_z, tsv27_z, tsv28_z, tsv29_z, tsv30_z,
                       tsv31_z, tsv32_z, tsv33_z, tsv34_z, tsv35_z];

    /* The tests. */
    auto bufferSizeTests = [1, 2, 3, 8, 128];

    foreach (bufferSize; bufferSizeTests)
    {
        ubyte[] readBuffer = new ubyte[](bufferSize);

        foreach (i, csva, csvb, tsv, tsv_x, tsv_y, tsv_z; lockstep(csvSet1a, csvSet1b, tsvSet1, tsvSet1_x, tsvSet1_y, tsvSet1_z))
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

            /* CSV Set B and TSV with $ separator and tsv delimiter/newline replacement. Same TSV as CSV Set A.*/
            csvInputB = cast(ubyte[])csvb;
            auto tsvResult_YB = appender!(char[])();
            csv2tsv(csvInputB, tsvResult_YB, readBuffer, "csvInputB__TSV_WithDollarAndDelimReplacement", 0, '#', '^', '$', "|--|", "|--|");
            assert(tsv_y == tsvResult_YB.data,
                   format("Unittest failure. tsv_y != tsvResult_YB.data.  Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                          i + 1, csvb, tsv_y, tsvResult_YB.data));

            /* CSV Set A and TSV with TAB replacement as <TAB> and newline replacement as <NL>. Same TSV as CSV Set A.*/
            csvInputA = cast(ubyte[])csva;
            auto tsvResult_ZA = appender!(char[])();
            csv2tsv(csvInputA, tsvResult_ZA, readBuffer, "csvInputA_TSV_WithDifferentTABandNLReplacements", 0, '"', ',', '\t', "<TAB>", "<NL>");
            assert(tsv_z == tsvResult_ZA.data,
                   format("Unittest failure. tsv_z != tsvResult_ZA.data. Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                          i + 1, csva, tsv_z, tsvResult_ZA.data));
        }
    }
}

// csv2tsv skiplines tests
unittest
{
    import std.string : representation;

    auto csv1 = "";
    auto csv2 = "a";

    auto csv3 = "\n";
    auto csv4 = "\n\n";
    auto csv5 = "\n\n\n";

    auto csv6 = "a\n";
    auto csv7 = "a\nb\n";
    auto csv8 = "a\nb\nc\n";

    auto csv9 = "\"\n\"\n";
    auto csv10 = "\"\n\"\n\"\n\"\n";
    auto csv11 = "\"\n\"\n\"\n\"\n\"\n\"\n";

    auto csv12 = "\r";
    auto csv13 = "\r\r";
    auto csv14 = "\r\r\r";

    auto csv15 = "a\r";
    auto csv16 = "a\rb\r";
    auto csv17 = "a\rb\rc\r";

    auto csv18 = "\"\r\"\r";
    auto csv19 = "\"\r\"\r\"\r\"\r";
    auto csv20 = "\"\r\"\r\"\r\"\r\"\r\"\r";

    auto csv21 = "\r\n";
    auto csv22 = "\r\n\r\n";
    auto csv23 = "\r\n\r\n\r\n";

    auto csv24 = "a\r\n";
    auto csv25 = "a\r\nb\r\n";
    auto csv26 = "a\r\nb\r\nc\r\n";

    auto csv27 = "\"\r\n\"\r\n";
    auto csv28 = "\"\r\n\"\r\n\"\r\n\"\r\n";
    auto csv29 = "\"\r\n\"\r\n\"\r\n\"\r\n\"\r\n\"\r\n";

    /* The Skip 1 expected results. */
    auto tsv1Skip1 = "";
    auto tsv2Skip1 = "";

    auto tsv3Skip1 = "";
    auto tsv4Skip1 = "\n";
    auto tsv5Skip1 = "\n\n";

    auto tsv6Skip1 = "";
    auto tsv7Skip1 = "b\n";
    auto tsv8Skip1 = "b\nc\n";

    auto tsv9Skip1 = "";
    auto tsv10Skip1 = " \n";
    auto tsv11Skip1 = " \n \n";

    auto tsv12Skip1 = "";
    auto tsv13Skip1 = "\n";
    auto tsv14Skip1 = "\n\n";

    auto tsv15Skip1 = "";
    auto tsv16Skip1 = "b\n";
    auto tsv17Skip1 = "b\nc\n";

    auto tsv18Skip1 = "";
    auto tsv19Skip1 = " \n";
    auto tsv20Skip1 = " \n \n";

    auto tsv21Skip1 = "";
    auto tsv22Skip1 = "\n";
    auto tsv23Skip1 = "\n\n";

    auto tsv24Skip1 = "";
    auto tsv25Skip1 = "b\n";
    auto tsv26Skip1 = "b\nc\n";

    auto tsv27Skip1 = "";
    auto tsv28Skip1 = " \n";
    auto tsv29Skip1 = " \n \n";

    /* The Skip 2 expected results. */
    auto tsv1Skip2 = "";
    auto tsv2Skip2 = "";

    auto tsv3Skip2 = "";
    auto tsv4Skip2 = "";
    auto tsv5Skip2 = "\n";

    auto tsv6Skip2 = "";
    auto tsv7Skip2 = "";
    auto tsv8Skip2 = "c\n";

    auto tsv9Skip2 = "";
    auto tsv10Skip2 = "";
    auto tsv11Skip2 = " \n";

    auto tsv12Skip2 = "";
    auto tsv13Skip2 = "";
    auto tsv14Skip2 = "\n";

    auto tsv15Skip2 = "";
    auto tsv16Skip2 = "";
    auto tsv17Skip2 = "c\n";

    auto tsv18Skip2 = "";
    auto tsv19Skip2 = "";
    auto tsv20Skip2 = " \n";

    auto tsv21Skip2 = "";
    auto tsv22Skip2 = "";
    auto tsv23Skip2 = "\n";

    auto tsv24Skip2 = "";
    auto tsv25Skip2 = "";
    auto tsv26Skip2 = "c\n";

    auto tsv27Skip2 = "";
    auto tsv28Skip2 = "";
    auto tsv29Skip2 = " \n";

    auto csvSet =
        [csv1, csv2, csv3, csv4, csv5, csv6, csv7, csv8, csv9, csv10,
         csv11, csv12, csv13, csv14, csv15, csv16, csv17, csv18, csv19, csv20,
         csv21, csv22, csv23, csv24, csv25, csv26, csv27, csv28, csv29];

    auto tsvSkip1Set =
        [tsv1Skip1, tsv2Skip1, tsv3Skip1, tsv4Skip1, tsv5Skip1, tsv6Skip1, tsv7Skip1, tsv8Skip1, tsv9Skip1, tsv10Skip1,
         tsv11Skip1, tsv12Skip1, tsv13Skip1, tsv14Skip1, tsv15Skip1, tsv16Skip1, tsv17Skip1, tsv18Skip1, tsv19Skip1, tsv20Skip1,
         tsv21Skip1, tsv22Skip1, tsv23Skip1, tsv24Skip1, tsv25Skip1, tsv26Skip1, tsv27Skip1, tsv28Skip1, tsv29Skip1];

    auto tsvSkip2Set =
        [tsv1Skip2, tsv2Skip2, tsv3Skip2, tsv4Skip2, tsv5Skip2, tsv6Skip2, tsv7Skip2, tsv8Skip2, tsv9Skip2, tsv10Skip2,
         tsv11Skip2, tsv12Skip2, tsv13Skip2, tsv14Skip2, tsv15Skip2, tsv16Skip2, tsv17Skip2, tsv18Skip2, tsv19Skip2, tsv20Skip2,
         tsv21Skip2, tsv22Skip2, tsv23Skip2, tsv24Skip2, tsv25Skip2, tsv26Skip2, tsv27Skip2, tsv28Skip2, tsv29Skip2];

    auto bufferSizeTests = [1, 2, 3, 4, 8, 128];

    foreach (bufferSize; bufferSizeTests)
    {
        ubyte[] readBuffer = new ubyte[](bufferSize);

        foreach (i, csv, tsvSkip1, tsvSkip2; lockstep(csvSet, tsvSkip1Set, tsvSkip2Set))
        {
            ubyte[] csvInput = csv.dup.representation;
            auto csvToTSVSkip1 = appender!(char[])();
            auto csvToTSVSkip2 = appender!(char[])();

            csv2tsv(csvInput, csvToTSVSkip1, readBuffer, "csvToTSVSkip1", 1);

            assert(tsvSkip1 == csvToTSVSkip1.data,
                   format("Unittest failure. tsv != csvToTSV.data. Test: %d; buffer size: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                          i + 1, bufferSize, csv, tsvSkip1, csvToTSVSkip1.data));

            csv2tsv(csvInput, csvToTSVSkip2, readBuffer, "csvToTSVSkip2", 2);

            assert(tsvSkip2 == csvToTSVSkip2.data,
                   format("Unittest failure. tsv != csvToTSV.data. Test: %d; buffer size: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                          i + 1, bufferSize, csv, tsvSkip2, csvToTSVSkip2.data));
        }
    }
}

// csv2tsv BOM tests. Note: std.range.lockstep prevents use of @safe
unittest
{
    import std.conv : hexString;
    import std.string : representation;

    enum utf8BOM = hexString!"efbbbf";

    auto csv1 = "";
    auto csv2 = "a";
    auto csv3 = "ab";
    auto csv4 = "a,b";
    auto csv5 = "a,b\ncdef,ghi\njklmn,opqrs\ntuv,wxyz";

    auto csv1BOM = utf8BOM ~ csv1;
    auto csv2BOM = utf8BOM ~ csv2;
    auto csv3BOM = utf8BOM ~ csv3;
    auto csv4BOM = utf8BOM ~ csv4;
    auto csv5BOM = utf8BOM ~ csv5;

    auto tsv1 = "";
    auto tsv2 = "a\n";
    auto tsv3 = "ab\n";
    auto tsv4 = "a\tb\n";
    auto tsv5 = "a\tb\ncdef\tghi\njklmn\topqrs\ntuv\twxyz\n";

    /* Note: csv1 is the empty string, so tsv1 does not have a trailing newline.
     * However, with the BOM prepended the tsv gets a trailing newline.
     */
    auto tsv1BOM = utf8BOM ~ tsv1 ~ "\n";
    auto tsv2BOM = utf8BOM ~ tsv2;
    auto tsv3BOM = utf8BOM ~ tsv3;
    auto tsv4BOM = utf8BOM ~ tsv4;
    auto tsv5BOM = utf8BOM ~ tsv5;

    auto csvSet = [csv1, csv2, csv3, csv4, csv5];
    auto csvBOMSet = [csv1BOM, csv2BOM, csv3BOM, csv4BOM, csv5BOM];

    auto tsvSet = [tsv1, tsv2, tsv3, tsv4, tsv5];
    auto tsvBOMSet = [tsv1BOM, tsv2BOM, tsv3BOM, tsv4BOM, tsv5BOM];

    auto bufferSizeTests = [1, 2, 3, 4, 8, 128];

    foreach (bufferSize; bufferSizeTests)
    {
        ubyte[] readBuffer = new ubyte[](bufferSize);

        foreach (i, csv, csvBOM, tsv, tsvBOM; lockstep(csvSet, csvBOMSet, tsvSet, tsvBOMSet))
        {
            ubyte[] csvInput = csv.dup.representation;
            ubyte[] csvBOMInput = csvBOM.dup.representation;

            auto csvToTSV = appender!(char[])();
            auto csvToTSV_NoBOMRemoval = appender!(char[])();
            auto csvBOMToTSV = appender!(char[])();
            auto csvBOMToTSV_NoBOMRemoval = appender!(char[])();

            csv2tsv(csvInput, csvToTSV, readBuffer, "csvToTSV", 0, '"', ',', '\t', " ", " ", true);
            assert(tsv == csvToTSV.data,
                   format("Unittest failure. tsv != csvToTSV.data. Test: %d; buffer size: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                          i + 1, bufferSize, csv, tsv, csvToTSV.data));

            csv2tsv(csvInput, csvToTSV_NoBOMRemoval, readBuffer, "csvToTSV_NoBOMRemoval", 0, '"', ',', '\t', " ", " ", false);
            assert(tsv == csvToTSV_NoBOMRemoval.data,
                   format("Unittest failure. tsv != csvToTSV_NoBOMRemoval.data. Test: %d; buffer size: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                          i + 1, bufferSize, csv, tsv, csvToTSV_NoBOMRemoval.data));

            csv2tsv(csvBOMInput, csvBOMToTSV, readBuffer, "csvBOMToTSV", 0, '"', ',', '\t', " ", " ", true);
            if (readBuffer.length < utf8BOM.length)
            {
                /* Removing BOMs, but didn't provide enough buffer, so no removal. */
                assert(tsvBOM == csvBOMToTSV.data,
                       format("Unittest failure. tsvBOM != csvBOMToTSV.data. (Small buffer) Test: %d; buffer size: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                              i + 1, bufferSize, csv, tsv, csvBOMToTSV.data));
            }
            else
            {
                assert(tsv == csvBOMToTSV.data,
                       format("Unittest failure. tsv != csvBOMToTSV.data. Test: Test: %d; buffer size: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                              i + 1, bufferSize, csv, tsv, csvBOMToTSV.data));
            }

            csv2tsv(csvBOMInput, csvBOMToTSV_NoBOMRemoval, readBuffer, "csvBOMToTSV_NoBOMRemoval", 0, '"', ',', '\t', " ", " ", false);
            assert(tsvBOM == csvBOMToTSV_NoBOMRemoval.data,
                   format("Unittest failure. tsvBOM != csvBOMToTSV_NoBOMRemoval.data. Test: Test: %d; buffer size: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                          i + 1, bufferSize, csv, tsv, csvBOMToTSV_NoBOMRemoval.data));
        }
    }
}
