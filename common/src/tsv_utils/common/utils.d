/**
Utilities used by tsv-utils applications. InputFieldReordering, BufferedOututRange,
and a several others.

Utilities in this file:
$(LIST
    * [InputFieldReordering] - A class that creates a reordered subset of fields from
      an input line. Fields in the subset are accessed by array indicies. This is
      especially useful when processing the subset in a specific order, such as the
      order listed on the command-line at run-time.

    * [BufferedOutputRange] - An OutputRange with an internal buffer used to buffer
      output. Intended for use with stdout, it is a significant performance benefit.

    * [joinAppend] - A function that performs a join, but appending the join output to
      an output stream. It is a performance improvement over using join or joiner with
      writeln.

    * [getTsvFieldValue] - A convenience function when only a single value is needed from
      an input line.

    * Field-lists: [parseFieldList], [makeFieldListOptionHandler] - Helper functions for
      parsing field-lists entered on the command line.

    * [throwIfWindowsNewlineOnUnix] - A utility for Unix platform builds to detecting
      Windows newlines in input.
)

Copyright (c) 2015-2019, eBay Software Foundation
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)
*/

module tsv_utils.common.utils;

import std.range;
import std.traits : isIntegral, isSomeChar, isSomeString, isUnsigned;
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
class InputFieldReordering(C, EnablePartialLines partialLinesOk = EnablePartialLines.no)
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
    import std.range;
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

    /** processNextField maps an input field to the correct locations in the outputFields
     * array. It should be called once for each field on the line, in the order found.
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

/* Tests using different character types. */
unittest
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

/* Test of partial line support. */
unittest
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

/* Field combination tests. */
unittest
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


import std.stdio : isFileHandle;
import std.range : isOutputRange;
import std.traits : Unqual;

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
    import std.range : isOutputRange;
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
        static if (isFileHandle!OutputTarget) _outputTarget.write(_outputBuffer.data);
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

    private void appendRaw(T)(T stuff)
    {
        import std.range : rangePut = put;
        rangePut(_outputBuffer, stuff);
    }

    void append(T)(T stuff)
    {
        appendRaw(stuff);
        flushIfMaxSize();
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

        auto ostream = BufferedOutputRange!File(filepath1.File("w"));
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

        auto ostream = BufferedOutputRange!File(filepath2.File("w"), 0, 0);
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

            auto ltw = filepath3.File("w").lockingTextWriter;
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
joinAppend performs a join operation on an input range, appending the results to
an output range.

Note: The main uses of joinAppend have been replaced by BufferedOutputRange, which has
its own joinAppend method.

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
T getTsvFieldValue(T, C)(const C[] line, size_t fieldIndex, C delim) pure @safe
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

unittest
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

/**
Field-lists - A field-list is a string entered on the command line identifying one or more
field numbers. They are used by the majority of the tsv utility applications. There are
two helper functions, makeFieldListOptionHandler and parseFieldList. Most applications
will use makeFieldListOptionHandler, it creates a delegate that can be passed to
std.getopt to process the command option. Actual processing of the option text is done by
parseFieldList. It can be called directly when the text of the option value contains more
than just the field number.

Syntax and behavior:

A 'field-list' is a list of numeric field numbers entered on the command line. Fields are
1-upped integers representing locations in an input line, in the traditional meaning of
Unix command line tools. Fields can be entered as single numbers or a range. Multiple
entries are separated by commas. Some examples (with 'fields' as the command line option):

   --fields 3                 // Single field
   --fields 4,1               // Two fields
   --fields 3-9               // A range, fields 3 to 9 inclusive
   --fields 1,2,7-34,11       // A mix of ranges and fields
   --fields 15-5,3-1          // Two ranges in reverse order.

Incomplete ranges are not supported, for example, '6-'. Zero is disallowed as a field
value by default, but can be enabled to support the notion of zero as representing the
entire line. However, zero cannot be part of a range. Field numbers are one-based by
default, but can be converted to zero-based. If conversion to zero-based is enabled, field
number zero must be disallowed or a signed integer type specified for the returned range.

An error is thrown if an invalid field specification is encountered. Error text is
intended for display. Error conditions include:
  - Empty fields list
  - Empty value, e.g. Two consequtive commas, a trailing comma, or a leading comma
  - String that does not parse as a valid integer
  - Negative integers, or zero if zero is disallowed.
  - An incomplete range
  - Zero used as part of a range.

No other behaviors are enforced. Repeated values are accepted. If zero is allowed, other
field numbers can be entered as well. Additional restrictions need to be applied by the
caller.

Notes:
  - The data type determines the max field number that can be entered. Enabling conversion
    to zero restricts to the signed version of the data type.
  - Use 'import std.typecons : Yes, No' to use the convertToZeroBasedIndex and
    allowFieldNumZero template parameters.
*/

/** [Yes|No].convertToZeroBasedIndex parameter controls whether field numbers are
 *  converted to zero-based indices by makeFieldListOptionHander and parseFieldList.
 */
alias ConvertToZeroBasedIndex = Flag!"convertToZeroBasedIndex";

/** [Yes|No].allowFieldNumZero parameter controls whether zero is a valid field. This is
 *  used by makeFieldListOptionHander and parseFieldList.
 */
alias AllowFieldNumZero = Flag!"allowFieldNumZero";

alias OptionHandlerDelegate = void delegate(string option, string value);

/**
makeFieldListOptionHandler creates a std.getopt option hander for processing field lists
entered on the command line. A field list is as defined by parseFieldList.
*/
OptionHandlerDelegate makeFieldListOptionHandler(
                                                 T,
                                                 ConvertToZeroBasedIndex convertToZero = No.convertToZeroBasedIndex,
                                                 AllowFieldNumZero allowZero = No.allowFieldNumZero)
    (ref T[] fieldsArray)
if (isIntegral!T && (!allowZero || !convertToZero || !isUnsigned!T))
{
    void fieldListOptionHandler(ref T[] fieldArray, string option, string value)
    {
        import std.algorithm : each;
        try value.parseFieldList!(T, convertToZero, allowZero).each!(x => fieldArray ~= x);
        catch (Exception exc)
        {
            import std.format : format;
            exc.msg = format("[--%s] %s", option, exc.msg);
            throw exc;
        }
    }

    return (option, value) => fieldListOptionHandler(fieldsArray, option, value);
}

unittest
{
    import std.exception : assertThrown, assertNotThrown;
    import std.getopt;

    {
        size_t[] fields;
        auto args = ["program", "--fields", "1", "--fields", "2,4,7-9,23-21"];
        getopt(args, "f|fields", fields.makeFieldListOptionHandler);
        assert(fields == [1, 2, 4, 7, 8, 9, 23, 22, 21]);
    }
    {
        size_t[] fields;
        auto args = ["program", "--fields", "1", "--fields", "2,4,7-9,23-21"];
        getopt(args,
               "f|fields", fields.makeFieldListOptionHandler!(size_t, Yes.convertToZeroBasedIndex));
        assert(fields == [0, 1, 3, 6, 7, 8, 22, 21, 20]);
    }
    {
        size_t[] fields;
        auto args = ["program", "-f", "0"];
        getopt(args,
               "f|fields", fields.makeFieldListOptionHandler!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
        assert(fields == [0]);
    }
    {
        size_t[] fields;
        auto args = ["program", "-f", "0", "-f", "1,0", "-f", "0,1"];
        getopt(args,
               "f|fields", fields.makeFieldListOptionHandler!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
        assert(fields == [0, 1, 0, 0, 1]);
    }
    {
        size_t[] ints;
        size_t[] fields;
        auto args = ["program", "--ints", "1,2,3", "--fields", "1", "--ints", "4,5,6", "--fields", "2,4,7-9,23-21"];
        std.getopt.arraySep = ",";
        getopt(args,
               "i|ints", "Built-in list of integers.", &ints,
               "f|fields", "Field-list style integers.", fields.makeFieldListOptionHandler);
        assert(ints == [1, 2, 3, 4, 5, 6]);
        assert(fields == [1, 2, 4, 7, 8, 9, 23, 22, 21]);
    }

    /* Basic cases involved unsinged types smaller than size_t. */
    {
        uint[] fields;
        auto args = ["program", "-f", "0", "-f", "1,0", "-f", "0,1", "-f", "55-58"];
        getopt(args,
               "f|fields", fields.makeFieldListOptionHandler!(uint, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
        assert(fields == [0, 1, 0, 0, 1, 55, 56, 57, 58]);
    }
    {
        ushort[] fields;
        auto args = ["program", "-f", "0", "-f", "1,0", "-f", "0,1", "-f", "55-58"];
        getopt(args,
               "f|fields", fields.makeFieldListOptionHandler!(ushort, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
        assert(fields == [0, 1, 0, 0, 1, 55, 56, 57, 58]);
    }

    /* Basic cases involving unsigned types. */
    {
        long[] fields;
        auto args = ["program", "--fields", "1", "--fields", "2,4,7-9,23-21"];
        getopt(args, "f|fields", fields.makeFieldListOptionHandler);
        assert(fields == [1, 2, 4, 7, 8, 9, 23, 22, 21]);
    }
    {
        long[] fields;
        auto args = ["program", "--fields", "1", "--fields", "2,4,7-9,23-21"];
        getopt(args,
               "f|fields", fields.makeFieldListOptionHandler!(long, Yes.convertToZeroBasedIndex));
        assert(fields == [0, 1, 3, 6, 7, 8, 22, 21, 20]);
    }
    {
        long[] fields;
        auto args = ["program", "-f", "0"];
        getopt(args,
               "f|fields", fields.makeFieldListOptionHandler!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
        assert(fields == [-1]);
    }
    {
        int[] fields;
        auto args = ["program", "--fields", "1", "--fields", "2,4,7-9,23-21"];
        getopt(args, "f|fields", fields.makeFieldListOptionHandler);
        assert(fields == [1, 2, 4, 7, 8, 9, 23, 22, 21]);
    }
    {
        int[] fields;
        auto args = ["program", "--fields", "1", "--fields", "2,4,7-9,23-21"];
        getopt(args,
               "f|fields", fields.makeFieldListOptionHandler!(int, Yes.convertToZeroBasedIndex));
        assert(fields == [0, 1, 3, 6, 7, 8, 22, 21, 20]);
    }
    {
        int[] fields;
        auto args = ["program", "-f", "0"];
        getopt(args,
               "f|fields", fields.makeFieldListOptionHandler!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
        assert(fields == [-1]);
    }
    {
        short[] fields;
        auto args = ["program", "--fields", "1", "--fields", "2,4,7-9,23-21"];
        getopt(args, "f|fields", fields.makeFieldListOptionHandler);
        assert(fields == [1, 2, 4, 7, 8, 9, 23, 22, 21]);
    }
    {
        short[] fields;
        auto args = ["program", "--fields", "1", "--fields", "2,4,7-9,23-21"];
        getopt(args,
               "f|fields", fields.makeFieldListOptionHandler!(short, Yes.convertToZeroBasedIndex));
        assert(fields == [0, 1, 3, 6, 7, 8, 22, 21, 20]);
    }
    {
        short[] fields;
        auto args = ["program", "-f", "0"];
        getopt(args,
               "f|fields", fields.makeFieldListOptionHandler!(short, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
        assert(fields == [-1]);
    }

    {
        /* Error cases. */
        size_t[] fields;
        auto args = ["program", "-f", "0"];
        assertThrown(getopt(args, "f|fields", fields.makeFieldListOptionHandler));

        args = ["program", "-f", "-1"];
        assertThrown(getopt(args, "f|fields", fields.makeFieldListOptionHandler));

        args = ["program", "-f", "--fields", "1"];
        assertThrown(getopt(args, "f|fields", fields.makeFieldListOptionHandler));

        args = ["program", "-f", "a"];
        assertThrown(getopt(args, "f|fields", fields.makeFieldListOptionHandler));

        args = ["program", "-f", "1.5"];
        assertThrown(getopt(args, "f|fields", fields.makeFieldListOptionHandler));

        args = ["program", "-f", "2-"];
        assertThrown(getopt(args, "f|fields", fields.makeFieldListOptionHandler));

        args = ["program", "-f", "3,5,-7"];
        assertThrown(getopt(args, "f|fields", fields.makeFieldListOptionHandler));

        args = ["program", "-f", "3,5,"];
        assertThrown(getopt(args, "f|fields", fields.makeFieldListOptionHandler));

        args = ["program", "-f", "-1"];
        assertThrown(getopt(args,
                            "f|fields", fields.makeFieldListOptionHandler!(
                                size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero)));
    }
}

/**
parseFieldList lazily generates a range of fields numbers from a 'field-list' string.
*/
auto parseFieldList(T = size_t,
                    ConvertToZeroBasedIndex convertToZero = No.convertToZeroBasedIndex,
                    AllowFieldNumZero allowZero = No.allowFieldNumZero)
    (string fieldList, char delim = ',')
if (isIntegral!T && (!allowZero || !convertToZero || !isUnsigned!T))
{
    import std.algorithm : splitter;

    auto _splitFieldList = fieldList.splitter(delim);
    auto _currFieldParse =
        (_splitFieldList.empty ? "" : _splitFieldList.front)
        .parseFieldRange!(T, convertToZero, allowZero);

    if (!_splitFieldList.empty) _splitFieldList.popFront;

    struct Result
    {
        @property bool empty() { return _currFieldParse.empty; }

        @property T front()
        {
            import std.conv : to;

            assert(!empty, "Attempting to fetch the front of an empty field-list.");
            assert(!_currFieldParse.empty, "Internal error. Call to front with an empty _currFieldParse.");

            return _currFieldParse.front.to!T;
        }

        void popFront()
        {
            assert(!empty, "Attempting to popFront an empty field-list.");

            _currFieldParse.popFront;
            if (_currFieldParse.empty && !_splitFieldList.empty)
            {
                _currFieldParse = _splitFieldList.front.parseFieldRange!(T, convertToZero, allowZero);
                _splitFieldList.popFront;
            }
        }
    }

    return Result();
}

unittest
{
    import std.algorithm : each, equal;
    import std.exception : assertThrown, assertNotThrown;

    /* Basic tests. */
    assert("1".parseFieldList.equal([1]));
    assert("1,2".parseFieldList.equal([1, 2]));
    assert("1,2,3".parseFieldList.equal([1, 2, 3]));
    assert("1-2".parseFieldList.equal([1, 2]));
    assert("1-2,6-4".parseFieldList.equal([1, 2, 6, 5, 4]));
    assert("1-2,1,1-2,2,2-1".parseFieldList.equal([1, 2, 1, 1, 2, 2, 2, 1]));
    assert("1-2,5".parseFieldList!size_t.equal([1, 2, 5]));

    /* Signed Int tests */
    assert("1".parseFieldList!int.equal([1]));
    assert("1,2,3".parseFieldList!int.equal([1, 2, 3]));
    assert("1-2".parseFieldList!int.equal([1, 2]));
    assert("1-2,6-4".parseFieldList!int.equal([1, 2, 6, 5, 4]));
    assert("1-2,5".parseFieldList!int.equal([1, 2, 5]));

    /* Convert to zero tests */
    assert("1".parseFieldList!(size_t, Yes.convertToZeroBasedIndex).equal([0]));
    assert("1,2,3".parseFieldList!(size_t, Yes.convertToZeroBasedIndex).equal([0, 1, 2]));
    assert("1-2".parseFieldList!(size_t, Yes.convertToZeroBasedIndex).equal([0, 1]));
    assert("1-2,6-4".parseFieldList!(size_t, Yes.convertToZeroBasedIndex).equal([0, 1, 5, 4, 3]));
    assert("1-2,5".parseFieldList!(size_t, Yes.convertToZeroBasedIndex).equal([0, 1, 4]));

    assert("1".parseFieldList!(long, Yes.convertToZeroBasedIndex).equal([0]));
    assert("1,2,3".parseFieldList!(long, Yes.convertToZeroBasedIndex).equal([0, 1, 2]));
    assert("1-2".parseFieldList!(long, Yes.convertToZeroBasedIndex).equal([0, 1]));
    assert("1-2,6-4".parseFieldList!(long, Yes.convertToZeroBasedIndex).equal([0, 1, 5, 4, 3]));
    assert("1-2,5".parseFieldList!(long, Yes.convertToZeroBasedIndex).equal([0, 1, 4]));

    /* Allow zero tests. */
    assert("0".parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("1,0,3".parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([1, 0, 3]));
    assert("1-2,5".parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([1, 2, 5]));
    assert("0".parseFieldList!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("1,0,3".parseFieldList!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([1, 0, 3]));
    assert("1-2,5".parseFieldList!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([1, 2, 5]));
    assert("0".parseFieldList!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([-1]));
    assert("1,0,3".parseFieldList!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0, -1, 2]));
    assert("1-2,5".parseFieldList!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0, 1, 4]));

    /* Error cases. */
    assertThrown("".parseFieldList.each);
    assertThrown(" ".parseFieldList.each);
    assertThrown(",".parseFieldList.each);
    assertThrown("5 6".parseFieldList.each);
    assertThrown(",7".parseFieldList.each);
    assertThrown("8,".parseFieldList.each);
    assertThrown("8,9,".parseFieldList.each);
    assertThrown("10,,11".parseFieldList.each);
    assertThrown("".parseFieldList!(long, Yes.convertToZeroBasedIndex).each);
    assertThrown("1,2-3,".parseFieldList!(long, Yes.convertToZeroBasedIndex).each);
    assertThrown("2-,4".parseFieldList!(long, Yes.convertToZeroBasedIndex).each);
    assertThrown("1,2,3,,4".parseFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown(",7".parseFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown("8,".parseFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown("10,0,,11".parseFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown("8,9,".parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);

    assertThrown("0".parseFieldList.each);
    assertThrown("1,0,3".parseFieldList.each);
    assertThrown("0".parseFieldList!(int, Yes.convertToZeroBasedIndex, No.allowFieldNumZero).each);
    assertThrown("1,0,3".parseFieldList!(int, Yes.convertToZeroBasedIndex, No.allowFieldNumZero).each);
    assertThrown("0-2,6-0".parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown("0-2,6-0".parseFieldList!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown("0-2,6-0".parseFieldList!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
}

/* parseFieldRange parses a single number or number range. E.g. '5' or '5-8'. These are
 * the values in a field-list separated by a comma or other delimiter. It returns a range
 * that iterates over all the values in the range.
 */
private auto parseFieldRange(T = size_t,
                             ConvertToZeroBasedIndex convertToZero = No.convertToZeroBasedIndex,
                             AllowFieldNumZero allowZero = No.allowFieldNumZero)
    (string fieldRange)
if (isIntegral!T && (!allowZero || !convertToZero || !isUnsigned!T))
{
    import std.algorithm : findSplit;
    import std.conv : to;
    import std.format : format;
    import std.range : iota;
    import std.traits : Signed;

    /* Pick the largest compatible integral type for the IOTA range. This must be the
     * signed type if convertToZero is true, as a reverse order range may end at -1.
     */
    static if (convertToZero) alias S = Signed!T;
    else alias S = T;

    if (fieldRange.length == 0) throw new Exception("Empty field number.");

    auto rangeSplit = findSplit(fieldRange, "-");

    if (!rangeSplit[1].empty && (rangeSplit[0].empty || rangeSplit[2].empty))
    {
        // Range starts or ends with a dash.
        throw new Exception(format("Incomplete ranges are not supported: '%s'", fieldRange));
    }

    S start = rangeSplit[0].to!S;
    S last = rangeSplit[1].empty ? start : rangeSplit[2].to!S;
    Signed!T increment = (start <= last) ? 1 : -1;

    static if (allowZero)
    {
        if (start == 0 && !rangeSplit[1].empty)
        {
            throw new Exception(format("Zero cannot be used as part of a range: '%s'", fieldRange));
        }
    }

    static if (allowZero)
    {
        if (start < 0 || last < 0)
        {
            throw new Exception(format("Field numbers must be non-negative integers: '%d'",
                                       (start < 0) ? start : last));
        }
    }
    else
    {
        if (start < 1 || last < 1)
        {
            throw new Exception(format("Field numbers must be greater than zero: '%d'",
                                       (start < 1) ? start : last));
        }
    }

    static if (convertToZero)
    {
        start--;
        last--;
    }

    return iota(start, last + increment, increment);
}

unittest // parseFieldRange
{
    import std.algorithm : equal;
    import std.exception : assertThrown, assertNotThrown;

    /* Basic cases */
    assert(parseFieldRange("1").equal([1]));
    assert("2".parseFieldRange.equal([2]));
    assert("3-4".parseFieldRange.equal([3, 4]));
    assert("3-5".parseFieldRange.equal([3, 4, 5]));
    assert("4-3".parseFieldRange.equal([4, 3]));
    assert("10-1".parseFieldRange.equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));

    /* Convert to zero-based indices */
    assert(parseFieldRange!(size_t, Yes.convertToZeroBasedIndex)("1").equal([0]));
    assert("2".parseFieldRange!(size_t, Yes.convertToZeroBasedIndex).equal([1]));
    assert("3-4".parseFieldRange!(size_t, Yes.convertToZeroBasedIndex).equal([2, 3]));
    assert("3-5".parseFieldRange!(size_t, Yes.convertToZeroBasedIndex).equal([2, 3, 4]));
    assert("4-3".parseFieldRange!(size_t, Yes.convertToZeroBasedIndex).equal([3, 2]));
    assert("10-1".parseFieldRange!(size_t, Yes.convertToZeroBasedIndex).equal([9, 8, 7, 6, 5, 4, 3, 2, 1, 0]));

    /* Allow zero. */
    assert("0".parseFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert(parseFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero)("1").equal([1]));
    assert("3-4".parseFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([3, 4]));
    assert("10-1".parseFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));

    /* Allow zero, convert to zero-based index. */
    assert("0".parseFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([-1]));
    assert(parseFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero)("1").equal([0]));
    assert("3-4".parseFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([2, 3]));
    assert("10-1".parseFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([9, 8, 7, 6, 5, 4, 3, 2, 1, 0]));

    /* Alternate integer types. */
    assert("2".parseFieldRange!uint.equal([2]));
    assert("3-5".parseFieldRange!uint.equal([3, 4, 5]));
    assert("10-1".parseFieldRange!uint.equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));
    assert("2".parseFieldRange!int.equal([2]));
    assert("3-5".parseFieldRange!int.equal([3, 4, 5]));
    assert("10-1".parseFieldRange!int.equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));
    assert("2".parseFieldRange!ushort.equal([2]));
    assert("3-5".parseFieldRange!ushort.equal([3, 4, 5]));
    assert("10-1".parseFieldRange!ushort.equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));
    assert("2".parseFieldRange!short.equal([2]));
    assert("3-5".parseFieldRange!short.equal([3, 4, 5]));
    assert("10-1".parseFieldRange!short.equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));

    assert("0".parseFieldRange!(long, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("0".parseFieldRange!(uint, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("0".parseFieldRange!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("0".parseFieldRange!(ushort, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("0".parseFieldRange!(short, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("0".parseFieldRange!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([-1]));
    assert("0".parseFieldRange!(short, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([-1]));

    /* Max field value cases. */
    assert("65535".parseFieldRange!ushort.equal([65535]));   // ushort max
    assert("65533-65535".parseFieldRange!ushort.equal([65533, 65534, 65535]));
    assert("32767".parseFieldRange!short.equal([32767]));    // short max
    assert("32765-32767".parseFieldRange!short.equal([32765, 32766, 32767]));
    assert("32767".parseFieldRange!(short, Yes.convertToZeroBasedIndex).equal([32766]));

    /* Error cases. */
    assertThrown("".parseFieldRange);
    assertThrown(" ".parseFieldRange);
    assertThrown("-".parseFieldRange);
    assertThrown(" -".parseFieldRange);
    assertThrown("- ".parseFieldRange);
    assertThrown("1-".parseFieldRange);
    assertThrown("-2".parseFieldRange);
    assertThrown("-1".parseFieldRange);
    assertThrown("1.0".parseFieldRange);
    assertThrown("0".parseFieldRange);
    assertThrown("0-3".parseFieldRange);
    assertThrown("-2-4".parseFieldRange);
    assertThrown("2--4".parseFieldRange);
    assertThrown("2-".parseFieldRange);
    assertThrown("a".parseFieldRange);
    assertThrown("0x3".parseFieldRange);
    assertThrown("3U".parseFieldRange);
    assertThrown("1_000".parseFieldRange);
    assertThrown(".".parseFieldRange);

    assertThrown("".parseFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown(" ".parseFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("-".parseFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("1-".parseFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("-2".parseFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("-1".parseFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("0".parseFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("0-3".parseFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("-2-4".parseFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("2--4".parseFieldRange!(size_t, Yes.convertToZeroBasedIndex));

    assertThrown("".parseFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown(" ".parseFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-".parseFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("1-".parseFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-2".parseFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-1".parseFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("0-3".parseFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-2-4".parseFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));

    assertThrown("".parseFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown(" ".parseFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-".parseFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("1-".parseFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-2".parseFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-1".parseFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("0-3".parseFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-2-4".parseFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));

    /* Value out of range cases. */
    assertThrown("65536".parseFieldRange!ushort);   // One more than ushort max.
    assertThrown("65535-65536".parseFieldRange!ushort);
    assertThrown("32768".parseFieldRange!short);    // One more than short max.
    assertThrown("32765-32768".parseFieldRange!short);
    // Convert to zero limits signed range.
    assertThrown("32768".parseFieldRange!(ushort, Yes.convertToZeroBasedIndex));
    assert("32767".parseFieldRange!(ushort, Yes.convertToZeroBasedIndex).equal([32766]));
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

unittest
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
