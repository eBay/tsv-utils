/**
Utilities used by TSV applications.

There are two main utilities in this file:
* InputFieldReordering class - A class that creates a reordered subset of fields from an
  input line. Fields in the subset are accessed by array indicies. This is especially 
  useful when processing the subset in a specific order, such as the order listed on the
  command-line at run-time.

* getTsvFieldValue - A convenience function when only a single value is needed from an
  input line.

Copyright (c) 2015-2017, eBay Software Foundation
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)
*/

import std.traits; 
import std.typecons: Flag;

// InputFieldReording class.

/** Flag used by the InputFieldReordering template. */
alias EnablePartialLines = Flag!"enablePartialLines";

/**
Move select fields from an input line to an output array, reordering along the way.

The InputFieldReordering class is used to reorder a subset of fields from an input line.
The caller instantiates an InputFieldReordering object at the start of input processing. 
The instance contains a mapping from input index to output index, plus a buffer holding
the reordered fields. The caller processes each input line by calling initNewLine,
splitting the line into fields, and calling processNextField on each field. The output
buffer is ready when the allFieldsFilled method returns true.

Fields are not copied, instead the output buffer points to the fields passed by the caller.
The caller needs to use or copy the output buffer while the fields are still valid, which
is normally until reading the next input line. The program below illustrates the basic use
case. It reads stdin and outputs fields [3, 0, 2], in that order.

    int main(string[] args) {
        import tsvutil;
        import std.algorithm, std.array, std.range, std.stdio;
        size_t[] fieldIndicies = [3, 0, 2];
        auto fieldReordering = new InputFieldReordering!char(fieldIndicies);
        foreach (line; stdin.byLine) {
            fieldReordering.initNewLine;
            foreach(fieldIndex, fieldValue; line.splitter('\t').enumerate) {
                fieldReordering.processNextField(fieldIndex, fieldValue);
                if (fieldReordering.allFieldsFilled)
                    break;
            }
            if (fieldReordering.allFieldsFilled)
                writeln(fieldReordering.outputFields.join('\t'));
            else 
                writeln("Error: Insufficient number of field on the line.");
        }
        return 0;
    }

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
     *
     */
    import std.range;
    import std.typecons : Tuple;
    
    alias TupleFromTo = Tuple!(size_t, "from", size_t, "to");

    private C[][] outputFieldsBuf;
    private TupleFromTo[] fromToMap;
    private TupleFromTo[] mapStack;

    final this(const ref size_t[] inputFieldIndicies, size_t start = 0) pure nothrow @safe {
        import std.algorithm : sort;

        outputFieldsBuf = new C[][](inputFieldIndicies.length);
        fromToMap.reserve(inputFieldIndicies.length);

        foreach (to, from; inputFieldIndicies.enumerate(start))
            fromToMap ~= TupleFromTo(from, to);

        sort(fromToMap);
        initNewLine;
    }

    /** initNewLine initializes the object for a new line. */
    final void initNewLine() pure nothrow @safe {
        mapStack = fromToMap;
        static if (partialLinesOk) {
            import std.algorithm : each;
            outputFieldsBuf.each!((ref s) => s.length = 0);
        }
    }

    /** processNextField maps an input field to the correct locations in the outputFields
     * array. It should be called once for each field on the line, in the order found.
     */
    final size_t processNextField(size_t fieldIndex, C[] fieldValue) pure nothrow @safe @nogc {
        size_t numFilled = 0;
        while (!mapStack.empty && fieldIndex == mapStack.front.from) {
            outputFieldsBuf[mapStack.front.to] = fieldValue;
            mapStack.popFront;
            numFilled++;
        }
        return numFilled;
    }

    /** allFieldsFilled returned true if all fields expected have been processed. */
    final bool allFieldsFilled() const pure nothrow @safe @nogc {
        return mapStack.empty;
    }

    /** outputFields is the assembled output fields. Unless partial lines are enabled,
     * it is only valid after allFieldsFilled is true.
     */
    final C[][] outputFields() pure nothrow @safe @nogc {
        return outputFieldsBuf[];
    }
}

/* Tests using different character types. */
unittest {
    import std.conv;
    
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

    foreach (lineIndex, line; inputLines) {
        charIFR.initNewLine;
        wcharIFR.initNewLine;
        dcharIFR.initNewLine;

        foreach (fieldIndex, fieldValue; line) {
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
unittest {
    import std.conv;
    
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

    foreach (lineIndex, line; inputLines) {
        charIFR.initNewLine;
        foreach (fieldIndex, fieldValue; line) {
            charIFR.processNextField(fieldIndex, to!(char[])(fieldValue));
            assert(charIFR.outputFields == charExpectedBylineByfield_2_0[lineIndex][fieldIndex]);
        }
    }
}

/* Field combination tests. */
unittest {
    import std.conv;
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

    foreach (lineIndex, line; inputLines) {
        ifr_0.initNewLine;
        ifr_3.initNewLine;
        ifr_01.initNewLine;
        ifr_10.initNewLine;
        ifr_03.initNewLine;
        ifr_30.initNewLine;
        ifr_0123.initNewLine;
        ifr_3210.initNewLine;
        ifr_03001.initNewLine;

        foreach (fieldIndex, fieldValue; line) {
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
    import std.conv;
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
             * column file. Correct for the case would be a single value representing an
             * empty string. The input line is a convenient source of an empty line. Info:
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
                       fieldIndex + 1, atField + 1));
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
    import std.conv;
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
