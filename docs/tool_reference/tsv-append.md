_Visit the [Tools Reference main page](../ToolReference.md)_<br>
_Visit the [TSV Utilities main page](../../README.md)_

# tsv-append reference

**Synopsis:** tsv-append [options] [file...]

tsv-append concatenates multiple TSV files, similar to the Unix `cat` utility. Unlike `cat`, it is header-aware (`--H|header`), writing the header from only the first file. It also supports source tracking, adding a column indicating the original file to each row. Results are written to standard output.

Concatenation with header support is useful when preparing data for traditional Unix utilities like `sort` and `sed` or applications that read a single file.

Source tracking is useful when creating long/narrow form tabular data, a format used by many statistics and data mining packages. In this scenario, files have been used to capture related data sets, the difference between data sets being a condition represented by the file. For example, results from different variants of an experiment might each be recorded in their own files. Retaining the source file as an output column preserves the condition represented by the file.

The file-name (without extension) is used as the source value. This can customized using the `--f|file` option.

Example: Header processing:
```
$ tsv-append -H file1.tsv file2.tsv file3.tsv
```

Example: Header processing and source tracking:
```
$ tsv-append -H -t file1.tsv file2.tsv file3.tsv
```

Example: Source tracking with custom source values:
```
$ tsv-append -H -s test_id -f test1=file1.tsv -f test2=file2.tsv
 ```

**Options:**
* `--h|help` - Print help.
* `--help-verbose` - Print detailed help.
* `--V|version` - Print version information and exit.
* `--H|header` - Treat the first line of each file as a header.
* `--t|track-source` - Track the source file. Adds an column with the source name.
* `--s|source-header STR` - Use STR as the header for the source column. Implies `--H|header` and `--t|track-source`. Default: 'file'
* `--f|file STR=FILE` - Read file FILE, using STR as the 'source' value. Implies `--t|track-source`.
* `--d|delimiter CHR` - Field delimiter. Default: TAB. (Single byte UTF-8 characters only.)
* `--line-buffered` - Immediately output every line.
