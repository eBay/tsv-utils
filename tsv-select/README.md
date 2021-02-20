_Visit the eBay TSV utilities [main page](../README.md)_

# tsv-select

A version of the Unix `cut` utility with the ability to select fields by name, drop fields, and reorder fields. The following command writes the `date` and `time` fields from a pair of files to standard output:
```
$ tsv-select -H -f date,time file1.tsv file2.tsv
```
Fields can also be selected by field number:
```
$ tsv-select -f 4,2,9-11 file1.tsv file2.tsv
```

Fields can be listed more than once, and fields not specified can be selected as a group using `--r|rest`. Fields can be dropped using `--e|exclude`.

The `--H|header` option turns on header processing. This enables specifying fields by name. Only the header from the first file is retained when multiple input files are provided.

Examples:
```
$ # Output fields 2 and 1, in that order.
$ tsv-select -f 2,1 data.tsv

$ # Output the 'Name' and 'RecordNum' fields.
$ tsv-select -H -f Name,RecordNum data.tsv.

$ # Drop the first field, keep everything else.
$ tsv-select --exclude 1 file.tsv

$ # Drop the 'Color' field, keep everything else.
$ tsv-select -H --exclude Color file.tsv

$ # Move the 'RecordNum' field to the start of the line.
$ tsv-select -H -f RecordNum --rest last data.tsv

$ # Move field 1 to the end of the line.
$ tsv-select -f 1 --rest first data.tsv

$ # Output a range of fields in reverse order.
$ tsv-select -f 30-3 data.tsv

$ # Drop all the fields ending in '_time'
$ tsv-select -H -e '*_time' data.tsv

$ # Multiple files with header lines. Keep only one header.
$ tsv-select data*.tsv -H --fields 1,2,4-7,14
```

Named fields, dropping and reordering fields, and header line management are useful enhancements over traditional `cut`. However, much of the motivation for writing `tsv-select` was to explore the D programming language and provide a comparison point against other common approaches to this task. Code for `tsv-select` is a bit more liberal with comments pointing out D programming constructs than code for the other tools. As an unexpected benefit, `tsv-select` is faster than other implementations of `cut` that are available.

See the [tsv-select reference](../docs/tool_reference/tsv-select.md) for more details on `tsv-select`. See [Field syntax](../docs/tool_reference/common-options-and-behavior.md#field-syntax) for more information on selecting fields by name.
