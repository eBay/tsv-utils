_Visit the [Tools Reference main page](../ToolReference.md)_<br>
_Visit the [TSV Utilities main page](../../README.md)_

# tsv-select reference

**Synopsis:** tsv-select [options] [file...]

tsv-select reads files or standard input and writes selected fields to standard output. Fields are written in the order listed. This is similar to Unix `cut`, but with the ability to select fields by name, reorder fields, and drop fields.

Fields can be specified by field number or, for files with header lines, by field name. Fields numbers start with one. They are comma separated, and ranges can be used. The `--H|header` option enables selection by field name. This also manages header lines from multiple files, retaining only the first header.

Fields can be listed more than once, and fields not listed can be selected as a group using the `--rest` option. Fields can be dropped using `--e|exclude`. All fields not excluded are output. `--f|fields` and `--r|rest` can be used with `--e|exclude` to change the order of non-excluded fields.

**Options:**
* `--h|help` - Print help.
* `--help-verbose` -  Print more detailed help.
* `--help-fields ` - Print help on specifying fields.
* `--V|version` - Print version information and exit.
* `--H|header` - Treat the first line of each file as a header.
* `--f|fields <field-list>` - Fields to retain. Fields are output in the order listed.
* `--e|--exclude <field-list>` - Fields to exclude.
* `--r|rest first|last` - Output location for fields not included in the `--f|fields` field-list.
* `--d|delimiter CHR` - Character to use as field delimiter. Default: TAB. (Single byte UTF-8 characters only.)

**Notes:**
* See [Field syntax](common-options-and-behavior.md#field-syntax) for information about specifying fields.
* One of `--f|fields` or `--e|exclude` is required.
* Fields specified by `--f|fields` and `--e|exclude` cannot overlap.
* When `--f|fields` and `--e|exclude` are used together, the effect is to specify `--rest last`. This can be overridden by specifying `--rest first`.
* Each input line must be long enough to contain all fields specified with `--f|fields`. This is not necessary for `--e|exclude` fields.
* Specifying field names containing special characters may require escaping the special characters. See [Field syntax](common-options-and-behavior.md#field-syntax) for details.

**Examples:**
```
$ # Keep the first field from two files
$ tsv-select -f 1 file1.tsv file2.tsv

$ # Keep fields 1 and 2, retain the header from the first file
$ tsv-select -H -f 1,2 file1.tsv file2.tsv

$ # Keep the 'time' field
$ tsv-select -H -f time file1.tsv

$ # Keep all fields ending '_date' or '_time'
$ tsv-select -H -f '*_date,*_time' file.tsv

$ # Drop all the '*_time' fields
$  tsv-select -H --exclude '*_time' file.tsv
   
$ # Output fields 2 and 1, in that order
$ tsv-select -f 2,1 file.tsv

$ # Output a range of fields
$ tsv-select -f 3-30 file.tsv

$ # Output a range of fields in reverse order
$ tsv-select -f 30-3 file.tsv

$ # Drop the first field, keep everything else
$ # Equivalent to 'cut -f 2- file.tsv'
$ tsv-select --exclude 1 file.tsv
$ tsv-select -e 1 file.tsv

$ # Move field 1 to the end of the line
$ tsv-select -f 1 --rest first file.tsv

$ # Move the 'Date' and 'Time' fields to the start of the line
$ tsv-select -H -f Date,Time --rest last file.tsv

# Output with repeating fields
$ tsv-select -f 1,2,1 file.tsv
$ tsv-select -f 1-3,3-1 file.tsv

$ # Read from standard input
$ cat file*.tsv | tsv-select -f 1,4-7,11

$ # Read from a file and standard input. The '--' terminates command
$ # option processing, '-' represents standard input.
$ cat file1.tsv | tsv-select -f 1-3 -- - file2.tsv

$ # Files using comma as the separator ('simple csv')
$ # (Note: Does not handle CSV escapes.)
$ tsv-select -d , --fields 5,1,2 file.csv

$ # Move field 2 to the front and drop fields 10-15
$ tsv-select -f 2 -e 10-15 file.tsv

$ # Move field 2 to the end, dropping fields 10-15
$ tsv-select -f 2 -rest first -e 10-15 file.tsv
```
