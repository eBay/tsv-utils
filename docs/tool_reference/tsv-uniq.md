_Visit the [Tools Reference main page](../ToolReference.md)_<br>
_Visit the [TSV Utilities main page](../../README.md)_

# tsv-uniq reference

`tsv-uniq` identifies equivalent lines in files or standard input. Input is read line by line, recording a key based on one or more of the fields. Two lines are equivalent if they have the same key. When operating in the default 'uniq' mode, the first time a key is seen the line is written to standard output. Subsequent lines having the same key are discarded. This is similar to the Unix `uniq` program, but based on individual fields and without requiring sorted data.

`tsv-uniq` can be run without specifying a key field. In this case the whole line is used as a key, same as the Unix `uniq` program. As with `uniq`, this works on any line-oriented text file, not just TSV files. There is no need to sort the data and the original input order is preserved.

The alternatives to the default 'uniq' mode are 'number' mode and 'equiv-class' mode. In 'equiv-class' mode (`--e|equiv`), all lines are written to standard output, but with a field appended marking equivalent entries with an ID. The ID is a one-upped counter.

'Number' mode (`--z|number`) also writes all lines to standard output, but with a field appended numbering the occurrence count for the line's key. The first line with a specific key is assigned the number '1', the second with the key is assigned the number '2', etc. 'Number' and 'equiv-class' modes can be used together.

The `--r|repeated` option can be used to print only lines occurring more than once. Specifically, the second occurrence of a key is printed. The `--a|at-least N` option is similar, printing lines occurring at least N times. (Like repeated, the Nth line with the key is printed.)

The `--m|max MAX` option changes the behavior to output the first MAX lines for each key, rather than just the first line for each key.

If both `--a|at-least` and `--m|max` are specified, the occurrences starting with 'at-least' and ending with 'max' are output.

See [Field syntax](common-options-and-behavior.md#field-syntax) for more information about specifying fields.

**Synopsis:** tsv-uniq [options] [file...]

**Options:**
* `-h|help` - Print help.
* `--help-verbose` - Print detailed help.
* `--help-fields ` - Print help on specifying fields.
* `--V|version` - Print version information and exit.
* `--H|header` - Treat the first line of each file as a header.
* `--f|fields <field-list>` - Fields to use as the key. Default: 0 (entire line).
* `--i|ignore-case` - Ignore case when comparing keys.
* `--e|equiv` - Output equiv class IDs rather than uniq'ing entries.
* `--equiv-header STR` - Use STR as the equiv-id field header. Applies when using `--header --equiv`. Default: `equiv_id`.
* `--equiv-start INT` - Use INT as the first equiv-id. Default: 1.
* `--z|number` - Output equivalence class occurrence counts rather than uniq'ing entries.
* `--number-header STR` - Use STR as the `--number` field header (when using `-H --number`). Default: `equiv_line`.
* `--r|repeated` - Output only lines that are repeated (based on the key).
* `--a|at-least INT` - Output only lines that are repeated INT times (based on the key). Zero and one are ignored.
* `--m|max INT` - Max number of each unique key to output (zero is ignored).
* `--d|delimiter CHR` - Field delimiter. Default: TAB. (Single byte UTF-8 characters only.)
* `--line-buffered` - Immediately output every line.

**Examples:**
```
$ # Uniq a file, using the full line as the key
$ tsv-uniq data.txt

$ # Same as above, but case-insensitive
$ tsv-uniq --ignore-case data.txt

$ # Unique a file based on one field
$ tsv-unique -f 1 data.tsv

$ # Unique a file based on two fields
$ tsv-uniq -f 1,2 data.tsv

$ # Unique a file based on the 'URL' field
$ tsv-uniq -H -f URL data.tsv

$ # Unique a file based on the 'URL' and 'Date' fields
$ tsv-uniq -H -f URL,Date data.tsv

$ # Output all the lines, generating an ID for each unique entry
$ tsv-uniq -f 1,2 --equiv data.tsv

$ # Generate line numbers specific to each key
$ tsv-uniq -f 1,2 --number --header data.tsv

$ # --Examples showing the data--

$ cat data.tsv
field1  field2  field2
ABCD    1234    PQR
efgh    5678    stu
ABCD    1234    PQR
wxyz    1234    stu
efgh    5678    stu
ABCD    1234    PQR

$ # Uniq using the full line as key
$ tsv-uniq -H data.tsv
field1  field2  field2
ABCD    1234    PQR
efgh    5678    stu
wxyz    1234    stu

$ # Uniq using field 2 as key
$ tsv-uniq -H -f field2 data.tsv
field1  field2  field2
ABCD    1234    PQR
efgh    5678    stu

$ # Generate equivalence class IDs, using the whole line as key
$ tsv-uniq -H --equiv data.tsv
field1  field2  field2  equiv_id
ABCD    1234    PQR     1
efgh    5678    stu     2
ABCD    1234    PQR     1
wxyz    1234    stu     3
efgh    5678    stu     2
ABCD    1234    PQR     1

$ # Generate equivalence class IDs and line numbers
$ tsv-uniq -H --equiv --number data.tsv
field1	field2	field2	equiv_id  equiv_line
ABCD    1234    PQR     1         1
efgh    5678    stu     2         1
ABCD    1234    PQR     1         2
wxyz    1234    stu     3         1
efgh    5678    stu     2         2
ABCD    1234    PQR     1         3
```
