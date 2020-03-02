_Visit the eBay TSV utilities [main page](../README.md)_

# tsv-select

A version of the Unix `cut` utility with the additional ability to re-order the fields. The following command writes fields [4, 2, 9, 10, 11] from a pair of files to stdout:
```
$ tsv-select -f 4,2,9-11 file1.tsv file2.tsv
```

Fields can be listed more than once, and fields not listed can be output using the `--rest` option. When working with multiple files, the `--header` option can be used to retain only the header from the first file.

Examples:
```
$ # Output fields 2 and 1, in that order
$ tsv-select -f 2,1 data.tsv

$ # Move field 7 to the start of the line
$ tsv-select -f 7 --rest last data.tsv

$ # Move field 1 to the end of the line
$ tsv-select -f 1 --rest first data.tsv

$ # Output a range of fields in reverse order
$ tsv-select -f 30-3 data.tsv

$ # Multiple files with header lines. Keep only one header.
$ tsv-select data*.tsv -H --fields 1,2,4-7,14
```

Reordering fields and managing headers are useful enhancements over `cut`. However, much of the motivation for writing `tsv-select` was to explore the D programming language and provide a comparison point against other common approaches to this task. Code for `tsv-select` is bit more liberal with comments pointing out D programming constructs than code for the other tools. As an unexpected benefit, `tsv-select` is faster than other implementations of `cut` that are available.

See the [tsv-select reference](../docs/ToolReference.md#tsv-select-reference) for details.
