_Visit the [Tools Reference main page](../ToolReference.md)_<br>
_Visit the [TSV Utilities main page](../../README.md)_

# Common options and behavior

Information in this section applies to all the tools. Topics:

* [Specifying options](#specifying-options)
* [Help](#help--h---help---help-verbose---helpfields)
* [UTF-8 input](#utf-8-input)
* [Line endings](#line-endings)
* [File format and alternate delimiters](#file-format-and-alternate-delimiters---delimiter)
* [Header line processing](#header-line-processing--h---header)
* [Multiple files and standard input](#Multiple-files-and-standard-input)
* [Field syntax](#field-syntax)

## Specifying options

Multi-letter options are specified with a double dash. Single letter options can be specified with a single dash or double dash. For example:
```
$ tsv-select -f 1,2         # Valid
$ tsv-select --f 1,2        # Valid
$ tsv-select --fields 1,2   # Valid
$ tsv-select -fields 1,2    # Invalid.
```

## Help (`-h`, `--help`, `--help-verbose`, `--helpfields`)

All tools print help if given the `-h` or `--help` option. Many provide more detail via the `--help-verbose` option. Tools taking fields as parameters provide detailed help on specifying fields via the `--help-fields` option.

## UTF-8 input

These tools assume data is utf-8 encoded.

## Line endings

These tools have been tested on Unix platforms, including macOS, but not Windows. On Unix platforms, Unix line endings (`\n`) are expected, with the notable exception of `tsv2csv`. Not all the tools are affected by DOS and Windows line endings (`\r\n`), those that are check the first line and flag an error. `csv2tsv` explicitly handles DOS and Windows line endings, converting to Unix line endings as part of the conversion.

The `dos2unix` tool can be used to convert Windows line endings to Unix format. See [Convert newline format and character encoding with dos2unix and iconv](../TipsAndTricks.md#convert-newline-format-and-character-encoding-with-dos2unix-and-iconv)

## File format and alternate delimiters (`--delimiter`)

Any character can be used as a field delimiter, TAB is the default. However, there is no mechanism to include the delimiter character or newlines within a field. This differs from CSV file format which provides an escaping mechanism. In practice the lack of an escaping mechanism is not a meaningful limitation for data oriented files. See [Comparing TSV and CSV formats](../comparing-tsv-and-csv.md) for more information on these formats.

All lines are expected to have data. There is no mechanism for recognizing comments or blank lines. Tools taking field indices as arguments expect the specified fields to be available on every line.

## Header line processing (`-H`, `--header`)

Most tools handle the first line of files as a header when given the `-H` or `--header` option. Turning on header line processing does three things:

* Enables selection of fields by name rather than by number. See [Field Syntax](#field-syntax) for details.
* Only one header line is written to standard output. If multiple files are being processed, the header line from the first file is kept and header lines from subsequent files are dropped.
* Excludes the header line from the normal processing of the command, if appropriate. For example, `tsv-filter` exempts the header from filtering.

## Multiple files and standard input

Tools can read from any number of files and from standard input. As per typical Unix behavior, a single dash represents standard input when included in a list of files. Terminate non-file arguments with a double dash (`--`) when using a single dash in this fashion. Example:
```
$ head -n 1000 file-c.tsv | tsv-filter --eq 2:1000 -- file-a.tsv file-b.tsv - > out.tsv
```

The above passes `file-a.tsv`, `file-b.tsv`, and the first 1000 lines of `file-c.tsv` to `tsv-filter` and writes the results to `out.tsv`.

## Field syntax

Most tsv-utils tools operate on fields specified on the command line. All tools use the same syntax to identify fields. `tsv-select` is used in this document to provide examples, but the syntax shown applies to all tools.

Fields can be identified either by a one-upped field number or by field name. Field names require the first line of input data to be a header with field names. Header line processing is enabled by the `--H|header` option.

Some command line options only accept a single field, but many operate on lists of fields. Here are some examples of field selection (using `tsv-select`):
```
$ tsv-select -f 1 file.tsv              # First field
$ tsv-select -f 1,3 file.tsv            # Pair of fields
$ tsv-select -f 5-9 file.txt            # A range
$ tsv-select -H -f RecordID file.txt    # Field name
$ tsv-select -H -f Date,Time,3,5-7,9    # Mix of names, numbers, ranges
```

Most tools process fields in the order listed, and repeated use is usually allowed:
```
$ tsv-select -f 5-1       # Fields 5, 4, 3, 2, 1
$ tsv-select -f 1-3,2,1   # Fields 1, 2, 3, 2, 1
```

Field name match is case sensitive and wildcards are supported. Field numbers are one-upped integers, following Unix conventions. Some tools accept field number zero (`0`) to represent the entire line. This is documented in the help for each tool.

Field ranges are specified as a pair of fields separated by a hyphen. This works for both field numbers and field names, but names and numbers cannot be mixed in the same range.

### Wildcards

Named fields support a simple 'glob' style wildcard scheme. The asterisk character (`*`) can be used to match any sequence of characters, including no characters. This is similar to how `*` can be used to match file names on the Unix command line. All fields with matching names are selected, so wildcards are a convenient way to select a set of related fields. Quotes should be placed around command line arguments containing wildcards to avoid interpretation by the shell.

### Examples

Consider a file `data.tsv` containing timing information:
```
$ tsv-pretty data.tsv
run  elapsed_time  user_time  system_time  max_memory
  1          57.5       52.0          5.5        1420
  2          52.0       49.0          3.0        1270
  3          55.5       51.0          4.5        1410
```

Some examples selecting fields from this file:
```
$ tsv-select data.tsv -H -f 3               # Field 3 (user_time)
$ tsv-select data.tsv -H -f user_time       # Field 3
$ tsv-select data.tsv -H -f run,user_time   # Fields 1,3
$ tsv-select data.tsv -H -f '*_memory'      # Field 5
$ tsv-select data.tsv -H -f '*_time'        # Fields 2,3,4
$ tsv-select data.tsv -H -f 1-3             # Fields 1,2,3
$ tsv-select data.tsv -H -f run-user_time   # Fields 1,2,3 (range with names)
```

### Special characters

There are several special characters that need to be escaped when specifying field names. Escaping is done by preceding the special character with a backslash. Characters requiring escapes are: asterisk (`*`), comma(`,`), colon (`:`), space (` `), hyphen (`-`), and backslash (`\`). A field name that contains only digits also needs to be backslash escaped, this indicates it should be treated as a field name and not a field number. A backslash can be used to escape any character, so it's not necessary to remember the list. Use an escape when not sure.

Consider a file with five fields named as follows:
```
1   test id
2   run:id
3   time-stamp
4   001
5   100
```
Some examples using specifying these fields by name:
```
$ tsv-select file.tsv -H -f 'test\ id'     # Field 1
$ tsv-select file.tsv -H -f '\test\ id'    # Field 1
$ tsv-select file.tsv -H -f 'run\:1'       # Field 2
$ tsv-select file.tsv -H -f 'time\-stamp'  # Field 3
$ tsv-select file.tsv -H -f '\001'         # Field 4
$ tsv-select file.tsv -H -f '\100'         # Field 5
$ tsv-select file.tsv -H -f '\001,\100'    # Fields 4,5
```

Note the use of single quotes to prevent the shell from interpreting these characters.
