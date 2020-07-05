/**
   Utilities for parsing "field-lists" entered on the command line.

   # Field-lists

   A "field-list" is entered on the command line to specify a set of fields for a
   command option. A field-list is a comma separated list of individual fields and
   "field-ranges". Fields are identified either by field number or by field names found
   in the header line of the input data. A field-range is a pair of fields separated
   by a hyphen and includes both the listed fields and all the fields in between.

   $(NOTE Note: Internally, the comma separated entries in a field-list are called a
   field-group.)

   Fields-lists are parsed into an ordered set of one-based field numbers. Repeating
   fields are allowed. Some examples of numeric fields with the `tsv-select` tool:

   $(CONSOLE
       $ tsv-select -f 3         # Field  3
       $ tsv-select -f 3-5       # Fields 3,4,5
       $ tsv-select -f 7,3-5     # Fields 7,3,4,5
       $ tsv-select -f 3,5-3,5   # Fields 3,5,4,3,5
   )

   Fields specified by name must match a name in the header line of the input data.
   Glob-style wildcards are supported using the asterisk (`*`) character. When
   wildcards are used with a single field, all matching fields in the header are used.
   When used in a field range, both field names must match a single header field.

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

   Some examples using named fields for this file. (Note: `-H` turns on header processing):

   $(CONSOLE
       $ tsv-select data.tsv -H -f user_time           # Field  3
       $ tsv-select data.tsv -H -f run,user_time       # Fields 1,3
       $ tsv-select data.tsv -H -f run-user_time       # Fields 1,2,3
       $ tsv-select data.tsv -H -f '*_memory'          # Field  5
       $ tsv-select data.tsv -H -f '*_time'            # Fields 2,3,4
       $ tsv-select data.tsv -H -f '*_time,*_memory'   # Fields 2,3,4,5
       $ tsv-select data.tsv -H -f '*_memory,*_time'   # Fields 5,2,3,4
       $ tsv-select data.tsv -H -f 'run-*_time'        # Invalid range. '*_time' matches 3 fields
   )

   Both field numbers and fields names can both be used in the same field-list, except
   when specifying a field range:

   $(CONSOLE
       $ tsv-select data.tsv -H -f 1,user_time         # Fields 1,3
       $ tsv-select data.tsv -H -f 1-user_time         # Invalid range
   )

   A backslash is used to escape special characters occurring in field names. Characters
   that must be escaped when specifying them field names are: asterisk (`*`), comma(`,`),
   colon (`:`), space (` `), hyphen (`-`), and backslash (`\`). A backslash is also used
   to escape numbers that should be treated as field names rather than field numbers.
   Consider a file with the following header fields:
   ```
       1    test id
       2    run:id
       3    time-stamp
       4    001
       5    100
   ```

   These fields can be used in named field commands as follows:

   $(CONSOLE
       $ tsv-select file.tsv -H -f 'test\ id'          # Field 1
       $ tsv-select file.tsv -H -f 'run\:1'            # Field 2
       $ tsv-select file.tsv -H -f 'time\-stamp'       # Field 3
       $ tsv-select file.tsv -H -f '\001'              # Field 4
       $ tsv-select file.tsv -H -f '\100'              # Field 5
       $ tsv-select file.tsv -H -f '\001,\100'         # Fields 4,5
   )

   $(NOTE Note: The use of single quotes on the command line is necessary to avoid shell
   interpretation of the backslash character.)

   Fields lists are combined with other content in some command line options. The colon
   and space characters are both terminator characters for field-lists. Some examples:

   $(CONSOLE
       $ tsv-filter -H --lt 3:100                        # Field 3 < 100
       $ tsv-filter -H --lt elapsed_time:100             # 'elapsed_time' field < 100
       $ tsv-summarize -H --quantile '*_time:0.25,0.75'  # 1st and 3rd quantiles for time fields
   )

   Field-list support routines identify the termination of the field-list. They do not
   do any processing of content occurring after the field-list.

   # Numeric field-lists

   The original field-lists used in tsv-utils were numeric only. This is still the
   format used when a header line is not available. They are a strict subset of the
   field-list syntax described so above. Due to this history there are support routines
   that only support numeric field-lists. They are used by tools supporting only numeric
   field lists. They are also used by the more general field-list processing routines in
   this file when a named field or field range can be reduced to a numeric field-group.

   # Field-list utilities

   The following functions provide the APIs for field-list processing:

   $(LIST
       * [parseFieldList] - The main routine for parsing a field-list entered on the
         command line. It returns a range iterating over the field numbers represented
         by field-list. It handles both numeric and named field-lists and works with or
         without header lines. The range has a special member function that tracks how
         much of the original input range has been consumed.

       * [parseNumericFieldList] - This is a top-level routine for processing numeric
         field-lists entered on the command line. It was the original routine used by
         tsv-utils tools when only numeric field-lists where supported. It is still
         used in cases where only numeric field-lists are supported.

       * [makeFieldListOptionHandler] - Returns a delegate that can be passed to
         std.getopt for parsing numeric field-lists. It was part of the original code
         supporting numeric field-lists. Note that delegates passed to std.getopt do
         not have access to the header line of the input file, so the technique can
         only be used for numeric field-lists.

       * [fieldListHelpText] - A global variable containing help text describing the
         field list syntax that can be shown to end users.
    )

    The following private functions handle key parts of the implementation:

    $(LIST
       * [findFieldGroups] - Range that iterates over the "field-groups" in a
         "field-list".

       * [isNumericFieldGroup] - Determines if a field-group is a valid numeric
         field-group.

       * [isNumericFieldGroupWithHyphenFirstOrLast] - Determines if a field-group is a
         valid numeric field-group, except for having a leading or trailing hyphen.
         This test is used to provide better error messages. A field-group that does not
         pass either [isNumericFieldGroup] or [isNumericFieldGroupWithHyphenFirstOrLast]
         is processed as a named field-group.

       * [isMixedNumericNamedFieldGroup] - determines if a field group is a range where
         one element is a field number and the other element is a named field (not a
         number). This is used for error handling.

       * [namedFieldGroupToRegex] - Generates regexes for matching field names in a
         field group to field names in the header line. One regex is generated for a
         single field, two are generated for a range. Wildcards and escape characters
         are translated into the correct regex format.

       * [namedFieldRegexMatches] - Returns an input range iterating over all the
         fields (strings) in a range matching a regular expression. It is used in
         conjunction with [namedFieldGroupToRegex] to find the fields in a header line
         matching a regular expression and map them to field numbers.

       * [parseNumericFieldGroup] - A helper function that parses a numeric field
         group (a string) and returns a range that iterates over all the field numbers
         in the field group. A numeric field-group is either a single number or a
         range. E.g. `5` or `5-8`. This routine was part of the original code
         supporting only numeric field-lists.
   )
*/

module tsv_utils.common.fieldlist;

import std.exception : enforce;
import std.format : format;
import std.range;
import std.regex;
import std.stdio;
import std.traits : isIntegral, isNarrowString, isUnsigned, ReturnType, Unqual;
import std.typecons : tuple, Tuple;

/**
    fieldListHelpText is text intended display to end users to describe the field-list
    syntax.
*/
immutable fieldListHelpText = q"EOS
tsv-utils Field Syntax

Most tsv-utils tools operate on fields specified on the command line. All
tools use the same syntax to identify fields. tsv-select is used in this
document for examples, but the syntax shown applies to all tools.

Fields can be identified either by a one-upped field number or by field
name. Field names require the first line of input data to be a header with
field names. Header line processing is enabled by the '--H|header' option.

Some command options only accept a single field, but many operate on lists
of fields. Here are some examples (using tsv-select):

  $ tsv-select -f 1,2 file.tsv            # Selection using field numbers
  $ tsv-select -f 5-9 file.txt            # Selection using a range
  $ tsv-select -H -f RecordID file.txt    # Selection using a field name
  $ tsv-select -H -f Date,Time,3,5-7,9    # Mix of names, numbers, ranges

Wildcards: Named fields support a simple 'glob' style wildcarding scheme.
The asterisk character ('*') can be used to match any sequence of
characters, including no characters. This is similar to how '*' can be
used to match file names on the Unix command line. All fields with
matching names are selected, so wildcards are a convenient way to select
a set of related fields. Quotes should be placed around command line
arguments containing wildcards to avoid interpretation by the shell.

Examples - Consider a file 'data.tsv' containing timing information:

  $ tsv-pretty data.tsv
  run  elapsed_time  user_time  system_time  max_memory
    1          57.5       52.0          5.5        1420
    2          52.0       49.0          3.0        1270
    3          55.5       51.0          4.5        1410

Some examples selecting fields from this file:

  $ tsv-select data.tsv -H -f 3              # Field 3 (user_time)
  $ tsv-select data.tsv -H -f user_time      # Field 3
  $ tsv-select data.tsv -H -f run,user_time  # Fields 1,3
  $ tsv-select data.tsv -H -f '*_memory'     # Field 5
  $ tsv-select data.tsv -H -f '*_time'       # Fields 2,3,4
  $ tsv-select data.tsv -H -f 1-3            # Fields 1,2,3
  $ tsv-select data.tsv -H -f run-user_time  # Fields 1,2,3 (range with names)

Special characters: There are several special characters that need to be
escaped when specifying field names. Escaping is done by preceeding the
special character with a backslash. Characters requiring escapes are:
asterisk (`*`), comma(`,`), colon (`:`), space (` `), hyphen (`-`), and
backslash (`\`). A field name that contains only digits also needs to be
backslash escaped, this indicates it should be treated as a field name
and not a field number. A backslash can be used to escape any character,
so it's not necessary to remember the list. Use an escape when not sure.

Examples - Consider a file with five fields named as follows:

  1   test id
  2   run:id
  3   time-stamp
  4   001
  5   100

Some examples using specifying these fields by name:

  $ tsv-select file.tsv -H -f 'test\ id'          # Field 1
  $ tsv-select file.tsv -H -f '\test\ id'         # Field 1
  $ tsv-select file.tsv -H -f 'run\:1'            # Field 2
  $ tsv-select file.tsv -H -f 'time\-stamp'       # Field 3
  $ tsv-select file.tsv -H -f '\001'              # Field 4
  $ tsv-select file.tsv -H -f '\100'              # Field 5
  $ tsv-select file.tsv -H -f '\001,\100'         # Fields 4,5
EOS";

/**
   The `convertToZeroBasedIndex` flag is used as a template parameter controlling
   whether field numbers are converted to zero-based indices. It is used by
   [parseFieldList], [parseNumericFieldList], and [makeFieldListOptionHandler].
*/
alias ConvertToZeroBasedIndex = Flag!"convertToZeroBasedIndex";

/**
   The `allowFieldNumZero` flag is used as a template parameter controlling
   whether zero is a valid field. It is used by [parseFieldList],
   [parseNumericFieldList], and [makeFieldListOptionHandler].
*/
alias AllowFieldNumZero = Flag!"allowFieldNumZero";

/**
   The `consumeEntireFieldListString` flag is used as a template parameter
   indicating whether the entire field-list string should be consumed. It is
   used by [parseNumericFieldList].
*/
alias ConsumeEntireFieldListString = Flag!"consumeEntireFieldListString";

/**
   `parseFieldList` returns a range iterating over the field numbers in a field-list.

   `parseFieldList` is the main routine for parsing field-lists entered on the command
   line. It handles both numeric and named field-lists. The elements of the returned
   range are sequence of 1-up field numbers corresponding to the fields specified in
   the field-list string.

   An error is thrown if the field-list string is malformed. The error text is
   intended for display to the user invoking the tsv-utils tool from the command
   line.

   Named field-lists require an array of field names from the header line. Named
   fields are allowed only if a header line is available. Using a named field-list
   without a header line generates an error message referencing the headerCmdArg
   string as a hint to the end user.

   Several optional modes of operation are available:

   $(LIST
       * Conversion to zero-based indexes (`convertToZero` template parameter) - Returns
         the field numbers as zero-based array indices rather than 1-based field numbers.

       * Allow zero as a field number (`allowZero` template parameter) - This allows zero
         to be used as a field number. This is typically used to allow the user to
         specify the entire line rather than an individual field. Use a signed result
         type if also using covertToZero, as this will be returned as (-1).

       * Consuming the entire field list string (`consumeEntire` template parameter) - By
         default, an error is thrown if the entire field-list string is not consumed.
         This is the most common behavior. Turning this off (the `No` option) will
         terminate processing without error when a valid field-list termination character
         is found. The `parseFieldList.consumed` member function can be used to see where
         in the input string processing terminated.
   )

   The optional `cmdOptionString` and `headerCmdArg` arguments are used to generate better
   error messages. `cmdOptionString` should be the command line arguments string passed to
   `std.getopt`. e.g `"f|field"`. This is added to the error message. Callers already
   adding the option name to the error message should pass the empty string.

   The `headerCmdArg` argument should be the option for turning on header line processing.
   This is standard for tsv-utils tools (`--H|header`), so most tsv-utils tools will use
   the default value.

   `parseFieldList` returns a reference range. This is so the `consumed` member function
   remains valid when using the range with facilities that would copy a value-based
   range.
*/
auto parseFieldList(T = size_t,
                    ConvertToZeroBasedIndex convertToZero = No.convertToZeroBasedIndex,
                    AllowFieldNumZero allowZero = No.allowFieldNumZero,
                    ConsumeEntireFieldListString consumeEntire = Yes.consumeEntireFieldListString)
(string fieldList, bool hasHeader = false, string[] headerFields = [],
 string cmdOptionString = "", string headerCmdArg = "H|header")
if (isIntegral!T && (!allowZero || !convertToZero || !isUnsigned!T))
{
    final class Result
    {
        private string _fieldList;
        private bool _hasHeader;
        private string[] _headerFields;
        private string _cmdOptionMsgPart;
        private string _headerCmdArg;
        private ReturnType!(findFieldGroups!string) _fieldGroupRange;
        private bool _isFrontNumericRange;
        private ReturnType!(parseNumericFieldGroup!(T, convertToZero, allowZero)) _numericFieldRange;
        private ReturnType!(namedFieldRegexMatches!(T, convertToZero, string[])) _namedFieldMatches;
        private size_t _consumed;

        this(string fieldList, bool hasHeader, string[] headerFields,
             string cmdOptionString, string headerCmdArg)
        {
            _fieldList = fieldList;
            _hasHeader = hasHeader;
            _headerFields = headerFields.dup;
            if (!cmdOptionString.empty) _cmdOptionMsgPart = "[--" ~ cmdOptionString ~ "] ";
            if (!headerCmdArg.empty) _headerCmdArg = "--" ~ headerCmdArg;
            _fieldGroupRange = findFieldGroups(fieldList);

            /* _namedFieldMatches must be initialized in the constructor because it
             * is a nested struct.
             */
            _namedFieldMatches = namedFieldRegexMatches!(T, convertToZero)(["X"], ctRegex!`^No Match$`);

            try
            {
                consumeNextFieldGroup();
                enforce(!empty, format("Empty field list: '%s'.", _fieldList));
            }
            catch (Exception e)
            {
                throw new Exception(_cmdOptionMsgPart ~ e.msg);
            }

            assert(_consumed <= _fieldList.length);
        }

        private void consumeNextFieldGroup()
        {
            if (!_fieldGroupRange.empty)
            {
                auto fieldGroup = _fieldGroupRange.front.value;
                _consumed = _fieldGroupRange.front.consumed;
                _fieldGroupRange.popFront;

                enforce(!fieldGroup.isNumericFieldGroupWithHyphenFirstOrLast,
                        format("Incomplete ranges are not supported: '%s'.",
                               fieldGroup));

                if (fieldGroup.isNumericFieldGroup)
                {
                    _isFrontNumericRange = true;
                    _numericFieldRange =
                        parseNumericFieldGroup!(T, convertToZero, allowZero)(fieldGroup);
                }
                else
                {
                    enforce(_hasHeader,
                            format("Non-numeric field group: '%s'. Use '%s' when using named field groups.",
                                   fieldGroup, _headerCmdArg));

                    enforce(!fieldGroup.isMixedNumericNamedFieldGroup,
                            format("Ranges with both numeric and named components are not supported: '%s'.",
                                   fieldGroup));

                    auto fieldGroupRegex = namedFieldGroupToRegex(fieldGroup);

                    if (!fieldGroupRegex[1].empty)
                    {
                        /* A range formed by a pair of field names. Find the field
                         * numbers and generate the string form of the numeric
                         * field-group. Pass this to parseNumberFieldRange.
                         */
                        auto f0 = namedFieldRegexMatches(_headerFields, fieldGroupRegex[0]).array;
                        auto f1 = namedFieldRegexMatches(_headerFields, fieldGroupRegex[1]).array;

                        string hintMsg = "Not specifying a range? Backslash escape any hyphens in the field name.";

                        enforce(f0.length > 0,
                                format("First field in range not found in file header. Range: '%s'.\n%s",
                                       fieldGroup, hintMsg));
                        enforce(f1.length > 0,
                                format("Second field in range not found in file header. Range: '%s'.\n%s",
                                       fieldGroup, hintMsg));
                        enforce(f0.length == 1,
                                format("First field in range matches multiple header fields. Range: '%s'.\n%s",
                                       fieldGroup, hintMsg));
                        enforce(f1.length == 1,
                                format("Second field in range matches multiple header fields. Range: '%s'.\n%s",
                                       fieldGroup, hintMsg));

                        _isFrontNumericRange = true;
                        auto fieldGroupAsNumericRange = format("%d-%d", f0[0][0], f1[0][0]);
                        _numericFieldRange =
                            parseNumericFieldGroup!(T, convertToZero, allowZero)(fieldGroupAsNumericRange);
                    }
                    else
                    {
                        enforce (!fieldGroupRegex[0].empty, "Empty field list entry: '%s'.", fieldGroup);

                        _isFrontNumericRange = false;
                        _namedFieldMatches =
                            namedFieldRegexMatches!(T, convertToZero)(_headerFields, fieldGroupRegex[0]);

                        enforce(!_namedFieldMatches.empty,
                                format("Field not found in file header: '%s'.", fieldGroup));
                    }
                }
            }
        }

        bool empty() @safe
        {
            return _fieldGroupRange.empty &&
                (_isFrontNumericRange ? _numericFieldRange.empty : _namedFieldMatches.empty);
        }

        @property T front() @safe
        {
            assert(!empty, "Attempting to fetch the front of an empty field list.");
            return _isFrontNumericRange ? _numericFieldRange.front : _namedFieldMatches.front[0];
        }

        void popFront() @safe
        {

            /* TODO: Move these definitions to a common location in the file. */
            enum char SPACE = ' ';
            enum char COLON = ':';

            assert(!empty, "Attempting to popFront an empty field-list.");

            try
            {
                if (_isFrontNumericRange) _numericFieldRange.popFront;
                else _namedFieldMatches.popFront;

                if (_isFrontNumericRange ? _numericFieldRange.empty : _namedFieldMatches.empty)
                {
                    consumeNextFieldGroup();
                }

                assert(_consumed <= _fieldList.length);

                if (empty)
                {
                    static if (consumeEntire)
                    {
                        enforce(_consumed == _fieldList.length,
                                format("Invalid field list: '%s'.", _fieldList));
                    }
                    else
                    {
                        enforce((_consumed == _fieldList.length ||
                                 _fieldList[_consumed] == SPACE ||
                                 _fieldList[_consumed] == COLON),
                                format("Invalid field list: '%s'.", _fieldList));
                    }
                }
            }
            catch (Exception e)
            {
                throw new Exception(_cmdOptionMsgPart ~ e.msg);
            }
        }

        size_t consumed() const nothrow pure @safe
        {
            return _consumed;
        }
    }

    return new Result(fieldList, hasHeader, headerFields, cmdOptionString, headerCmdArg);
}

/// Basic cases showing how `parseFieldList` works
@safe unittest
{
    import std.algorithm : each, equal;

    string[] emptyHeader = [];

    // Numeric field-lists, with no header line.
    assert(`5`.parseFieldList
           .equal([5]));

    assert(`10`.parseFieldList(false, emptyHeader)
           .equal([10]));

    assert(`1-3,17`.parseFieldList(false, emptyHeader)
           .equal([1, 2, 3, 17]));

    // General field lists, when a header line is available
    assert(`5,1-3`.parseFieldList(true, [`f1`, `f2`, `f3`, `f4`, `f5`])
           .equal([5, 1, 2, 3]));

    assert(`f1`.parseFieldList(true, [`f1`, `f2`, `f3`])
           .equal([1]));

    assert(`f3`.parseFieldList(true, [`f1`, `f2`, `f3`])
           .equal([3]));

    assert(`f1-f3`.parseFieldList(true, [`f1`, `f2`, `f3`])
           .equal([1, 2, 3]));

    assert(`f3-f1`.parseFieldList(true, [`f1`, `f2`, `f3`])
           .equal([3, 2, 1]));

    assert(`f*`.parseFieldList(true, [`f1`, `f2`, `f3`])
           .equal([1, 2, 3]));

    assert(`B*`.parseFieldList(true, [`A1`, `A2`, `B1`, `B2`])
           .equal([3, 4]));

    assert(`*2`.parseFieldList(true, [`A1`, `A2`, `B1`, `B2`])
           .equal([2, 4]));

    assert(`1-2,f4`.parseFieldList(true, [`f1`, `f2`, `f3`, `f4`, `f5`])
           .equal([1, 2, 4]));

    /* The next few examples are closer to the code that would really be
     * used during in command line arg processing.
     */
    {
        string getoptOption = "f|fields";
        bool hasHeader = true;
        auto headerFields = [`A1`, `A2`, `B1`, `B2`];
        auto fieldListCmdArg = `B*,A1`;
        auto fieldNumbers = fieldListCmdArg.parseFieldList(hasHeader, headerFields, getoptOption);
        assert(fieldNumbers.equal([3, 4, 1]));
        assert(fieldNumbers.consumed == fieldListCmdArg.length);
    }
    {
        /* Supplimentary options after the field-list. */
        string getoptOption = "f|fields";
        bool hasHeader = false;
        string[] headerFields;
        auto fieldListCmdArg = `3,4:option`;
        auto fieldNumbers =
            fieldListCmdArg.parseFieldList!(size_t, No.convertToZeroBasedIndex,
                                            No.allowFieldNumZero, No.consumeEntireFieldListString)
            (hasHeader, headerFields, getoptOption);
        assert(fieldNumbers.equal([3, 4]));
        assert(fieldNumbers.consumed == 3);
        assert(fieldListCmdArg[fieldNumbers.consumed .. $] == `:option`);
    }
    {
        /* Supplimentary options after the field-list. */
        string getoptOption = "f|fields";
        bool hasHeader = true;
        auto headerFields = [`A1`, `A2`, `B1`, `B2`];
        auto fieldListCmdArg = `B*:option`;
        auto fieldNumbers =
            fieldListCmdArg.parseFieldList!(size_t, No.convertToZeroBasedIndex,
                                            No.allowFieldNumZero, No.consumeEntireFieldListString)
            (hasHeader, headerFields, getoptOption);
        assert(fieldNumbers.equal([3, 4]));
        assert(fieldNumbers.consumed == 2);
        assert(fieldListCmdArg[fieldNumbers.consumed .. $] == `:option`);
    }
    {
        /* Supplementary options after the field-list. */
        string getoptOption = "f|fields";
        bool hasHeader = true;
        auto headerFields = [`A1`, `A2`, `B1`, `B2`];
        auto fieldListCmdArg = `B* option`;
        auto fieldNumbers =
            fieldListCmdArg.parseFieldList!(size_t, No.convertToZeroBasedIndex,
                                            No.allowFieldNumZero, No.consumeEntireFieldListString)
            (hasHeader, headerFields, getoptOption);
        assert(fieldNumbers.equal([3, 4]));
        assert(fieldNumbers.consumed == 2);
        assert(fieldListCmdArg[fieldNumbers.consumed .. $] == ` option`);
    }
    {
        /* Mixed numeric and named fields. */
        string getoptOption = "f|fields";
        bool hasHeader = true;
        auto headerFields = [`A1`, `A2`, `B1`, `B2`];
        auto fieldListCmdArg = `B2,1`;
        auto fieldNumbers =
            fieldListCmdArg.parseFieldList!(size_t, No.convertToZeroBasedIndex,
                                            No.allowFieldNumZero, No.consumeEntireFieldListString)
            (hasHeader, headerFields, getoptOption);
        assert(fieldNumbers.equal([4, 1]));
        assert(fieldNumbers.consumed == fieldListCmdArg.length);
    }
}

// parseFieldList - Empty and erroneous field list tests
@safe unittest
{
    import std.exception : assertThrown, assertNotThrown;

    assertThrown(``.parseFieldList);
    assertThrown(`,`.parseFieldList);
    assertThrown(`:`.parseFieldList);
    assertThrown(` `.parseFieldList);
    assertThrown(`\`.parseFieldList);
    assertThrown(`,x`.parseFieldList);
    assertThrown(`:option`.parseFieldList);
    assertThrown(` option`.parseFieldList);
    assertThrown(`:1-3`.parseFieldList);

    {
        string getoptOption = "f|fields";
        string cmdHeaderOption = "header";
        bool hasHeader = true;
        auto headerFields = [`A1`, `A2`, `B1`, `B2`];
        auto fieldListCmdArg = `XYZ`;
        size_t[] fieldNumbers;
        bool wasCaught = false;
        try fieldNumbers = fieldListCmdArg.parseFieldList(hasHeader, headerFields, getoptOption).array;
        catch (Exception e)
        {
            wasCaught = true;
            assert(e.msg == "[--f|fields] Field not found in file header: 'XYZ'.");
        }
        finally assert(wasCaught);
    }
    {
        string getoptOption = "f|fields";
        bool hasHeader = false;             // hasHeader=false triggers this error.
        auto headerFields = [`A1`, `A2`, `B1`, `B2`];
        auto fieldListCmdArg = `A1`;
        size_t[] fieldNumbers;
        bool wasCaught = false;

        try fieldNumbers = fieldListCmdArg.parseFieldList(hasHeader, headerFields, getoptOption).array;
        catch (Exception e)
        {
            wasCaught = true;
            assert(e.msg == "[--f|fields] Non-numeric field group: 'A1'. Use '--H|header' when using named field groups.");
        }
        finally assert(wasCaught);

        string cmdHeaderOption = "ZETA";

        try fieldNumbers = fieldListCmdArg.parseFieldList(hasHeader, headerFields, getoptOption, cmdHeaderOption).array;
        catch (Exception e)
        {
            wasCaught = true;
            assert(e.msg == "[--f|fields] Non-numeric field group: 'A1'. Use '--ZETA' when using named field groups.");
        }
        finally assert(wasCaught);
    }
    {
        bool hasHeader = true;
        auto headerFields = [`A1`, `A2`, `B1`, `B2`];

        assertThrown(`XYZ`.parseFieldList(hasHeader, headerFields));
        assertThrown(`XYZ-B1`.parseFieldList(hasHeader, headerFields));
        assertThrown(`B1-XYZ`.parseFieldList(hasHeader, headerFields));
        assertThrown(`A*-B1`.parseFieldList(hasHeader, headerFields));
        assertThrown(`B1-A*`.parseFieldList(hasHeader, headerFields));
        assertThrown(`B1-`.parseFieldList(hasHeader, headerFields));
        assertThrown(`-A1`.parseFieldList(hasHeader, headerFields));
        assertThrown(`A1-3`.parseFieldList(hasHeader, headerFields));
        assertThrown(`1-A3`.parseFieldList(hasHeader, headerFields));
    }

}

//parseFieldList - Named field groups
@safe unittest
{
    import std.algorithm : each, equal;

    bool hasHeader = true;
    auto singleFieldHeader = [`a`];

    assert(`a`.parseFieldList(hasHeader, singleFieldHeader)
           .equal([1]));

    assert(`a*`.parseFieldList(hasHeader, singleFieldHeader)
           .equal([1]));

    assert(`*a`.parseFieldList(hasHeader, singleFieldHeader)
           .equal([1]));

    assert(`*a*`.parseFieldList(hasHeader, singleFieldHeader)
           .equal([1]));

    assert(`*`.parseFieldList(hasHeader, singleFieldHeader)
           .equal([1]));

    auto twoFieldHeader = [`f1`, `f2`];

    assert(`f1`.parseFieldList(hasHeader, twoFieldHeader)
           .equal([1]));

    assert(`f2`.parseFieldList(hasHeader, twoFieldHeader)
           .equal([2]));

    assert(`f1,f2`.parseFieldList(hasHeader, twoFieldHeader)
           .equal([1, 2]));

    assert(`f2,f1`.parseFieldList(hasHeader, twoFieldHeader)
           .equal([2, 1]));

    assert(`f1-f2`.parseFieldList(hasHeader, twoFieldHeader)
           .equal([1, 2]));

    assert(`f2-f1`.parseFieldList(hasHeader, twoFieldHeader)
           .equal([2, 1]));

    assert(`*`.parseFieldList(hasHeader, twoFieldHeader)
           .equal([1, 2]));

    auto multiFieldHeader = [`f1`, `f2`, `x`, `01`, `02`, `3`, `snow storm`, `雪风暴`, `Tempête de neige`, `x`];

    assert(`*`.parseFieldList(hasHeader, multiFieldHeader)
           .equal([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));

    assert(`*2`.parseFieldList(hasHeader, multiFieldHeader)
           .equal([2, 5]));

    assert(`snow*`.parseFieldList(hasHeader, multiFieldHeader)
           .equal([7]));

    assert(`snow\ storm`.parseFieldList(hasHeader, multiFieldHeader)
           .equal([7]));

    assert(`雪风暴`.parseFieldList(hasHeader, multiFieldHeader)
           .equal([8]));

    assert(`雪风*`.parseFieldList(hasHeader, multiFieldHeader)
           .equal([8]));

    assert(`*风*`.parseFieldList(hasHeader, multiFieldHeader)
           .equal([8]));

    assert(`Tempête\ de\ neige`.parseFieldList(hasHeader, multiFieldHeader)
           .equal([9]));

    assert(`x`.parseFieldList(hasHeader, multiFieldHeader)
           .equal([3, 10]));

    /* Convert to zero - A subset of the above tests. */
    assert(`a`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex)(hasHeader, singleFieldHeader)
           .equal([0]));

    assert(`a*`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex)(hasHeader, singleFieldHeader)
           .equal([0]));

    assert(`f1`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex)(hasHeader, twoFieldHeader)
           .equal([0]));

    assert(`f2`.parseFieldList!(long, Yes.convertToZeroBasedIndex)(hasHeader, twoFieldHeader)
           .equal([1]));

    assert(`f2,f1`.parseFieldList!(int, Yes.convertToZeroBasedIndex)(hasHeader, twoFieldHeader)
           .equal([1, 0]));

    assert(`f2-f1`.parseFieldList!(uint, Yes.convertToZeroBasedIndex)(hasHeader, twoFieldHeader)
           .equal([1, 0]));

    assert(`*`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex)(hasHeader, multiFieldHeader)
           .equal([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]));

    assert(`*2`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex)(hasHeader, multiFieldHeader)
           .equal([1, 4]));

    assert(`snow*`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex)(hasHeader, multiFieldHeader)
           .equal([6]));

    assert(`snow\ storm`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex)(hasHeader, multiFieldHeader)
           .equal([6]));

    assert(`雪风暴`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex)(hasHeader, multiFieldHeader)
           .equal([7]));

    assert(`雪风*`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex)(hasHeader, multiFieldHeader)
           .equal([7]));

    assert(`x`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex)(hasHeader, multiFieldHeader)
           .equal([2, 9]));

    /* Allow zero tests. */
    assert(`0,f1`.parseFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero)
           (hasHeader, twoFieldHeader)
           .equal([-1, 0]));

    assert(`f2,0`.parseFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero)
           (hasHeader, twoFieldHeader)
           .equal([1, -1]));

    assert(`f2,f1,0`.parseFieldList!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero)
           (hasHeader, twoFieldHeader)
           .equal([2, 1, 0]));

    assert(`0,f2-f1`.parseFieldList!(uint, No.convertToZeroBasedIndex, Yes.allowFieldNumZero)
           (hasHeader, twoFieldHeader)
           .equal([0, 2, 1]));

    assert(`*,0`.parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero)
           (hasHeader, multiFieldHeader)
           .equal([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 0]));

    assert(`0,snow\ storm`.parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero)
           (hasHeader, multiFieldHeader)
           .equal([0,7]));
}

// parseFieldList - The same tests as used for parseNumericFieldGroup
@safe unittest
{
    import std.algorithm : each, equal;
    import std.exception : assertThrown, assertNotThrown;

    /* Basic tests. */
    assert(`1`.parseFieldList.equal([1]));
    assert(`1,2`.parseFieldList.equal([1, 2]));
    assert(`1,2,3`.parseFieldList.equal([1, 2, 3]));
    assert(`1-2`.parseFieldList.equal([1, 2]));
    assert(`1-2,6-4`.parseFieldList.equal([1, 2, 6, 5, 4]));
    assert(`1-2,1,1-2,2,2-1`.parseFieldList.equal([1, 2, 1, 1, 2, 2, 2, 1]));
    assert(`1-2,5`.parseFieldList!size_t.equal([1, 2, 5]));

    /* Signed Int tests */
    assert(`1`.parseFieldList!int.equal([1]));
    assert(`1,2,3`.parseFieldList!int.equal([1, 2, 3]));
    assert(`1-2`.parseFieldList!int.equal([1, 2]));
    assert(`1-2,6-4`.parseFieldList!int.equal([1, 2, 6, 5, 4]));
    assert(`1-2,5`.parseFieldList!int.equal([1, 2, 5]));

    /* Convert to zero tests */
    assert(`1`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex).equal([0]));
    assert(`1,2,3`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex).equal([0, 1, 2]));
    assert(`1-2`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex).equal([0, 1]));
    assert(`1-2,6-4`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex).equal([0, 1, 5, 4, 3]));
    assert(`1-2,5`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex).equal([0, 1, 4]));

    assert(`1`.parseFieldList!(long, Yes.convertToZeroBasedIndex).equal([0]));
    assert(`1,2,3`.parseFieldList!(long, Yes.convertToZeroBasedIndex).equal([0, 1, 2]));
    assert(`1-2`.parseFieldList!(long, Yes.convertToZeroBasedIndex).equal([0, 1]));
    assert(`1-2,6-4`.parseFieldList!(long, Yes.convertToZeroBasedIndex).equal([0, 1, 5, 4, 3]));
    assert(`1-2,5`.parseFieldList!(long, Yes.convertToZeroBasedIndex).equal([0, 1, 4]));

    /* Allow zero tests. */
    assert(`0`.parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert(`1,0,3`.parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([1, 0, 3]));
    assert(`1-2,5`.parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([1, 2, 5]));
    assert(`0`.parseFieldList!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert(`1,0,3`.parseFieldList!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([1, 0, 3]));
    assert(`1-2,5`.parseFieldList!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([1, 2, 5]));
    assert(`0`.parseFieldList!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([-1]));
    assert(`1,0,3`.parseFieldList!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0, -1, 2]));
    assert(`1-2,5`.parseFieldList!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0, 1, 4]));

    /* Error cases. */
    assertThrown(``.parseFieldList.each);
    assertThrown(` `.parseFieldList.each);
    assertThrown(`,`.parseFieldList.each);
    assertThrown(`5 6`.parseFieldList.each);
    assertThrown(`,7`.parseFieldList.each);
    assertThrown(`8,`.parseFieldList.each);
    assertThrown(`8,9,`.parseFieldList.each);
    assertThrown(`10,,11`.parseFieldList.each);
    assertThrown(``.parseFieldList!(long, Yes.convertToZeroBasedIndex).each);
    assertThrown(`1,2-3,`.parseFieldList!(long, Yes.convertToZeroBasedIndex).each);
    assertThrown(`2-,4`.parseFieldList!(long, Yes.convertToZeroBasedIndex).each);
    assertThrown(`1,2,3,,4`.parseFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown(`,7`.parseFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown(`8,`.parseFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown(`10,0,,11`.parseFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown(`8,9,`.parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown(`0`.parseFieldList.each);
    assertThrown(`1,0,3`.parseFieldList.each);
    assertThrown(`0`.parseFieldList!(int, Yes.convertToZeroBasedIndex, No.allowFieldNumZero).each);
    assertThrown(`1,0,3`.parseFieldList!(int, Yes.convertToZeroBasedIndex, No.allowFieldNumZero).each);
    assertThrown(`0-2,6-0`.parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown(`0-2,6-0`.parseFieldList!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
    assertThrown(`0-2,6-0`.parseFieldList!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).each);
}

// parseFieldList - Subset of tests used for parseNumericFieldGroup, but allowing non-consumed characters.
@safe unittest
{
    import std.algorithm : each, equal;
    import std.exception : assertThrown, assertNotThrown;

    /* Basic tests. */
    assert(`1`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([1]));
    assert(`1,2`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([1, 2]));
    assert(`1,2,3`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([1, 2, 3]));
    assert(`1-2`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([1, 2]));
    assert(`1-2,6-4`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([1, 2, 6, 5, 4]));
    assert(`1-2,1,1-2,2,2-1`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([1, 2, 1, 1, 2, 2, 2, 1]));
    assert(`1-2,5`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([1, 2, 5]));

    /* Signed Int tests. */
    assert(`1`.parseFieldList!(int, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([1]));
    assert(`1,2,3`.parseFieldList!(int, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([1, 2, 3]));
    assert(`1-2`.parseFieldList!(int, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([1, 2]));
    assert(`1-2,6-4`.parseFieldList!(int, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([1, 2, 6, 5, 4]));
    assert(`1-2,5`.parseFieldList!(int, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([1, 2, 5]));

    /* Convert to zero tests */
    assert(`1`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([0]));
    assert(`1,2,3`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([0, 1, 2]));
    assert(`1-2`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([0, 1]));
    assert(`1-2,6-4`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([0, 1, 5, 4, 3]));
    assert(`1-2,5`.parseFieldList!(size_t, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([0, 1, 4]));

    /* Allow zero tests. */
    assert(`0`.parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([0]));
    assert(`1,0,3`.parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([1, 0, 3]));
    assert(`1-2,5`.parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([1, 2, 5]));
    assert(`0`.parseFieldList!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([-1]));
    assert(`1,0,3`.parseFieldList!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([0, -1, 2]));
    assert(`1-2,5`.parseFieldList!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero, No.consumeEntireFieldListString)
           .equal([0, 1, 4]));

    /* Error cases. */
    assertThrown(``.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString).each);
    assertThrown(` `.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString).each);
    assertThrown(`,`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString).each);
    assertThrown(`,7`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString).each);

    assertThrown(``.parseFieldList!(long, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString).each);
    assertThrown(`2-,4`.parseFieldList!(long, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString).each);
    assertThrown(`,7`.parseFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero, No.consumeEntireFieldListString).each);

    assertThrown(`0`.parseFieldList!(int, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString).each);
    assertThrown(`1,0,3`.parseFieldList!(int, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString).each);

    assertThrown(`0`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString).each);
    assertThrown(`1,0,3`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString).each);

    assertThrown(`0-2,6-0`.parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero, No.consumeEntireFieldListString).each);
    assertThrown(`0-2,6-0`.parseFieldList!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero, No.consumeEntireFieldListString).each);
    assertThrown(`0-2,6-0`.parseFieldList!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero, No.consumeEntireFieldListString).each);

    /* Allowed termination without consuming entire string. */
    {
        auto x = `5:abc`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString);
        assert(x.equal([5]));
        assert(x.consumed == 1);
    }

    {
        auto x = `1-3,6-10:abc`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString);
        assert(x.equal([1, 2, 3, 6, 7, 8, 9, 10]));
        assert(x.consumed == 8);
    }

    {
        auto x = `1-3,6-10 xyz`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString);
        assert(x.equal([1, 2, 3, 6, 7, 8, 9, 10]));
        assert(x.consumed == 8);
    }

    {
        auto x = `5 6`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString);
        assert(x.equal([5]));
        assert(x.consumed == 1);
    }

    /* Invalid termination when not consuming the entire string. */
    assertThrown(`8,`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString).each);
    assertThrown(`8,9,`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString).each);
    assertThrown(`10,,11`.parseFieldList!(size_t, No.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString).each);
    assertThrown(`1,2-3,`.parseFieldList!(long, Yes.convertToZeroBasedIndex, No.allowFieldNumZero, No.consumeEntireFieldListString).each);
    assertThrown(`1,2,3,,4`.parseFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero, No.consumeEntireFieldListString).each);
    assertThrown(`8,`.parseFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero, No.consumeEntireFieldListString).each);
    assertThrown(`10,0,,11`.parseFieldList!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero, No.consumeEntireFieldListString).each);
    assertThrown(`8,9,`.parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero, No.consumeEntireFieldListString).each);
}

/**
   `findFieldGroups` creates range that iterates over the 'field-groups' in a 'field-list'.
   (Private function.)

   Input is typically a string or character array. The range becomes empty when the end
   of input is reached or an unescaped field-list terminator character is found.

   A 'field-list' is a comma separated list of 'field-groups'. A 'field-group' is a
   single numeric or named field, or a hyphen-separated pair of numeric or named fields.
   For example:

   ```
   1,3,4-7               # 3 numeric field-groups
   field_a,field_b       # 2 named fields
   ```

   Each element in the range is represented by a tuple of two values:

   $(LIST
       * consumed - The total index positions consumed by the range so far
       * value - A slice containing the text of the field-group.
   )

   The field-group slice does not contain the separator character, but this is included
   in the total consumed. The field-group tuples from the previous examples:

   ```
   Input: 1,2,4-7
      tuple(1, "1")
      tuple(3, "2")
      tuple(7, "4-7")

   Input: field_a,field_b
      tuple(7, "field_a")
      tuple(8, "field_b")
   ```

   The details of field-groups are not material to this routine, it is only concerned
   with finding the boundaries between field-groups and the termination boundary for the
   field-list. This is relatively straightforward. The main parsing concern is the use
   of escape character when delimiter characters are included in field names.

   Field-groups are separated by a single comma (','). A field-list is terminated by a
   colon (':') or space (' ') character. Comma, colon, and space characters can be
   included in a field-group by preceding them with a backslash. A backslash not
   intended as an escape character must also be backslash escaped.

   A field-list is also terminated if an unescaped backslash is encountered or a pair
   of consecutive commas. This is normally an error, but handling of these cases is left
   to the caller.

   Additional characters need to be backslash escaped inside field-groups, the asterisk
   ('*') and hyphen ('-') characters in particular. However, this routine needs only be
   aware of characters that affect field-list and field-group boundaries, which are the
   set listed above.

   Backslash escape sequences are recognized but not removed from field-groups.

   Field and record delimiter characters (usually TAB and newline) are not handled by
   this routine. They cannot be used in field names as there is no way to represent them
   in the header line. However, it is not necessary for this routine to check for them,
   these checks occurs naturally when processing header lines.

   $(ALWAYS_DOCUMENT)
*/
private auto findFieldGroups(Range)(Range r)
if (isInputRange!Range &&
    (is(Unqual!(ElementEncodingType!Range) == char) || is(Unqual!(ElementEncodingType!Range) == ubyte)) &&
    (isNarrowString!Range || (isRandomAccessRange!Range &&
                              hasSlicing!Range &&
                              hasLength!Range))
   )
{
    static struct Result
    {
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

        /* Finds the start and end indexes of the next field-group.
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

// findFieldGroups
@safe unittest
{
    import std.algorithm : equal;

    /* Note: backticks generate string literals without escapes. */

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

    /* field-list termination. */
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

    assert(equal(`abc,,def`.findFieldGroups,
                 [tuple(3, `abc`),
                 ]));

    assert(equal(`abc,,`.findFieldGroups,
                 [tuple(3, `abc`),
                 ]));

    assert(equal(`abc,`.findFieldGroups,
                 [tuple(3, `abc`),
                 ]));

    /* Leading, trailing, or solo hyphen. Captured for error handling. */
    assert(equal(`-1,1-,-`.findFieldGroups,
                 [tuple(2, `-1`),
                  tuple(5, `1-`),
                  tuple(7, `-`)
                 ]));
}

/**
   `isNumericFieldGroup` determines if a field-group is a valid numeric field-group.
   (Private function.)

   A numeric field-group is single, non-negative integer or a pair of non-negative
   integers separated by a hyphen.

   Note that zero is valid by this definition, even though it is usually disallowed as a
   field number, except when representing the entire line.

   $(ALWAYS_DOCUMENT)
*/
private bool isNumericFieldGroup(const char[] fieldGroup) @safe
{
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
    assert(isNumericFieldGroup(`3-5`));
    assert(isNumericFieldGroup(`30-5`));
    assert(isNumericFieldGroup(`0123456789-0123456789`));

    assert(`0123456789-0123456789`.to!(char[]).isNumericFieldGroup);
}

/**
   `isNumericFieldGroupWithHyphenFirstOrLast` determines if a field-group is a field
   number with a leading or trailing hyphen. (Private function.)

   This routine is used for better error handling. Currently, incomplete field ranges
   are not supported. That is, field ranges leaving off the first or last field,
   defaulting to the end of the line. This syntax is available in `cut`, e.g.

   $(CONSOLE
       $ cut -f 2-
   )

   In `cut`, this represents field 2 to the end of the line. This routine identifies
   these forms so an error message specific to this case can be generated.

   $(ALWAYS_DOCUMENT)
*/
private bool isNumericFieldGroupWithHyphenFirstOrLast(const char[] fieldGroup) @safe
{
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
    assert(!isNumericFieldGroupWithHyphenFirstOrLast(`\-1`));
    assert(!isNumericFieldGroupWithHyphenFirstOrLast(`\-12`));
    assert(!isNumericFieldGroupWithHyphenFirstOrLast(`1\-`));
    assert(!isNumericFieldGroupWithHyphenFirstOrLast(`12\-`));
}

/**
   `isMixedNumericNamedFieldGroup` determines if a field group is a range where one
   element is a field number and the other element is a named field (not a number).

   This routine is used for better error handling. Currently, field ranges must be
   either entirely numeric or entirely named. This is primarily to catch unintended
   used of a mixed range on the command line.

   $(ALWAYS_DOCUMENT)
 */
private bool isMixedNumericNamedFieldGroup(const char[] fieldGroup) @safe
{
    /* Patterns cases:
     * - Field group starts with a series of digits followed by a hyphen, followed
     *   sequence containing a non-digit character.
     *      ^([0-9]+\-.*[^0-9].*)$
     * - Field ends with an unescaped hyphen and a series of digits. Two start cases:
     *   - Non-digit, non-backslash immediately preceding the hyphen
     *     ^(.*[^0-9\\]\-[0-9]+)$
     *   - Digit immediately preceding the hyphen, non-hyphen earlier
     *     ^(.*[^0-9].*[0-9]\-[0-9]+)$
     *   These two combined:
     *     ^( ( (.*[^0-9\\]) | (.*[^0-9].*[0-9]) ) \-[0-9]+ )$
     *
     * All cases combined:
     *   ^( ([0-9]+\-.*[^0-9].*) | ( (.*[^0-9\\]) | (.*[^0-9].*[0-9]) ) \-[0-9]+)$
     */
    return cast(bool) fieldGroup.matchFirst(ctRegex!`^(([0-9]+\-.*[^0-9].*)|((.*[^0-9\\])|(.*[^0-9].*[0-9]))\-[0-9]+)$`);
}

@safe unittest
{
    assert(isMixedNumericNamedFieldGroup(`1-g`));
    assert(isMixedNumericNamedFieldGroup(`y-2`));
    assert(isMixedNumericNamedFieldGroup(`23-zy`));
    assert(isMixedNumericNamedFieldGroup(`pB-37`));

    assert(isMixedNumericNamedFieldGroup(`5x-0`));
    assert(isMixedNumericNamedFieldGroup(`x5-9`));
    assert(isMixedNumericNamedFieldGroup(`0-2m`));
    assert(isMixedNumericNamedFieldGroup(`9-m2`));
    assert(isMixedNumericNamedFieldGroup(`5x-37`));
    assert(isMixedNumericNamedFieldGroup(`x5-37`));
    assert(isMixedNumericNamedFieldGroup(`37-2m`));
    assert(isMixedNumericNamedFieldGroup(`37-m2`));

    assert(isMixedNumericNamedFieldGroup(`18-23t`));
    assert(isMixedNumericNamedFieldGroup(`x12-632`));
    assert(isMixedNumericNamedFieldGroup(`15-15.5`));

    assert(isMixedNumericNamedFieldGroup(`1-g\-h`));
    assert(isMixedNumericNamedFieldGroup(`z\-y-2`));
    assert(isMixedNumericNamedFieldGroup(`23-zy\-st`));
    assert(isMixedNumericNamedFieldGroup(`ts\-pB-37`));

    assert(!isMixedNumericNamedFieldGroup(`a-c`));
    assert(!isMixedNumericNamedFieldGroup(`1-3`));
    assert(!isMixedNumericNamedFieldGroup(`\1-g`));
    assert(!isMixedNumericNamedFieldGroup(`-g`));
    assert(!isMixedNumericNamedFieldGroup(`h-`));
    assert(!isMixedNumericNamedFieldGroup(`-`));
    assert(!isMixedNumericNamedFieldGroup(``));
    assert(!isMixedNumericNamedFieldGroup(`\2-\3`));
    assert(!isMixedNumericNamedFieldGroup(`\10-\20`));
    assert(!isMixedNumericNamedFieldGroup(`x`));
    assert(!isMixedNumericNamedFieldGroup(`xyz`));
    assert(!isMixedNumericNamedFieldGroup(`0`));
    assert(!isMixedNumericNamedFieldGroup(`9`));

    assert(!isMixedNumericNamedFieldGroup(`1\-g`));
    assert(!isMixedNumericNamedFieldGroup(`y\-2`));
    assert(!isMixedNumericNamedFieldGroup(`23\-zy`));
    assert(!isMixedNumericNamedFieldGroup(`pB\-37`));
    assert(!isMixedNumericNamedFieldGroup(`18\-23t`));
    assert(!isMixedNumericNamedFieldGroup(`x12\-632`));

    assert(!isMixedNumericNamedFieldGroup(`5x\-0`));
    assert(!isMixedNumericNamedFieldGroup(`x5\-9`));
    assert(!isMixedNumericNamedFieldGroup(`0\-2m`));
    assert(!isMixedNumericNamedFieldGroup(`9\-m2`));
    assert(!isMixedNumericNamedFieldGroup(`5x\-37`));
    assert(!isMixedNumericNamedFieldGroup(`x5\-37`));
    assert(!isMixedNumericNamedFieldGroup(`37\-2m`));
    assert(!isMixedNumericNamedFieldGroup(`37\-m2`));

    assert(!isMixedNumericNamedFieldGroup(`1\-g\-h`));
    assert(!isMixedNumericNamedFieldGroup(`z\-y\-2`));
    assert(!isMixedNumericNamedFieldGroup(`23\-zy\-st`));
    assert(!isMixedNumericNamedFieldGroup(`ts\-pB\-37`));

    assert(!isMixedNumericNamedFieldGroup(`\-g`));
    assert(!isMixedNumericNamedFieldGroup(`h\-`));
    assert(!isMixedNumericNamedFieldGroup(`i\-j`));
    assert(!isMixedNumericNamedFieldGroup(`\-2`));
    assert(!isMixedNumericNamedFieldGroup(`2\-`));
    assert(!isMixedNumericNamedFieldGroup(`2\-3`));
    assert(!isMixedNumericNamedFieldGroup(`\2\-\3`));
}

/**
   `namedFieldGroupToRegex` generates regular expressions for matching fields in named
   field-group to field names in a header line. (Private function.)

   One regex is generated for a single field, two are generated for a range. These are
   returned as a tuple with a pair of regex instances. The first regex is used for
   single field entries and the first entry of range. The second regex is filled with
   the second entry of a range and is empty otherwise. (Test with 'empty()'.)

   This routine converts all field-list escape and wildcard syntax into the necessary
   regular expression syntax. Backslash escaped characters are converted to their plain
   characters and asterisk wildcarding (glob style) is converted to regex syntax.

   Regular expressions include beginning and end of string markers. This is intended for
   matching field names after they have been extracted from the header line.

   Most field-group syntax errors requiring end-user error messages should be detected
   elsewhere in field-list processing. The exception is field-names with a non-escaped
   leading or trailing hyphen. A user-appropriate error message is thrown for this case.
   Other erroneous inputs result in both regex's set empty.

   There is no detection of numeric field-groups. If a numeric-field group is passed in
   it will be treated as a named field-group and regular expressions generated.

   $(ALWAYS_DOCUMENT)
*/
private auto namedFieldGroupToRegex(const char[] fieldGroup)
{
    import std.array : appender;
    import std.conv : to;
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
                        format("Hyphens in field names must be backslash escaped unless separating two field names: '%s'.",
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
            format("Hyphens in field names must be backslash escaped unless separating two field names: '%s'.",
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
   `namedFieldRegexMatches` returns an input range iterating over all the fields (strings)
   in an input range that match a regular expression. (Private function.)

   This routine is used in conjunction with `namedFieldGroupToRegex` to find the set of
   header line fields that match a field in a field-group expression. The input is a
   range where the individual elements are strings, e.g. an array of strings.

   The elements of the returned range are a tuple where the first element is the
   one-based field number of the matching field and the second is the matched field
   name. A zero-based index is returned if `convertToZero` is Yes.

   The regular expression must not be empty.

   $(ALWAYS_DOCUMENT)
*/
private auto namedFieldRegexMatches(T = size_t,
                                    ConvertToZeroBasedIndex convertToZero = No.convertToZeroBasedIndex,
                                    Range)
(Range headerFields, Regex!char fieldRegex)
if (isInputRange!Range && is(ElementEncodingType!Range == string))
{
    import std.algorithm : filter;

    assert(!fieldRegex.empty);

    static if (convertToZero) enum T indexOffset = 0;
    else enum T indexOffset = 1;

    return headerFields
        .enumerate!(T)(indexOffset)
        .filter!(x => x[1].matchFirst(fieldRegex));
}

/* namedFieldRegexMatches tests. Some additional testing of namedFieldGroupToRegex,
 * though all the regex edge cases occur in the namedFieldGroupToRegex tests.
 */
@safe unittest
{
    import std.algorithm : equal;
    import std.array : array;

    void testBothRegexMatches(T = size_t,
                              ConvertToZeroBasedIndex convertToZero = No.convertToZeroBasedIndex)
        (string test, string[] headerFields,
         Tuple!(Regex!char, Regex!char) regexPair,
         Tuple!(T, string)[] regex0Matches,
         Tuple!(T, string)[] regex1Matches)
    {
        if (regexPair[0].empty)
        {
            assert(regex1Matches.empty,
                   format("[namedFieldRegexMatches: %s] (empty regex[0], non-empty matches]", test));
        }
        else
        {
            assert(equal(headerFields.namedFieldRegexMatches!(T, convertToZero)(regexPair[0]),
                         regex0Matches),
                   format("[namedFieldRegexMatches: %s] (regex[0] mismatch\nExpected: %s\nActual  : %s",
                          test, regex0Matches, headerFields.namedFieldRegexMatches!(T, convertToZero)(regexPair[0]).array));
        }

        if (regexPair[1].empty)
        {
            assert(regex1Matches.empty,
                   format("[namedFieldRegexMatches: %s] (empty regex[1], non-empty matches]", test));
        }
        else
        {
            assert(equal(headerFields.namedFieldRegexMatches!(T, convertToZero)(regexPair[1]),
                         regex1Matches),
                   format("[namedFieldRegexMatches: %s] (regex[1] mismatch\nExpected: %s\nActual  : %s",
                          test, regex1Matches, headerFields.namedFieldRegexMatches!(T, convertToZero)(regexPair[1]).array));
        }
    }

    Tuple!(size_t, string)[] emptyRegexMatch;

    testBothRegexMatches(
        "test-1",
        [`a`, `b`, `c`],              // Header line
        `a`.namedFieldGroupToRegex,   // field-group
        [ tuple(1UL, `a`) ],          // regex-0 expected match
        emptyRegexMatch);             // regex-1 expected match

    testBothRegexMatches(
        "test-2",
        [`a`, `b`, `c`],
        `b`.namedFieldGroupToRegex,
        [ tuple(2UL, `b`) ],
        emptyRegexMatch);

    testBothRegexMatches(
        "test-3",
        [`a`, `b`, `c`],
        `c`.namedFieldGroupToRegex,
        [ tuple(3UL, `c`) ],
        emptyRegexMatch);

    testBothRegexMatches(
        "test-4",
        [`a`, `b`, `c`],
        `x`.namedFieldGroupToRegex,
        emptyRegexMatch,
        emptyRegexMatch);

    testBothRegexMatches(
        "test-5",
        [`a`],
        `a`.namedFieldGroupToRegex,
        [ tuple(1UL, `a`) ],
        emptyRegexMatch);

    testBothRegexMatches(
        "test-6",
        [`abc`, `def`, `ghi`],
        `abc`.namedFieldGroupToRegex,
        [ tuple(1UL, `abc`) ],
        emptyRegexMatch);

    testBothRegexMatches(
        "test-7",
        [`x_abc`, `y_def`, `x_ghi`],
        `x_*`.namedFieldGroupToRegex,
        [ tuple(1UL, `x_abc`),  tuple(3UL, `x_ghi`),],
        emptyRegexMatch);

    testBothRegexMatches(
        "test-8",
        [`x_abc`, `y_def`, `x_ghi`],
        `*`.namedFieldGroupToRegex,
        [ tuple(1UL, `x_abc`), tuple(2UL, `y_def`),  tuple(3UL, `x_ghi`),],
        emptyRegexMatch);

    testBothRegexMatches(
        "test-9",
        [`a`, `b`, `c`],
        `a-c`.namedFieldGroupToRegex,
        [ tuple(1UL, `a`),],
        [ tuple(3UL, `c`),]);

    testBothRegexMatches(
        "test-10",
        [`a`, `b`, `c`],
        `c-a`.namedFieldGroupToRegex,
        [ tuple(3UL, `c`),],
        [ tuple(1UL, `a`),]);

    testBothRegexMatches(
        "test-11",
        [`a`, `b`, `c`],
        `c*-a*`.namedFieldGroupToRegex,
        [ tuple(3UL, `c`),],
        [ tuple(1UL, `a`),]);

    testBothRegexMatches(
        "test-12",
        [`abc`, `abc-def`, `def`],
        `abc-def`.namedFieldGroupToRegex,
        [ tuple(1UL, `abc`) ],
        [ tuple(3UL, `def`) ]);

    testBothRegexMatches(
        "test-13",
        [`abc`, `abc-def`, `def`],
        `abc\-def`.namedFieldGroupToRegex,
        [ tuple(2UL, `abc-def`) ],
        emptyRegexMatch);

    testBothRegexMatches!(size_t, Yes.convertToZeroBasedIndex)
       ("test-101",
        [`a`, `b`, `c`],
        `a`.namedFieldGroupToRegex,
        [ tuple(0UL, `a`) ],
        emptyRegexMatch);

    testBothRegexMatches!(size_t, Yes.convertToZeroBasedIndex)
        ("test-102",
         [`a`, `b`, `c`],
         `b`.namedFieldGroupToRegex,
         [ tuple(1UL, `b`) ],
         emptyRegexMatch);

    testBothRegexMatches!(size_t, Yes.convertToZeroBasedIndex)
        ("test-103",
         [`a`, `b`, `c`],
         `c`.namedFieldGroupToRegex,
         [ tuple(2UL, `c`) ],
         emptyRegexMatch);

    testBothRegexMatches!(size_t, Yes.convertToZeroBasedIndex)
        ("test-104",
         [`a`, `b`, `c`],
         `x`.namedFieldGroupToRegex,
         emptyRegexMatch,
         emptyRegexMatch);

    testBothRegexMatches!(size_t, Yes.convertToZeroBasedIndex)
        ("test-105",
         [`a`],
         `a`.namedFieldGroupToRegex,
         [ tuple(0UL, `a`) ],
         emptyRegexMatch);

    testBothRegexMatches!(size_t, Yes.convertToZeroBasedIndex)
        ("test-106",
         [`abc`, `def`, `ghi`],
         `abc`.namedFieldGroupToRegex,
         [ tuple(0UL, `abc`) ],
         emptyRegexMatch);

    testBothRegexMatches!(size_t, Yes.convertToZeroBasedIndex)
        ("test-107",
         [`x_abc`, `y_def`, `x_ghi`],
         `x_*`.namedFieldGroupToRegex,
         [ tuple(0UL, `x_abc`),  tuple(2UL, `x_ghi`),],
         emptyRegexMatch);

    testBothRegexMatches!(size_t, Yes.convertToZeroBasedIndex)
        ("test-108",
         [`x_abc`, `y_def`, `x_ghi`],
         `*`.namedFieldGroupToRegex,
         [ tuple(0UL, `x_abc`), tuple(1UL, `y_def`),  tuple(2UL, `x_ghi`),],
         emptyRegexMatch);

    testBothRegexMatches!(size_t, Yes.convertToZeroBasedIndex)
        ("test-109",
         [`a`, `b`, `c`],
         `a-c`.namedFieldGroupToRegex,
         [ tuple(0UL, `a`),],
         [ tuple(2UL, `c`),]);

    testBothRegexMatches!(size_t, Yes.convertToZeroBasedIndex)
        ("test-110",
         [`a`, `b`, `c`],
         `c-a`.namedFieldGroupToRegex,
         [ tuple(2UL, `c`),],
         [ tuple(0UL, `a`),]);

    testBothRegexMatches!(size_t, Yes.convertToZeroBasedIndex)
        ("test-111",
         [`a`, `b`, `c`],
         `c*-a*`.namedFieldGroupToRegex,
         [ tuple(2UL, `c`),],
         [ tuple(0UL, `a`),]);

    testBothRegexMatches!(size_t, Yes.convertToZeroBasedIndex)
        ("test-112",
         [`abc`, `abc-def`, `def`],
         `abc-def`.namedFieldGroupToRegex,
         [ tuple(0UL, `abc`) ],
         [ tuple(2UL, `def`) ]);

    testBothRegexMatches!(size_t, Yes.convertToZeroBasedIndex)
        ("test-113",
         [`abc`, `abc-def`, `def`],
         `abc\-def`.namedFieldGroupToRegex,
         [ tuple(1UL, `abc-def`) ],
         emptyRegexMatch);

    Tuple!(int, string)[] intEmptyRegexMatch;
    Tuple!(uint, string)[] uintEmptyRegexMatch;
    Tuple!(long, string)[] longEmptyRegexMatch;

    testBothRegexMatches!(int, Yes.convertToZeroBasedIndex)
       ("test-201",
        [`a`, `b`, `c`],
        `a`.namedFieldGroupToRegex,
        [ tuple(0, `a`) ],
        intEmptyRegexMatch);

    testBothRegexMatches!(long, Yes.convertToZeroBasedIndex)
        ("test-202",
         [`a`, `b`, `c`],
         `b`.namedFieldGroupToRegex,
         [ tuple(1L, `b`) ],
         longEmptyRegexMatch);

    testBothRegexMatches!(uint, Yes.convertToZeroBasedIndex)
        ("test-203",
         [`a`, `b`, `c`],
         `c`.namedFieldGroupToRegex,
         [ tuple(2U, `c`) ],
         uintEmptyRegexMatch);

    testBothRegexMatches!(uint, Yes.convertToZeroBasedIndex)(
        "test-204",
        [`a`, `b`, `c`],
        `x`.namedFieldGroupToRegex,
        uintEmptyRegexMatch,
        uintEmptyRegexMatch);

    testBothRegexMatches!(int)
        ("test-211",
         [`a`, `b`, `c`],
         `c*-a*`.namedFieldGroupToRegex,
         [ tuple(3, `c`),],
         [ tuple(1, `a`),]);

    testBothRegexMatches!(long)
        ("test-212",
         [`abc`, `abc-def`, `def`],
         `abc-def`.namedFieldGroupToRegex,
         [ tuple(1L, `abc`) ],
         [ tuple(3L, `def`) ]);

    testBothRegexMatches!(uint)
        ("test-213",
         [`abc`, `abc-def`, `def`],
         `abc\-def`.namedFieldGroupToRegex,
         [ tuple(2U, `abc-def`) ],
         uintEmptyRegexMatch);
}

/**
    `parseNumericFieldGroup` parses a single number or number range. E.g. '5' or '5-8'.
    (Private function.)

    `parseNumericFieldGroup` returns a range that iterates over all the values in the
    field-group. It has options supporting conversion of field numbers to zero-based
    indices and the use of '0' (zero) as a field number.

    This was part of the original code supporting numeric field list and is used by
    both numeric and named field-list routines.

   $(ALWAYS_DOCUMENT)
*/
private auto parseNumericFieldGroup(T = size_t,
                                    ConvertToZeroBasedIndex convertToZero = No.convertToZeroBasedIndex,
                                    AllowFieldNumZero allowZero = No.allowFieldNumZero)
    (string fieldRange)
if (isIntegral!T && (!allowZero || !convertToZero || !isUnsigned!T))
{
    import std.algorithm : findSplit;
    import std.conv : to;
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
            format("Incomplete ranges are not supported: '%s'.", fieldRange));

    S start = rangeSplit[0].to!S;
    S last = rangeSplit[1].empty ? start : rangeSplit[2].to!S;
    Signed!T increment = (start <= last) ? 1 : -1;

    static if (allowZero)
    {
        enforce(rangeSplit[1].empty || (start != 0 && last != 0),
                format("Zero cannot be used as part of a range: '%s'.", fieldRange));
    }

    static if (allowZero)
    {
        enforce(start >= 0 && last >= 0,
                format("Field numbers must be non-negative integers: '%d'.",
                       (start < 0) ? start : last));
    }
    else
    {
        enforce(start >= 1 && last >= 1,
                format("Field numbers must be greater than zero: '%d'.",
                       (start < 1) ? start : last));
    }

    static if (convertToZero)
    {
        start--;
        last--;
    }

    return iota(start, last + increment, increment);
}

// parseNumericFieldGroup.
@safe unittest
{
    import std.algorithm : equal;
    import std.exception : assertThrown, assertNotThrown;

    /* Basic cases */
    assert(parseNumericFieldGroup("1").equal([1]));
    assert("2".parseNumericFieldGroup.equal([2]));
    assert("3-4".parseNumericFieldGroup.equal([3, 4]));
    assert("3-5".parseNumericFieldGroup.equal([3, 4, 5]));
    assert("4-3".parseNumericFieldGroup.equal([4, 3]));
    assert("10-1".parseNumericFieldGroup.equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));

    /* Convert to zero-based indices */
    assert(parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex)("1").equal([0]));
    assert("2".parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex).equal([1]));
    assert("3-4".parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex).equal([2, 3]));
    assert("3-5".parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex).equal([2, 3, 4]));
    assert("4-3".parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex).equal([3, 2]));
    assert("10-1".parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex).equal([9, 8, 7, 6, 5, 4, 3, 2, 1, 0]));

    /* Allow zero. */
    assert("0".parseNumericFieldGroup!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert(parseNumericFieldGroup!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero)("1").equal([1]));
    assert("3-4".parseNumericFieldGroup!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([3, 4]));
    assert("10-1".parseNumericFieldGroup!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));

    /* Allow zero, convert to zero-based index. */
    assert("0".parseNumericFieldGroup!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([-1]));
    assert(parseNumericFieldGroup!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero)("1").equal([0]));
    assert("3-4".parseNumericFieldGroup!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([2, 3]));
    assert("10-1".parseNumericFieldGroup!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([9, 8, 7, 6, 5, 4, 3, 2, 1, 0]));

    /* Alternate integer types. */
    assert("2".parseNumericFieldGroup!uint.equal([2]));
    assert("3-5".parseNumericFieldGroup!uint.equal([3, 4, 5]));
    assert("10-1".parseNumericFieldGroup!uint.equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));
    assert("2".parseNumericFieldGroup!int.equal([2]));
    assert("3-5".parseNumericFieldGroup!int.equal([3, 4, 5]));
    assert("10-1".parseNumericFieldGroup!int.equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));
    assert("2".parseNumericFieldGroup!ushort.equal([2]));
    assert("3-5".parseNumericFieldGroup!ushort.equal([3, 4, 5]));
    assert("10-1".parseNumericFieldGroup!ushort.equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));
    assert("2".parseNumericFieldGroup!short.equal([2]));
    assert("3-5".parseNumericFieldGroup!short.equal([3, 4, 5]));
    assert("10-1".parseNumericFieldGroup!short.equal([10,  9, 8, 7, 6, 5, 4, 3, 2, 1]));

    assert("0".parseNumericFieldGroup!(long, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("0".parseNumericFieldGroup!(uint, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("0".parseNumericFieldGroup!(int, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("0".parseNumericFieldGroup!(ushort, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("0".parseNumericFieldGroup!(short, No.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([0]));
    assert("0".parseNumericFieldGroup!(int, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([-1]));
    assert("0".parseNumericFieldGroup!(short, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero).equal([-1]));

    /* Max field value cases. */
    assert("65535".parseNumericFieldGroup!ushort.equal([65535]));   // ushort max
    assert("65533-65535".parseNumericFieldGroup!ushort.equal([65533, 65534, 65535]));
    assert("32767".parseNumericFieldGroup!short.equal([32767]));    // short max
    assert("32765-32767".parseNumericFieldGroup!short.equal([32765, 32766, 32767]));
    assert("32767".parseNumericFieldGroup!(short, Yes.convertToZeroBasedIndex).equal([32766]));

    /* Error cases. */
    assertThrown("".parseNumericFieldGroup);
    assertThrown(" ".parseNumericFieldGroup);
    assertThrown("-".parseNumericFieldGroup);
    assertThrown(" -".parseNumericFieldGroup);
    assertThrown("- ".parseNumericFieldGroup);
    assertThrown("1-".parseNumericFieldGroup);
    assertThrown("-2".parseNumericFieldGroup);
    assertThrown("-1".parseNumericFieldGroup);
    assertThrown("1.0".parseNumericFieldGroup);
    assertThrown("0".parseNumericFieldGroup);
    assertThrown("0-3".parseNumericFieldGroup);
    assertThrown("3-0".parseNumericFieldGroup);
    assertThrown("-2-4".parseNumericFieldGroup);
    assertThrown("2--4".parseNumericFieldGroup);
    assertThrown("2-".parseNumericFieldGroup);
    assertThrown("a".parseNumericFieldGroup);
    assertThrown("0x3".parseNumericFieldGroup);
    assertThrown("3U".parseNumericFieldGroup);
    assertThrown("1_000".parseNumericFieldGroup);
    assertThrown(".".parseNumericFieldGroup);

    assertThrown("".parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown(" ".parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("-".parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("1-".parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("-2".parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("-1".parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("0".parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("0-3".parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("3-0".parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("-2-4".parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex));
    assertThrown("2--4".parseNumericFieldGroup!(size_t, Yes.convertToZeroBasedIndex));

    assertThrown("".parseNumericFieldGroup!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown(" ".parseNumericFieldGroup!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-".parseNumericFieldGroup!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("1-".parseNumericFieldGroup!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-2".parseNumericFieldGroup!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-1".parseNumericFieldGroup!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("0-3".parseNumericFieldGroup!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("3-0".parseNumericFieldGroup!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-2-4".parseNumericFieldGroup!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("2--4".parseNumericFieldGroup!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero));

    assertThrown("".parseNumericFieldGroup!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown(" ".parseNumericFieldGroup!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-".parseNumericFieldGroup!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("1-".parseNumericFieldGroup!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-2".parseNumericFieldGroup!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-1".parseNumericFieldGroup!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("0-3".parseNumericFieldGroup!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("3-0".parseNumericFieldGroup!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("-2-4".parseNumericFieldGroup!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));
    assertThrown("2--4".parseNumericFieldGroup!(long, Yes.convertToZeroBasedIndex, Yes.allowFieldNumZero));

    /* Value out of range cases. */
    assertThrown("65536".parseNumericFieldGroup!ushort);   // One more than ushort max.
    assertThrown("65535-65536".parseNumericFieldGroup!ushort);
    assertThrown("32768".parseNumericFieldGroup!short);    // One more than short max.
    assertThrown("32765-32768".parseNumericFieldGroup!short);
    // Convert to zero limits signed range.
    assertThrown("32768".parseNumericFieldGroup!(ushort, Yes.convertToZeroBasedIndex));
    assert("32767".parseNumericFieldGroup!(ushort, Yes.convertToZeroBasedIndex).equal([32766]));
}

/**
   Numeric field-lists

   Numeric field-lists are the original form of field-list supported by tsv-utils tools.
   They have largely been superseded by the more general field-list support provided by
   [parseFieldList], but the basic facilities for processing numeric field-lists are
   still available.

   A numeric field-list is a string entered on the command line identifying one or more
   field numbers. They are used by the majority of the tsv-utils applications. There are
   two helper functions, [makeFieldListOptionHandler] and [parseNumericFieldList]. Most
   applications will use [makeFieldListOptionHandler], it creates a delegate that can be
   passed to `std.getopt` to process the command option. Actual processing of the option
   text is done by [parseNumericFieldList]. It can be called directly when the text of the
   option value contains more than just the field number.

   Syntax and behavior:

   A 'numeric field-list' is a list of numeric field numbers entered on the command line.
   Fields are 1-upped integers representing locations in an input line, in the traditional
   meaning of Unix command line tools. Fields can be entered as single numbers or a range.
   Multiple entries are separated by commas. Some examples (with 'fields' as the command
   line option):

   ```
      --fields 3              # Single field
      --fields 4,1            # Two fields
      --fields 3-9            # A range, fields 3 to 9 inclusive
      --fields 1,2,7-34,11    # A mix of ranges and fields
      --fields 15-5,3-1       # Two ranges in reverse order.
   ```

   Incomplete ranges are not supported, for example, '6-'. Zero is disallowed as a field
   value by default, but can be enabled to support the notion of zero as representing the
   entire line. However, zero cannot be part of a range. Field numbers are one-based by
   default, but can be converted to zero-based. If conversion to zero-based is enabled,
   field number zero must be disallowed or a signed integer type specified for the
   returned range.

   An error is thrown if an invalid field specification is encountered. Error text is
   intended for display. Error conditions include:

   $(LIST
       * Empty fields list
       * Empty value, e.g. Two consecutive commas, a trailing comma, or a leading comma
       * String that does not parse as a valid integer
       * Negative integers, or zero if zero is disallowed.
       * An incomplete range
       * Zero used as part of a range.
   )

   No other behaviors are enforced. Repeated values are accepted. If zero is allowed,
   other field numbers can be entered as well. Additional restrictions need to be
   applied by the caller.

   Notes:

   $(LIST
       * The data type determines the max field number that can be entered. Enabling
         conversion to zero restricts to the signed version of the data type.
       * Use 'import std.typecons : Yes, No' to use the convertToZeroBasedIndex and
         allowFieldNumZero template parameters.
   )
*/

/**
   `OptionHandlerDelegate` is the signature of the delegate returned by
   [makeFieldListOptionHandler].
 */
alias OptionHandlerDelegate = void delegate(string option, string value);

/**
   `makeFieldListOptionHandler` creates a std.getopt option handler for processing field-lists
   entered on the command line. A field-list is as defined by [parseNumericFieldList].
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

    /* Basic cases involved unsigned types smaller than size_t. */
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
   `parseNumericFieldList` lazily generates a range of fields numbers from a
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
    import std.conv : to;

    alias SplitFieldListRange = typeof(fieldList.splitter(delim));
    alias NumericFieldGroupParse
        = ReturnType!(parseNumericFieldGroup!(T, convertToZero, allowZero));

    static struct Result
    {
        private SplitFieldListRange _splitFieldList;
        private NumericFieldGroupParse _currFieldParse;

        this(string fieldList, char delim)
        {
            _splitFieldList = fieldList.splitter(delim);
            _currFieldParse =
                (_splitFieldList.empty ? "" : _splitFieldList.front)
                .parseNumericFieldGroup!(T, convertToZero, allowZero);

            if (!_splitFieldList.empty) _splitFieldList.popFront;
        }

        bool empty() pure nothrow @safe @nogc
        {
            return _currFieldParse.empty;
        }

        T front() pure @safe
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
                _currFieldParse = _splitFieldList.front.parseNumericFieldGroup!(
                    T, convertToZero, allowZero);
                _splitFieldList.popFront;
            }
        }
    }

    return Result(fieldList, delim);
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
