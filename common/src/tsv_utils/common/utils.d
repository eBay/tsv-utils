/**
Utilities used by tsv-utils applications. InputFieldReordering, BufferedOutputRange,
and a several others.

Utilities in this file:
$(LIST
    * [InputFieldReordering] - A class that creates a reordered subset of fields from
      an input line. Fields in the subset are accessed by array indicies. This is
      especially useful when processing the subset in a specific order, such as the
      order listed on the command-line at run-time.

    * [BufferedOutputRange] - An OutputRange with an internal buffer used to buffer
      output. Intended for use with stdout, it is a significant performance benefit.

    * [isFlushableOutputRange] - Tests if something is an OutputRange with a flush
      member.

    * [bufferedByLine] - An input range that reads from a File handle line by line.
      It is similar to the standard library method std.stdio.File.byLine, but quite a
      bit faster. This is achieved by reading in larger blocks and buffering.

    * [InputSourceRange] - An input range that provides open file access to a set of
      files. It is used to iterate over files passed as command line arguments. This
      enable reading header line of a file during command line argument process, then
      passing the open file to the main processing functions.

    * [ByLineSourceRange] - Similar to an InputSourceRange, except that it provides
      access to a byLine iterator (bufferedByLine) rather than an open file. This is
      used by tools that run the same processing logic both header non-header lines.

    * [isBufferableInputSource] - Tests if a file or input range can be read in a
      buffered fashion by inputSourceByChunk.

    * [inputSourceByChunk] - Returns a range that reads from a file handle (File) or
      a ubyte input range a chunk at a time.

    * [joinAppend] - A function that performs a join, but appending the join output to
      an output stream. It is a performance improvement over using join or joiner with
      writeln.

    * [getTsvFieldValue] - A convenience function when only a single value is needed
      from an input line.

    * [throwIfWindowsNewlineOnUnix] - A utility for Unix platform builds to detecting
      Windows newlines in input.
)

Copyright (c) 2015-2020, eBay Inc.
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)
*/

module tsv_utils.common.utils;

import std.range;
import std.stdio : File, isFileHandle, KeepTerminator;
import std.traits : isIntegral, isSomeChar, isSomeString, isUnsigned, ReturnType, Unqual;
import std.typecons : Flag, No, Yes;

// InputFieldReording class.

/** Flag used by the InputFieldReordering template. */
alias EnablePartialLines = Flag!"enablePartialLines";

/**
InputFieldReordering - Move select fields from an input line to an output array,
reordering along the way.

The InputFieldReordering class is used to reorder a subset of fields from an input line.
The caller instantiates an InputFieldReordering object at the start of input processing.
The instance contains a mapping from input index to output index, plus a buffer holding
the reordered fields. The caller processes each input line by calling initNewLine,
splitting the line into fields, and calling processNextField on each field. The output
buffer is ready when the allFieldsFilled method returns true.

Fields are not copied, instead the output buffer points to the fields passed by the caller.
The caller needs to use or copy the output buffer while the fields are still valid, which
is normally until reading the next input line. The program below illustrates the basic use
case. It reads stdin and outputs fields [3, 0, 2], in that order. (See also joinAppend,
below, which has a performance improvement over join used here.)

---
int main(string[] args)
{
    import tsv_utils.common.utils;
    import std.algorithm, std.array, std.range, std.stdio;
    size_t[] fieldIndicies = [3, 0, 2];
    auto fieldReordering = new InputFieldReordering!char(fieldIndicies);
    foreach (line; stdin.byLine)
    {
        fieldReordering.initNewLine;
        foreach(fieldIndex, fieldValue; line.splitter('\t').enumerate)
        {
            fieldReordering.processNextField(fieldIndex, fieldValue);
            if (fieldReordering.allFieldsFilled) break;
        }
        if (fieldReordering.allFieldsFilled)
        {
            writeln(fieldReordering.outputFields.join('\t'));
        }
        else
        {
            writeln("Error: Insufficient number of field on the line.");
        }
    }
    return 0;
}
---

Field indicies are zero-based. An individual field can be listed multiple times. The
outputFields array is not valid until all the specified fields have been processed. The
allFieldsFilled method tests this. If a line does not have enough fields the outputFields
buffer cannot be used. For most TSV applications this is okay, as it means the line is
invalid and cannot be used. However, if partial lines are okay, the template can be
instantiated with EnablePartialLines.yes. This will ensure that any fields not filled-in
are empty strings in the outputFields return.
*/
final class InputFieldReordering(C, EnablePartialLines partialLinesOk = EnablePartialLines.no)
if (isSomeChar!C)
{
    /* Implementation: The class works by creating an array of tuples mapping the input
     * field index to the location in the outputFields array. The 'fromToMap' array is
     * sorted in input field order, enabling placement in the outputFields buffer during a
     * pass over the input fields. The map is created by the constructor. An example:
     *
     *    inputFieldIndicies: [3, 0, 7, 7, 1, 0, 9]
     *             fromToMap: [<0,1>, <0,5>, <1,4>, <3,0>, <7,2>, <7,3>, <9,6>]
     *
     * During processing of an a line, an array slice, mapStack, is used to track how
     * much of the fromToMap remains to be processed.
     */
    import std.typecons : Tuple;

    alias TupleFromTo = Tuple!(size_t, "from", size_t, "to");

    private C[][] outputFieldsBuf;
    private TupleFromTo[] fromToMap;
    private TupleFromTo[] mapStack;

    final this(const ref size_t[] inputFieldIndicies, size_t start = 0) pure nothrow @safe
    {
        import std.algorithm : sort;

        outputFieldsBuf = new C[][](inputFieldIndicies.length);
        fromToMap.reserve(inputFieldIndicies.length);

        foreach (to, from; inputFieldIndicies.enumerate(start))
        {
            fromToMap ~= TupleFromTo(from, to);
        }

        sort(fromToMap);
        initNewLine;
    }

    /** initNewLine initializes the object for a new line. */
    final void initNewLine() pure nothrow @safe
    {
        mapStack = fromToMap;
        static if (partialLinesOk)
        {
            import std.algorithm : each;
            outputFieldsBuf.each!((ref s) => s.length = 0);
        }
    }

    /** processNextField maps an input field to the correct locations in the
     * outputFields array.
     *
     * processNextField should be called once for each field on the line, in the order
     * found. The processing of the line can terminate once allFieldsFilled returns
     * true.
     *
     * The return value is the number of output fields the input field maps to. Zero
     * means the field is not mapped to the output fields array.
     *
     * If, prior to allFieldsProcessed returning true, any fields on the input line
     * are not passed to processNextField, the caller should either ensure the fields
     * are not part of the output fields or have partial lines enabled.
     */
    final size_t processNextField(size_t fieldIndex, C[] fieldValue) pure nothrow @safe @nogc
    {
        size_t numFilled = 0;
        while (!mapStack.empty && fieldIndex == mapStack.front.from)
        {
            outputFieldsBuf[mapStack.front.to] = fieldValue;
            mapStack.popFront;
            numFilled++;
        }
        return numFilled;
    }

    /** allFieldsFilled returned true if all fields expected have been processed. */
    final bool allFieldsFilled() const pure nothrow @safe @nogc
    {
        return mapStack.empty;
    }

    /** outputFields is the assembled output fields. Unless partial lines are enabled,
     * it is only valid after allFieldsFilled is true.
     */
    final C[][] outputFields() pure nothrow @safe @nogc
    {
        return outputFieldsBuf[];
    }
}

// InputFieldReordering - Tests using different character types.
@safe unittest
{
    import std.conv : to;

    auto inputLines = [["r1f0", "r1f1", "r1f2",   "r1f3"],
                       ["r2f0", "abc",  "ÀBCßßZ", "ghi"],
                       ["r3f0", "123",  "456",    "789"]];

    size_t[] fields_2_0 = [2, 0];

    auto expected_2_0 = [["r1f2",   "r1f0"],
                         ["ÀBCßßZ", "r2f0"],
                         ["456",    "r3f0"]];

    char[][][]  charExpected_2_0 = to!(char[][][])(expected_2_0);
    wchar[][][] wcharExpected_2_0 = to!(wchar[][][])(expected_2_0);
    dchar[][][] dcharExpected_2_0 = to!(dchar[][][])(expected_2_0);
    dstring[][] dstringExpected_2_0 = to!(dstring[][])(expected_2_0);

    auto charIFR  = new InputFieldReordering!char(fields_2_0);
    auto wcharIFR = new InputFieldReordering!wchar(fields_2_0);
    auto dcharIFR = new InputFieldReordering!dchar(fields_2_0);

    foreach (lineIndex, line; inputLines)
    {
        charIFR.initNewLine;
        wcharIFR.initNewLine;
        dcharIFR.initNewLine;

        foreach (fieldIndex, fieldValue; line)
        {
            charIFR.processNextField(fieldIndex, to!(char[])(fieldValue));
            wcharIFR.processNextField(fieldIndex, to!(wchar[])(fieldValue));
            dcharIFR.processNextField(fieldIndex, to!(dchar[])(fieldValue));

            assert ((fieldIndex >= 2) == charIFR.allFieldsFilled);
            assert ((fieldIndex >= 2) == wcharIFR.allFieldsFilled);
            assert ((fieldIndex >= 2) == dcharIFR.allFieldsFilled);
        }
        assert(charIFR.allFieldsFilled);
        assert(wcharIFR.allFieldsFilled);
        assert(dcharIFR.allFieldsFilled);

        assert(charIFR.outputFields == charExpected_2_0[lineIndex]);
        assert(wcharIFR.outputFields == wcharExpected_2_0[lineIndex]);
        assert(dcharIFR.outputFields == dcharExpected_2_0[lineIndex]);
    }
}

// InputFieldReordering - Test of partial line support.
@safe unittest
{
    import std.conv : to;

    auto inputLines = [["r1f0", "r1f1", "r1f2",   "r1f3"],
                       ["r2f0", "abc",  "ÀBCßßZ", "ghi"],
                       ["r3f0", "123",  "456",    "789"]];

    size_t[] fields_2_0 = [2, 0];

    // The expected states of the output field while each line and field are processed.
    auto expectedBylineByfield_2_0 =
        [
            [["", "r1f0"], ["", "r1f0"], ["r1f2", "r1f0"],   ["r1f2", "r1f0"]],
            [["", "r2f0"], ["", "r2f0"], ["ÀBCßßZ", "r2f0"], ["ÀBCßßZ", "r2f0"]],
            [["", "r3f0"], ["", "r3f0"], ["456", "r3f0"],    ["456", "r3f0"]],
        ];

    char[][][][]  charExpectedBylineByfield_2_0 = to!(char[][][][])(expectedBylineByfield_2_0);

    auto charIFR  = new InputFieldReordering!(char, EnablePartialLines.yes)(fields_2_0);

    foreach (lineIndex, line; inputLines)
    {
        charIFR.initNewLine;
        foreach (fieldIndex, fieldValue; line)
        {
            charIFR.processNextField(fieldIndex, to!(char[])(fieldValue));
            assert(charIFR.outputFields == charExpectedBylineByfield_2_0[lineIndex][fieldIndex]);
        }
    }
}

// InputFieldReordering - Field combination tests.
@safe unittest
{
    import std.conv : to;
    import std.stdio;

    auto inputLines = [["00", "01", "02", "03"],
                       ["10", "11", "12", "13"],
                       ["20", "21", "22", "23"]];

    size_t[] fields_0 = [0];
    size_t[] fields_3 = [3];
    size_t[] fields_01 = [0, 1];
    size_t[] fields_10 = [1, 0];
    size_t[] fields_03 = [0, 3];
    size_t[] fields_30 = [3, 0];
    size_t[] fields_0123 = [0, 1, 2, 3];
    size_t[] fields_3210 = [3, 2, 1, 0];
    size_t[] fields_03001 = [0, 3, 0, 0, 1];

    auto expected_0 = to!(char[][][])([["00"],
                                       ["10"],
                                       ["20"]]);

    auto expected_3 = to!(char[][][])([["03"],
                                       ["13"],
                                       ["23"]]);

    auto expected_01 = to!(char[][][])([["00", "01"],
                                        ["10", "11"],
                                        ["20", "21"]]);

    auto expected_10 = to!(char[][][])([["01", "00"],
                                        ["11", "10"],
                                        ["21", "20"]]);

    auto expected_03 = to!(char[][][])([["00", "03"],
                                        ["10", "13"],
                                        ["20", "23"]]);

    auto expected_30 = to!(char[][][])([["03", "00"],
                                        ["13", "10"],
                                        ["23", "20"]]);

    auto expected_0123 = to!(char[][][])([["00", "01", "02", "03"],
                                          ["10", "11", "12", "13"],
                                          ["20", "21", "22", "23"]]);

    auto expected_3210 = to!(char[][][])([["03", "02", "01", "00"],
                                          ["13", "12", "11", "10"],
                                          ["23", "22", "21", "20"]]);

    auto expected_03001 = to!(char[][][])([["00", "03", "00", "00", "01"],
                                           ["10", "13", "10", "10", "11"],
                                           ["20", "23", "20", "20", "21"]]);

    auto ifr_0 = new InputFieldReordering!char(fields_0);
    auto ifr_3 = new InputFieldReordering!char(fields_3);
    auto ifr_01 = new InputFieldReordering!char(fields_01);
    auto ifr_10 = new InputFieldReordering!char(fields_10);
    auto ifr_03 = new InputFieldReordering!char(fields_03);
    auto ifr_30 = new InputFieldReordering!char(fields_30);
    auto ifr_0123 = new InputFieldReordering!char(fields_0123);
    auto ifr_3210 = new InputFieldReordering!char(fields_3210);
    auto ifr_03001 = new InputFieldReordering!char(fields_03001);

    foreach (lineIndex, line; inputLines)
    {
        ifr_0.initNewLine;
        ifr_3.initNewLine;
        ifr_01.initNewLine;
        ifr_10.initNewLine;
        ifr_03.initNewLine;
        ifr_30.initNewLine;
        ifr_0123.initNewLine;
        ifr_3210.initNewLine;
        ifr_03001.initNewLine;

        foreach (fieldIndex, fieldValue; line)
        {
            ifr_0.processNextField(fieldIndex, to!(char[])(fieldValue));
            ifr_3.processNextField(fieldIndex, to!(char[])(fieldValue));
            ifr_01.processNextField(fieldIndex, to!(char[])(fieldValue));
            ifr_10.processNextField(fieldIndex, to!(char[])(fieldValue));
            ifr_03.processNextField(fieldIndex, to!(char[])(fieldValue));
            ifr_30.processNextField(fieldIndex, to!(char[])(fieldValue));
            ifr_0123.processNextField(fieldIndex, to!(char[])(fieldValue));
            ifr_3210.processNextField(fieldIndex, to!(char[])(fieldValue));
            ifr_03001.processNextField(fieldIndex, to!(char[])(fieldValue));
        }

        assert(ifr_0.outputFields == expected_0[lineIndex]);
        assert(ifr_3.outputFields == expected_3[lineIndex]);
        assert(ifr_01.outputFields == expected_01[lineIndex]);
        assert(ifr_10.outputFields == expected_10[lineIndex]);
        assert(ifr_03.outputFields == expected_03[lineIndex]);
        assert(ifr_30.outputFields == expected_30[lineIndex]);
        assert(ifr_0123.outputFields == expected_0123[lineIndex]);
        assert(ifr_3210.outputFields == expected_3210[lineIndex]);
        assert(ifr_03001.outputFields == expected_03001[lineIndex]);
    }
}

/**
BufferedOutputRange is a performance enhancement over writing directly to an output
stream. It holds a File open for write or an OutputRange. Ouput is accumulated in an
internal buffer and written to the output stream as a block.

Writing to stdout is a key use case. BufferedOutputRange is often dramatically faster
than writing to stdout directly. This is especially noticable for outputs with short
lines, as it blocks many writes together in a single write.

The internal buffer is written to the output stream after flushSize has been reached.
This is checked at newline boundaries, when appendln is called or when put is called
with a single newline character. Other writes check maxSize, which is used to avoid
runaway buffers.

BufferedOutputRange has a put method allowing it to be used a range. It has a number
of other methods providing additional control.

$(LIST
    * `this(outputStream [, flushSize, reserveSize, maxSize])` - Constructor. Takes the
      output stream, e.g. stdout. Other arguments are optional, defaults normally suffice.

    * `append(stuff)` - Append to the internal buffer.

    * `appendln(stuff)` - Append to the internal buffer, followed by a newline. The buffer
      is flushed to the output stream if is has reached flushSize.

    * `appendln()` - Append a newline to the internal buffer. The buffer is flushed to the
      output stream if is has reached flushSize.

    * `joinAppend(inputRange, delim)` - An optimization of `append(inputRange.joiner(delim))`.
      For reasons that are not clear, joiner is quite slow.

    * `flushIfFull()` - Flush the internal buffer to the output stream if flushSize has been
      reached.

    * `flush()` - Write the internal buffer to the output stream.

    * `put(stuff)` - Appends to the internal buffer. Acts as `appendln()` if passed a single
      newline character, '\n' or "\n".
)

The internal buffer is automatically flushed when the BufferedOutputRange goes out of
scope.
*/
struct BufferedOutputRange(OutputTarget)
if (isFileHandle!(Unqual!OutputTarget) || isOutputRange!(Unqual!OutputTarget, char))
{
    import std.array : appender;
    import std.format : format;

    /* Identify the output element type. Only supporting char and ubyte for now. */
    static if (isFileHandle!OutputTarget || isOutputRange!(OutputTarget, char))
    {
        alias C = char;
    }
    else static if (isOutputRange!(OutputTarget, ubyte))
    {
        alias C = ubyte;
    }
    else static assert(false);

    private enum defaultReserveSize = 11264;
    private enum defaultFlushSize = 10240;
    private enum defaultMaxSize = 4194304;

    private OutputTarget _outputTarget;
    private auto _outputBuffer = appender!(C[]);
    private immutable size_t _flushSize;
    private immutable size_t _maxSize;

    this(OutputTarget outputTarget,
         size_t flushSize = defaultFlushSize,
         size_t reserveSize = defaultReserveSize,
         size_t maxSize = defaultMaxSize)
    {
        assert(flushSize <= maxSize);

        _outputTarget = outputTarget;
        _flushSize = flushSize;
        _maxSize = (flushSize <= maxSize) ? maxSize : flushSize;
        _outputBuffer.reserve(reserveSize);
    }

    ~this()
    {
        flush();
    }

    void flush()
    {
        static if (isFileHandle!OutputTarget) _outputTarget.rawWrite(_outputBuffer.data);
        else _outputTarget.put(_outputBuffer.data);

        _outputBuffer.clear;
    }

    bool flushIfFull()
    {
        bool isFull = _outputBuffer.data.length >= _flushSize;
        if (isFull) flush();
        return isFull;
    }

    /* flushIfMaxSize is a safety check to avoid runaway buffer growth. */
    void flushIfMaxSize()
    {
        if (_outputBuffer.data.length >= _maxSize) flush();
    }

    /* maybeFlush is intended for the case where put is called with a trailing newline.
     *
     * Flushing occurs if the buffer has a trailing newline and has reached flush size.
     * Flushing also occurs if the buffer has reached max size.
     */
    private bool maybeFlush()
    {
        immutable bool doFlush =
            _outputBuffer.data.length >= _flushSize &&
            (_outputBuffer.data[$-1] == '\n' || _outputBuffer.data.length >= _maxSize);

        if (doFlush) flush();
        return doFlush;
    }


    private void appendRaw(T)(T stuff) pure
    {
        import std.range : rangePut = put;
        rangePut(_outputBuffer, stuff);
    }

    void append(T)(T stuff)
    {
        appendRaw(stuff);
        maybeFlush();
    }

    bool appendln()
    {
        appendRaw('\n');
        return flushIfFull();
    }

    bool appendln(T)(T stuff)
    {
        appendRaw(stuff);
        return appendln();
    }

    /* joinAppend is an optimization of append(inputRange.joiner(delimiter).
     * This form is quite a bit faster, 40%+ on some benchmarks.
     */
    void joinAppend(InputRange, E)(InputRange inputRange, E delimiter)
    if (isInputRange!InputRange &&
        is(ElementType!InputRange : const C[]) &&
        (is(E : const C[]) || is(E : const C)))
    {
        if (!inputRange.empty)
        {
            appendRaw(inputRange.front);
            inputRange.popFront;
        }
        foreach (x; inputRange)
        {
            appendRaw(delimiter);
            appendRaw(x);
        }
        flushIfMaxSize();
    }

    /* Make this an output range. */
    void put(T)(T stuff)
    {
        import std.traits;
        import std.stdio;

        static if (isSomeChar!T)
        {
            if (stuff == '\n') appendln();
            else appendRaw(stuff);
        }
        else static if (isSomeString!T)
        {
            if (stuff == "\n") appendln();
            else append(stuff);
        }
        else append(stuff);
    }
}

// BufferedOutputRange.
unittest
{
    import tsv_utils.common.unittest_utils;
    import std.file : rmdirRecurse, readText;
    import std.path : buildPath;

    auto testDir = makeUnittestTempDir("tsv_utils_buffered_output");
    scope(exit) testDir.rmdirRecurse;

    import std.algorithm : map, joiner;
    import std.range : iota;
    import std.conv : to;

    /* Basic test. Note that exiting the scope triggers flush. */
    string filepath1 = buildPath(testDir, "file1.txt");
    {
        import std.stdio : File;

        auto ostream = BufferedOutputRange!File(filepath1.File("wb"));
        ostream.append("file1: ");
        ostream.append("abc");
        ostream.append(["def", "ghi", "jkl"]);
        ostream.appendln(100.to!string);
        ostream.append(iota(0, 10).map!(x => x.to!string).joiner(" "));
        ostream.appendln();
    }
    assert(filepath1.readText == "file1: abcdefghijkl100\n0 1 2 3 4 5 6 7 8 9\n");

    /* Test with no reserve and no flush at every line. */
    string filepath2 = buildPath(testDir, "file2.txt");
    {
        import std.stdio : File;

        auto ostream = BufferedOutputRange!File(filepath2.File("wb"), 0, 0);
        ostream.append("file2: ");
        ostream.append("abc");
        ostream.append(["def", "ghi", "jkl"]);
        ostream.appendln("100");
        ostream.append(iota(0, 10).map!(x => x.to!string).joiner(" "));
        ostream.appendln();
    }
    assert(filepath2.readText == "file2: abcdefghijkl100\n0 1 2 3 4 5 6 7 8 9\n");

    /* With a locking text writer. Requires version 2.078.0
       See: https://issues.dlang.org/show_bug.cgi?id=9661
     */
    static if (__VERSION__ >= 2078)
    {
        string filepath3 = buildPath(testDir, "file3.txt");
        {
            import std.stdio : File;

            auto ltw = filepath3.File("wb").lockingTextWriter;
            {
                auto ostream = BufferedOutputRange!(typeof(ltw))(ltw);
                ostream.append("file3: ");
                ostream.append("abc");
                ostream.append(["def", "ghi", "jkl"]);
                ostream.appendln("100");
                ostream.append(iota(0, 10).map!(x => x.to!string).joiner(" "));
                ostream.appendln();
            }
        }
        assert(filepath3.readText == "file3: abcdefghijkl100\n0 1 2 3 4 5 6 7 8 9\n");
    }

    /* With an Appender. */
    import std.array : appender;
    auto app1 = appender!(char[]);
    {
        auto ostream = BufferedOutputRange!(typeof(app1))(app1);
        ostream.append("appender1: ");
        ostream.append("abc");
        ostream.append(["def", "ghi", "jkl"]);
        ostream.appendln("100");
        ostream.append(iota(0, 10).map!(x => x.to!string).joiner(" "));
        ostream.appendln();
    }
    assert(app1.data == "appender1: abcdefghijkl100\n0 1 2 3 4 5 6 7 8 9\n");

    /* With an Appender, but checking flush boundaries. */
    auto app2 = appender!(char[]);
    {
        auto ostream = BufferedOutputRange!(typeof(app2))(app2, 10, 0); // Flush if 10+
        bool wasFlushed = false;

        assert(app2.data == "");

        ostream.append("12345678"); // Not flushed yet.
        assert(app2.data == "");

        wasFlushed = ostream.appendln;  // Nineth char, not flushed yet.
        assert(!wasFlushed);
        assert(app2.data == "");

        wasFlushed = ostream.appendln;  // Tenth char, now flushed.
        assert(wasFlushed);
        assert(app2.data == "12345678\n\n");

        app2.clear;
        assert(app2.data == "");

        ostream.append("12345678");

        wasFlushed = ostream.flushIfFull;
        assert(!wasFlushed);
        assert(app2.data == "");

        ostream.flush;
        assert(app2.data == "12345678");

        app2.clear;
        assert(app2.data == "");

        ostream.append("123456789012345");
        assert(app2.data == "");
    }
    assert(app2.data == "123456789012345");

    /* Using joinAppend. */
    auto app1b = appender!(char[]);
    {
        auto ostream = BufferedOutputRange!(typeof(app1b))(app1b);
        ostream.append("appenderB: ");
        ostream.joinAppend(["a", "bc", "def"], '-');
        ostream.append(':');
        ostream.joinAppend(["g", "hi", "jkl"], '-');
        ostream.appendln("*100*");
        ostream.joinAppend(iota(0, 6).map!(x => x.to!string), ' ');
        ostream.append(' ');
        ostream.joinAppend(iota(6, 10).map!(x => x.to!string), " ");
        ostream.appendln();
    }
    assert(app1b.data == "appenderB: a-bc-def:g-hi-jkl*100*\n0 1 2 3 4 5 6 7 8 9\n",
           "app1b.data: |" ~app1b.data ~ "|");

    /* Operating as an output range. When passed to a function as a ref, exiting
     * the function does not flush. When passed as a value, it get flushed when
     * the function returns. Also test both UCFS and non-UFCS styles.
     */

    void outputStuffAsRef(T)(ref T range)
    if (isOutputRange!(T, char))
    {
        range.put('1');
        put(range, "23");
        range.put('\n');
        range.put(["5", "67"]);
        put(range, iota(8, 10).map!(x => x.to!string));
        put(range, "\n");
    }

    void outputStuffAsVal(T)(T range)
    if (isOutputRange!(T, char))
    {
        put(range, '1');
        range.put("23");
        put(range, '\n');
        put(range, ["5", "67"]);
        range.put(iota(8, 10).map!(x => x.to!string));
        range.put("\n");
    }

    auto app3 = appender!(char[]);
    {
        auto ostream = BufferedOutputRange!(typeof(app3))(app3, 12, 0);
        outputStuffAsRef(ostream);
        assert(app3.data == "", "app3.data: |" ~app3.data ~ "|");
        outputStuffAsRef(ostream);
        assert(app3.data == "123\n56789\n123\n", "app3.data: |" ~app3.data ~ "|");
    }
    assert(app3.data == "123\n56789\n123\n56789\n", "app3.data: |" ~app3.data ~ "|");

    auto app4 = appender!(char[]);
    {
        auto ostream = BufferedOutputRange!(typeof(app4))(app4, 12, 0);
        outputStuffAsVal(ostream);
        assert(app4.data == "123\n56789\n", "app4.data: |" ~app4.data ~ "|");
        outputStuffAsVal(ostream);
        assert(app4.data == "123\n56789\n123\n56789\n", "app4.data: |" ~app4.data ~ "|");
    }
    assert(app4.data == "123\n56789\n123\n56789\n", "app4.data: |" ~app4.data ~ "|");

    /* Test maxSize. */
    auto app5 = appender!(char[]);
    {
        auto ostream = BufferedOutputRange!(typeof(app5))(app5, 5, 0, 10); // maxSize 10
        assert(app5.data == "");

        ostream.append("1234567");  // Not flushed yet (no newline).
        assert(app5.data == "");

        ostream.append("89012");    // Flushed by maxSize
        assert(app5.data == "123456789012");

        ostream.put("1234567");     // Not flushed yet (no newline).
        assert(app5.data == "123456789012");

        ostream.put("89012");       // Flushed by maxSize
        assert(app5.data == "123456789012123456789012");

        ostream.joinAppend(["ab", "cd"], '-');        // Not flushed yet
        ostream.joinAppend(["de", "gh", "ij"], '-');  // Flushed by maxSize
        assert(app5.data == "123456789012123456789012ab-cdde-gh-ij");
    }
    assert(app5.data == "123456789012123456789012ab-cdde-gh-ij");
}

/**
isFlushableOutputRange returns true if R is an output range with a flush member.
*/
enum bool isFlushableOutputRange(R, E=char) = isOutputRange!(R, E)
    && is(ReturnType!((R r) => r.flush) == void);

@safe unittest
{
    import std.array;
    auto app = appender!(char[]);
    auto ostream = BufferedOutputRange!(typeof(app))(app, 5, 0, 10); // maxSize 10

    static assert(isOutputRange!(typeof(app), char));
    static assert(!isFlushableOutputRange!(typeof(app), char));
    static assert(!isFlushableOutputRange!(typeof(app)));

    static assert(isOutputRange!(typeof(ostream), char));
    static assert(isFlushableOutputRange!(typeof(ostream), char));
    static assert(isFlushableOutputRange!(typeof(ostream)));

    static assert(isOutputRange!(Appender!string, string));
    static assert(!isFlushableOutputRange!(Appender!string, string));
    static assert(!isFlushableOutputRange!(Appender!string));

    static assert(isOutputRange!(Appender!(char[]), char));
    static assert(!isFlushableOutputRange!(Appender!(char[]), char));
    static assert(!isFlushableOutputRange!(Appender!(char[])));

    static assert(isOutputRange!(BufferedOutputRange!(Appender!(char[])), char));
    static assert(isFlushableOutputRange!(BufferedOutputRange!(Appender!(char[]))));
    static assert(isFlushableOutputRange!(BufferedOutputRange!(Appender!(char[])), char));
}


/**
bufferedByLine is a performance enhancement over std.stdio.File.byLine. It works by
reading a large buffer from the input stream rather than just a single line.

The file argument needs to be a File object open for reading, typically a filesystem
file or standard input. Use the Yes.keepTerminator template parameter to keep the
newline. This is similar to stdio.File.byLine, except specified as a template paramter
rather than a runtime parameter.

Reading in blocks does mean that input is not read until a full buffer is available or
end-of-file is reached. For this reason, bufferedByLine is not appropriate for
interactive input.
*/

auto bufferedByLine(KeepTerminator keepTerminator = No.keepTerminator, Char = char,
                    ubyte terminator = '\n', size_t readSize = 1024 * 128, size_t growSize = 1024 * 16)
    (File file)
if (is(Char == char) || is(Char == ubyte))
{
    static assert(0 < growSize && growSize <= readSize);

    static final class BufferedByLineImpl
    {
        /* Buffer state variables
         *   - _buffer.length - Full length of allocated buffer.
         *   - _dataEnd - End of currently valid data (end of last read).
         *   - _lineStart - Start of current line.
         *   - _lineEnd - End of current line.
         */
        private File _file;
        private ubyte[] _buffer;
        private size_t _lineStart = 0;
        private size_t _lineEnd = 0;
        private size_t _dataEnd = 0;

        this (File f)
        {
            _file = f;
            _buffer = new ubyte[readSize + growSize];
        }

        bool empty() const pure
        {
            return _file.eof && _lineStart == _dataEnd;
        }

        Char[] front() pure
        {
            assert(!empty, "Attempt to take the front of an empty bufferedByLine.");

            static if (keepTerminator == Yes.keepTerminator)
            {
                return cast(Char[]) _buffer[_lineStart .. _lineEnd];
            }
            else
            {
                assert(_lineStart < _lineEnd);
                immutable end = (_buffer[_lineEnd - 1] == terminator) ? _lineEnd - 1 : _lineEnd;
                return cast(Char[]) _buffer[_lineStart .. end];
            }
        }

        /* Note: Call popFront at initialization to do the initial read. */
        void popFront()
        {
            import std.algorithm: copy, find;
            assert(!empty, "Attempt to popFront an empty bufferedByLine.");

            /* Pop the current line. */
            _lineStart = _lineEnd;

            /* Set up the next line if more data is available, either in the buffer or
             * the file. The next line ends at the next newline, if there is one.
             *
             * Notes:
             * - 'find' returns the slice starting with the character searched for, or
             *   an empty range if not found.
             * - _lineEnd is set to _dataEnd both when the current buffer does not have
             *   a newline and when it ends with one.
             */
            auto found = _buffer[_lineStart .. _dataEnd].find(terminator);
            _lineEnd = found.empty ? _dataEnd : _dataEnd - found.length + 1;

            if (found.empty && !_file.eof)
            {
                /* No newline in current buffer. Read from the file until the next
                 * newline is found.
                 */
                assert(_lineEnd == _dataEnd);

                if (_lineStart > 0)
                {
                    /* Move remaining data to the start of the buffer. */
                    immutable remainingLength = _dataEnd - _lineStart;
                    copy(_buffer[_lineStart .. _dataEnd], _buffer[0 .. remainingLength]);
                    _lineStart = 0;
                    _lineEnd = _dataEnd = remainingLength;
                }

                do
                {
                    /* Grow the buffer if necessary. */
                    immutable availableSize = _buffer.length - _dataEnd;
                    if (availableSize < readSize)
                    {
                        size_t growBy = growSize;
                        while (availableSize + growBy < readSize) growBy += growSize;
                        _buffer.length += growBy;
                    }

                    /* Read the next block. */
                    _dataEnd +=
                        _file.rawRead(_buffer[_dataEnd .. _dataEnd + readSize])
                        .length;

                    found = _buffer[_lineEnd .. _dataEnd].find(terminator);
                    _lineEnd = found.empty ? _dataEnd : _dataEnd - found.length + 1;

                } while (found.empty && !_file.eof);
            }
        }
    }

    assert(file.isOpen, "bufferedByLine passed a closed file.");

    auto r = new BufferedByLineImpl(file);
    if (!r.empty) r.popFront;
    return r;
}

// BufferedByLine.
unittest
{
    import std.array : appender;
    import std.conv : to;
    import std.file : rmdirRecurse, readText;
    import std.path : buildPath;
    import std.range : lockstep;
    import std.stdio;
    import tsv_utils.common.unittest_utils;

    auto testDir = makeUnittestTempDir("tsv_utils_buffered_byline");
    scope(exit) testDir.rmdirRecurse;

    /* Create two data files with the same data. Read both in parallel with byLine and
     * bufferedByLine and compare each line.
     */
    auto data1 = appender!(char[])();

    foreach (i; 1 .. 1001) data1.put('\n');
    foreach (i; 1 .. 1001) data1.put("a\n");
    foreach (i; 1 .. 1001) { data1.put(i.to!string); data1.put('\n'); }
    foreach (i; 1 .. 1001)
    {
        foreach (j; 1 .. i+1) data1.put('x');
        data1.put('\n');
    }

    string file1a = buildPath(testDir, "file1a.txt");
    string file1b = buildPath(testDir, "file1b.txt");
    {
        auto f1aFH = file1a.File("wb");
        f1aFH.write(data1.data);
        f1aFH.close;

        auto f1bFH = file1b.File("wb");
        f1bFH.write(data1.data);
        f1bFH.close;
    }

    /* Default parameters. */
    {
        auto f1aFH = file1a.File();
        auto f1bFH = file1b.File();
        auto f1aIn = f1aFH.bufferedByLine!(No.keepTerminator);
        auto f1bIn = f1bFH.byLine(No.keepTerminator);

        foreach (a, b; lockstep(f1aIn, f1bIn, StoppingPolicy.requireSameLength)) assert(a == b);

        f1aFH.close;
        f1bFH.close;
    }
    {
        auto f1aFH = file1a.File();
        auto f1bFH = file1b.File();
        auto f1aIn = f1aFH.bufferedByLine!(Yes.keepTerminator);
        auto f1bIn = f1bFH.byLine(Yes.keepTerminator);

        foreach (a, b; lockstep(f1aIn, f1bIn, StoppingPolicy.requireSameLength)) assert(a == b);

        f1aFH.close;
        f1bFH.close;
    }

    /* Smaller read size. This will trigger buffer growth. */
    {
        auto f1aFH = file1a.File();
        auto f1bFH = file1b.File();
        auto f1aIn = f1aFH.bufferedByLine!(No.keepTerminator, char, '\n', 512, 256);
        auto f1bIn = f1bFH.byLine(No.keepTerminator);

        foreach (a, b; lockstep(f1aIn, f1bIn, StoppingPolicy.requireSameLength)) assert(a == b);

        f1aFH.close;
        f1bFH.close;
    }

    /* Exercise boundary cases in buffer growth.
     * Note: static-foreach requires DMD 2.076 / LDC 1.6
     */
    static foreach (readSize; [1, 2, 4])
    {
        static foreach (growSize; 1 .. readSize + 1)
        {{
            auto f1aFH = file1a.File();
            auto f1bFH = file1b.File();
            auto f1aIn = f1aFH.bufferedByLine!(No.keepTerminator, char, '\n', readSize, growSize);
            auto f1bIn = f1bFH.byLine(No.keepTerminator);

            foreach (a, b; lockstep(f1aIn, f1bIn, StoppingPolicy.requireSameLength)) assert(a == b);

            f1aFH.close;
            f1bFH.close;
        }}
        static foreach (growSize; 1 .. readSize + 1)
        {{
            auto f1aFH = file1a.File();
            auto f1bFH = file1b.File();
            auto f1aIn = f1aFH.bufferedByLine!(Yes.keepTerminator, char, '\n', readSize, growSize);
            auto f1bIn = f1bFH.byLine(Yes.keepTerminator);

            foreach (a, b; lockstep(f1aIn, f1bIn, StoppingPolicy.requireSameLength)) assert(a == b);

            f1aFH.close;
            f1bFH.close;
        }}
    }


    /* Files that do not end in a newline. */

    string file2a = buildPath(testDir, "file2a.txt");
    string file2b = buildPath(testDir, "file2b.txt");
    string file3a = buildPath(testDir, "file3a.txt");
    string file3b = buildPath(testDir, "file3b.txt");
    string file4a = buildPath(testDir, "file4a.txt");
    string file4b = buildPath(testDir, "file4b.txt");

    {
        auto f1aFH = file1a.File("wb");
        f1aFH.write("a");
        f1aFH.close;
    }
    {
        auto f1bFH = file1b.File("wb");
        f1bFH.write("a");
        f1bFH.close;
    }
    {
        auto f2aFH = file2a.File("wb");
        f2aFH.write("ab");
        f2aFH.close;
    }
    {
        auto f2bFH = file2b.File("wb");
        f2bFH.write("ab");
        f2bFH.close;
    }
    {
        auto f3aFH = file3a.File("wb");
        f3aFH.write("abc");
        f3aFH.close;
    }
    {
        auto f3bFH = file3b.File("wb");
        f3bFH.write("abc");
        f3bFH.close;
    }

    static foreach (readSize; [1, 2, 4])
    {
        static foreach (growSize; 1 .. readSize + 1)
        {{
            auto f1aFH = file1a.File();
            auto f1bFH = file1b.File();
            auto f1aIn = f1aFH.bufferedByLine!(No.keepTerminator, char, '\n', readSize, growSize);
            auto f1bIn = f1bFH.byLine(No.keepTerminator);

            foreach (a, b; lockstep(f1aIn, f1bIn, StoppingPolicy.requireSameLength)) assert(a == b);

            f1aFH.close;
            f1bFH.close;

            auto f2aFH = file2a.File();
            auto f2bFH = file2b.File();
            auto f2aIn = f2aFH.bufferedByLine!(No.keepTerminator, char, '\n', readSize, growSize);
            auto f2bIn = f2bFH.byLine(No.keepTerminator);

            foreach (a, b; lockstep(f2aIn, f2bIn, StoppingPolicy.requireSameLength)) assert(a == b);

            f2aFH.close;
            f2bFH.close;

            auto f3aFH = file3a.File();
            auto f3bFH = file3b.File();
            auto f3aIn = f3aFH.bufferedByLine!(No.keepTerminator, char, '\n', readSize, growSize);
            auto f3bIn = f3bFH.byLine(No.keepTerminator);

            foreach (a, b; lockstep(f3aIn, f3bIn, StoppingPolicy.requireSameLength)) assert(a == b);

            f3aFH.close;
            f3bFH.close;
        }}
        static foreach (growSize; 1 .. readSize + 1)
        {{
            auto f1aFH = file1a.File();
            auto f1bFH = file1b.File();
            auto f1aIn = f1aFH.bufferedByLine!(Yes.keepTerminator, char, '\n', readSize, growSize);
            auto f1bIn = f1bFH.byLine(Yes.keepTerminator);

            foreach (a, b; lockstep(f1aIn, f1bIn, StoppingPolicy.requireSameLength)) assert(a == b);

            f1aFH.close;
            f1bFH.close;

            auto f2aFH = file2a.File();
            auto f2bFH = file2b.File();
            auto f2aIn = f2aFH.bufferedByLine!(Yes.keepTerminator, char, '\n', readSize, growSize);
            auto f2bIn = f2bFH.byLine(Yes.keepTerminator);

            foreach (a, b; lockstep(f2aIn, f2bIn, StoppingPolicy.requireSameLength)) assert(a == b);

            f2aFH.close;
            f2bFH.close;

            auto f3aFH = file3a.File();
            auto f3bFH = file3b.File();
            auto f3aIn = f3aFH.bufferedByLine!(Yes.keepTerminator, char, '\n', readSize, growSize);
            auto f3bIn = f3bFH.byLine(Yes.keepTerminator);

            foreach (a, b; lockstep(f3aIn, f3bIn, StoppingPolicy.requireSameLength)) assert(a == b);

            f3aFH.close;
            f3bFH.close;
        }}
    }
}

/**
joinAppend performs a join operation on an input range, appending the results to
an output range.

joinAppend was written as a performance enhancement over using std.algorithm.joiner
or std.array.join with writeln. Using joiner with writeln is quite slow, 3-4x slower
than std.array.join with writeln. The joiner performance may be due to interaction
with writeln, this was not investigated. Using joiner with stdout.lockingTextWriter
is better, but still substantially slower than join. Using join works reasonably well,
but is allocating memory unnecessarily.

Using joinAppend with Appender is a bit faster than join, and allocates less memory.
The Appender re-uses the underlying data buffer, saving memory. The example below
illustrates. It is a modification of the InputFieldReordering example. The role
Appender plus joinAppend are playing is to buffer the output. BufferedOutputRange
uses a similar technique to buffer multiple lines.

Note: The original uses joinAppend have been replaced by BufferedOutputRange, which has
its own joinAppend method. However, joinAppend remains useful when constructing internal
buffers where BufferedOutputRange is not appropriate.

---
int main(string[] args)
{
    import tsvutil;
    import std.algorithm, std.array, std.range, std.stdio;
    size_t[] fieldIndicies = [3, 0, 2];
    auto fieldReordering = new InputFieldReordering!char(fieldIndicies);
    auto outputBuffer = appender!(char[]);
    foreach (line; stdin.byLine)
    {
        fieldReordering.initNewLine;
        foreach(fieldIndex, fieldValue; line.splitter('\t').enumerate)
        {
            fieldReordering.processNextField(fieldIndex, fieldValue);
            if (fieldReordering.allFieldsFilled) break;
        }
        if (fieldReordering.allFieldsFilled)
        {
            outputBuffer.clear;
            writeln(fieldReordering.outputFields.joinAppend(outputBuffer, ('\t')));
        }
        else
        {
            writeln("Error: Insufficient number of field on the line.");
        }
    }
    return 0;
}
---
*/
OutputRange joinAppend(InputRange, OutputRange, E)
    (InputRange inputRange, ref OutputRange outputRange, E delimiter)
if (isInputRange!InputRange &&
    (is(ElementType!InputRange : const E[]) &&
     isOutputRange!(OutputRange, E[]))
     ||
    (is(ElementType!InputRange : const E) &&
     isOutputRange!(OutputRange, E))
    )
{
    if (!inputRange.empty)
    {
        outputRange.put(inputRange.front);
        inputRange.popFront;
    }
    foreach (x; inputRange)
    {
        outputRange.put(delimiter);
        outputRange.put(x);
    }
    return outputRange;
}

// joinAppend.
@safe unittest
{
    import std.array : appender;
    import std.algorithm : equal;

    char[] c1 = ['a', 'b', 'c'];
    char[] c2 = ['d', 'e', 'f'];
    char[] c3 = ['g', 'h', 'i'];
    auto cvec = [c1, c2, c3];

    auto s1 = "abc";
    auto s2 = "def";
    auto s3 = "ghi";
    auto svec = [s1, s2, s3];

    auto charAppender = appender!(char[])();

    assert(cvec.joinAppend(charAppender, '_').data == "abc_def_ghi");
    assert(equal(cvec, [c1, c2, c3]));

    charAppender.put('$');
    assert(svec.joinAppend(charAppender, '|').data == "abc_def_ghi$abc|def|ghi");
    assert(equal(cvec, [s1, s2, s3]));

    charAppender.clear;
    assert(svec.joinAppend(charAppender, '|').data == "abc|def|ghi");

    auto intAppender = appender!(int[])();

    auto i1 = [100, 101, 102];
    auto i2 = [200, 201, 202];
    auto i3 = [300, 301, 302];
    auto ivec = [i1, i2, i3];

    assert(ivec.joinAppend(intAppender, 0).data ==
           [100, 101, 102, 0, 200, 201, 202, 0, 300, 301, 302]);

    intAppender.clear;
    assert(i1.joinAppend(intAppender, 0).data ==
           [100, 0, 101, 0, 102]);
    assert(i2.joinAppend(intAppender, 1).data ==
           [100, 0, 101, 0, 102,
            200, 1, 201, 1, 202]);
    assert(i3.joinAppend(intAppender, 2).data ==
           [100, 0, 101, 0, 102,
            200, 1, 201, 1, 202,
            300, 2, 301, 2, 302]);
}

/**
getTsvFieldValue extracts the value of a single field from a delimited text string.

This is a convenience function intended for cases when only a single field from an
input line is needed. If multiple values are needed, it will be more efficient to
work directly with std.algorithm.splitter or the InputFieldReordering class.

The input text is split by a delimiter character. The specified field is converted
to the desired type and the value returned.

An exception is thrown if there are not enough fields on the line or if conversion
fails. Conversion is done with std.conv.to, it throws a std.conv.ConvException on
failure. If not enough fields, the exception text is generated referencing 1-upped
field numbers as would be provided by command line users.
 */
T getTsvFieldValue(T, C)(const C[] line, size_t fieldIndex, C delim)
if (isSomeChar!C)
{
    import std.algorithm : splitter;
    import std.conv : to;
    import std.format : format;
    import std.range;

    auto splitLine = line.splitter(delim);
    size_t atField = 0;

    while (atField < fieldIndex && !splitLine.empty)
    {
        splitLine.popFront;
        atField++;
    }

    T val;
    if (splitLine.empty)
    {
        if (fieldIndex == 0)
        {
            /* This is a workaround to a splitter special case - If the input is empty,
             * the returned split range is empty. This doesn't properly represent a single
             * column file. More correct mathematically, and for this case, would be a
             * single value representing an empty string. The input line is a convenient
             * source of an empty line. Info:
             *   Bug: https://issues.dlang.org/show_bug.cgi?id=15735
             *   Pull Request: https://github.com/D-Programming-Language/phobos/pull/4030
             */
            assert(line.empty);
            val = line.to!T;
        }
        else
        {
            throw new Exception(
                format("Not enough fields on line. Number required: %d; Number found: %d",
                       fieldIndex + 1, atField));
        }
    }
    else
    {
        val = splitLine.front.to!T;
    }

    return val;
}

// getTsvFieldValue.
@safe unittest
{
    import std.conv : ConvException, to;
    import std.exception;

    /* Common cases. */
    assert(getTsvFieldValue!double("123", 0, '\t') == 123.0);
    assert(getTsvFieldValue!double("-10.5", 0, '\t') == -10.5);
    assert(getTsvFieldValue!size_t("abc|123", 1, '|') == 123);
    assert(getTsvFieldValue!int("紅\t红\t99", 2, '\t') == 99);
    assert(getTsvFieldValue!int("紅\t红\t99", 2, '\t') == 99);
    assert(getTsvFieldValue!string("紅\t红\t99", 2, '\t') == "99");
    assert(getTsvFieldValue!string("紅\t红\t99", 1, '\t') == "红");
    assert(getTsvFieldValue!string("紅\t红\t99", 0, '\t') == "紅");
    assert(getTsvFieldValue!string("红色和绿色\tred and green\t赤と緑\t10.5", 2, '\t') == "赤と緑");
    assert(getTsvFieldValue!double("红色和绿色\tred and green\t赤と緑\t10.5", 3, '\t') == 10.5);

    /* The empty field cases. */
    assert(getTsvFieldValue!string("", 0, '\t') == "");
    assert(getTsvFieldValue!string("\t", 0, '\t') == "");
    assert(getTsvFieldValue!string("\t", 1, '\t') == "");
    assert(getTsvFieldValue!string("", 0, ':') == "");
    assert(getTsvFieldValue!string(":", 0, ':') == "");
    assert(getTsvFieldValue!string(":", 1, ':') == "");

    /* Tests with different data types. */
    string stringLine = "orange and black\tნარინჯისფერი და შავი\t88.5";
    char[] charLine = "orange and black\tნარინჯისფერი და შავი\t88.5".to!(char[]);
    dchar[] dcharLine = stringLine.to!(dchar[]);
    wchar[] wcharLine = stringLine.to!(wchar[]);

    assert(getTsvFieldValue!string(stringLine, 0, '\t') == "orange and black");
    assert(getTsvFieldValue!string(stringLine, 1, '\t') == "ნარინჯისფერი და შავი");
    assert(getTsvFieldValue!wstring(stringLine, 1, '\t') == "ნარინჯისფერი და შავი".to!wstring);
    assert(getTsvFieldValue!double(stringLine, 2, '\t') == 88.5);

    assert(getTsvFieldValue!string(charLine, 0, '\t') == "orange and black");
    assert(getTsvFieldValue!string(charLine, 1, '\t') == "ნარინჯისფერი და შავი");
    assert(getTsvFieldValue!wstring(charLine, 1, '\t') == "ნარინჯისფერი და შავი".to!wstring);
    assert(getTsvFieldValue!double(charLine, 2, '\t') == 88.5);

    assert(getTsvFieldValue!string(dcharLine, 0, '\t') == "orange and black");
    assert(getTsvFieldValue!string(dcharLine, 1, '\t') == "ნარინჯისფერი და შავი");
    assert(getTsvFieldValue!wstring(dcharLine, 1, '\t') == "ნარინჯისფერი და შავი".to!wstring);
    assert(getTsvFieldValue!double(dcharLine, 2, '\t') == 88.5);

    assert(getTsvFieldValue!string(wcharLine, 0, '\t') == "orange and black");
    assert(getTsvFieldValue!string(wcharLine, 1, '\t') == "ნარინჯისფერი და შავი");
    assert(getTsvFieldValue!wstring(wcharLine, 1, '\t') == "ნარინჯისფერი და შავი".to!wstring);
    assert(getTsvFieldValue!double(wcharLine, 2, '\t') == 88.5);

    /* Conversion errors. */
    assertThrown!ConvException(getTsvFieldValue!double("", 0, '\t'));
    assertThrown!ConvException(getTsvFieldValue!double("abc", 0, '|'));
    assertThrown!ConvException(getTsvFieldValue!size_t("-1", 0, '|'));
    assertThrown!ConvException(getTsvFieldValue!size_t("a23|23.4", 1, '|'));
    assertThrown!ConvException(getTsvFieldValue!double("23.5|def", 1, '|'));

    /* Not enough field errors. These should throw, but not a ConvException.*/
    assertThrown(assertNotThrown!ConvException(getTsvFieldValue!double("", 1, '\t')));
    assertThrown(assertNotThrown!ConvException(getTsvFieldValue!double("abc", 1, '\t')));
    assertThrown(assertNotThrown!ConvException(getTsvFieldValue!double("abc\tdef", 2, '\t')));
}

/** [Yes|No.newlineWasRemoved] is a template parameter to throwIfWindowsNewlineOnUnix.
 *  A Yes value indicates the Unix newline was already removed, as might be done via
 *  std.File.byLine or similar mechanism.
 */
alias NewlineWasRemoved = Flag!"newlineWasRemoved";

/**
throwIfWindowsLineNewlineOnUnix is used to throw an exception if a Windows/DOS
line ending is found on a build compiled for a Unix platform. This is used by
the TSV Utilities to detect Window/DOS line endings and terminate processing
with an error message to the user.
 */
void throwIfWindowsNewlineOnUnix
    (NewlineWasRemoved nlWasRemoved = Yes.newlineWasRemoved)
    (const char[] line, const char[] filename, size_t lineNum)
{
    version(Posix)
    {
        static if (nlWasRemoved)
        {
            immutable bool hasWindowsLineEnding = line.length != 0 && line[$ - 1] == '\r';
        }
        else
        {
            immutable bool hasWindowsLineEnding =
                line.length > 1 &&
                line[$ - 2] == '\r' &&
                line[$ - 1] == '\n';
        }

        if (hasWindowsLineEnding)
        {
            import std.format;
            throw new Exception(
                format("Windows/DOS line ending found. Convert file to Unix newlines before processing (e.g. 'dos2unix').\n  File: %s, Line: %s",
                       (filename == "-") ? "Standard Input" : filename, lineNum));
        }
    }
}

// throwIfWindowsNewlineOnUnix
@safe unittest
{
    /* Note: Currently only building on Posix. Need to add non-Posix test cases
     * if Windows builds are ever done.
     */
    version(Posix)
    {
        import std.exception;

        assertNotThrown(throwIfWindowsNewlineOnUnix("", "afile.tsv", 1));
        assertNotThrown(throwIfWindowsNewlineOnUnix("a", "afile.tsv", 2));
        assertNotThrown(throwIfWindowsNewlineOnUnix("ab", "afile.tsv", 3));
        assertNotThrown(throwIfWindowsNewlineOnUnix("abc", "afile.tsv", 4));

        assertThrown(throwIfWindowsNewlineOnUnix("\r", "afile.tsv", 1));
        assertThrown(throwIfWindowsNewlineOnUnix("a\r", "afile.tsv", 2));
        assertThrown(throwIfWindowsNewlineOnUnix("ab\r", "afile.tsv", 3));
        assertThrown(throwIfWindowsNewlineOnUnix("abc\r", "afile.tsv", 4));

        assertNotThrown(throwIfWindowsNewlineOnUnix!(No.newlineWasRemoved)("\n", "afile.tsv", 1));
        assertNotThrown(throwIfWindowsNewlineOnUnix!(No.newlineWasRemoved)("a\n", "afile.tsv", 2));
        assertNotThrown(throwIfWindowsNewlineOnUnix!(No.newlineWasRemoved)("ab\n", "afile.tsv", 3));
        assertNotThrown(throwIfWindowsNewlineOnUnix!(No.newlineWasRemoved)("abc\n", "afile.tsv", 4));

        assertThrown(throwIfWindowsNewlineOnUnix!(No.newlineWasRemoved)("\r\n", "afile.tsv", 5));
        assertThrown(throwIfWindowsNewlineOnUnix!(No.newlineWasRemoved)("a\r\n", "afile.tsv", 6));
        assertThrown(throwIfWindowsNewlineOnUnix!(No.newlineWasRemoved)("ab\r\n", "afile.tsv", 7));
        assertThrown(throwIfWindowsNewlineOnUnix!(No.newlineWasRemoved)("abc\r\n", "afile.tsv", 8));

        /* Standard Input formatting. */
        import std.algorithm : endsWith;
        bool exceptionCaught = false;

        try (throwIfWindowsNewlineOnUnix("\r", "-", 99));
        catch (Exception e)
        {
            assert(e.msg.endsWith("File: Standard Input, Line: 99"));
            exceptionCaught = true;
        }
        finally
        {
            assert(exceptionCaught);
            exceptionCaught = false;
        }

        try (throwIfWindowsNewlineOnUnix!(No.newlineWasRemoved)("\r\n", "-", 99));
        catch (Exception e)
        {
            assert(e.msg.endsWith("File: Standard Input, Line: 99"));
            exceptionCaught = true;
        }
        finally
        {
            assert(exceptionCaught);
            exceptionCaught = false;
        }
    }
}

/** Flag used by InputSourceRange to determine if the header line should be when
opening a file.
*/
alias ReadHeader = Flag!"readHeader";

/**
inputSourceRange is a helper function for creating new InputSourceRange objects.
*/
InputSourceRange inputSourceRange(string[] filepaths, ReadHeader readHeader)
{
    return new InputSourceRange(filepaths, readHeader);
}

/**
InputSourceRange is an input range that iterates over a set of input files.

InputSourceRange is used to iterate over a set of files passed on the command line.
Files are automatically opened and closed during iteration. The caller can choose to
have header lines read automatically.

The range is created from a set of filepaths. These filepaths are mapped to
InputSource objects during the iteration. This is what enables automatically opening
and closing files and reading the header line.

The motivation for an InputSourceRange is to provide a standard way to look at the
header line of the first input file during command line argument processing, and then
pass the open input file and the header line along to the main processing functions.
This enables a features like named fields to be implemented in a standard way.

Both InputSourceRange and InputSource are reference objects. This keeps their use
limited to a single iteration over the set of files. The files can be iterated again
by creating a new InputSourceRange against the same filepaths.

Currently, InputSourceRange supports files and standard input. It is possible other
types of input sources will be added in the future.
 */
final class InputSourceRange
{
    private string[] _filepaths;
    private ReadHeader _readHeader;
    private InputSource _front;

    this(string[] filepaths, ReadHeader readHeader)
    {
        _filepaths = filepaths.dup;
        _readHeader = readHeader;
        _front = null;

        if (!_filepaths.empty)
        {
            _front = new InputSource(_filepaths.front, _readHeader);
            _front.open;
            _filepaths.popFront;
        }
    }

    size_t length() const pure nothrow @safe
    {
        return empty ? 0 : _filepaths.length + 1;
    }

    bool empty() const pure nothrow @safe
    {
        return _front is null;
    }

    InputSource front() pure @safe
    {
        assert(!empty, "Attempt to take the front of an empty InputSourceRange");
        return _front;
    }

    void popFront()
    {
        assert(!empty, "Attempt to popFront an empty InputSourceRange");

        _front.close;

        if (!_filepaths.empty)
        {
            _front = new InputSource(_filepaths.front, _readHeader);
            _front.open;
            _filepaths.popFront;
        }
        else
        {
            _front = null;
        }
    }
}

/**
InputSource is a class of objects produced by iterating over an InputSourceRange.

An InputSource object provides access to the open file currently the front element
of an InputSourceRange. The main methods application code is likely to need are:

$(LIST
    * `file()` - Returns the File object. The file will be open for reading as long
      InputSource instance is the front element of the InputSourceRange it came from.

    * `header(KeepTerminator keepTerminator = No.keepTerminator)` - Returns the
      header line from the file. An empty string is returned if InputSource range
      was created with readHeader=false.

    * `name()` - The name of the input source. The name returned is intended for
      user error messages. For files, this is the filepath that was passed to
      InputSourceRange. For standard input, it is "Standard Input".
)

An InputSource is a reference object, so the copies will retain the state of the
InputSourceRange front element. In particular, all copies will have the open
state of the front element of the InputSourceRange.

This class is not intended for use outside the context of an InputSourceRange.
*/
final class InputSource
{
    import std.stdio;

    private immutable string _filepath;
    private immutable bool _isStdin;
    private bool _isOpen;
    private ReadHeader _readHeader;
    private bool _hasBeenOpened;
    private string _header;
    private File _file;

    private this(string filepath, ReadHeader readHeader) pure nothrow @safe
    {
        _filepath = filepath;
        _isStdin = filepath == "-";
        _isOpen = false;
        _readHeader = readHeader;
        _hasBeenOpened = false;
    }

    /** file returns the File object held by the InputSource.
     *
     * The File will be open for reading as long as the InputSource instance is the
     * front element of the InputSourceRange it came from.
     */
    File file() nothrow @safe
    {
        return _file;
    }

    /** isReadHeaderEnabled returns true if the header line is being read.
     */
    bool isReadHeaderEnabled() const pure nothrow @safe
    {
        return _readHeader == Yes.readHeader;
    }

    /** header returns the header line from the input file.
     *
     * An empty string is returned if InputSource range was created with
     * readHeader=false.
     */
    string header(KeepTerminator keepTerminator = No.keepTerminator) const pure nothrow @safe
    {
        assert(_hasBeenOpened);
        return (keepTerminator == Yes.keepTerminator ||
                _header.length == 0 ||
                _header[$ - 1] != '\n') ?
            _header : _header[0 .. $-1];
    }

    /** isHeaderEmpty returns true if there is no data for a header, including the
     * terminator.
     *
     * When headers are being read, this true only if the file is empty.
     */
    bool isHeaderEmpty() const pure nothrow @safe
    {
        assert(_hasBeenOpened);
        return _header.empty;
    }

    /** name returns a user friendly name representing the input source.
     *
     * For files, it is the filepath provided to InputSourceRange. For standard
     * input, it is "Standard Input". (Use isStdin() to test for standard input,
     * not name().
     */
    string name() const pure nothrow @safe
    {
        return _isStdin ? "Standard Input" : _filepath;
    }

    /** isStdin returns true if the input source is Standard Input, false otherwise.
    */
    bool isStdin() const pure nothrow @safe
    {
        return _isStdin;
    }

    /** isOpen returns true if the input source is open for reading, false otherwise.
     *
     * "Open" in this context is whether the InputSource object is currently open,
     * meaning that it is the front element of the InputSourceRange that created it.
     *
     * For files, this is also reflected in the state of the underlying File object.
     * However, standard input is never actually closed.
     */
    bool isOpen() const pure nothrow @safe
    {
        return _isOpen;
    }

    private void open()
    {
        assert(!_isOpen);
        assert(!_hasBeenOpened);

        _file = isStdin ? stdin : _filepath.File("rb");
        if (_readHeader) _header = _file.readln;
        _isOpen = true;
        _hasBeenOpened = true;
    }

    private void close()
    {
        if (!_isStdin) _file.close;
        _isOpen = false;
    }
}

// InputSourceRange and InputSource
unittest
{
    import std.algorithm : all, each;
    import std.array : appender;
    import std.exception : assertThrown;
    import std.file : rmdirRecurse;
    import std.path : buildPath;
    import std.range;
    import std.stdio;
    import tsv_utils.common.unittest_utils;

    auto testDir = makeUnittestTempDir("tsv_utils_input_source_range");
    scope(exit) testDir.rmdirRecurse;

    string file0 = buildPath(testDir, "file0.txt");
    string file1 = buildPath(testDir, "file1.txt");
    string file2 = buildPath(testDir, "file2.txt");
    string file3 = buildPath(testDir, "file3.txt");

    string file0Header = "";
    string file1Header = "file 1 header\n";
    string file2Header = "file 2 header\n";
    string file3Header = "file 3 header\n";

    string file0Body = "";
    string file1Body = "";
    string file2Body = "file 2 line 1\n";
    string file3Body = "file 3 line 1\nfile 3 line 2\n";

    string file0Data = file0Header ~ file0Body;
    string file1Data = file1Header ~ file1Body;
    string file2Data = file2Header ~ file2Body;
    string file3Data = file3Header ~ file3Body;

    {
        file0.File("wb").write(file0Data);
        file1.File("wb").write(file1Data);
        file2.File("wb").write(file2Data);
        file3.File("wb").write(file3Data);
    }

    auto inputFiles = [file0, file1, file2, file3];
    auto fileHeaders = [file0Header, file1Header, file2Header, file3Header];
    auto fileBodies = [file0Body, file1Body, file2Body, file3Body];
    auto fileData = [file0Data, file1Data, file2Data, file3Data];

    auto readSources = appender!(InputSource[]);
    auto buffer = new char[1024];    // Must be large enough to hold the test files.

    /* Tests without standard input. Don't want to count on state of standard
     * input or modifying it when doing unit tests, so avoid reading from it.
     */

    foreach(numFiles; 1 .. inputFiles.length + 1)
    {
        /* Reading headers. */

        readSources.clear;
        auto inputSourcesYesHeader = inputSourceRange(inputFiles[0 .. numFiles], Yes.readHeader);
        assert(inputSourcesYesHeader.length == numFiles);

        foreach(fileNum, source; inputSourcesYesHeader.enumerate)
        {
            readSources.put(source);
            assert(source.isOpen);
            assert(source.file.isOpen);
            assert(readSources.data[0 .. fileNum].all!(s => !s.isOpen));
            assert(readSources.data[fileNum].isOpen);

            assert(source.header(Yes.keepTerminator) == fileHeaders[fileNum]);

            auto headerNoTerminatorLength = fileHeaders[fileNum].length;
            if (headerNoTerminatorLength > 0) --headerNoTerminatorLength;
            assert(source.header(No.keepTerminator) ==
                   fileHeaders[fileNum][0 .. headerNoTerminatorLength]);

            assert(source.name == inputFiles[fileNum]);
            assert(!source.isStdin);
            assert(source.isReadHeaderEnabled);

            assert(source.file.rawRead(buffer) == fileBodies[fileNum]);
        }

        /* The InputSourceRange is a reference range, consumed by the foreach. */
        assert(inputSourcesYesHeader.empty);

        /* Without reading headers. */

        readSources.clear;
        auto inputSourcesNoHeader = inputSourceRange(inputFiles[0 .. numFiles], No.readHeader);
        assert(inputSourcesNoHeader.length == numFiles);

        foreach(fileNum, source; inputSourcesNoHeader.enumerate)
        {
            readSources.put(source);
            assert(source.isOpen);
            assert(source.file.isOpen);
            assert(readSources.data[0 .. fileNum].all!(s => !s.isOpen));
            assert(readSources.data[fileNum].isOpen);

            assert(source.header(Yes.keepTerminator).empty);
            assert(source.header(No.keepTerminator).empty);

            assert(source.name == inputFiles[fileNum]);
            assert(!source.isStdin);
            assert(!source.isReadHeaderEnabled);

            assert(source.file.rawRead(buffer) == fileData[fileNum]);
        }

        /* The InputSourceRange is a reference range, consumed by the foreach. */
        assert(inputSourcesNoHeader.empty);
    }

    /* Tests with standard input. No actual reading in these tests.
     */

    readSources.clear;
    foreach(fileNum, source; inputSourceRange(["-", "-"], No.readHeader).enumerate)
    {
        readSources.put(source);
        assert(source.isOpen);
        assert(source.file.isOpen);
        assert(readSources.data[0 .. fileNum].all!(s => !s.isOpen));      // InputSource objects are "closed".
        assert(readSources.data[0 .. fileNum].all!(s => s.file.isOpen));  // Actual stdin should not be closed.
        assert(readSources.data[fileNum].isOpen);

        assert(source.header(Yes.keepTerminator).empty);
        assert(source.header(No.keepTerminator).empty);

        assert(source.name == "Standard Input");
        assert(source.isStdin);
    }

    /* Empty filelist. */
    string[] nofiles;
    {
        auto sources = inputSourceRange(nofiles, No.readHeader);
        assert(sources.empty);
    }
    {
        auto sources = inputSourceRange(nofiles, Yes.readHeader);
        assert(sources.empty);
    }

    /* Error cases. */
    assertThrown(inputSourceRange([file0, "no_such_file.txt"], No.readHeader).each);
    assertThrown(inputSourceRange(["no_such_file.txt", file1], Yes.readHeader).each);
}

/**
byLineSourceRange is a helper function for creating new byLineSourceRange objects.
*/
auto byLineSourceRange(
    KeepTerminator keepTerminator = No.keepTerminator, Char = char, ubyte terminator = '\n')
(string[] filepaths)
if (is(Char == char) || is(Char == ubyte))
{
    return new ByLineSourceRange!(keepTerminator, Char, terminator)(filepaths);
}

/**
ByLineSourceRange is an input range that iterates over a set of input files. It
provides bufferedByLine access to each file.

A ByLineSourceRange is used to iterate over a set of files passed on the command line.
Files are automatically opened and closed during iteration. The front element of the
range provides access to a bufferedByLine for iterating over the lines in the file.

The range is created from a set of filepaths. These filepaths are mapped to
ByLineSource objects during the iteration. This is what enables automatically opening
and closing files and providing bufferedByLine access.

The motivation behind ByLineSourceRange is to provide a standard way to look at the
header line of the first input file during command line argument processing, and then
pass the open input file along to the main processing functions. This enables
features like named fields to be implemented in a standard way.

Access to the first line of the first file is available after creating the
ByLineSourceRange instance. The first file is opened and a bufferedByLine created.
The first line of the first file is via byLine.front (after checking !byLine.empty).

Both ByLineSourceRange and ByLineSource are reference objects. This keeps their use
limited to a single iteration over the set of files. The files can be iterated again
by creating a new InputSourceRange against the same filepaths.

Currently, ByLineSourceRange supports files and standard input. It is possible other
types of input sources will be added in the future.
 */
final class ByLineSourceRange(
    KeepTerminator keepTerminator = No.keepTerminator, Char = char, ubyte terminator = '\n')
if (is(Char == char) || is(Char == ubyte))
{
    alias ByLineSourceType = ByLineSource!(keepTerminator, char, terminator);

    private string[] _filepaths;
    private ByLineSourceType _front;

    this(string[] filepaths)
    {
        _filepaths = filepaths.dup;
        _front = null;

        if (!_filepaths.empty)
        {
            _front = new ByLineSourceType(_filepaths.front);
            _front.open;
            _filepaths.popFront;
        }
    }

    size_t length() const pure nothrow @safe
    {
        return empty ? 0 : _filepaths.length + 1;
    }

    bool empty() const pure nothrow @safe
    {
        return _front is null;
    }

    ByLineSourceType front() pure @safe
    {
        assert(!empty, "Attempt to take the front of an empty ByLineSourceRange");
        return _front;
    }

    void popFront()
    {
        assert(!empty, "Attempt to popFront an empty ByLineSourceRange");

        _front.close;

        if (!_filepaths.empty)
        {
            _front = new ByLineSourceType(_filepaths.front);
            _front.open;
            _filepaths.popFront;
        }
        else
        {
            _front = null;
        }
    }
}

/**
ByLineSource is a class of objects produced by iterating over an ByLineSourceRange.

A ByLineSource instance provides a bufferedByLine range for the current the front
element of a ByLineSourceRange. The main methods application code is likely to
need are:

$(LIST
    * `byLine()` - Returns the bufferedByLine range accessing the open file. The file
       will be open for reading (using the bufferedByLine range) as long as the
       ByLineSource instance is the front element of the ByLineSourceRange
       it came from.

    * `name()` - The name of the input source. The name returned is intended for
      user error messages. For files, this is the filepath that was passed to
      ByLineSourceRange. For standard input, it is "Standard Input".
)

A ByLineSource is a reference object, so the copies have the same state as the
ByLineSourceRange front element. In particular, all copies will have the open
state of the front element of the ByLineSourceRange.

This class is not intended for use outside the context of an ByLineSourceRange.
*/
final class ByLineSource(
    KeepTerminator keepTerminator, Char = char, ubyte terminator = '\n')
if (is(Char == char) || is(Char == ubyte))
{
    import std.stdio;
    import std.traits : ReturnType;

    alias newByLineFn = bufferedByLine!(keepTerminator, char, terminator);
    alias ByLineType = ReturnType!newByLineFn;

    private immutable string _filepath;
    private immutable bool _isStdin;
    private bool _isOpen;
    private bool _hasBeenOpened;
    private File _file;
    private ByLineType _byLineRange;

    private this(string filepath) pure nothrow @safe
    {
        _filepath = filepath;
        _isStdin = filepath == "-";
        _isOpen = false;
        _hasBeenOpened = false;
    }

    /** byLine returns the bufferedByLine object held by the ByLineSource instance.
     *
     * The File underlying the BufferedByLine object is open for reading as long as
     * the ByLineSource instance is the front element of the ByLineSourceRange it
     * came from.
     */
    ByLineType byLine() nothrow @safe
    {
        return _byLineRange;
    }

    /** name returns a user friendly name representing the underlying input source.
     *
     * For files, it is the filepath provided to ByLineSourceRange. For standard
     * input, it is "Standard Input". (Use isStdin() to test for standard input,
     * compare against name().)
     */
    string name() const pure nothrow @safe
    {
        return _isStdin ? "Standard Input" : _filepath;
    }

    /** isStdin returns true if the underlying input source is Standard Input, false
     * otherwise.
     */
    bool isStdin() const pure nothrow @safe
    {
        return _isStdin;
    }

    /** isOpen returns true if the ByLineSource instance is open for reading, false
     * otherwise.
     *
     * "Open" in this context is whether the ByLineSource object is currently "open".
     * The underlying input source backing it does not necessarily have the same
     * state. The ByLineSource instance is "open" if is the front element of the
     * ByLineSourceRange that created it.
     *
     * The underlying input source object follows the same open/close state as makes
     * sense. In particular, real files are closed when the ByLineSource object is
     * closed. The exception is standard input, which is never actually closed.
     */
    bool isOpen() const pure nothrow @safe
    {
        return _isOpen;
    }

    private void open()
    {
        assert(!_isOpen);
        assert(!_hasBeenOpened);

        _file = isStdin ? stdin : _filepath.File("rb");
        _byLineRange = newByLineFn(_file);
        _isOpen = true;
        _hasBeenOpened = true;
    }

    private void close()
    {
        if (!_isStdin) _file.close;
        _isOpen = false;
    }
}

// ByLineSourceRange and ByLineSource
unittest
{
    import std.algorithm : all, each;
    import std.array : appender;
    import std.exception : assertThrown;
    import std.file : rmdirRecurse;
    import std.path : buildPath;
    import std.range;
    import std.stdio;
    import tsv_utils.common.unittest_utils;

    auto testDir = makeUnittestTempDir("tsv_utils_byline_input_source_range");
    scope(exit) testDir.rmdirRecurse;

    string file0 = buildPath(testDir, "file0.txt");
    string file1 = buildPath(testDir, "file1.txt");
    string file2 = buildPath(testDir, "file2.txt");
    string file3 = buildPath(testDir, "file3.txt");

    string file0Header = "";
    string file1Header = "file 1 header\n";
    string file2Header = "file 2 header\n";
    string file3Header = "file 3 header\n";

    string file0Body = "";
    string file1Body = "";
    string file2Body = "file 2 line 1\n";
    string file3Body = "file 3 line 1\nfile 3 line 2\n";

    string file0Data = file0Header ~ file0Body;
    string file1Data = file1Header ~ file1Body;
    string file2Data = file2Header ~ file2Body;
    string file3Data = file3Header ~ file3Body;

    {
        file0.File("wb").write(file0Data);
        file1.File("wb").write(file1Data);
        file2.File("wb").write(file2Data);
        file3.File("wb").write(file3Data);
    }

    auto inputFiles = [file0, file1, file2, file3];
    auto fileHeaders = [file0Header, file1Header, file2Header, file3Header];
    auto fileBodies = [file0Body, file1Body, file2Body, file3Body];
    auto fileData = [file0Data, file1Data, file2Data, file3Data];

    auto buffer = new char[1024];    // Must be large enough to hold the test files.

    /* Tests without standard input. Don't want to count on state of standard
     * input or modifying it when doing unit tests, so avoid reading from it.
     */

    auto readSourcesNoTerminator = appender!(ByLineSource!(No.keepTerminator)[]);
    auto readSourcesYesTerminator = appender!(ByLineSource!(Yes.keepTerminator)[]);

    foreach(numFiles; 1 .. inputFiles.length + 1)
    {
        /* Using No.keepTerminator. */
        readSourcesNoTerminator.clear;
        auto inputSourcesNoTerminator = byLineSourceRange!(No.keepTerminator)(inputFiles[0 .. numFiles]);
        assert(inputSourcesNoTerminator.length == numFiles);

        foreach(fileNum, source; inputSourcesNoTerminator.enumerate)
        {
            readSourcesNoTerminator.put(source);
            assert(source.isOpen);
            assert(source._file.isOpen);
            assert(readSourcesNoTerminator.data[0 .. fileNum].all!(s => !s.isOpen));
            assert(readSourcesNoTerminator.data[fileNum].isOpen);

            auto headerNoTerminatorLength = fileHeaders[fileNum].length;
            if (headerNoTerminatorLength > 0) --headerNoTerminatorLength;

            assert(source.byLine.empty ||
                   source.byLine.front == fileHeaders[fileNum][0 .. headerNoTerminatorLength]);

            assert(source.name == inputFiles[fileNum]);
            assert(!source.isStdin);

            auto readFileData = appender!(char[]);
            foreach(line; source.byLine)
            {
                readFileData.put(line);
                readFileData.put('\n');
            }

            assert(readFileData.data == fileData[fileNum]);
        }

        /* The ByLineSourceRange is a reference range, consumed by the foreach. */
        assert(inputSourcesNoTerminator.empty);

        /* Using Yes.keepTerminator. */
        readSourcesYesTerminator.clear;
        auto inputSourcesYesTerminator = byLineSourceRange!(Yes.keepTerminator)(inputFiles[0 .. numFiles]);
        assert(inputSourcesYesTerminator.length == numFiles);

        foreach(fileNum, source; inputSourcesYesTerminator.enumerate)
        {
            readSourcesYesTerminator.put(source);
            assert(source.isOpen);
            assert(source._file.isOpen);
            assert(readSourcesYesTerminator.data[0 .. fileNum].all!(s => !s.isOpen));
            assert(readSourcesYesTerminator.data[fileNum].isOpen);

            assert(source.byLine.empty || source.byLine.front == fileHeaders[fileNum]);

            assert(source.name == inputFiles[fileNum]);
            assert(!source.isStdin);

            auto readFileData = appender!(char[]);
            foreach(line; source.byLine)
            {
                readFileData.put(line);
            }

            assert(readFileData.data == fileData[fileNum]);
        }

        /* The ByLineSourceRange is a reference range, consumed by the foreach. */
        assert(inputSourcesYesTerminator.empty);
    }

    /* Empty filelist. */
    string[] nofiles;
    {
        auto sources = byLineSourceRange!(No.keepTerminator)(nofiles);
        assert(sources.empty);
    }
    {
        auto sources = byLineSourceRange!(Yes.keepTerminator)(nofiles);
        assert(sources.empty);
    }

    /* Error cases. */
    assertThrown(byLineSourceRange!(No.keepTerminator)([file0, "no_such_file.txt"]).each);
    assertThrown(byLineSourceRange!(Yes.keepTerminator)(["no_such_file.txt", file1]).each);
}

/** Defines the 'bufferable' input sources supported by inputSourceByChunk.
 *
 * This includes std.stdio.File objects and mutable dynamic ubyte arrays. Or, input
 * ranges with ubyte elements.
 *
 * Static, const, and immutable arrays can be sliced to turn them into input ranges.
 *
 * Note: The element types could easily be generalized much further if that were useful.
 * At present, the primary purpose of inputSourceByChunk is to have a range representing
 * a buffered file that can also take ubyte arrays as sources for unit testing.
 */
enum bool isBufferableInputSource(R) =
    isFileHandle!(Unqual!R) ||
    (isInputRange!R && is(Unqual!(ElementEncodingType!R) == ubyte)
    );

@safe unittest
{
    import std.stdio : stdin;

    static assert(isBufferableInputSource!(File));
    static assert(isBufferableInputSource!(typeof(stdin)));
    static assert(isBufferableInputSource!(ubyte[]));
    static assert(!isBufferableInputSource!(char[]));
    static assert(!isBufferableInputSource!(string));

    ubyte[10] staticArray;
    const ubyte[1] staticConstArray;
    immutable ubyte[1] staticImmutableArray;
    const(ubyte)[1] staticArrayConstElts;
    immutable(ubyte)[1] staticArrayImmutableElts;

    ubyte[] dynamicArray = new ubyte[](10);
    const(ubyte)[] dynamicArrayConstElts = new ubyte[](10);
    immutable(ubyte)[] dynamicArrayImmutableElts = new ubyte[](10);
    const ubyte[] dynamicConstArray = new ubyte[](10);
    immutable ubyte[] dynamicImmutableArray = new ubyte[](10);

    /* Dynamic mutable arrays are bufferable. */
    static assert(!isBufferableInputSource!(typeof(staticArray)));
    static assert(!isBufferableInputSource!(typeof(staticArrayConstElts)));
    static assert(!isBufferableInputSource!(typeof(staticArrayImmutableElts)));
    static assert(!isBufferableInputSource!(typeof(staticConstArray)));
    static assert(!isBufferableInputSource!(typeof(staticImmutableArray)));

    static assert(isBufferableInputSource!(typeof(dynamicArray)));
    static assert(isBufferableInputSource!(typeof(dynamicArrayConstElts)));
    static assert(isBufferableInputSource!(typeof(dynamicArrayImmutableElts)));
    static assert(!isBufferableInputSource!(typeof(dynamicConstArray)));
    static assert(!isBufferableInputSource!(typeof(dynamicImmutableArray)));

    /* Slicing turns all forms into bufferable arrays. */
    static assert(isBufferableInputSource!(typeof(staticArray[])));
    static assert(isBufferableInputSource!(typeof(staticArrayConstElts[])));
    static assert(isBufferableInputSource!(typeof(staticArrayImmutableElts[])));
    static assert(isBufferableInputSource!(typeof(staticConstArray[])));
    static assert(isBufferableInputSource!(typeof(staticImmutableArray[])));

    static assert(isBufferableInputSource!(typeof(dynamicConstArray[])));
    static assert(isBufferableInputSource!(typeof(dynamicImmutableArray[])));
    static assert(isBufferableInputSource!(typeof(dynamicArray[])));
    static assert(isBufferableInputSource!(typeof(dynamicArrayConstElts[])));
    static assert(isBufferableInputSource!(typeof(dynamicArrayImmutableElts[])));

    /* Element type tests. */
    static assert(is(Unqual!(ElementType!(typeof(staticArray))) == ubyte));
    static assert(is(Unqual!(ElementType!(typeof(staticArrayConstElts))) == ubyte));
    static assert(is(Unqual!(ElementType!(typeof(staticArrayImmutableElts))) == ubyte));
    static assert(is(Unqual!(ElementType!(typeof(staticConstArray))) == ubyte));
    static assert(is(Unqual!(ElementType!(typeof(staticImmutableArray))) == ubyte));
    static assert(is(Unqual!(ElementType!(typeof(dynamicArray))) == ubyte));
    static assert(is(Unqual!(ElementType!(typeof(dynamicArrayConstElts))) == ubyte));
    static assert(is(Unqual!(ElementType!(typeof(dynamicArrayImmutableElts))) == ubyte));
    static assert(is(Unqual!(ElementType!(typeof(dynamicConstArray))) == ubyte));
    static assert(is(Unqual!(ElementType!(typeof(dynamicImmutableArray))) == ubyte));

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
    static assert(isBufferableInputSource!S1);

    static assert(isInputRange!S2);
    static assert(is(ElementEncodingType!S2 == ubyte));
    static assert(hasSlicing!S2);
    static assert(isBufferableInputSource!S2);

    /* For code coverage. */
    S2 s2;
    auto x = s2.save;

    auto repeatInt = 7.repeat!int(5);
    auto repeatUbyte = 7.repeat!ubyte(5);
    auto infiniteUbyte = 7.repeat!ubyte;

    static assert(!isBufferableInputSource!(typeof(repeatInt)));
    static assert(isBufferableInputSource!(typeof(repeatUbyte)));
    static assert(isBufferableInputSource!(typeof(infiniteUbyte)));
}

/** inputSourceByChunk returns a range that reads either a file handle (File) or a
 * ubyte[] array a chunk at a time.
 *
 * This is a cover for File.byChunk that allows passing an in-memory array or input
 * range as well. At present the motivation is primarily to enable unit testing of
 * chunk-based algorithms using in-memory strings.
 *
 * inputSourceByChunk takes either a File open for reading or an input range with
 * ubyte elements. Data is read a buffer at a time. The buffer can be user provided,
 * or  allocated by inputSourceByChunk based on a caller provided buffer size.
 *
 * The primary motivation for supporting both files and input ranges as sources is to
 * enable unit testing of buffer based algorithms using in-memory arrays. Dynamic,
 * mutable arras are fine. Use slicing to turn a static, const, or immutable arrays
 * into an input range.
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
                    import std.algorithm : copy;
                    auto remainingBuffer = _chunks.front.take(_buffer.length).copy(_buffer);
                    _chunks.popFront;

                    /* Only the last chunk should be shorter than the buffer. */
                    assert(remainingBuffer.length == 0 || _chunks.empty);

                    _buffer.length -= remainingBuffer.length;
                }
            }

            this(InputSource source, ubyte[] buffer)
            {
                import std.exception : enforce;
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

    auto testDir = makeUnittestTempDir("tsv_utils_inputSourceByChunk");
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

        auto f = filePath.File("wb");
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

@safe unittest // inputSourceByChunk array cases
{
    import std.algorithm : equal;

    ubyte[5] staticArray = [5, 6, 7, 8, 9];
    const(ubyte)[5] staticArrayConstElts = [5, 6, 7, 8, 9];
    immutable(ubyte)[5] staticArrayImmutableElts = [5, 6, 7, 8, 9];
    const ubyte[5] staticConstArray = [5, 6, 7, 8, 9];
    immutable ubyte[5] staticImmutableArray = [5, 6, 7, 8, 9];

    ubyte[] dynamicArray = [5, 6, 7, 8, 9];
    const(ubyte)[] dynamicArrayConstElts = [5, 6, 7, 8, 9];
    immutable(ubyte)[] dynamicArrayImmutableElts = [5, 6, 7, 8, 9];
    const ubyte[] dynamicConstArray = [5, 6, 7, 8, 9];
    immutable ubyte[] dynamicImmutableArray = [5, 6, 7, 8, 9];

    /* The dynamic mutable arrays can be used directly. */
    assert (dynamicArray.inputSourceByChunk(2).equal([[5, 6], [7, 8], [9]]));
    assert (dynamicArrayConstElts.inputSourceByChunk(2).equal([[5, 6], [7, 8], [9]]));
    assert (dynamicArrayImmutableElts.inputSourceByChunk(2).equal([[5, 6], [7, 8], [9]]));

    /* All the arrays can be used with slicing. */
    assert (staticArray[].inputSourceByChunk(2).equal([[5, 6], [7, 8], [9]]));
    assert (staticArrayConstElts[].inputSourceByChunk(2).equal([[5, 6], [7, 8], [9]]));
    assert (staticArrayImmutableElts[].inputSourceByChunk(2).equal([[5, 6], [7, 8], [9]]));
    assert (staticConstArray[].inputSourceByChunk(2).equal([[5, 6], [7, 8], [9]]));
    assert (staticImmutableArray[].inputSourceByChunk(2).equal([[5, 6], [7, 8], [9]]));
    assert (dynamicArray[].inputSourceByChunk(2).equal([[5, 6], [7, 8], [9]]));
    assert (dynamicArrayConstElts[].inputSourceByChunk(2).equal([[5, 6], [7, 8], [9]]));
    assert (dynamicArrayImmutableElts[].inputSourceByChunk(2).equal([[5, 6], [7, 8], [9]]));
    assert (dynamicConstArray[].inputSourceByChunk(2).equal([[5, 6], [7, 8], [9]]));
    assert (dynamicImmutableArray[].inputSourceByChunk(2).equal([[5, 6], [7, 8], [9]]));
}

@safe unittest // inputSourceByChunk input ranges
{
    import std.algorithm : equal;

    assert (7.repeat!ubyte(5).inputSourceByChunk(1).equal([[7], [7], [7], [7], [7]]));
    assert (7.repeat!ubyte(5).inputSourceByChunk(2).equal([[7, 7], [7, 7], [7]]));
    assert (7.repeat!ubyte(5).inputSourceByChunk(3).equal([[7, 7, 7], [7, 7]]));
    assert (7.repeat!ubyte(5).inputSourceByChunk(4).equal([[7, 7, 7, 7], [7]]));
    assert (7.repeat!ubyte(5).inputSourceByChunk(5).equal([[7, 7, 7, 7, 7]]));
    assert (7.repeat!ubyte(5).inputSourceByChunk(6).equal([[7, 7, 7, 7, 7]]));

    /* Infinite. */
    assert (7.repeat!ubyte.inputSourceByChunk(2).take(3).equal([[7, 7], [7, 7], [7, 7]]));
}
