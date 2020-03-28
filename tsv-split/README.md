_Visit the eBay TSV utilities [main page](../README.md)_

# tsv-split

`tsv-split` is used to split one or more input files into multiple output files. There are three modes of operation:
* Fixed number of lines per file (`--l|lines-per-file NUM`): Each input block of NUM lines is written to a new file. This is similar to the Unix `split` utility.

* Random assignment (`--n|num-files NUM`): Each input line is written to a randomly selected output file. Random selection is from NUM files.

* Random assignment by key (`--n|num-files NUM, --k|key-fields FIELDS`): Input lines are written to output files using fields as a key. Each unique key is randomly assigned to one of NUM output files. All lines with the same key are written to the same file.

By default, files are written to the current directory and have names of the form `part_NNN<suffix>`, with `NNN` being a number and `<suffix>` being the extension of the first input file. If the input file is `file.txt`, the names will take the form `part_NNN.txt`. The output directory and file names are customizable.

Examples:
```
$ # Split a file into files of 10,000 lines each. Output files
$ # are written to the 'split_files/' directory.
$ tsv-split data.txt --lines-per-file 10000 --dir split_files

$ # Split a file into 1000 files with lines randomly assigned.
$ tsv-split data.txt --num-files 1000 --dir split_files

# Randomly assign lines to 1000 files using field 3 as a key.
$ tsv-split data.tsv --num-files 1000 -key-fields 3 --dir split_files
```

See the [tsv-split reference](../docs/ToolReference.md#tsv-split-reference) for more information.
