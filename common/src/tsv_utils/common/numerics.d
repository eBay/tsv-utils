/**
Numeric related utilities used by TSV Utilities.

Utilities in this file:
$(LIST
    * [formatNumber] - An alternate print format for numbers, especially useful when
      doubles are being used to represent integer and float values.

    * [rangeMedian] - Finds the median value of a range.

    * [quantile] - Generates quantile values for a data set.
)

Copyright (c) 2016-2020, eBay Inc.
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)
*/

module tsv_utils.common.numerics;

import std.traits : isFloatingPoint, isIntegral, Unqual;

/**
formatNumber is an alternate way to print numbers. It is especially useful when
representing both integral and floating point values with float point data types.

formatNumber was created for tsv-summarize, where all calculations are done as doubles,
but may be integers by nature. In addition, output may be either for human consumption
or for additional machine processing. Integers are printed normally. Floating point is
printed as follows:
$(LIST
    * Values that are exact integral values are printed as integers, as long as they
      are within the range of where all integers are represented exactly by the floating
      point type. The practical effect is to avoid switching to exponential notion.

    * If the specified floatPrecision is between 0 and readablePrecisionMax, then
      floatPrecision is used to set the significant digits following the decimal point.
      Otherwise, it is used to set total significant digits. This does not apply to
      really large numbers, for doubles, those larger than 2^53. Trailing zeros are
      chopped in all cases.
)
*/
auto formatNumber(T, size_t readablePrecisionMax = 6)(T num, const size_t floatPrecision = 12)
if (isFloatingPoint!T || isIntegral!T)
{
    alias UT = Unqual!T;

    import std.conv : to;
    import std.format : format;

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
                immutable str = format("%.*f", floatPrecision, num);
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
    import std.conv : to;
    import std.format : format;

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

/**
rangeMedian. Finds the median. Modifies the range via topN or sort in the process.

Note: topN is the preferred algorithm, but the version prior to Phobos 2.073
is pathologically slow on certain data sets. Use topN in 2.073 and later,
sort in earlier versions.

See: https://issues.dlang.org/show_bug.cgi?id=16517
     https://github.com/dlang/phobos/pull/4815
     http://forum.dlang.org/post/ujuugklmbibuheptdwcn@forum.dlang.org
*/
static if (__VERSION__ >= 2073)
{
    version = rangeMedianViaTopN;
}
else
{
    version = rangeMedianViaSort;
}

auto rangeMedian (Range) (Range r)
if (isRandomAccessRange!Range && hasLength!Range && hasSlicing!Range)
{
    version(rangeMedianViaSort)
    {
        version(rangeMedianViaTopN)
        {
            assert(0, "Both rangeMedianViaSort and rangeMedianViaTopN assigned as versions. Assign only one.");
        }
    }
    else version(rangeMedianViaTopN)
    {
    }
    else
    {
        static assert(0, "A version of rangeMedianViaSort or rangeMedianViaTopN must be assigned.");
    }

    import std.traits : isFloatingPoint;

    ElementType!Range median;

    if (r.length > 0)
    {
        size_t medianIndex = r.length / 2;

        version(rangeMedianViaSort)
        {
            import std.algorithm : sort;
            sort(r);
            median = r[medianIndex];

            static if (isFloatingPoint!(ElementType!Range))
            {
                if (r.length % 2 == 0)
                {
                    /* Even number of values. Split the difference. */
                    median = (median + r[medianIndex - 1]) / 2.0;
                }
            }
        }
        else version(rangeMedianViaTopN)
        {
            import std.algorithm : maxElement, topN;
            topN(r, medianIndex);
            median = r[medianIndex];

            static if (isFloatingPoint!(ElementType!Range))
            {
                if (r.length % 2 == 0)
                {
                    /* Even number of values. Split the difference. */
                    if (r[medianIndex - 1] < median)
                    {
                        median = (median + r[0..medianIndex].maxElement) / 2.0;
                    }
                }
            }
        }
        else
        {
            static assert(0, "A version of rangeMedianViaSort or rangeMedianViaTopN must be assigned.");
        }
    }

    return median;
}

/* rangeMedian unit tests. */
@safe unittest
{
    import std.math : isNaN;
    import std.algorithm : all, permutations;

    // Median of empty range is (type).init. Zero for int, nan for floats/doubles
    assert(rangeMedian(new int[0]) == int.init);
    assert(rangeMedian(new double[0]).isNaN && double.init.isNaN);
    assert(rangeMedian(new string[0]) == "");

    assert(rangeMedian([3]) == 3);
    assert(rangeMedian([3.0]) == 3.0);
    assert(rangeMedian([3.5]) == 3.5);
    assert(rangeMedian(["aaa"]) == "aaa");

    /* Even number of elements: Split the difference for floating point, but not other types. */
    assert(rangeMedian([3, 4]) == 4);
    assert(rangeMedian([3.0, 4.0]) == 3.5);

    assert(rangeMedian([3, 6, 12]) == 6);
    assert(rangeMedian([3.0, 6.5, 12.5]) == 6.5);

    // Do the rest with permutations
    assert([4, 7].permutations.all!(x => (x.rangeMedian == 7)));
    assert([4.0, 7.0].permutations.all!(x => (x.rangeMedian == 5.5)));
    assert(["aaa", "bbb"].permutations.all!(x => (x.rangeMedian == "bbb")));

    assert([4, 7, 19].permutations.all!(x => (x.rangeMedian == 7)));
    assert([4.5, 7.5, 19.5].permutations.all!(x => (x.rangeMedian == 7.5)));
    assert(["aaa", "bbb", "ccc"].permutations.all!(x => (x.rangeMedian == "bbb")));

    assert([4.5, 7.5, 19.5, 21.0].permutations.all!(x => (x.rangeMedian == 13.5)));
    assert([4.5, 7.5, 19.5, 20.5, 36.0].permutations.all!(x => (x.rangeMedian == 19.5)));
    assert([4.5, 7.5, 19.5, 24.0, 24.5, 25.0].permutations.all!(x => (x.rangeMedian == 21.75)));
    assert([1.5, 3.25, 3.55, 4.5, 24.5, 25.0, 25.6].permutations.all!(x => (x.rangeMedian == 4.5)));
}

/// Quantiles

/** The different quantile interpolation methods.
 * See: https://stat.ethz.ch/R-manual/R-devel/library/stats/html/quantile.html
 */
enum QuantileInterpolation
{
    R1 = 1, /// R quantile type 1
    R2 = 2, /// R quantile type 2
    R3 = 3, /// R quantile type 3
    R4 = 4, /// R quantile type 4
    R5 = 5, /// R quantile type 5
    R6 = 6, /// R quantile type 6
    R7 = 7, /// R quantile type 7
    R8 = 8, /// R quantile type 8
    R9 = 9, /// R quantile type 9
}


import std.traits : isFloatingPoint, isNumeric, Unqual;
import std.range;

/**
Returns the quantile in a data vector for a cumulative probability.

Takes a data vector and a probability and returns the quantile cut point for the
probability. The vector must be sorted and the probability in the range [0.0, 1.0].
The interpolation methods available are the same as in R and available in a number
of statistical packages. See the R documentation or wikipedia for details
(https://en.wikipedia.org/wiki/Quantile).

Examples:
----
double data = [22, 57, 73, 97, 113];
double median = quantile(0.5, data);   // 73
auto q1 = [0.25, 0.5, 0.75].map!(p => p.quantile(data));  // 57, 73, 97
auto q2 = [0.25, 0.5, 0.75].map!(p => p.quantile(data), QuantileInterpolation.R8);  //45.3333, 73, 102.333
----
*/
double quantile(ProbType, Range)
    (const ProbType prob, Range data, QuantileInterpolation method = QuantileInterpolation.R7)
if (isRandomAccessRange!Range && hasLength!Range && isNumeric!(ElementType!Range) &&
    isFloatingPoint!ProbType)
in
{
    import std.algorithm : isSorted;
    assert(0.0 <= prob && prob <= 1.0);
    assert(method >= QuantileInterpolation.min && method <= QuantileInterpolation.max);
    assert(data.isSorted);
}
do
{
    import core.stdc.math : modf;
    import std.algorithm : max, min;
    import std.conv : to;
    import std.math : ceil, lrint;

    /* Note: In the implementation below, 'h1' is the 1-based index into the data vector.
     * This follows the wikipedia notation for the interpolation methods. One will be
     * subtracted before the vector is accessed.
     */

    double q = double.nan;     // The return value.

    if (data.length == 1) q = data[0].to!double;
    else if (data.length > 1)
    {
        if (method == QuantileInterpolation.R1)
        {
            q = data[((data.length * prob).ceil - 1.0).to!long.max(0).to!size_t].to!double;
        }
        else if (method == QuantileInterpolation.R2)
        {
            immutable double h1 = data.length * prob + 0.5;
            immutable size_t lo = ((h1 - 0.5).ceil.to!long - 1).max(0);
            immutable size_t hi = ((h1 + 0.5).to!size_t - 1).min(data.length - 1);
            q = (data[lo].to!double + data[hi].to!double) / 2.0;
        }
        else if (method == QuantileInterpolation.R3)
        {
            /* Implementation notes:
             * - R3 uses 'banker's rounding', where 0.5 is rounded to the nearest even
             *   value. The 'lrint' routine does this.
             * - DMD will sometimes choose the incorrect 0.5 rounding if the calculation
             *   is done as a single step. The separate calculation of 'h1' avoids this.
             */
            immutable double h1 = data.length * prob;
            q = data[h1.lrint.max(1) - 1].to!double;
        }
        else if ((method == QuantileInterpolation.R4) ||
                 (method == QuantileInterpolation.R5) ||
                 (method == QuantileInterpolation.R6) ||
                 (method == QuantileInterpolation.R7) ||
                 (method == QuantileInterpolation.R8) ||
                 (method == QuantileInterpolation.R9))
        {
            /* Methods 4-9 have different formulas for generating the real-valued index,
             * but work the same after that, choosing the final value by linear interpolation.
             */
            double h1;
            switch (method)
            {
            case QuantileInterpolation.R4: h1 = data.length * prob; break;
            case QuantileInterpolation.R5: h1 = data.length * prob + 0.5; break;
            case QuantileInterpolation.R6: h1 = (data.length + 1) * prob; break;
            case QuantileInterpolation.R7: h1 = (data.length - 1) * prob + 1.0; break;
            case QuantileInterpolation.R8: h1 = (data.length.to!double + 1.0/3.0) * prob + 1.0/3.0; break;
            case QuantileInterpolation.R9: h1 = (data.length + 0.25) * prob + 3.0/8.0; break;
            default: assert(0);
            }

            double h1IntegerPart;
            immutable double h1FractionPart = modf(h1, &h1IntegerPart);
            immutable size_t lo = (h1IntegerPart - 1.0).to!long.max(0).min(data.length - 1);
            q = data[lo];
            if (h1FractionPart > 0.0)
            {
                immutable size_t hi = h1IntegerPart.to!long.min(data.length - 1);
                q += h1FractionPart * (data[hi].to!double - data[lo].to!double);
            }
        }
        else assert(0);
    }
    return q;
}

unittest
{
    import std.algorithm : equal, map;
    import std.array : array;
    import std.traits : EnumMembers;

    /* A couple simple tests. */
    assert(quantile(0.5, [22, 57, 73, 97, 113]) == 73);
    assert(quantile(0.5, [22.5, 57.5, 73.5, 97.5, 113.5]) == 73.5);
    assert([0.25, 0.5, 0.75].map!(p => p.quantile([22, 57, 73, 97, 113])).array == [57.0, 73.0, 97.0]);
    assert([0.25, 0.5, 0.75].map!(p => p.quantile([22, 57, 73, 97, 113], QuantileInterpolation.R1)).array == [57.0, 73.0, 97.0]);

    /* Data arrays. */
    double[] d1 = [];
    double[] d2 = [5.5];
    double[] d3 = [0.0, 1.0];
    double[] d4 = [-1.0, 1.0];
    double[] d5 = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0];
    double[] d6 = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0];
    double[] d7  = [ 31.79,  64.19,  81.77];
    double[] d8  = [-94.43, -74.55, -50.81,  27.45,  78.79];
    double[] d9  = [-89.17,  20.93,  38.51,  48.03,  76.43,  77.02];
    double[] d10 = [-99.53, -76.87, -76.69, -67.81, -40.26, -11.29,  21.02];
    double[] d11 = [-78.32, -52.22, -50.86,  13.45,  15.96,  17.25,  46.35,  85.00];
    double[] d12 = [-81.36, -70.87, -53.56, -42.14,  -9.18,   7.23,  49.52,  80.43,  98.50];
    double[] d13 = [ 38.37,  44.36,  45.70,  50.69,  51.36,  55.66,  56.91,  58.95,  62.01,  65.25];

    /* Spot check a few other data types. Same expected outputs.*/
    int[] d3Int = [0, 1];
    int[] d4Int = [-1, 1];
    int[] d5Int = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    size_t[] d6Size_t = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
    float[] d7Float  = [ 31.79f,  64.19f,  81.77f];
    float[] d8Float  = [-94.43f, -74.55f, -50.81f,  27.45f,  78.79f];
    float[] d9Float  = [-89.17f,  20.93f,  38.51f,  48.03f,  76.43f,  77.02f];
    float[] d10Float = [-99.53f, -76.87f, -76.69f, -67.81f, -40.26f, -11.29f,  21.02f];

    /* Probability values. */
    double[] probs = [0.0, 0.05, 0.1, 0.25, 0.4, 0.49, 0.5, 0.51, 0.75, 0.9, 0.95, 0.98, 1.0];

    /* Expected values for each data array, for 'probs'. One expected result for each of the nine methods.
     * The expected values were generated by R and Octave.
     */
    double[13][9] d1_expected; // All values double.nan, the default.
    double[13][9] d2_expected = [
        [5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5],
        [5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5],
        [5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5],
        [5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5],
        [5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5],
        [5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5],
        [5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5],
        [5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5],
        [5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5],
        ];
    double[13][9] d3_expected = [
        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.02, 0.5, 0.8, 0.9, 0.96, 1.0],
        [0.0, 0.0, 0.0, 0.0, 0.3, 0.48, 0.5, 0.52, 1.0, 1.0, 1.0, 1.0, 1.0],
        [0.0, 0.0, 0.0, 0.0, 0.2, 0.47, 0.5, 0.53, 1.0, 1.0, 1.0, 1.0, 1.0],
        [0.0, 0.05, 0.1, 0.25, 0.4, 0.49, 0.5, 0.51, 0.75, 0.9, 0.95, 0.98, 1.0],
        [0.0, 0.0, 0.0, 0.0, 0.2666667, 0.4766667, 0.5, 0.5233333, 1.0, 1.0, 1.0, 1.0, 1.0],
        [0.0, 0.0, 0.0, 0.0, 0.275, 0.4775, 0.5, 0.5225, 1.0, 1.0, 1.0, 1.0, 1.0],
        ];
    double[13][9] d4_expected = [
        [-1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        [-1.0, -1.0, -1.0, -1.0, -1.0, -1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        [-1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        [-1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -0.96, 0.0, 0.6, 0.8, 0.92, 1.0],
        [-1.0, -1.0, -1.0, -1.0, -0.4, -0.04, 0.0, 0.04, 1.0, 1.0, 1.0, 1.0, 1.0],
        [-1.0, -1.0, -1.0, -1.0, -0.6, -0.06, 0.0, 0.06, 1.0, 1.0, 1.0, 1.0, 1.0],
        [-1.0, -0.9, -0.8, -0.5, -0.2, -0.02, 0.0, 0.02, 0.5, 0.8, 0.9, 0.96, 1.0],
        [-1.0, -1.0, -1.0, -1.0, -0.4666667, -0.04666667, -4.440892e-16, 0.04666667, 1.0, 1.0, 1.0, 1.0, 1.0],
        [-1.0, -1.0, -1.0, -1.0, -0.45, -0.045, 0.0, 0.045, 1.0, 1.0, 1.0, 1.0, 1.0],
        ];
    double[13][9] d5_expected = [
        [0.0, 0.0, 1.0, 2.0, 4.0, 5.0, 5.0, 5.0, 8.0, 9.0, 10.0, 10.0, 10.0],
        [0.0, 0.0, 1.0, 2.0, 4.0, 5.0, 5.0, 5.0, 8.0, 9.0, 10.0, 10.0, 10.0],
        [0.0, 0.0, 0.0, 2.0, 3.0, 4.0, 5.0, 5.0, 7.0, 9.0, 9.0, 10.0, 10.0],
        [0.0, 0.0, 0.1, 1.75, 3.4, 4.39, 4.5, 4.61, 7.25, 8.9, 9.45, 9.78, 10.0],
        [0.0, 0.05, 0.6, 2.25, 3.9, 4.89, 5.0, 5.11, 7.75, 9.4, 9.95, 10.0, 10.0],
        [0.0, 0.0, 0.2, 2.0, 3.8, 4.88, 5.0, 5.12, 8.0, 9.8, 10.0, 10.0, 10.0],
        [0.0, 0.5, 1.0, 2.5, 4.0, 4.9, 5.0, 5.1, 7.5, 9.0, 9.5, 9.8, 10.0],
        [0.0, 0.0, 0.4666667, 2.166667, 3.866667, 4.886667, 5.0, 5.113333, 7.833333, 9.533333, 10.0, 10.0, 10.0],
        [0.0, 0.0, 0.5, 2.1875, 3.875, 4.8875, 5.0, 5.1125, 7.8125, 9.5, 10.0, 10.0, 10.0],
        ];
    double[13][9] d6_expected = [
        [0.0, 0.0, 1.0, 2.0, 4.0, 5.0, 5.0, 6.0, 8.0, 10.0, 11.0, 11.0, 11.0],
        [0.0, 0.0, 1.0, 2.5, 4.0, 5.0, 5.5, 6.0, 8.5, 10.0, 11.0, 11.0, 11.0],
        [0.0, 0.0, 0.0, 2.0, 4.0, 5.0, 5.0, 5.0, 8.0, 10.0, 10.0, 11.0, 11.0],
        [0.0, 0.0, 0.2, 2.0, 3.8, 4.88, 5.0, 5.12, 8.0, 9.8, 10.4, 10.76, 11.0],
        [0.0, 0.1, 0.7, 2.5, 4.3, 5.38, 5.5, 5.62, 8.5, 10.3, 10.9, 11.0, 11.0],
        [0.0, 0.0, 0.3, 2.25, 4.2, 5.37, 5.5, 5.63, 8.75, 10.7, 11.0, 11.0, 11.0],
        [0.0, 0.55, 1.1, 2.75, 4.4, 5.39, 5.5, 5.61, 8.25, 9.9, 10.45, 10.78, 11.0],
        [0.0, 0.0, 0.5666667, 2.416667, 4.266667, 5.376667, 5.5, 5.623333, 8.583333, 10.43333, 11.0, 11.0, 11.0],
        [0.0, 0.0, 0.6, 2.4375, 4.275, 5.3775, 5.5, 5.6225, 8.5625, 10.4, 11.0, 11.0, 11.0],
        ];
    double[13][9] d7_expected = [
        [31.79, 31.79, 31.79, 31.79, 64.19, 64.19, 64.19, 64.19, 81.77, 81.77, 81.77, 81.77, 81.77],
        [31.79, 31.79, 31.79, 31.79, 64.19, 64.19, 64.19, 64.19, 81.77, 81.77, 81.77, 81.77, 81.77],
        [31.79, 31.79, 31.79, 31.79, 31.79, 31.79, 64.19, 64.19, 64.19, 81.77, 81.77, 81.77, 81.77],
        [31.79, 31.79, 31.79, 31.79, 38.27, 47.018, 47.99, 48.962, 68.585, 76.496, 79.133, 80.7152, 81.77],
        [31.79, 31.79, 31.79, 39.89, 54.47, 63.218, 64.19, 64.7174, 77.375, 81.77, 81.77, 81.77, 81.77],
        [31.79, 31.79, 31.79, 31.79, 51.23, 62.894, 64.19, 64.8932, 81.77, 81.77, 81.77, 81.77, 81.77],
        [31.79, 35.03, 38.27, 47.99, 57.71, 63.542, 64.19, 64.5416, 72.98, 78.254, 80.012, 81.0668, 81.77],
        [31.79, 31.79, 31.79, 37.19, 53.39, 63.11, 64.19, 64.776, 78.84, 81.77, 81.77, 81.77, 81.77],
        [31.79, 31.79, 31.79, 37.865, 53.66, 63.137, 64.19, 64.76135, 78.47375, 81.77, 81.77, 81.77, 81.77],
        ];
    double[13][9] d8_expected = [
        [-94.43, -94.43, -94.43, -74.55, -74.55, -50.81, -50.81, -50.81, 27.45, 78.79, 78.79, 78.79, 78.79],
        [-94.43, -94.43, -94.43, -74.55, -62.68, -50.81, -50.81, -50.81, 27.45, 78.79, 78.79, 78.79, 78.79],
        [-94.43, -94.43, -94.43, -94.43, -74.55, -74.55, -74.55, -50.81, 27.45, 27.45, 78.79, 78.79, 78.79],
        [-94.43, -94.43, -94.43, -89.46, -74.55, -63.867, -62.68, -61.493, 7.885, 53.12, 65.955, 73.656, 78.79],
        [-94.43, -94.43, -94.43, -79.52, -62.68, -51.997, -50.81, -46.897, 40.285, 78.79, 78.79, 78.79, 78.79],
        [-94.43, -94.43, -94.43, -84.49, -65.054, -52.2344, -50.81, -46.1144, 53.12, 78.79, 78.79, 78.79, 78.79],
        [-94.43, -90.454, -86.478, -74.55, -60.306, -51.7596, -50.81, -47.6796, 27.45, 58.254, 68.522, 74.6828, 78.79],
        [-94.43, -94.43, -94.43, -81.17667, -63.47133, -52.07613, -50.81, -46.63613, 44.56333, 78.79, 78.79, 78.79, 78.79],
        [-94.43, -94.43, -94.43, -80.7625, -63.2735, -52.05635, -50.81, -46.70135, 43.49375, 78.79, 78.79, 78.79, 78.79],
        ];
    double[13][9] d9_expected = [
        [-89.17, -89.17, -89.17, 20.93, 38.51, 38.51, 38.51, 48.03, 76.43, 77.02, 77.02, 77.02, 77.02],
        [-89.17, -89.17, -89.17, 20.93, 38.51, 38.51, 43.27, 48.03, 76.43, 77.02, 77.02, 77.02, 77.02],
        [-89.17, -89.17, -89.17, 20.93, 20.93, 38.51, 38.51, 38.51, 48.03, 76.43, 77.02, 77.02, 77.02],
        [-89.17, -89.17, -89.17, -34.12, 27.962, 37.4552, 38.51, 39.0812, 62.23, 76.666, 76.843, 76.9492, 77.02],
        [-89.17, -89.17, -78.16, 20.93, 36.752, 42.6988, 43.27, 43.8412, 76.43, 76.961, 77.02, 77.02, 77.02],
        [-89.17, -89.17, -89.17, -6.595, 34.994, 42.6036, 43.27, 43.9364, 76.5775, 77.02, 77.02, 77.02, 77.02],
        [-89.17, -61.645, -34.12, 25.325, 38.51, 42.794, 43.27, 43.746, 69.33, 76.725, 76.8725, 76.961, 77.02],
        [-89.17, -89.17, -89.17, 11.755, 36.166, 42.66707, 43.27, 43.87293, 76.47917, 77.02, 77.02, 77.02, 77.02],
        [-89.17, -89.17, -89.17, 14.04875, 36.3125, 42.675, 43.27, 43.865, 76.46688, 77.02, 77.02, 77.02, 77.02],
        ];
    double[13][9] d10_expected = [
        [-99.53, -99.53, -99.53, -76.87, -76.69, -67.81, -67.81, -67.81, -11.29, 21.02, 21.02, 21.02, 21.02],
        [-99.53, -99.53, -99.53, -76.87, -76.69, -67.81, -67.81, -67.81, -11.29, 21.02, 21.02, 21.02, 21.02],
        [-99.53, -99.53, -99.53, -76.87, -76.69, -76.69, -67.81, -67.81, -40.26, -11.29, 21.02, 21.02, 21.02],
        [-99.53, -99.53, -99.53, -82.535, -76.726, -72.8716, -72.25, -71.6284, -33.0175, -1.597, 9.7115, 16.4966, 21.02],
        [-99.53, -99.53, -94.998, -76.825, -74.026, -68.4316, -67.81, -65.8815, -18.5325, 14.558, 21.02, 21.02, 21.02],
        [-99.53, -99.53, -99.53, -76.87, -74.914, -68.5204, -67.81, -65.606, -11.29, 21.02, 21.02, 21.02, 21.02],
        [-99.53, -92.732, -85.934, -76.78, -73.138, -68.3428, -67.81, -66.157, -25.775, 1.634, 11.327, 17.1428, 21.02],
        [-99.53, -99.53, -98.01933, -76.84, -74.322, -68.4612, -67.81, -65.78967, -16.11833, 18.866, 21.02, 21.02, 21.02],
        [-99.53, -99.53, -97.264, -76.83625, -74.248, -68.4538, -67.81, -65.81263, -16.72187, 17.789, 21.02, 21.02, 21.02],
        ];
    double[13][9] d11_expected = [
        [-78.32, -78.32, -78.32, -52.22, 13.45, 13.45, 13.45, 15.96, 17.25, 85.0, 85.0, 85.0, 85.0],
        [-78.32, -78.32, -78.32, -51.54, 13.45, 13.45, 14.705, 15.96, 31.8, 85.0, 85.0, 85.0, 85.0],
        [-78.32, -78.32, -78.32, -52.22, -50.86, 13.45, 13.45, 13.45, 17.25, 46.35, 85.0, 85.0, 85.0],
        [-78.32, -78.32, -78.32, -52.22, -37.998, 8.3052, 13.45, 13.6508, 17.25, 54.08, 69.54, 78.816, 85.0],
        [-78.32, -78.32, -70.49, -51.54, -5.843, 14.5042, 14.705, 14.9058, 31.8, 73.405, 85.0, 85.0, 85.0],
        [-78.32, -78.32, -78.32, -51.88, -12.274, 14.4791, 14.705, 14.9309, 39.075, 85.0, 85.0, 85.0, 85.0],
        [-78.32, -69.185, -60.05, -51.2, 0.588, 14.5293, 14.705, 14.8807, 24.525, 57.945, 71.4725, 79.589, 85.0],
        [-78.32, -78.32, -73.97, -51.65333, -7.986667, 14.49583, 14.705, 14.91417, 34.225, 78.55833, 85.0, 85.0, 85.0],
        [-78.32, -78.32, -73.1, -51.625, -7.45075, 14.49792, 14.705, 14.91208, 33.61875, 77.27, 85.0, 85.0, 85.0],
        ];
    double[13][9] d12_expected = [
        [-81.36, -81.36, -81.36, -53.56, -42.14, -9.18, -9.18, -9.18, 49.52, 98.5, 98.5, 98.5, 98.5],
        [-81.36, -81.36, -81.36, -53.56, -42.14, -9.18, -9.18, -9.18, 49.52, 98.5, 98.5, 98.5, 98.5],
        [-81.36, -81.36, -81.36, -70.87, -42.14, -42.14, -42.14, -9.18, 49.52, 80.43, 98.5, 98.5, 98.5],
        [-81.36, -81.36, -81.36, -66.5425, -46.708, -28.6264, -25.66, -22.6936, 38.9475, 82.237, 90.3685, 95.2474, 98.5],
        [-81.36, -81.36, -77.164, -57.8875, -38.844, -12.1464, -9.18, -7.7031, 57.2475, 91.272, 98.5, 98.5, 98.5],
        [-81.36, -81.36, -81.36, -62.215, -42.14, -12.476, -9.18, -7.539, 64.975, 98.5, 98.5, 98.5, 98.5],
        [-81.36, -77.164, -72.968, -53.56, -35.548, -11.8168, -9.18, -7.8672, 49.52, 84.044, 91.272, 95.6088, 98.5],
        [-81.36, -81.36, -78.56267, -59.33, -39.94267, -12.25627, -9.18, -7.6484, 59.82333, 93.68133, 98.5, 98.5, 98.5],
        [-81.36, -81.36, -78.213, -58.96938, -39.668, -12.2288, -9.18, -7.662075, 59.17938, 93.079, 98.5, 98.5, 98.5],
        ];
    double[13][9] d13_expected = [
        [38.37, 38.37, 38.37, 45.7, 50.69, 51.36, 51.36, 55.66, 58.95, 62.01, 65.25, 65.25, 65.25],
        [38.37, 38.37, 41.365, 45.7, 51.025, 51.36, 53.51, 55.66, 58.95, 63.63, 65.25, 65.25, 65.25],
        [38.37, 38.37, 38.37, 44.36, 50.69, 51.36, 51.36, 51.36, 58.95, 62.01, 65.25, 65.25, 65.25],
        [38.37, 38.37, 38.37, 45.03, 50.69, 51.293, 51.36, 51.79, 57.93, 62.01, 63.63, 64.602, 65.25],
        [38.37, 38.37, 41.365, 45.7, 51.025, 53.08, 53.51, 53.94, 58.95, 63.63, 65.25, 65.25, 65.25],
        [38.37, 38.37, 38.969, 45.365, 50.958, 53.037, 53.51, 53.983, 59.715, 64.926, 65.25, 65.25, 65.25],
        [38.37, 41.0655, 43.761, 46.9475, 51.092, 53.123, 53.51, 53.897, 58.44, 62.334, 63.792, 64.6668, 65.25],
        [38.37, 38.37, 40.56633, 45.58833, 51.00267, 53.06567, 53.51, 53.95433, 59.205, 64.062, 65.25, 65.25, 65.25],
        [38.37, 38.37, 40.766, 45.61625, 51.00825, 53.06925, 53.51, 53.95075, 59.14125, 63.954, 65.25, 65.25, 65.25],
        ];

    void compareResults(const double[] actual, const double[] expected, string dataset, QuantileInterpolation method)
    {
        import std.conv : to;
        import std.format : format;
        import std.math : approxEqual, isNaN;
        import std.range : lockstep;

        foreach (i, actualValue, expectedValue; lockstep(actual, expected))
        {
            assert(actualValue.approxEqual(expectedValue) || (actualValue.isNaN && expectedValue.isNaN),
                   format("Quantile unit test failure, dataset %s, method: %s, index: %d, expected: %g, actual: %g",
                          dataset, method.to!string, i, expectedValue, actualValue));
        }
    }

    foreach(methodIndex, method; EnumMembers!QuantileInterpolation)
    {
        compareResults(probs.map!(p => p.quantile(d1, method)).array, d1_expected[methodIndex], "d1", method);
        compareResults(probs.map!(p => p.quantile(d2, method)).array, d2_expected[methodIndex], "d2", method);
        compareResults(probs.map!(p => p.quantile(d3, method)).array, d3_expected[methodIndex], "d3", method);
        compareResults(probs.map!(p => p.quantile(d3Int, method)).array, d3_expected[methodIndex], "d3Int", method);
        compareResults(probs.map!(p => p.quantile(d4, method)).array, d4_expected[methodIndex], "d4", method);
        compareResults(probs.map!(p => p.quantile(d4Int, method)).array, d4_expected[methodIndex], "d4Int", method);
        compareResults(probs.map!(p => p.quantile(d5, method)).array, d5_expected[methodIndex], "d5", method);
        compareResults(probs.map!(p => p.quantile(d5Int, method)).array, d5_expected[methodIndex], "d5Int", method);
        compareResults(probs.map!(p => p.quantile(d6, method)).array, d6_expected[methodIndex], "d6", method);
        compareResults(probs.map!(p => p.quantile(d6Size_t, method)).array, d6_expected[methodIndex], "d6Size_t", method);
        compareResults(probs.map!(p => p.quantile(d7, method)).array, d7_expected[methodIndex], "d7", method);
        compareResults(probs.map!(p => p.quantile(d7Float, method)).array, d7_expected[methodIndex], "d7Float", method);
        compareResults(probs.map!(p => p.quantile(d8, method)).array, d8_expected[methodIndex], "d8", method);
        compareResults(probs.map!(p => p.quantile(d8Float, method)).array, d8_expected[methodIndex], "d8Float", method);
        compareResults(probs.map!(p => p.quantile(d9, method)).array, d9_expected[methodIndex], "d9", method);
        compareResults(probs.map!(p => p.quantile(d9Float, method)).array, d9_expected[methodIndex], "d9Float", method);
        compareResults(probs.map!(p => p.quantile(d10, method)).array, d10_expected[methodIndex], "d10", method);
        compareResults(probs.map!(p => p.quantile(d10Float, method)).array, d10_expected[methodIndex], "d10Float", method);
        compareResults(probs.map!(p => p.quantile(d11, method)).array, d11_expected[methodIndex], "d11", method);
        compareResults(probs.map!(p => p.quantile(d12, method)).array, d12_expected[methodIndex], "d12", method);
        compareResults(probs.map!(p => p.quantile(d13, method)).array, d13_expected[methodIndex], "d13", method);
    }
}
