_Visit the [Tools Reference main page](../ToolReference.md)_<br>
_Visit the [TSV Utilities main page](../../README.md)_

# number-lines reference

**Synopsis:** number-lines [options] [file...]

number-lines reads from files or standard input and writes each line to standard output preceded by a line number. It is a simplified version of the Unix `nl` program. It supports one feature `nl` does not: the ability to treat the first line of files as a header. This is useful when working with tab-separated-value files. If header processing is used, a header line is written for the first file, and the header lines are dropped from any subsequent files.

**Options:**
* `--h|help` - Print help.
* `--V|version` - Print version information and exit.
* `--H|header` - Treat the first line of each file as a header. The first input file's header is output, subsequent file headers are discarded.
* `--s|header-string STR` - String to use as the header for the line number field. Implies `--header`. Default: 'line'.
* `--n|start-number NUM` - Number to use for the first line. Default: 1.
* `--d|delimiter CHR` - Character appended to line number, preceding the rest of the line. Default: TAB (Single byte UTF-8 characters only.)
* `--line-buffered` - Immediately output every line.

**Examples:**
```
$ # Number lines in a file
$ number-lines file.tsv

$ # Number lines from multiple files. Treat the first line of each file
$ # as a header.
$ number-lines --header data*.tsv
```

**See Also:**

* [tsv-uniq](tsv-uniq.md) supports numbering lines grouped by key.
