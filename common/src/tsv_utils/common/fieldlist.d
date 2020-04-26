/**
Utilities for parsing "field-lists" entered on the command line.

# Field-lists

A "field-list" is entered on the command line to specify a set of fields for a
command option. A field-list is a comma separated list of individual fields and
"field-ranges". Fields are identified either by field number or by field names found
in the header line of the input data. A field-range is a pair of fields separated
by a hyphen and includes both fields and all the fields in between.

$(NOTE Internally, the comma separated entries in a field-list are called a field-group.)

Fields-lists are parsed into an ordered set of one-based field numbers. Repeating
fields are allowed. Some examples of numeric fields with the `tsv-select` tool:

$(CONSOLE
    $ tsv-select -f 3         # Field  3
    $ tsv-select -f 3-5       # Fields 3,4,5
    $ tsv-select -f 7,3-5     # Fields 7,3,4,5
    $ tsv-select -f 3,5-3,5   # Fields 3,5,4,3,5
)

Fields specified by name must match a name in the header line of the input data.
Glob-style wildcarding is supported using the asterisk (`*`) character. When
wildcards are used with a single field, all matches in the header are used. When used
in a field range, both field names must match a single header field.

Consider a file `data.tsv` containing timing information:

$(CONSOLE
    $ tsv-pretty data.tsv
    run  elapsed_time  user_time  system_time  max_memory
      1          57.5       52.0          5.5        1420
      2          52.0       49.0          3.0        1270
      3          55.5       51.0          4.5        1410
)

The header fields are:

```
    1    run
    2    elapsed_time
    3    user_time
    4    system_time
    5    max_memory
```

Some examples using named fields for this file:

$(CONSOLE
    $ tsv-select data.tsv -f user_time           # Field  3
    $ tsv-select data.tsv -f run,user_time       # Fields 1,3
    $ tsv-select data.tsv -f run-user_time       # Fields 1,2,3
    $ tsv-select data.tsv -f '*_memory'          # Field  6
    $ tsv-select data.tsv -f '*_time'            # Fields 3,4,5
    $ tsv-select data.tsv -f '*_time,*_memory'   # Fields 3,4,5,6
    $ tsv-select data.tsv -f '*_memory,*_time'   # Fields 6,3,4,5
    $ tsv-select data.tsv -f 'run-*_time'        # Invalid. '*_time' matches 3 fields
)

Both field numbers and fields names can both be used in the same field list, except
when specifying a field range:

$(CONSOLE
    $ tsv-select data.tsv -f 1,user_time         # Fields 1,3
    $ tsv-select data.tsv -f 1-user_time         # Invalid
)

A backslash is used to escape special characters occurring in field names. Characters
that must be escaped when specifying them field names are: asterisk (`*`), comma(`,`),
colon (`:`), space (` `), and backslash (`\`). A backslash is also used to escape
numbers that should be treated as field names rather than field numbers. Consider a
file with the following header fields:
```
    1    test id
    2    run:id
    3    001
    4    100
```

These fields can be used in named field commands as follows:

$(CONSOLE
    $ tsv-select file.tsv -f 'test\ id'          # Field  1
    $ tsv-select file.tsv -f 'run\:1'            # Field  2
    $ tsv-select file.tsv -f '\001,\100'         # Fields 3,4
)

Fields lists are combined with other content in some command line options. The colon
and space characters are both terminator characters for field lists. Some examples:

$(CONSOLE
    $ tsv-filter --le 3:100                        # Field 3 < 100
    $ tsv-filter --le elapsed_time:100             # 'elapsed_time' field < 100
    $ tsv-summarize --quantile '*_time:0.25,0.75'  # 1st and 3rd quantiles for time fields
)

Field-list support routines identify the termination of the field list. They do not
do any processing of content occurring after the field-list.

# Numeric field-lists

The original field-lists used in tsv-utils were numeric only. This is still the format
used when a header line is not available. They are a strict subset of the field-list
syntax described so above. There are however, several routines that only support
numeric field lists.

# Field-list utilities

The following facilities are used for field list processing:

$(LIST
    * [findFieldGroups] - Range that iterates over the "field-groups" in a "field-list".

    * [isNumericFieldGroup] - Determines if a field-group is a valid numeric field
      group.

    * [isNumericFieldGroupWithHyphenFirstOrLast] - Determines if field-group is a valid
      numeric group, except for having a leading or trailing hypen. This test is used
      to provide better error messages.

    * [namedFieldGroupToRegex] - Generates regexes for matching field names in a field
      group to field names in the header line. One regex is generated for a single
      field, two are generated for a range. Properly translates wildcards and escape
      characters into regex format.

    * [parseNumericFieldList], [makeFieldListOptionHandler] - Helper functions for
      parsing numeric field-lists entered on the command line.
)

*/

module tsv_utils.common.fieldlist;

import std.exception : enforce;
import std.range;
import std.stdio;
import std.traits : isIntegral, isNarrowString, isUnsigned, Unqual;

/** Creates range that iterates over the 'field groups' in a 'field list'.
 *
 * Input is typically a string or character array. The range becomes empty when the
 * end of input is reached or an unescaped field list terminator character is found.
 *
 * A 'field list' is a comma separated list 'field groups'. A 'field group' is a
 * single numeric or named field, or a hyphen-separated pair of numeric or named
 * fields. For example:
 *
 *    1,3,4-7               # 3 numeric field groups
 *    field_a,field_b       # 2 named fields
 *
 * Each element in the range is represented by a tuple of two values:
 *    * consumed - The total index positions consumed by the range so far
 *    * value - A slice containing the text of the field group.
 *
 * The field group slice does not contain the separator character, but this is
 * included in the total consumed. The field group tuples from the previous examples:
 *
 *   Input: 1,2,4-7
 *      tuple(1, "1")
 *      tuple(3, "2")
 *      tuple(7, "4-7")
 *
 *   Input: field_a,field_b
 *      tuple(7, "field_a")
 *      tuple(8, "field_b")
 *
 * The details of field groups are not material to this routine, it is only concerned
 * with finding the boundaries between field groups and the termination boundary for
 * the field list. This is relatively straightforward. The main parsing concern is
 * the use of escape character when delimiter characters are included in field names.
 *
 * Field groups are separated by a single comma (','). A field list is terminated by
 * a colon (':') or space (' ') character. Comma, colon, and space characters can be
 * included in a field group by preceding them with a backslash. A backslash not
 * intended as an escape character must also be backslash escaped.
 *
 * Additional characters need to be backslash escaped inside field groups, the
 * asterisk ('*') and hyphen ('-') characters in particular. However, this routine
 * needs only be aware of characters that affect field list and field group
 * boundaries, which are the set listed above.
 *
 * Backslash escape sequences are recognized but not removed from field groups.
 *
 * Field and record delimiter characters (usually TAB and newline) are not handled by
 * this routine. They cannot be used in field names as there is no way to represent
 * them in the header line. However, it is not necessary for this routine to check
 * for them, these checks occurs naturally when processing header lines.
 */
auto findFieldGroups(Range)(Range r)
if (isInputRange!Range &&
    (is(Unqual!(ElementEncodingType!Range) == char) || is(Unqual!(ElementEncodingType!Range) == ubyte)) &&
    (isNarrowString!Range || (isRandomAccessRange!Range &&
                              hasSlicing!Range &&
                              hasLength!Range))
   )
{
    struct Result
    {
        import std.typecons : tuple, Tuple;

        private alias R = Unqual!Range;
        private alias Char = ElementType!R;
        private alias ResultType = Tuple!(size_t, "consumed", R, "value");

        private R _input;
        private R _front;
        private size_t _consumed;

        this(Range data) nothrow pure @safe
        {
            auto fieldGroup = nextFieldGroup!true(data);
            assert(fieldGroup.start == 0);

            _front = data[0 .. fieldGroup.end];
            _consumed = fieldGroup.end;
            _input = data[fieldGroup.end .. $];

            // writefln("[this] data: '%s', _front: '%s', _input: '%s', _frontEnd: %d", data, _front, _input, _frontEnd);
        }

        bool empty() const nothrow pure @safe
        {
            return _front.empty;
        }

        ResultType front() const nothrow pure @safe
        {
            assert(!empty, "Attempt to take the front of an empty findFieldGroups.");

            return ResultType(_consumed, _front);
        }

        void popFront() nothrow pure @safe
        {
            assert(!empty, "Attempt to popFront an empty findFieldGroups.");

            auto fieldGroup = nextFieldGroup!false(_input);

            // writefln("[popFront] _input: '%s', next start: %d, next end: %d", _input, fieldGroup.start, fieldGroup.end);

            _front = _input[fieldGroup.start .. fieldGroup.end];
            _consumed += fieldGroup.end;
            _input = _input[fieldGroup.end .. $];
        }

        /* Finds the start and end indexes of the next field group.
         *
         * The start and end indexes exclude delimiter characters (comma, space, colon).
         */
        private auto nextFieldGroup(bool isFirst)(R r) const nothrow pure @safe
        {
            alias RetType = Tuple!(size_t, "start", size_t, "end");


            enum Char COMMA = ',';
            enum Char BACKSLASH = '\\';
            enum Char SPACE = ' ';
            enum Char COLON = ':';

            if (r.empty) return RetType(0, 0);

            size_t start = 0;

            static if (!isFirst)
            {
                if (r[0] == COMMA) start = 1;
            }

            size_t end = start;

            while (end < r.length)
            {
                Char lookingAt = r[end];

                if (lookingAt == COMMA || lookingAt == SPACE || lookingAt == COLON) break;

                if (lookingAt == BACKSLASH)
                {
                    if (end + 1 == r.length) break;
                    end += 2;
                }
                else
                {
                    end += 1;
                }
            }

            return RetType(start, end);
        }
    }

    return Result(r);
}

@safe unittest
{
    import std.algorithm : equal;
    import std.typecons : tuple, Tuple;

    /* Note: backticks generate literal without escapes. */

    /* Immediate termination. */
    assert(``.findFieldGroups.empty);
    assert(`,`.findFieldGroups.empty);
    assert(`:`.findFieldGroups.empty);
    assert(` `.findFieldGroups.empty);
    assert(`\`.findFieldGroups.empty);

    assert(`,1`.findFieldGroups.empty);
    assert(`:1`.findFieldGroups.empty);
    assert(` 1`.findFieldGroups.empty);

    /* Common cases. */
    assert(equal(`1`.findFieldGroups,
                 [tuple(1, `1`)
                 ]));

    assert(equal(`1,2`.findFieldGroups,
                 [tuple(1, `1`),
                  tuple(3, `2`)
                 ]));

    assert(equal(`1,2,3`.findFieldGroups,
                 [tuple(1, `1`),
                  tuple(3, `2`),
                  tuple(5, `3`)
                 ]));

    assert(equal(`1-3`.findFieldGroups,
                 [tuple(3, `1-3`)
                 ]));

    assert(equal(`1-3,5,7-2`.findFieldGroups,
                 [tuple(3, `1-3`),
                  tuple(5, `5`),
                  tuple(9, `7-2`)
                 ]));

    assert(equal(`field1`.findFieldGroups,
                 [tuple(6, `field1`)
                 ]));

    assert(equal(`field1,field2`.findFieldGroups,
                 [tuple(6, `field1`),
                  tuple(13, `field2`)
                 ]));

    assert(equal(`field1-field5`.findFieldGroups,
                 [tuple(13, `field1-field5`)
                 ]));

    assert(equal(`snow\ storm,雪风暴,Tempête\ de\ neige,Χιονοθύελλα,吹雪`.findFieldGroups,
                 [tuple(11, `snow\ storm`),
                  tuple(21, `雪风暴`),
                  tuple(41, `Tempête\ de\ neige`),
                  tuple(64, `Χιονοθύελλα`),
                  tuple(71, `吹雪`)
                 ]));

    /* Escape sequences. */
    assert(equal(`Field\ 1,Field\ 2,Field\ 5-Field\ 11`.findFieldGroups,
                 [tuple(8, `Field\ 1`),
                  tuple(17, `Field\ 2`),
                  tuple(36, `Field\ 5-Field\ 11`)
                 ]));

    assert(equal(`Jun\ 03\-08,Jul\ 14\-23`.findFieldGroups,
                 [tuple(11, `Jun\ 03\-08`),
                  tuple(23, `Jul\ 14\-23`)
                 ]));

    assert(equal(`field\:1`.findFieldGroups,
                 [tuple(8, `field\:1`)
                 ]));

    assert(equal(`\\,\,,\:,\ ,\a`.findFieldGroups,
                 [tuple(2, `\\`),
                  tuple(5, `\,`),
                  tuple(8, `\:`),
                  tuple(11, `\ `),
                  tuple(14, `\a`)
                 ]));

    assert(equal(`\001,\a\b\c\ \ \-\d,fld\*1`.findFieldGroups,
                 [tuple(4, `\001`),
                  tuple(19, `\a\b\c\ \ \-\d`),
                  tuple(26, `fld\*1`)
                 ]));

    /* Field list termination. */
    assert(equal(`X:`.findFieldGroups,
                 [tuple(1, `X`)
                 ]));

    assert(equal(`X `.findFieldGroups,
                 [tuple(1, `X`)
                 ]));

    assert(equal(`X\`.findFieldGroups,
                 [tuple(1, `X`)
                 ]));

    assert(equal(`1-3:5-7`.findFieldGroups,
                 [tuple(3, `1-3`)
                 ]));

    assert(equal(`1-3,4:5-7`.findFieldGroups,
                 [tuple(3, `1-3`),
                  tuple(5, `4`)
                 ]));

    /* Leading, trailing, or solo hyphen. Captured for error handling. */
    assert(equal(`-1,1-,-`.findFieldGroups,
                 [tuple(2, `-1`),
                  tuple(5, `1-`),
                  tuple(7, `-`)
                 ]));

    /* TODO: Remove or turn into unit tests. */
    version(none)
    {
        /* This example shows how to use a for loop. */
        foreach (consumed, fieldRange; `1-3,4:5-7`.findFieldGroups)
        {
            writefln("consumed: %d; fieldRange: '%s'", consumed, fieldRange);
        }
    }

    version(none)
    {
        /* This example from when consumed was being returned for each field group rather
         * cummuatively. Currently expect uses to want the cumulative value, so putting
         * in the range.
         */
        import std.algorithm : cumulativeFold;

        writefln("cumulativeFold of: '%s'", "1-3,5,7-2");
        auto emptyResult = tuple!("consumed", "value")(0UL, "");
        foreach (x; "1-3,5,7-2".findFieldGroups
                 .cumulativeFold!((a, b) => tuple(a.consumed + b.consumed, b.value))(emptyResult))
        {
            writefln("%s", x);
        }
    }
}

bool isNumericFieldGroup(const char[] fieldGroup) @safe
{
    import std.regex;
    return cast(bool) fieldGroup.matchFirst(ctRegex!`^[0-9]+(-[0-9]+)?$`);
}

@safe unittest
{
    import std.conv : to;

    assert(!isNumericFieldGroup(``));
    assert(!isNumericFieldGroup(`-`));
    assert(!isNumericFieldGroup(`\1`));
    assert(!isNumericFieldGroup(`\01`));
    assert(!isNumericFieldGroup(`1-`));
    assert(!isNumericFieldGroup(`-1`));
    assert(!isNumericFieldGroup(`a`));
    assert(!isNumericFieldGroup(`a1`));
    assert(!isNumericFieldGroup(`1.1`));

    assert(isNumericFieldGroup(`1`));
    assert(isNumericFieldGroup(`0123456789`));
    assert(isNumericFieldGroup(`0-0`));
    assert(isNumericFieldGroup(`0123456789-0123456789`));

    assert(`0123456789-0123456789`.to!(char[]).isNumericFieldGroup);
}

bool isNumericFieldGroupWithHyphenFirstOrLast(const char[] fieldGroup) @safe
{
    import std.regex;
    return cast(bool) fieldGroup.matchFirst(ctRegex!`^((\-[0-9]+)|([0-9]+\-))$`);
}

@safe unittest
{
    assert(!isNumericFieldGroupWithHyphenFirstOrLast(``));
    assert(!isNumericFieldGroupWithHyphenFirstOrLast(`-`));
    assert(!isNumericFieldGroupWithHyphenFirstOrLast(`1-2`));
    assert(!isNumericFieldGroupWithHyphenFirstOrLast(`-a`));
    assert(isNumericFieldGroupWithHyphenFirstOrLast(`-1`));
    assert(isNumericFieldGroupWithHyphenFirstOrLast(`-12`));
    assert(isNumericFieldGroupWithHyphenFirstOrLast(`1-`));
    assert(isNumericFieldGroupWithHyphenFirstOrLast(`12-`));
    assert(!isNumericFieldGroupWithHyphenFirstOrLast(`-1333-`));
}

auto namedFieldGroupToRegex(const char[] fieldGroup)
{
    import std.array : appender;
    import std.conv : to;
    import std.format : format;
    import std.regex;
    import std.typecons : tuple, Tuple;
    import std.uni : byCodePoint, byGrapheme;

    import std.stdio;

    enum dchar BACKSLASH = '\\';
    enum dchar HYPHEN = '-';
    enum dchar ASTERISK = '*';

    auto createRegex(const dchar[] basePattern)
    {
        return ("^"d ~ basePattern ~ "$").to!string.regex;
    }

    Regex!char field1Regex;
    Regex!char field2Regex;

    auto regexString = appender!(dchar[])();

    bool hyphenSeparatorFound = false;
    bool isEscaped = false;
    foreach (g; fieldGroup.byGrapheme)
    {
        if (isEscaped)
        {
            put(regexString, [g].byCodePoint.escaper);
            isEscaped = false;
        }
        else if (g.length == 1)
        {
            if (g[0] == HYPHEN)
            {
                enforce(!hyphenSeparatorFound && regexString.data.length != 0,
                        format("Hyphens in field names must be backslash escaped unless separating two field names: '%s'\n",
                               fieldGroup));

                assert(field1Regex.empty);

                field1Regex = createRegex(regexString.data);
                hyphenSeparatorFound = true;
                regexString.clear;
            }
            else if (g[0] == BACKSLASH)
            {
                isEscaped = true;
            }
            else if (g[0] == ASTERISK)
            {
                put(regexString, ".*"d);
            }
            else
            {
                put(regexString, [g].byCodePoint.escaper);
            }
        }
        else
        {
            put(regexString, [g].byCodePoint.escaper);
        }
    }
    enforce(!hyphenSeparatorFound || regexString.data.length != 0,
            format("Hyphens in field names must be backslash escaped unless separating two field names: '%s'\n",
                   fieldGroup));

    if (!hyphenSeparatorFound)
    {
        if (regexString.data.length != 0) field1Regex = createRegex(regexString.data);
    }
    else field2Regex = createRegex(regexString.data);

    return tuple(field1Regex, field2Regex);
}

@safe unittest
{
    import std.algorithm : all, equal;
    import std.exception : assertThrown;
    import std.format : format;
    import std.regex;
    import std.typecons : tuple, Tuple;

    /* Use when both regexes should be empty. */
    void testBothRegexEmpty(string test, Tuple!(Regex!char, Regex!char) regexPair)
    {
        assert(regexPair[0].empty, format("[namedFieldGroupToRegex: %s]", test));
        assert(regexPair[1].empty, format("[namedFieldGroupToRegex: %s]", test));
    }

    /* Use when there should only be one regex. */
    void testFirstRegexMatches(string test, Tuple!(Regex!char, Regex!char) regexPair,
                           string[] regex1Matches)
    {
        assert(!regexPair[0].empty, format("[namedFieldGroupToRegex: %s]", test));
        assert(regexPair[1].empty, format("[namedFieldGroupToRegex: %s]", test));

        assert(regex1Matches.all!(s => s.matchFirst(regexPair[0])),
               format("[namedFieldGroupToRegex: %s] regex: %s; strings: %s",
                      test, regexPair[0], regex1Matches));
    }

    /* Use when there should be two regex with matches. */
    void testBothRegexMatches(string test, Tuple!(Regex!char, Regex!char) regexPair,
                              const (char[])[] regex1Matches, const (char[])[] regex2Matches)
    {
        assert(!regexPair[0].empty, format("[namedFieldGroupToRegex: %s]", test));
        assert(!regexPair[1].empty, format("[namedFieldGroupToRegex: %s]", test));

        assert(regex1Matches.all!(s => s.matchFirst(regexPair[0])),
               format("[namedFieldGroupToRegex: %s] regex1: %s; strings: %s",
                      test, regexPair[0], regex1Matches));

        assert(regex2Matches.all!(s => s.matchFirst(regexPair[1])),
               format("[namedFieldGroupToRegex: %s] regex2: %s; strings: %s",
                      test, regexPair[1], regex2Matches));
    }

    /* Invalid hyphen use. These are the only error cases. */
    assertThrown(`-`.namedFieldGroupToRegex);
    assertThrown(`a-`.namedFieldGroupToRegex);
    assertThrown(`-a`.namedFieldGroupToRegex);
    assertThrown(`a-b-`.namedFieldGroupToRegex);
    assertThrown(`a-b-c`.namedFieldGroupToRegex);

    /* Some special cases. These cases are caught elsewhere and errors signaled to the
     * user. nameFieldGroupToRegex should just send back empty.
     */
    testBothRegexEmpty(`test-empty-1`, ``.namedFieldGroupToRegex);
    testBothRegexEmpty(`test-empty-2`, `\`.namedFieldGroupToRegex);

    /* Single name cases. */
    testFirstRegexMatches(`test-single-1`, `a`.namedFieldGroupToRegex, [`a`]);
    testFirstRegexMatches(`test-single-2`, `\a`.namedFieldGroupToRegex, [`a`]);
    testFirstRegexMatches(`test-single-3`, `abc`.namedFieldGroupToRegex, [`abc`]);
    testFirstRegexMatches(`test-single-4`, `abc*`.namedFieldGroupToRegex, [`abc`, `abcd`, `abcde`]);
    testFirstRegexMatches(`test-single-5`, `*`.namedFieldGroupToRegex, [`a`, `ab`, `abc`, `abcd`, `abcde`, `*`]);
    testFirstRegexMatches(`test-single-6`, `abc\*`.namedFieldGroupToRegex, [`abc*`]);
    testFirstRegexMatches(`test-single-7`, `abc{}`.namedFieldGroupToRegex, [`abc{}`]);
    testFirstRegexMatches(`test-single-8`, `\002`.namedFieldGroupToRegex, [`002`]);
    testFirstRegexMatches(`test-single-9`, `\\002`.namedFieldGroupToRegex, [`\002`]);
    testFirstRegexMatches(`test-single-10`, `With A Space`.namedFieldGroupToRegex, [`With A Space`]);
    testFirstRegexMatches(`test-single-11`, `With\-A\-Hyphen`.namedFieldGroupToRegex, [`With-A-Hyphen`]);
    testFirstRegexMatches(`test-single-11`, `\a\b\c\d\e\f\g`.namedFieldGroupToRegex, [`abcdefg`]);
    testFirstRegexMatches(`test-single-12`, `雪风暴`.namedFieldGroupToRegex, [`雪风暴`]);
    testFirstRegexMatches(`test-single-13`, `\雪风暴`.namedFieldGroupToRegex, [`雪风暴`]);
    testFirstRegexMatches(`test-single-14`, `\雪\风\暴`.namedFieldGroupToRegex, [`雪风暴`]);
    testFirstRegexMatches(`test-single-15`, `雪*`.namedFieldGroupToRegex, [`雪`]);
    testFirstRegexMatches(`test-single-16`, `雪*`.namedFieldGroupToRegex, [`雪风`]);
    testFirstRegexMatches(`test-single-17`, `雪*`.namedFieldGroupToRegex, [`雪风暴`]);
    testFirstRegexMatches(`test-single-18`, `g̈각நிกำषिkʷक्षि`.namedFieldGroupToRegex, [`g̈각நிกำषिkʷक्षि`]);
    testFirstRegexMatches(`test-single-19`, `*g̈각நிกำषिkʷक्षि*`.namedFieldGroupToRegex, [`XYZg̈각நிกำषिkʷक्षिPQR`]);

    testBothRegexMatches(`test-pair-1`, `a-b`.namedFieldGroupToRegex, [`a`], [`b`]);
    testBothRegexMatches(`test-pair-2`, `\a-\b`.namedFieldGroupToRegex, [`a`], [`b`]);
    testBothRegexMatches(`test-pair-3`, `a*-b*`.namedFieldGroupToRegex, [`a`, `ab`, `abc`], [`b`, `bc`, `bcd`]);
    testBothRegexMatches(`test-pair-4`, `abc-bcd`.namedFieldGroupToRegex, [`abc`], [`bcd`]);
    testBothRegexMatches(`test-pair-5`, `a\-f-r\-t`.namedFieldGroupToRegex, [`a-f`], [`r-t`]);
    testBothRegexMatches(`test-pair-6`, `雪风暴-吹雪`.namedFieldGroupToRegex, [`雪风暴`], [`吹雪`]);
    testBothRegexMatches(`test-pair-7`, `நிกำ각-aिg̈क्षिkʷ`.namedFieldGroupToRegex, [`நிกำ각`], [`aिg̈क्षिkʷ`]);
}

/**
Numeric Field-lists - A numeric field-list is a string entered on the command line
identifying one or more field numbers. They are used by the majority of the tsv-utils
applications. There are two helper functions, makeFieldListOptionHandler and
parseNumericFieldList. Most applications will use makeFieldListOptionHandler, it
creates a delegate that can be passed to std.getopt to process the command option.
Actual processing of the option text is done by parseNumericFieldList. It can be
called directly when the text of the option value contains more than just the field
number.

Syntax and behavior:

A 'numeric field-list' is a list of numeric field numbers entered on the command line.
Fields are 1-upped integers representing locations in an input line, in the traditional
meaning of Unix command line tools. Fields can be entered as single numbers or a range.
Multiple entries are separated by commas. Some examples (with 'fields' as the command
line option):

   --fields 3                 // Single field
   --fields 4,1               // Two fields
   --fields 3-9               // A range, fields 3 to 9 inclusive
   --fields 1,2,7-34,11       // A mix of ranges and fields
   --fields 15-5,3-1          // Two ranges in reverse order.

Incomplete ranges are not supported, for example, '6-'. Zero is disallowed as a field
value by default, but can be enabled to support the notion of zero as representing the
entire line. However, zero cannot be part of a range. Field numbers are one-based by
default, but can be converted to zero-based. If conversion to zero-based is enabled,
field number zero must be disallowed or a signed integer type specified for the
returned range.

An error is thrown if an invalid field specification is encountered. Error text is
intended for display. Error conditions include:
  - Empty fields list
  - Empty value, e.g. Two consequtive commas, a trailing comma, or a leading comma
  - String that does not parse as a valid integer
  - Negative integers, or zero if zero is disallowed.
  - An incomplete range
  - Zero used as part of a range.

No other behaviors are enforced. Repeated values are accepted. If zero is allowed,
other field numbers can be entered as well. Additional restrictions need to be
applied by the caller.

Notes:
  - The data type determines the max field number that can be entered. Enabling
    conversion to zero restricts to the signed version of the data type.
  - Use 'import std.typecons : Yes, No' to use the convertToZeroBasedIndex and
    allowFieldNumZero template parameters.
*/

/** [Yes|No].convertToZeroBasedIndex parameter controls whether field numbers are
 *  converted to zero-based indices by makeFieldListOptionHander and
 *  parseNumericFieldList.
 */
alias ConvertToZeroBasedIndex = Flag!"convertToZeroBasedIndex";

/** [Yes|No].allowFieldNumZero parameter controls whether zero is a valid field. This is
 *  used by makeFieldListOptionHander and parseNumericFieldList.
 */
alias AllowFieldNumZero = Flag!"allowFieldNumZero";

alias OptionHandlerDelegate = void delegate(string option, string value);

/**
makeFieldListOptionHandler creates a std.getopt option hander for processing field lists
entered on the command line. A field list is as defined by parseNumericFieldList.
*/
OptionHandlerDelegate makeFieldListOptionHandler(
    T,
    ConvertToZeroBasedIndex convertToZero = No.convertToZeroBasedIndex,
    AllowFieldNumZero allowZero = No.allowFieldNumZero)
    (ref T[] fieldsArray)
if (isIntegral!T && (!allowZero || !convertToZero || !isUnsigned!T))
{
    void fieldListOptionHandler(ref T[] fieldArray, string option, string value) pure @safe
    {
        import std.algorithm : each;
        try value.parseNumericFieldList!(T, convertToZero, allowZero).each!(x => fieldArray ~= x);
        catch (Exception exc)
        {
            import std.format : format;
            exc.msg = format("[--%s] %s", option, exc.msg);
            throw exc;
        }
    }

    return (option, value) => fieldListOptionHandler(fieldsArray, option, value);
}

// makeFieldListOptionHandler.
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
parseNumericFieldList lazily generates a range of fields numbers from a
'numeric field-list' string.
*/
auto parseNumericFieldList(
    T = size_t,
    ConvertToZeroBasedIndex convertToZero = No.convertToZeroBasedIndex,
    AllowFieldNumZero allowZero = No.allowFieldNumZero)
(string fieldList, char delim = ',')
if (isIntegral!T && (!allowZero || !convertToZero || !isUnsigned!T))
{
    import std.algorithm : splitter;

    auto _splitFieldList = fieldList.splitter(delim);
    auto _currFieldParse =
        (_splitFieldList.empty ? "" : _splitFieldList.front)
        .parseNumericFieldRange!(T, convertToZero, allowZero);

    if (!_splitFieldList.empty) _splitFieldList.popFront;

    struct Result
    {
        @property bool empty() pure nothrow @safe @nogc
        {
            return _currFieldParse.empty;
        }

        @property T front() pure @safe
        {
            import std.conv : to;

            assert(!empty, "Attempting to fetch the front of an empty numeric field-list.");
            assert(!_currFieldParse.empty, "Internal error. Call to front with an empty _currFieldParse.");

            return _currFieldParse.front.to!T;
        }

        void popFront() pure @safe
        {
            assert(!empty, "Attempting to popFront an empty field-list.");

            _currFieldParse.popFront;
            if (_currFieldParse.empty && !_splitFieldList.empty)
            {
                _currFieldParse = _splitFieldList.front.parseNumericFieldRange!(
                    T, convertToZero, allowZero);
                _splitFieldList.popFront;
            }
        }
    }

    return Result();
}

// parseNumericFieldList.
@safe unittest
{
    import std.algorithm : each, equal;
    import std.exception : assertThrown, assertNotThrown;

    /* Basic tests. */
    assert("1".parseNumericFieldList.equal([1]));
    assert("1,2".parseNumericFieldList.equal([1, 2]));
    assert("1,2,3".parseNumericFieldList.equal([1, 2, 3]));
    assert("1-2".parseNumericFieldList.equal([1, 2]));
    assert("1-2,6-4".parseNumericFieldList.equal([1, 2, 6, 5, 4]));
    assert("1-2,1,1-2,2,2-1".parseNumericFieldList.equal([1, 2, 1, 1, 2, 2, 2, 1]));
    assert("1-2,5".parseNumericFieldList!size_t.equal([1, 2, 5]));

    /* Signed Int tests */
    assert("1".parseNumericFieldList!int.equal([1]));
    assert("1,2,3".parseNumericFieldList!int.equal([1, 2, 3]));
    assert("1-2".parseNumericFieldList!int.equal([1, 2]));
    assert("1-2,6-4".parseNumericFieldList!int.equal([1, 2, 6, 5, 4]));
    assert("1-2,5".parseNumericFieldList!int.equal([1, 2, 5]));

    /* Convert to zero tests */
    assert("1".parseNumericFieldList!(size_t, Yes.convertToZeroBasedIndex).equal([0]));
    assert("1,2,3".parseNumericFieldList!(size_t, Yes.convertToZeroBasedIndex).equal([0, 1, 2]));
    assert("1-2".parseNumericFieldList!(size_t, Yes.convertToZeroBasedIndex).equal([0, 1]));
    assert("1-2,6-4".parseNumericFieldList!(size_t, Yes.convertToZeroBasedIndex).equal([0, 1, 5, 4, 3]));
    assert("1-2,5".parseNumericFieldList!(size_t, Yes.convertToZeroBasedIndex).equal([0, 1, 4]));

    assert("1".parseNumericFieldList!(long, Yes.convertToZeroBasedIndex).equal([0]));
    assert("1,2,3".parseNumericFieldList!(long, Yes.convertToZeroBasedIndex).equal([0, 1, 2]));
    assert("1-2".parseNumericFieldList!(long, Yes.convertToZeroBasedIndex).equal([0, 1]));
    assert("1-2,6-4".parseNumericFieldList!(long, Yes.convertToZeroBasedIndex).equal([0, 1, 5, 4, 3]));
    assert("1-2,5".parseNumericFieldList!(long, Yes.convertToZeroBasedIndex).equal([0, 1, 4]));

    /* Allow zero tests. */
    assert("0".parseNumericFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("1,0,3".parseNumericFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([1, 0, 3]));
    assert("1-2,5".parseNumericFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([1, 2, 5]));
    assert("0".parseNumericFieldList!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("1,0,3".parseNumericFieldList!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([1, 0, 3]));
    assert("1-2,5".parseNumericFieldList!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([1, 2, 5]));
    assert("0".parseNumericFieldList!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([-1]));
    assert("1,0,3".parseNumericFieldList!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0, -1, 2]));
    assert("1-2,5".parseNumericFieldList!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0, 1, 4]));

    /* Error cases. */
    assertThrown("".parseNumericFieldList.each);
    assertThrown(" ".parseNumericFieldList.each);
    assertThrown(",".parseNumericFieldList.each);
    assertThrown("5 6".parseNumericFieldList.each);
    assertThrown(",7".parseNumericFieldList.each);
    assertThrown("8,".parseNumericFieldList.each);
    assertThrown("8,9,".parseNumericFieldList.each);
    assertThrown("10,,11".parseNumericFieldList.each);
    assertThrown("".parseNumericFieldList!(long, Yes.convertToZeroBasedIndex).each);
    assertThrown("1,2-3,".parseNumericFieldList!(long, Yes.convertToZeroBasedIndex).each);
    assertThrown("2-,4".parseNumericFieldList!(long, Yes.convertToZeroBasedIndex).each);
    assertThrown("1,2,3,,4".parseNumericFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown(",7".parseNumericFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown("8,".parseNumericFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown("10,0,,11".parseNumericFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown("8,9,".parseNumericFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);

    assertThrown("0".parseNumericFieldList.each);
    assertThrown("1,0,3".parseNumericFieldList.each);
    assertThrown("0".parseNumericFieldList!(int, Yes.convertToZeroBasedIndex, No.allowFieldNumZero).each);
    assertThrown("1,0,3".parseNumericFieldList!(int, Yes.convertToZeroBasedIndex, No.allowFieldNumZero).each);
    assertThrown("0-2,6-0".parseNumericFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown("0-2,6-0".parseNumericFieldList!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown("0-2,6-0".parseNumericFieldList!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
}

/* parseNumericFieldRange parses a single number or number range. E.g. '5' or '5-8'.
 * These are the values in a field-list separated by a comma or other delimiter. It
 * returns a range that iterates over all the values in the range.
 */
private auto parseNumericFieldRange(T = size_t,
                                    ConvertToZeroBasedIndex convertToZero = No.convertToZeroBasedIndex,
                                    AllowFieldNumZero allowZero = No.allowFieldNumZero)
    (string fieldRange)
if (isIntegral!T && (!allowZero || !convertToZero || !isUnsigned!T))
{
    import std.algorithm : findSplit;
    import std.conv : to;
    import std.exception : enforce;
    import std.format : format;
    import std.range : iota;
    import std.traits : Signed;

    /* Pick the largest compatible integral type for the IOTA range. This must be the
     * signed type if convertToZero is true, as a reverse order range may end at -1.
     */
    static if (convertToZero) alias S = Signed!T;
    else alias S = T;

    enforce(fieldRange.length != 0, "Empty field number.");

    auto rangeSplit = findSplit(fieldRange, "-");

    /* Make sure the range does not start or end with a dash. */
    enforce(rangeSplit[1].empty || (!rangeSplit[0].empty && !rangeSplit[2].empty),
            format("Incomplete ranges are not supported: '%s'", fieldRange));

    S start = rangeSplit[0].to!S;
    S last = rangeSplit[1].empty ? start : rangeSplit[2].to!S;
    Signed!T increment = (start <= last) ? 1 : -1;

    static if (allowZero)
    {
        enforce(rangeSplit[1].empty || (start != 0 && last != 0),
                format("Zero cannot be used as part of a range: '%s'", fieldRange));
    }

    static if (allowZero)
    {
        enforce(start >= 0 && last >= 0,
                format("Field numbers must be non-negative integers: '%d'",
                       (start < 0) ? start : last));
    }
    else
    {
        enforce(start >= 1 && last >= 1,
                format("Field numbers must be greater than zero: '%d'",
                       (start < 1) ? start : last));
    }

    static if (convertToZero)
    {
        start--;
        last--;
    }

    return iota(start, last + increment, increment);
}

// parseNumericFieldRange.
@safe unittest
{
    import std.algorithm : equal;
    import std.exception : assertThrown, assertNotThrown;

    /* Basic cases */
    assert(parseNumericFieldRange("1").equal([1]));
    assert("2".parseNumericFieldRange.equal([2]));
    assert("3-4".parseNumericFieldRange.equal([3, 4]));
    assert("3-5".parseNumericFieldRange.equal([3, 4, 5]));
    assert("4-3".parseNumericFieldRange.equal([4, 3]));
    assert("10-1".parseNumericFieldRange.equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));

    /* Convert to zero-based indices */
    assert(parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex)("1").equal([0]));
    assert("2".parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex).equal([1]));
    assert("3-4".parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex).equal([2, 3]));
    assert("3-5".parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex).equal([2, 3, 4]));
    assert("4-3".parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex).equal([3, 2]));
    assert("10-1".parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex).equal([9, 8, 7, 6, 5, 4, 3, 2, 1, 0]));

    /* Allow zero. */
    assert("0".parseNumericFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert(parseNumericFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero)("1").equal([1]));
    assert("3-4".parseNumericFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([3, 4]));
    assert("10-1".parseNumericFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));

    /* Allow zero, convert to zero-based index. */
    assert("0".parseNumericFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([-1]));
    assert(parseNumericFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero)("1").equal([0]));
    assert("3-4".parseNumericFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([2, 3]));
    assert("10-1".parseNumericFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([9, 8, 7, 6, 5, 4, 3, 2, 1, 0]));

    /* Alternate integer types. */
    assert("2".parseNumericFieldRange!uint.equal([2]));
    assert("3-5".parseNumericFieldRange!uint.equal([3, 4, 5]));
    assert("10-1".parseNumericFieldRange!uint.equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));
    assert("2".parseNumericFieldRange!int.equal([2]));
    assert("3-5".parseNumericFieldRange!int.equal([3, 4, 5]));
    assert("10-1".parseNumericFieldRange!int.equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));
    assert("2".parseNumericFieldRange!ushort.equal([2]));
    assert("3-5".parseNumericFieldRange!ushort.equal([3, 4, 5]));
    assert("10-1".parseNumericFieldRange!ushort.equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));
    assert("2".parseNumericFieldRange!short.equal([2]));
    assert("3-5".parseNumericFieldRange!short.equal([3, 4, 5]));
    assert("10-1".parseNumericFieldRange!short.equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));

    assert("0".parseNumericFieldRange!(long, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("0".parseNumericFieldRange!(uint, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("0".parseNumericFieldRange!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("0".parseNumericFieldRange!(ushort, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("0".parseNumericFieldRange!(short, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("0".parseNumericFieldRange!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([-1]));
    assert("0".parseNumericFieldRange!(short, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([-1]));

    /* Max field value cases. */
    assert("65535".parseNumericFieldRange!ushort.equal([65535]));   // ushort max
    assert("65533-65535".parseNumericFieldRange!ushort.equal([65533, 65534, 65535]));
    assert("32767".parseNumericFieldRange!short.equal([32767]));    // short max
    assert("32765-32767".parseNumericFieldRange!short.equal([32765, 32766, 32767]));
    assert("32767".parseNumericFieldRange!(short, Yes.convertToZeroBasedIndex).equal([32766]));

    /* Error cases. */
    assertThrown("".parseNumericFieldRange);
    assertThrown(" ".parseNumericFieldRange);
    assertThrown("-".parseNumericFieldRange);
    assertThrown(" -".parseNumericFieldRange);
    assertThrown("- ".parseNumericFieldRange);
    assertThrown("1-".parseNumericFieldRange);
    assertThrown("-2".parseNumericFieldRange);
    assertThrown("-1".parseNumericFieldRange);
    assertThrown("1.0".parseNumericFieldRange);
    assertThrown("0".parseNumericFieldRange);
    assertThrown("0-3".parseNumericFieldRange);
    assertThrown("3-0".parseNumericFieldRange);
    assertThrown("-2-4".parseNumericFieldRange);
    assertThrown("2--4".parseNumericFieldRange);
    assertThrown("2-".parseNumericFieldRange);
    assertThrown("a".parseNumericFieldRange);
    assertThrown("0x3".parseNumericFieldRange);
    assertThrown("3U".parseNumericFieldRange);
    assertThrown("1_000".parseNumericFieldRange);
    assertThrown(".".parseNumericFieldRange);

    assertThrown("".parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown(" ".parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("-".parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("1-".parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("-2".parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("-1".parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("0".parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("0-3".parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("3-0".parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("-2-4".parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("2--4".parseNumericFieldRange!(size_t, Yes.convertToZeroBasedIndex));

    assertThrown("".parseNumericFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown(" ".parseNumericFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-".parseNumericFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("1-".parseNumericFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-2".parseNumericFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-1".parseNumericFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("0-3".parseNumericFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("3-0".parseNumericFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-2-4".parseNumericFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("2--4".parseNumericFieldRange!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));

    assertThrown("".parseNumericFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown(" ".parseNumericFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-".parseNumericFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("1-".parseNumericFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-2".parseNumericFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-1".parseNumericFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("0-3".parseNumericFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("3-0".parseNumericFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-2-4".parseNumericFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("2--4".parseNumericFieldRange!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));

    /* Value out of range cases. */
    assertThrown("65536".parseNumericFieldRange!ushort);   // One more than ushort max.
    assertThrown("65535-65536".parseNumericFieldRange!ushort);
    assertThrown("32768".parseNumericFieldRange!short);    // One more than short max.
    assertThrown("32765-32768".parseNumericFieldRange!short);
    // Convert to zero limits signed range.
    assertThrown("32768".parseNumericFieldRange!(ushort, Yes.convertToZeroBasedIndex));
    assert("32767".parseNumericFieldRange!(ushort, Yes.convertToZeroBasedIndex).equal([32766]));
}
