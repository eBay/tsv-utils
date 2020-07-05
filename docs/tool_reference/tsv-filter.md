_Visit the [Tools Reference main page](../ToolReference.md)_<br>
_Visit the [TSV Utilities main page](../../README.md)_

# tsv-filter reference

_Note: See the [tsv-filter](../../README.md#tsv-filter) description in the project [README](../../README.md) for a tutorial style introduction._

**Synopsis:** tsv-filter [options] [file...]

Filter lines by comparison tests against fields. Multiple tests can be specified. By default, only lines satisfying all tests are output. This can be change using the `--or` option. A variety of tests are available.

**General options:**
* `--help` - Print help.
* `--help-verbose` - Print detailed help.
* `--help-options` - Print the options list by itself.
* `--help-fields ` - Print help on specifying fields.
* `--V|version` - Print version information and exit.
* `--H|header` - Treat the first line of each file as a header.
* `--d|delimiter CHR` - Field delimiter. Default: TAB. (Single byte UTF-8 characters only.)
* `--or` - Evaluate tests as an OR rather than an AND.
* `--v|invert` - Invert the filter, printing lines that do not match.

**Tests:**

Empty and blank field tests:
* `--empty <field-list>` - True if field is empty (no characters)
* `--not-empty <field-list>` - True if field is not empty.
* `--blank <field-list>` - True if field is empty or all whitespace.
* `--not-blank <field-list>` - True if field contains a non-whitespace character.

Numeric type tests:
* `--is-numeric <field-list>` - True if the field can be interpreted as a number.
* `--is-finite <field-list>` - True if the field can be interpreted as a number, and it is not NaN or infinity.
* `--is-nan <field-list>` - True if the field is NaN (including: "nan", "NaN", "NAN").
* `--is-infinity <field-list>` - True if the field is infinity (including: "inf", "INF", "-inf", "-INF")

Numeric comparisons:
* `--le <field-list>:NUM` - FIELD <= NUM (numeric).
* `--lt <field-list>:NUM` - FIELD <  NUM (numeric).
* `--ge <field-list>:NUM` - FIELD >= NUM (numeric).
* `--gt <field-list>:NUM` - FIELD >  NUM (numeric).
* `--eq <field-list>:NUM` - FIELD == NUM (numeric).
* `--ne <field-list>:NUM` - FIELD != NUM (numeric).

String comparisons:
* `--str-le <field-list>:STR` - FIELD <= STR (string).
* `--str-lt <field-list>:STR` - FIELD <  STR (string).
* `--str-ge <field-list>:STR` - FIELD >= STR (string).
* `--str-gt <field-list>:STR` - FIELD >  STR (string).
* `--str-eq <field-list>:STR` - FIELD == STR (string).
* `--istr-eq <field-list>:STR` - FIELD == STR (string, case-insensitive).
* `--str-ne <field-list>:STR` - FIELD != STR (string).
* `--istr-ne <field-list>:STR` - FIELD != STR (string, case-insensitive).
* `--str-in-fld <field-list>:STR` - FIELD contains STR (substring search).
* `--istr-in-fld <field-list>:STR` - FIELD contains STR (substring search, case-insensitive).
* `--str-not-in-fld <field-list>:STR` - FIELD does not contain STR (substring search).
* `--istr-not-in-fld <field-list>:STR` - FIELD does not contain STR (substring search, case-insensitive).

Regular expression tests:
* `--regex <field-list>:REGEX` - FIELD matches regular expression.
* `--iregex <field-list>:REGEX` - FIELD matches regular expression, case-insensitive.
* `--not-regex <field-list>:REGEX` - FIELD does not match regular expression.
* `--not-iregex <field-list>:REGEX` - FIELD does not match regular expression, case-insensitive.

Field length tests
* `--char-len-le <field-list>:NUM` - FIELD character length <= NUM.
* `--char-len-lt <field-list>:NUM` - FIELD character length < NUM.
* `--char-len-ge <field-list>:NUM` - FIELD character length >= NUM.
* `--char-len-gt <field-list>:NUM` - FIELD character length > NUM.
* `--char-len-eq <field-list>:NUM` - FIELD character length == NUM.
* `--char-len-ne <field-list>:NUM` - FIELD character length != NUM.
* `--byte-len-le <field-list>:NUM` - FIELD byte length <= NUM.
* `--byte-len-lt <field-list>:NUM` - FIELD byte length < NUM.
* `--byte-len-ge <field-list>:NUM` - FIELD byte length >= NUM.
* `--byte-len-gt <field-list>:NUM` - FIELD byte length > NUM.
* `--byte-len-eq <field-list>:NUM` - FIELD byte length == NUM.
* `--byte-len-ne <field-list>:NUM` - FIELD byte length != NUM.

Field to field comparisons:
* `--ff-le FIELD1:FIELD2` - FIELD1 <= FIELD2 (numeric).
* `--ff-lt FIELD1:FIELD2` - FIELD1 <  FIELD2 (numeric).
* `--ff-ge FIELD1:FIELD2` - FIELD1 >= FIELD2 (numeric).
* `--ff-gt FIELD1:FIELD2` - FIELD1 >  FIELD2 (numeric).
* `--ff-eq FIELD1:FIELD2` - FIELD1 == FIELD2 (numeric).
* `--ff-ne FIELD1:FIELD2` - FIELD1 != FIELD2 (numeric).
* `--ff-str-eq FIELD1:FIELD2` - FIELD1 == FIELD2 (string).
* `--ff-istr-eq FIELD1:FIELD2` - FIELD1 == FIELD2 (string, case-insensitive).
* `--ff-str-ne FIELD1:FIELD2` - FIELD1 != FIELD2 (string).
* `--ff-istr-ne FIELD1:FIELD2` - FIELD1 != FIELD2 (string, case-insensitive).
* `--ff-absdiff-le FIELD1:FIELD2:NUM` - abs(FIELD1 - FIELD2) <= NUM
* `--ff-absdiff-gt FIELD1:FIELD2:NUM` - abs(FIELD1 - FIELD2)  > NUM
* `--ff-reldiff-le FIELD1:FIELD2:NUM` - abs(FIELD1 - FIELD2) / min(abs(FIELD1), abs(FIELD2)) <= NUM
* `--ff-reldiff-gt FIELD1:FIELD2:NUM` - abs(FIELD1 - FIELD2) / min(abs(FIELD1), abs(FIELD2))  > NUM

**Examples:**

Basic comparisons:
```
$ # 'Count' field non-zero
$ tsv-filter --header --ne Count:0

$ # Field 2 non-zero
$ tsv-filter --ne 2:0 data.tsv

$ # Field 1 == 0 and Field 2 >= 100, first line is a header.
$ tsv-filter --header --eq 1:0 --ge 2:100 data.tsv

$ # 'Count' field == -1 or 'Count' field > 100
$ tsv-filter --or --eq Count:-1 --gt Count:100

$ # 'Name1' field is foo, 'Name2' field contains bar
$ tsv-filter -H --str-eq Name1:foo --str-in-fld Name2:bar data.tsv

$ # 'start_date' field == 'end-date' field (numeric test)
$ tsv-filter -H --ff-eq start_date:end_date data.tsv
```

Field lists:

Field lists can be used to run the same test on multiple fields. For example:
```
$ # Test that fields 1-10 are not blank
$ tsv-filter --not-blank 1-10 data.tsv

$ # Test that fields 1-5 are not zero
$ tsv-filter --ne 1-5:0 data.tsv

$ # Test that all the '_time' fields are not zero
$ tsv-filter -H --ne '*_time:0' data.tsv

$ # Test that fields 1-5, 7, and 10-20 are less than 100
$ tsv-filter --lt 1-5,7,10-20:100 data.tsv
```

See [Field syntax](common-options-and-behavior.md#field-syntax) for more information on field lists and specifying fields by name.

Regular expressions:

The regular expression syntax supported is that defined by the [D regex library](<http://dlang.org/phobos/std_regex.html>). The  basic syntax has become quite standard and is used by many tools. It will rarely be necessary to consult the D language documentation. A general reference such as the guide available at [Regular-Expressions.info](http://www.regular-expressions.info/) will suffice in nearly all cases. (Note: Unicode properties are supported.)

```
$ # Field 2 has a sequence with two a's, one or more digits, then 2 a's.
$ tsv-filter --regex '2:aa[0-9]+aa' data.tsv

$ # Same thing, except the field starts and ends with the two a's.
$ tsv-filter --regex '2:^aa[0-9]+aa$' data.tsv

$ # 'Name' field is a sequence of "word" characters with two or more embedded
$ # whitespace sequences (match against entire field)
$ tsv-filter -H --regex 'Name:^\w+\s+(\w+\s+)+\w+$' data.tsv

$ # 'Title' field containing at least one cyrillic character.
$ tsv-filter -H --regex 'Title:\p{Cyrillic}' data.tsv
```

Short-circuiting expressions:

Numeric tests like `--gt` (greater-than) assume field values can be interpreted as numbers. An error occurs if the field cannot be parsed as a number, halting the program. This can be avoiding by including a testing ensure the field is recognizable as a number. For example:

```
$ # Ensure 'count' field is a number before testing for greater-than 10.
$ tsv-filter -H --is-numeric count --gt count:10 data.tsv

$ # Ensure field 2 is a number, not NaN or infinity before greater-than test.
$ tsv-filter --is-finite 2 --gt 2:10 data.tsv
```

The above tests work because `tsv-filter` short-circuits evaluation, only running as many tests as necessary to filter each line. Tests are run in the order listed on the command line. In the first example, if `--is-numeric 2` is false, the remaining tests do not get run.

_**Tip:**_ Bash completion is very helpful when using commands like `tsv-filter` that have many options. See [Enable bash-completion](../TipsAndTricks.md#enable-bash-completion) for details.

