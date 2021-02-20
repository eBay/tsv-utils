_Visit the [Tools Reference main page](../ToolReference.md)_<br>
_Visit the [TSV Utilities main page](../../README.md)_

# tsv-split reference

Synopsis: tsv-split [options] [file...]

Split input lines into multiple output files. There are three modes of operation:

* **Fixed number of lines per file** (`--l|lines-per-file NUM`): Each input block of NUM lines is written to a new file. Similar to Unix `split`.

* **Random assignment** (`--n|num-files NUM`): Each input line is written to a randomly selected output file. Random selection is from NUM files.

* **Random assignment by key** (`--n|num-files NUM`, `--k|key-fields FIELDS`): Input lines are written to output files using fields as a key. Each unique key is randomly assigned to one of NUM output files. All lines with the same key are written to the same file.

**Output files**: By default, files are written to the current directory and have names of the form `part_NNN<suffix>`, with `NNN` being a number and `<suffix>` being the extension of the first input file. If the input file is `file.txt`, the names will take the form `part_NNN.txt`. The suffix is empty when reading from standard input. The numeric part defaults to 3 digits for `--l|lines-per-files`. For `--n|num-files` enough digits are used so all filenames are the same length. The output directory and file names are customizable.

**Header lines**: There are two ways to handle input with headers: write a header to all output files (`--H|header`), or exclude headers from all output files (`--I|header-in-only`). The best choice depends on the follow-up processing. All tsv-utils tools support header lines in multiple input files, but many other tools do not. For example, [GNU parallel](https://www.gnu.org/software/parallel/) works best on files without header lines. (See [Faster processing using GNU parallel](../TipsAndTricks.md#faster-processing-using-gnu-parallel) for some info on using GNU parallel and tsv-utils together.)

**About Random assignment** (`--n|num-files`): Random distribution of records to a set of files is a common task. When data fits in memory the preferred approach is usually to shuffle the data and split it into fixed sized blocks. Both of the following command lines accomplish this:
```
$ shuf data.tsv | split -l NUM
$ tsv-sample data.tsv | tsv-split -l NUM
```

However, alternate approaches are needed when data is too large for convenient shuffling. tsv-split's random assignment feature can be useful in these cases. Each input line is written to a randomly selected output file. Note that output files will have similar but not identical numbers of records.

**About Random assignment by key** (`--n|num-files NUM`, `--k|key-fields FIELDS`): This splits a data set into multiple files sharded by key. All lines with the same key are written to the same file. This partitioning enables parallel computation based on the key. For example, statistical calculation (`tsv-summarize --group-by`) or duplicate removal (`tsv-uniq --fields`). These operations can be parallelized using tools like GNU parallel, which simplifies concurrent operations on multiple files. Fields are specified using field number or field name. Field names require that the input file has a header line.

**Random seed**: By default, each tsv-split invocation using random assignment or random assignment by key produces different assignments to the output files. Using `--s|static-seed` changes this so multiple runs produce the same assignments. This works by using the same random seed each run. The seed can be specified using `--v|seed-value`.

**Appending to existing files**: By default, an error is triggered if an output file already exists. `--a|append` changes this so that lines are appended to existing files. (Header lines are not appended to files with data.) This is useful when adding new data to files created by a previous `tsv-split` run. Random assignment should use the same `--n|num-files` value each run, but different random seeds (avoid `--s|static-seed`). Random assignment by key should use the same `--n|num-files`, `--k|key-fields`, and seed (`--s|static-seed` or `--v|seed-value`) each run.

**Max number of open files**: Random assignment and random assignment by key are dramatically faster when all output files are kept open. However, keeping a large number of open files can bump into system limits or limit resources available to other processes. By default, `tsv-split` uses up to 4096 open files or the system per-process limit, whichever is smaller. This can be changed using `--max-open-files`, though it cannot be set larger than the system limit. The system limit varies considerably between systems. On many systems it is unlimited. On MacOS it is often set to 256. Use Unix `ulimit` to display and modify the limits:
```
$ ulimit -n       # Show the "soft limit". The per-process maximum.
$ ulimit -Hn      # Show the "hard limit". The max allowed soft limit.
$ ulimit -Sn NUM  # Change the "soft limit" to NUM.
```

**Examples**:
```
$ # Split a 10 million line file into 1000 files, 10,000 lines each.
$ # Output files are part_000.txt, part_001.txt, ... part_999.txt.
$ tsv-split data.txt --lines-per-file 10000

$ # Same as the previous example, but write files to a subdirectory.
$  tsv-split data.txt --dir split_files --lines-per-file 10000

$ # Split a file into 10,000 line files, writing a header line to each
$ tsv-split data.txt -H --lines-per-file 10000

$ # Same as the previous example, but dropping the header line.
$ tsv-split data.txt -I --lines-per-file 10000

$ # Randomly assign lines to 1000 files
$ tsv-split data.txt --num-files 1000

$ # Randomly assign lines to 1000 files while keeping unique entries
$ # from the 'url' field together.
$ tsv-split data.tsv -H -k url --num-files 1000

$ # Randomly assign lines to 1000 files. Later, randomly assign lines
$ # from a second data file to the same output files.
$ tsv-split data1.tsv -n 1000
$ tsv-split data2.tsv -n 1000 --append

$ # Randomly assign lines to 1000 files using field 3 as a key.
$ # Later, add a second file to the same output files.
$ tsv-split data1.tsv -n 1000 -k 3 --static-seed
$ tsv-split data2.tsv -n 1000 -k 3 --static-seed --append

$ # Change the system per-process open file limit for one command.
$ # The parens create a sub-shell. The current shell is not changed.
$ ( ulimit -Sn 1000 && tsv-split --num-files 1000 data.txt )
```

**Options**:
* `--h|--help` - Print help.
* `--help-verbose` - Print more detailed help.
* `--help-fields ` - Print help on specifying fields.
* `--V|--version` -  Print version information and exit.
* `--H|header` - Input files have a header line. Write the header to each output file.
* `--I|header-in-only` - Input files have a header line. Do not write the header to output files.
* `--l|lines-per-file NUM` - Number of lines to write to each output file (excluding the header line).
* `--n|num-files NUM` - Number of output files to generate.
* `--k|key-fields <field-list>` - Fields to use as key. Lines with the same key are written to the same output file. Use `--k|key-fields 0` to use the entire line as the key.
* `--dir STR` - Directory to write to. Default: Current working directory.
* `--prefix STR` - Filename prefix. Default: `part_`
* `--suffix STR` - Filename suffix. Default: First input file extension. None for standard input.
* `--w|digit-width NUM` - Number of digits in filename numeric portion. Default: `--l|lines-per-file`: 3. `--n|num-files`: Chosen so filenames have the same length. `--w|digit-width 0` uses the default.
* `--a|append` - Append to existing files.
* `--s|static-seed` - Use the same random seed every run.
* `--v|seed-value NUM` - Sets the random seed. Use a non-zero, 32 bit positive integer. Zero is a no-op.
* `--d|delimiter CHR` - Field delimiter.
* `--max-open-files NUM` - Maximum open file handles to use. Min of 5 required.
