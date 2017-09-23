_Visit the eBay TSV utilities [main page](../README.md)_

# tsv-select

A version of the Unix `cut` utility with the additional ability to re-order the fields. It also helps with header lines by keeping only the header from the first file (`--header` option). The following command writes fields [4, 2, 9, 10, 11] from a pair of files to stdout:
```
$ tsv-select -f 4,2,9-11 file1.tsv file2.tsv
```

Reordering fields and managing headers are useful enhancements over `cut`. However, much of the motivation for writing it was to explore the D programming language and provide a comparison point against other common approaches to this task. Code for `tsv-select` is bit more liberal with comments pointing out D programming constructs than code for the other tools. As an unexpected benefit, `tsv-select` is faster than other implementations of `cut` that are available.

See the [tsv-select reference](../docs/ToolReference.md#tsv-select-reference) for details.
