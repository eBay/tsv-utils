/**
Utilities used by TSV applications.

Copyright (c) 2015-2016, eBay Software Foundation
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
