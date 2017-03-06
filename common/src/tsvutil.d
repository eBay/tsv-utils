/**
Utilities used by TSV applications.

Utilities in this file:
* InputFieldReordering class - A class that creates a reordered subset of fields from an
  input line. Fields in the subset are accessed by array indicies. This is especially 
  useful when processing the subset in a specific order, such as the order listed on the
  command-line at run-time.

* getTsvFieldValue - A convenience function when only a single value is needed from an
  input line.

* formatNumber - An alternate print format for numbers, especially useful when doubles
  are being used to represent integer and float values.

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

    int main(string[] args)
    {
        import tsvutil;
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

/**
formatNumber is an alternate way to print numbers. It is especially useful when representing
both integral and floating point values with float point data types.

formatNumber was created for tsv-summarize, where all calculations are done as doubles, but
may be integers by nature. In addition, output may be either for human consumption or for
additional machine processing. Integers are printed normally. Floating point is printed as
follows:

- Values that are exact integral values are printed as integers, as long as they are within
  the range of where all integers are represented exactly by the floating point type. The
  practical effect is to avoid switching to exponential notion.

- If the specified floatPrecision is between 0 and readablePrecisionMax, then floatPrecision
  is used to set the significant digits following the decimal point. Otherwise, it is used
  to set total significant digits. This does not apply to really large numbers, for doubles,
  those larger than 2^53. Trailing zeros are chopped in all cases.
*/
import std.traits : isFloatingPoint, isIntegral, Unqual;
auto formatNumber(T, size_t readablePrecisionMax = 6)(T num, const size_t floatPrecision = 12)
    if (isFloatingPoint!T || isIntegral!T)
{
    alias UT = Unqual!T;

    import std.conv;
    import std.format;
    
    static if (isIntegral!T)
    {
        return format("%d", num);  // The easy case.
    }
    else 
    {
        static assert(isFloatingPoint!T);
        
        static if (!is(UT == float) && !is(UT == double))
        {
            /* Not a double or float, but a floating point. Punt on refinements. */
            return format("%.*g", floatPrecision, num);
        }
        else
        {
            static assert(is(UT == float) || is(UT == double));

            if (floatPrecision <= readablePrecisionMax)
            {
                /* Print with a fixed precision beyond the decimal point (%.*f), but
                 * remove trailing zeros. Notes:
                 * - This handles integer values stored in floating point types.
                 * - Values like NaN and infinity also handled.
                 */
                auto str = format("%.*f", floatPrecision, num);
                size_t trimToLength = str.length;
                
                if (floatPrecision != 0 && str.length > floatPrecision + 1)
                {
                    import std.ascii : isDigit;
                    assert(str.length - floatPrecision - 1 > 0);
                    size_t decimalIndex = str.length - floatPrecision - 1;

                    if (str[decimalIndex] == '.' && str[decimalIndex - 1].isDigit)
                    {
                        size_t lastNonZeroDigit = str.length - 1;
                        assert(decimalIndex < lastNonZeroDigit);
                        while (str[lastNonZeroDigit] == '0') lastNonZeroDigit--;
                        trimToLength = (decimalIndex < lastNonZeroDigit)
                            ? lastNonZeroDigit + 1
                            : decimalIndex;
                    }
                }

                return str[0 .. trimToLength];
            }
            else
            {
                /* Determine if the number is subject to special integer value printing.
                 * Goal is to avoid exponential notion for integer values that '%.*g'
                 * generates. Numbers within the significant digit range of floatPrecision
                 * will print as desired with '%.*g', whether there is a fractional part
                 * or not. The '%.*g' format, with exponential notation, is also used for
                 * really large numbers. "Really large" being numbers outside the range
                 * of integers exactly representable by the floating point type.
                 */

                enum UT maxConsecutiveUTInteger = 2.0^^UT.mant_dig;
                enum bool maxUTIntFitsInLong = (maxConsecutiveUTInteger <= long.max);

                import std.math : fabs;
                immutable UT absNum = num.fabs;

                if (!maxUTIntFitsInLong ||
                    absNum < 10.0^^floatPrecision ||
                    absNum > maxConsecutiveUTInteger)
                {
                    /* Within signficant digits range or very large. */
                    return format("%.*g", floatPrecision, num);
                }
                else
                {
                    /* Check for integral values needing to be printed in decimal format. 
                     * modf/modff are used to determine if the value has a non-zero
                     * fractional component.
                     */
                    import core.stdc.math : modf, modff;
                
                    static if (is(UT == float)) alias modfUT = modff;
                    else static if (is(UT == double)) alias modfUT = modf;
                    else static assert(0);
                
                    UT integerPart;

                    if (modfUT(num, &integerPart) == 0.0) return format("%d", num.to!long);
                    else return format("%.*g", floatPrecision, num);
                }
            }
        }
    }
    assert(0);
}

unittest  // formatNumber unit tests
{
    import std.conv;
    import std.format;

    /* Integers */
    assert(formatNumber(0) == "0");
    assert(formatNumber(1) == "1");
    assert(formatNumber(-1) == "-1");
    assert(formatNumber(999) == "999");
    assert(formatNumber(12345678912345) == "12345678912345");
    assert(formatNumber(-12345678912345) == "-12345678912345");

    size_t a1 = 10;                      assert(a1.formatNumber == "10");
    const int a2 = -33234;               assert(a2.formatNumber == "-33234");
    immutable long a3 = -12345678912345; assert(a3.formatNumber == "-12345678912345");

    // Specifying precision should never matter for integer values.
    assert(formatNumber(0, 0) == "0");
    assert(formatNumber(1, 0) == "1");
    assert(formatNumber(-1, 0) == "-1");
    assert(formatNumber(999, 0) == "999");
    assert(formatNumber(12345678912345, 0) == "12345678912345");
    assert(formatNumber(-12345678912345, 0) == "-12345678912345");

    assert(formatNumber(0, 3) == "0");
    assert(formatNumber(1, 3) == "1");
    assert(formatNumber(-1, 3 ) == "-1");
    assert(formatNumber(999, 3) == "999");
    assert(formatNumber(12345678912345, 3) == "12345678912345");
    assert(formatNumber(-12345678912345, 3) == "-12345678912345");

    assert(formatNumber(0, 9) == "0");
    assert(formatNumber(1, 9) == "1");
    assert(formatNumber(-1, 9 ) == "-1");
    assert(formatNumber(999, 9) == "999");
    assert(formatNumber(12345678912345, 9) == "12345678912345");
    assert(formatNumber(-12345678912345, 9) == "-12345678912345");

    /* Doubles */
    assert(formatNumber(0.0) == "0");
    assert(formatNumber(0.2) == "0.2");
    assert(formatNumber(0.123412, 0) == "0");
    assert(formatNumber(0.123412, 1) == "0.1");
    assert(formatNumber(0.123412, 2) == "0.12");
    assert(formatNumber(0.123412, 5) == "0.12341");
    assert(formatNumber(0.123412, 6) == "0.123412");
    assert(formatNumber(0.123412, 7) == "0.123412");
    assert(formatNumber(9.123412, 5) == "9.12341");
    assert(formatNumber(9.123412, 6) == "9.123412");
    assert(formatNumber(99.123412, 5) == "99.12341");
    assert(formatNumber(99.123412, 6) == "99.123412");
    assert(formatNumber(99.123412, 7) == "99.12341");
    assert(formatNumber(999.123412, 0) == "999");
    assert(formatNumber(999.123412, 1) == "999.1");
    assert(formatNumber(999.123412, 2) == "999.12");
    assert(formatNumber(999.123412, 3) == "999.123");
    assert(formatNumber(999.123412, 4) == "999.1234");
    assert(formatNumber(999.123412, 5) == "999.12341");
    assert(formatNumber(999.123412, 6) == "999.123412");
    assert(formatNumber(999.123412, 7) == "999.1234");
    assert(formatNumber!(double, 9)(999.12341234, 7) == "999.1234123");
    assert(formatNumber(9001.0) == "9001");
    assert(formatNumber(1234567891234.0) == "1234567891234");
    assert(formatNumber(1234567891234.0, 0) == "1234567891234");
    assert(formatNumber(1234567891234.0, 1) == "1234567891234");

    // Test round off cases
    assert(formatNumber(0.6, 0) == "1");
    assert(formatNumber(0.6, 1) == "0.6");
    assert(formatNumber(0.06, 0) == "0");
    assert(formatNumber(0.06, 1) == "0.1");
    assert(formatNumber(0.06, 2) == "0.06");
    assert(formatNumber(0.06, 3) == "0.06");
    assert(formatNumber(9.49999, 0) == "9");
    assert(formatNumber(9.49999, 1) == "9.5");
    assert(formatNumber(9.6, 0) == "10");
    assert(formatNumber(9.6, 1) == "9.6");
    assert(formatNumber(99.99, 0) == "100");
    assert(formatNumber(99.99, 1) == "100");
    assert(formatNumber(99.99, 2) == "99.99");
    assert(formatNumber(9999.9996, 3) == "10000");
    assert(formatNumber(9999.9996, 4) == "9999.9996");
    assert(formatNumber(99999.99996, 4) == "100000");
    assert(formatNumber(99999.99996, 5) == "99999.99996");
    assert(formatNumber(999999.999996, 5) == "1000000");
    assert(formatNumber(999999.999996, 6) == "999999.999996");
    
    /* Turn off precision, the 'human readable' style.
     * Note: Remains o if both are zero (first test). If it becomes desirable to support
     * turning it off when for the precision equal zero case the simple extension is to
     * allow the 'human readable' precision template parameter to be negative.
     */
    assert(formatNumber!(double, 0)(999.123412, 0) == "999");
    assert(formatNumber!(double, 0)(999.123412, 1) == "1e+03");
    assert(formatNumber!(double, 0)(999.123412, 2) == "1e+03");
    assert(formatNumber!(double, 0)(999.123412, 3) == "999");
    assert(formatNumber!(double, 0)(999.123412, 4) == "999.1");

    // Default number printing
    assert(formatNumber(1.2) == "1.2");
    assert(formatNumber(12.3) == "12.3");
    assert(formatNumber(12.34) == "12.34");
    assert(formatNumber(123.45) == "123.45");
    assert(formatNumber(123.456) == "123.456");
    assert(formatNumber(1234.567) == "1234.567");
    assert(formatNumber(1234.5678) == "1234.5678");
    assert(formatNumber(12345.6789) == "12345.6789");
    assert(formatNumber(12345.67891) == "12345.67891");
    assert(formatNumber(123456.78912) == "123456.78912");
    assert(formatNumber(123456.789123) == "123456.789123");
    assert(formatNumber(1234567.891234) == "1234567.89123");
    assert(formatNumber(12345678.912345) == "12345678.9123");
    assert(formatNumber(123456789.12345) == "123456789.123");
    assert(formatNumber(1234567891.2345) == "1234567891.23");
    assert(formatNumber(12345678912.345) == "12345678912.3");
    assert(formatNumber(123456789123.45) == "123456789123");
    assert(formatNumber(1234567891234.5) == "1.23456789123e+12");
    assert(formatNumber(12345678912345.6) == "1.23456789123e+13");
    assert(formatNumber(123456789123456.0) == "123456789123456");
    assert(formatNumber(0.3) == "0.3");
    assert(formatNumber(0.03) == "0.03");
    assert(formatNumber(0.003) == "0.003");
    assert(formatNumber(0.0003) == "0.0003");
    assert(formatNumber(0.00003) == "3e-05" || formatNumber(0.00003) == "3e-5");
    assert(formatNumber(0.000003) == "3e-06" || formatNumber(0.000003) == "3e-6");
    assert(formatNumber(0.0000003) == "3e-07" || formatNumber(0.0000003) == "3e-7");
    
    // Large number inside and outside the contiguous integer representation range
    double dlarge = 2.0^^(double.mant_dig - 2) - 10.0;
    double dhuge =  2.0^^(double.mant_dig + 1) + 1000.0;

    assert(dlarge.formatNumber == format("%d", dlarge.to!long));
    assert(dhuge.formatNumber!(double) == format("%.12g", dhuge));

    // Negative values - Repeat most of above tests.
    assert(formatNumber(-0.0) == "-0" || formatNumber(-0.0) == "0");
    assert(formatNumber(-0.2) == "-0.2");
    assert(formatNumber(-0.123412, 0) == "-0");
    assert(formatNumber(-0.123412, 1) == "-0.1");
    assert(formatNumber(-0.123412, 2) == "-0.12");
    assert(formatNumber(-0.123412, 5) == "-0.12341");
    assert(formatNumber(-0.123412, 6) == "-0.123412");
    assert(formatNumber(-0.123412, 7) == "-0.123412");
    assert(formatNumber(-9.123412, 5) == "-9.12341");
    assert(formatNumber(-9.123412, 6) == "-9.123412");
    assert(formatNumber(-99.123412, 5) == "-99.12341");
    assert(formatNumber(-99.123412, 6) == "-99.123412");
    assert(formatNumber(-99.123412, 7) == "-99.12341");
    assert(formatNumber(-999.123412, 0) == "-999");
    assert(formatNumber(-999.123412, 1) == "-999.1");
    assert(formatNumber(-999.123412, 2) == "-999.12");
    assert(formatNumber(-999.123412, 3) == "-999.123");
    assert(formatNumber(-999.123412, 4) == "-999.1234");
    assert(formatNumber(-999.123412, 5) == "-999.12341");
    assert(formatNumber(-999.123412, 6) == "-999.123412");
    assert(formatNumber(-999.123412, 7) == "-999.1234");
    assert(formatNumber!(double, 9)(-999.12341234, 7) == "-999.1234123");
    assert(formatNumber(-9001.0) == "-9001");
    assert(formatNumber(-1234567891234.0) == "-1234567891234");
    assert(formatNumber(-1234567891234.0, 0) == "-1234567891234");
    assert(formatNumber(-1234567891234.0, 1) == "-1234567891234");

    // Test round off cases
    assert(formatNumber(-0.6, 0) == "-1");
    assert(formatNumber(-0.6, 1) == "-0.6");
    assert(formatNumber(-0.06, 0) == "-0");
    assert(formatNumber(-0.06, 1) == "-0.1");
    assert(formatNumber(-0.06, 2) == "-0.06");
    assert(formatNumber(-0.06, 3) == "-0.06");
    assert(formatNumber(-9.49999, 0) == "-9");
    assert(formatNumber(-9.49999, 1) == "-9.5");
    assert(formatNumber(-9.6, 0) == "-10");
    assert(formatNumber(-9.6, 1) == "-9.6");
    assert(formatNumber(-99.99, 0) == "-100");
    assert(formatNumber(-99.99, 1) == "-100");
    assert(formatNumber(-99.99, 2) == "-99.99");
    assert(formatNumber(-9999.9996, 3) == "-10000");
    assert(formatNumber(-9999.9996, 4) == "-9999.9996");
    assert(formatNumber(-99999.99996, 4) == "-100000");
    assert(formatNumber(-99999.99996, 5) == "-99999.99996");
    assert(formatNumber(-999999.999996, 5) == "-1000000");
    assert(formatNumber(-999999.999996, 6) == "-999999.999996");

    assert(formatNumber!(double, 0)(-999.123412, 0) == "-999");
    assert(formatNumber!(double, 0)(-999.123412, 1) == "-1e+03");
    assert(formatNumber!(double, 0)(-999.123412, 2) == "-1e+03");
    assert(formatNumber!(double, 0)(-999.123412, 3) == "-999");
    assert(formatNumber!(double, 0)(-999.123412, 4) == "-999.1");

    // Default number printing
    assert(formatNumber(-1.2) == "-1.2");
    assert(formatNumber(-12.3) == "-12.3");
    assert(formatNumber(-12.34) == "-12.34");
    assert(formatNumber(-123.45) == "-123.45");
    assert(formatNumber(-123.456) == "-123.456");
    assert(formatNumber(-1234.567) == "-1234.567");
    assert(formatNumber(-1234.5678) == "-1234.5678");
    assert(formatNumber(-12345.6789) == "-12345.6789");
    assert(formatNumber(-12345.67891) == "-12345.67891");
    assert(formatNumber(-123456.78912) == "-123456.78912");
    assert(formatNumber(-123456.789123) == "-123456.789123");
    assert(formatNumber(-1234567.891234) == "-1234567.89123");

    assert(formatNumber(-12345678.912345) == "-12345678.9123");
    assert(formatNumber(-123456789.12345) == "-123456789.123");
    assert(formatNumber(-1234567891.2345) == "-1234567891.23");
    assert(formatNumber(-12345678912.345) == "-12345678912.3");
    assert(formatNumber(-123456789123.45) == "-123456789123");
    assert(formatNumber(-1234567891234.5) == "-1.23456789123e+12");
    assert(formatNumber(-12345678912345.6) == "-1.23456789123e+13");
    assert(formatNumber(-123456789123456.0) == "-123456789123456");

    assert(formatNumber(-0.3) == "-0.3");
    assert(formatNumber(-0.03) == "-0.03");
    assert(formatNumber(-0.003) == "-0.003");
    assert(formatNumber(-0.0003) == "-0.0003");
    assert(formatNumber(-0.00003) == "-3e-05" || formatNumber(-0.00003) == "-3e-5");
    assert(formatNumber(-0.000003) == "-3e-06" || formatNumber(-0.000003) == "-3e-6");
    assert(formatNumber(-0.0000003) == "-3e-07" || formatNumber(-0.0000003) == "-3e-7");
    
    const double dlargeNeg = -2.0^^(double.mant_dig - 2) + 10.0;
    immutable double dhugeNeg =  -2.0^^(double.mant_dig + 1) - 1000.0;

    assert(dlargeNeg.formatNumber == format("%d", dlargeNeg.to!long));
    assert(dhugeNeg.formatNumber!(double) == format("%.12g", dhugeNeg));

    // Type qualifiers
    const double b1 = 0.0;           assert(formatNumber(b1) == "0");
    const double b2 = 0.2;           assert(formatNumber(b2) == "0.2");
    const double b3 = 0.123412;      assert(formatNumber(b3, 2) == "0.12");
    immutable double b4 = 99.123412; assert(formatNumber(b4, 5) == "99.12341");
    immutable double b5 = 99.123412; assert(formatNumber(b5, 7) == "99.12341");

    // Special values
    assert(formatNumber(double.nan) == "nan");
    assert(formatNumber(double.nan, 0) == "nan");
    assert(formatNumber(double.nan, 1) == "nan");
    assert(formatNumber(double.nan, 9) == "nan");
    assert(formatNumber(double.infinity) == "inf");
    assert(formatNumber(double.infinity, 0) == "inf");
    assert(formatNumber(double.infinity, 1) == "inf");
    assert(formatNumber(double.infinity, 9) == "inf");

    // Float. Mix negative and type qualifiers in.
    assert(formatNumber(0.0f) == "0");
    assert(formatNumber(0.5f) == "0.5");    
    assert(formatNumber(0.123412f, 0) == "0");
    assert(formatNumber(0.123412f, 1) == "0.1");
    assert(formatNumber(-0.123412f, 2) == "-0.12");
    assert(formatNumber(9.123412f, 5) == "9.12341");
    assert(formatNumber(9.123412f, 6) == "9.123412");
    assert(formatNumber(-99.123412f, 5) == "-99.12341");
    assert(formatNumber(99.123412f, 7) == "99.12341");
    assert(formatNumber(-999.123412f, 5) == "-999.12341");
    
    float c1 = 999.123412f;           assert(formatNumber(c1, 7) == "999.1234");
    float c2 = 999.1234f;             assert(formatNumber!(float, 9)(c2, 3) == "999.123");
    const float c3 = 9001.0f;         assert(formatNumber(c3) == "9001");
    const float c4 = -12345678.0f;    assert(formatNumber(c4) == "-12345678");
    immutable float c5 = 12345678.0f; assert(formatNumber(c5, 0) == "12345678");
    immutable float c6 = 12345678.0f; assert(formatNumber(c6, 1) == "12345678");

    float flarge = 2.0^^(float.mant_dig - 2) - 10.0;
    float fhuge =  2.0^^(float.mant_dig + 1) + 1000.0;

    assert(flarge.formatNumber == format("%d", flarge.to!long));
    assert(fhuge.formatNumber!(float, 12) == format("%.12g", fhuge));

    // Reals - No special formatting
    real d1 = 2.0^^(double.mant_dig) - 1000.0; assert(formatNumber(d1) == format("%.12g", d1));
    real d2 = 123456789.12341234L;             assert(formatNumber(d2, 12) == format("%.12g", d2));
}
