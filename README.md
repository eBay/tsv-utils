# Command line utilities for tabular data files

This is a set of command line utilities for working with tab-separated value files. They were originally developed in Perl and used for day-to-day work in a large scale data mining environment. One of the tools was re-written in D as an exercise exploring the language. Significant performance gains and agreeable programmer characteristics soon led to writing the other utilities in D as well.

The tools have been made available in the hope they will benefit others needing similar tools or who are considering D as a programming language.

Information on the D programming language is available at: http://dlang.org/.

**In this README:**
* [Tools overview](#tools-overview)
* [Installation](#installation)
* [Other toolkits](#other-toolkits)

**More details:**
* [Tool reference](docs/ToolReference.md)
* [Performance benchmarks](docs/Performance.md)
* [About the code](docs/AboutTheCode.md)
* [Tips and tricks](docs/TipsAndTricks.md)

Please file an issue if you have problems or questions.

## Tools overview

These tools were developed for working with reasonably large data files. Larger than ideal for loading entirely in memory in an application like R, but not so big as to necessitate moving to Hadoop or similar distributed compute environments. They work like traditional Unix command line utilities such as `cut`, `sort`, `grep`, etc., and are intended to complement these tools. Each tool is a standalone executable. They follow common Unix conventions for pipeline programs. Data is read from files or standard input, results are written to standard output. The field separator defaults to TAB, but any character can be used. Input and output is UTF-8, and all operations are Unicode ready, including regular expression match (`tsv-filter`). Documentation is available for each tool by invoking it with the `--help` option. Speed matters when processing large files. Check out [Performance benchmarks](docs/Performance.md) to see how these tools measure up.

The rest of this section contains a short description of each tool. There is more detail in the [tool reference](docs/ToolReference.md).

* [tsv-filter](#tsv-filter) - Filter data file rows via numeric and string comparisons.
* [tsv-select](#tsv-select) - Keep a subset of the columns (fields) in the input.
* [tsv-summarize](#tsv-summarize) - Aggregate field values, summarizing across the entire file or grouped by key.
* [tsv-join](#tsv-join) - Join lines from multiple files using fields as a key.
* [tsv-append](#tsv-append) - Concatenate TSV files. Header-aware; supports source file tracking.
* [tsv-uniq](#tsv-uniq) - Filter out duplicate lines using fields as a key.
* [tsv-sample](#tsv-sample) - Uniform and weighted random sampling or permutation of input lines.
* [csv2tsv](#csv2tsv) - Convert CSV files to TSV.
* [number-lines](#number-lines) - Number the input lines.
* [keep-header](#keep-header) - Run a shell command in a header-aware fashion.

### tsv-filter

Outputs select lines by making numeric and string comparisons against individual fields. Multiple comparisons can be specified in a single call. A variety of numeric and string comparison operators are available as well as regular expressions. Example:
```
$ tsv-filter --ge 3:100 --le 3:200 --str-eq 4:red file.tsv
```

This outputs lines where field 3 satisfies (100 <= fieldval <= 200) and field 4 matches 'red'.

`tsv-filter` is the most widely applicable of the tools, as dataset pruning is a common task. It is stream oriented, so it can handle arbitrarily large files. It is quite fast, faster than other tools the author has tried. This makes it idea for preparing data for applications like R and Pandas. It is also convenient for quickly answering simple questions about a dataset. For example, to count the number of records with a non-zero value in field 3, use the command:
```
$ tsv-filter --ne 3:0 file.tsv | wc -l
```

See the [tsv-filter reference](docs/ToolReference.md#tsv-filter-reference) for details.

### tsv-select

A version of the Unix `cut` utility with the additional ability to re-order the fields. It also helps with header lines by keeping only the header from the first file (`--header` option). The following command writes fields [4, 2, 9] from a pair of files to stdout:
```
$ tsv-select -f 4,2,9 file1.tsv file2.tsv
```

Reordering fields and managing headers are useful enhancements over `cut`. However, much of the motivation for writing it was to explore the D programming language and provide a comparison point against other common approaches to this task. Code for `tsv-select` is bit more liberal with comments pointing out D programming constructs than code for the other tools.

See the [tsv-select reference](docs/ToolReference.md#tsv-select-reference) for details.

### tsv-summarize

`tsv-summarize` runs aggregation operations on fields. For example, generating the sum or median of a field's values. Summarization calculations can be run across the entire input or can be grouped by key fields. As an example, consider the file `data.tsv`:
```
color   weight
red     6
red     5
blue    15
red     4
blue    10
```
Calculation of the sum and mean of the `weight` column are below. The first command runs calculations on all values. The second groups them by color.
```
$ tsv-summarize --header --sum 2 --mean 2 data.tsv
weight_sum  weight_mean
40          8

$ tsv-summarize --header --group-by 1 --sum 2 --mean 2 data.tsv
color  weight_sum  weight_mean
red    15          5
blue   25          12.5
```

Multiple fields can be used as the `--group-by` key. The file's sort order does not matter, there is no need to sort in the `--group-by` order first.

See the [tsv-summarize reference](docs/ToolReference.md#tsv-summarize-reference) for the list of statistical and other aggregation operations available.

### tsv-join

Joins lines from multiple files based on a common key. One file, the 'filter' file, contains the records (lines) being matched. The other input files are scanned for matching records. Matching records are written to standard output, along with any designated fields from the filter file. In database parlance this is a hash semi-join. Example:
```
$ tsv-join --filter-file filter.tsv --key-fields 1,3 --append-fields 5,6 data.tsv
```

This reads `filter.tsv`, creating a lookup table keyed on fields 1 and 3. `data.tsv` is read, lines with a matching key are written to standard output with fields 5 and 6 from `filter.tsv` appended. This is a form of inner-join. Outer-joins and anti-joins can also be done.

Common uses for `tsv-join` are to join related datasets or to filter one dataset based on another. Filter file entries are kept in memory, this limits the ultimate size that can be handled effectively. The author has found that filter files up to about 10 million lines are processed effectively, but performance starts to degrade after that.

See the [tsv-join reference](docs/ToolReference.md#tsv-join-reference) for details.

### tsv-append

`tsv-append` concatenates multiple TSV files, similar to the Unix `cat` utility. It is header-aware, writing the header from only the first file. It also supports source tracking, adding a column indicating the original file to each row.

Concatenation with header support is useful when preparing data for traditional Unix utilities like `sort` and `sed` or applications that read a single file.

Source tracking is useful when creating long/narrow form tabular data. This format is used by many statistics and data mining packages. (See [Wide & Long Data - Stanford University](http://stanford.edu/~ejdemyr/r-tutorials/wide-and-long/) or Hadley Wickham's [Tidy data](http://vita.had.co.nz/papers/tidy-data.html) for more info.)

In this scenario, files have been used to capture related data sets, the difference between data sets being a condition represented by the file. For example, results from different variants of an experiment might each be recorded in their own files. Retaining the source file as an output column preserves the condition represented by the file. The source values default to the file names, but this can be customized.

See the [tsv-append reference](docs/ToolReference.md#tsv-append-reference) for the complete list of options available.

### tsv-uniq

Similar in spirit to the Unix `uniq` tool, `tsv-uniq` filters a dataset so there is only one copy of each line. `tsv-uniq` goes beyond Unix `uniq` in a couple ways. First, data does not need to be sorted. Second, equivalence is based on a subset of fields rather than the full line. `tsv-uniq` can also be run in an 'equivalence class identification' mode, where equivalent entries are marked with a unique id rather than being filtered. An example uniq'ing a file on fields 2 and 3:
```
$ tsv-uniq -f 2,3 data.tsv
```

`tsv-uniq` operates on the entire line when no fields are specified. This is a useful alternative to the traditional `sort -u` or `sort | uniq` paradigms for identifying unique lines in unsorted files, as it is often quite a bit faster.

As with `tsv-join`, this uses an in-memory lookup table to record unique entries. This ultimately limits the data sizes that can be processed. The author has found that datasets with up to about 10 million unique entries work fine, but performance degrades after that.

See the [tsv-uniq reference](docs/ToolReference.md#tsv-uniq-reference) for details.

### tsv-sample

For uniform random sampling, the GNU `shuf` program is quite good and widely available. For weighted random sampling the choices are limited, especially when working with large files. This is where `tsv-sample` is useful. It implements weighted reservoir sampling, with the weights taken from a field in the input data. Uniform random sampling is supported as well. Performance is good, it works quite well on large files. See the [tsv-sample reference](docs/ToolReference.md#tsv-sample-reference) for details.

### csv2tsv

Sometimes you have a CSV file. This program does what you expect: convert CSV data to TSV. Example:
```
$ csv2tsv data.csv > data.tsv
```

CSV files come in different formats. See the [csv2tsv reference](docs/ToolReference.md#csv2tsv-reference) for details of how this tool operates and the format variations handled.

### number-lines

A simpler version of the Unix 'nl' program. It prepends a line number to each line read from files or standard input. This tool was written primarily as an example of a simple command line tool. The code structure it uses is the same as followed by all the other tools. Example:
```
$ number-lines myfile.txt
```

See the [number-lines reference](docs/ToolReference.md#tsv-summarize-reference) for details.

### keep-header

A convenience utility that runs unix commands in a header-aware fashion. It is especially useful with `sort`, which puts the header line wherever it falls in the sort order. Using `keep-header`, the header line retains its position as the first line. For example:
```
$ keep-header myfile.txt -- sort
```

It is also useful with `grep`, `awk`, `sed`, similar tools, when the header line should be excluded from the command's action.

Multiple files can be provided, only the header from the first is retained. The command is executed as specified, so additional command options can be provided. See the [keep-header reference](docs/ToolReference.md#keep-header-reference) for more information.

## Installation

Download a D compiler (http://dlang.org/download.html). These tools have been tested with the DMD and LDC compilers, on Mac OSX and Linux. Use DMD version 2.070 or later, LDC version 1.0.0 or later.

Clone this repository, select a compiler, and run `make` from the top level directory:
```
$ git clone https://github.com/eBay/tsv-utils-dlang.git
$ cd tsv-utils-dlang
$ make         # For LDC: make DCOMPILER=ldc2
```

Executables are written to `tsv-utils-dlang/bin`, place this directory or the executables in the PATH. The compiler defaults to DMD, this can be changed on the make command line (e.g. `make DCOMPILER=ldc2`). DMD is the reference compiler, but LDC produces faster executables. (For some tools LDC is quite a bit faster than DMD.)

DUB, the D Package Manager, can also be used to install and build the executables. It is also possible to run
build commands manually, see [BuildCommands](docs/BuildCommands.md) file for details.

### Install using DUB

If you are already a D user you likely use DUB, the D package manager. DUB comes packaged with DMD starting with DMD 2.072. You can install and build using DUB as follows:
```
$ dub fetch tsv-utils-dlang
$ dub run tsv-utils-dlang    # For LDC: dub run tsv-utils-dlang -- --compiler=ldc
```

The `dub run` command compiles all the tools. The executables are written to a DUB package repository directory. For example: `~/.dub/packages/tsv-utils-dlang-1.0.8/bin`. Add the executables to the PATH. Installation to a DUB package repository is not always most convenient. As an alternative, clone the repository and run dub from the source directory. This puts the executables in the `tsv-utils-dlang/bin` directory:
```
$ git clone https://github.com/eBay/tsv-utils-dlang.git
$ dub add-local tsv-utils-dlang
$ cd tsv-utils-dlang
$ dub run      # For LDC: dub run -- --compiler=ldc2
```

See [Building and makefile](docs/AboutTheCode.md#building-and-makefile) for more information.

## Other toolkits

There are a number of toolkits that have similar or related functionality. Several are listed below. Those handling CSV files handle TSV files as well:

* [csvkit](https://github.com/wireservice/csvkit) - CSV tools, written in Python.
* [csvtk](https://github.com/shenwei356/csvtk) - CSV tools, written in Go.
* [GNU datamash](https://www.gnu.org/software/datamash/) - Performs numeric, textual and statistical operations on TSV files. Written in C.
* [dplyr](https://github.com/hadley/dplyr) - Tools for tabular data in R storage formats. Runs in an R environment, code is in C++.
* [miller](https://github.com/johnkerl/miller) - CSV and JSON tools, written in C.
* [tsvutils](https://github.com/brendano/tsvutils) - TSV tools, especially rich in format converters. Written in Python.
* [xsv](https://github.com/BurntSushi/xsv) - CSV tools, written in Rust.

The different toolkits are certainly worth investigating if you work with tabular data files. Several have quite extensive feature sets. Each toolkit has its own strengths, your workflow and preferences are likely to fit some toolkits better than others.

File format is perhaps the most important dimension. CSV files cannot be processed reliably by traditional unix tools, so CSV toolkits naturally extend further into this space. However, this tends to increase complexity of the tools when working with TSV files.

Tradeoffs between file formats is its own topic. The [tsvutils README](https://github.com/brendano/tsvutils#the-philosophy-of-tsvutils) (Brendan O'Conner) has a nice discussion of the rationale for using TSV files. Note that many numeric CSV data sets use comma as a separator, but don't use CSV escapes. Such data sets can be processed reliabily by Unix tools and this toolset by setting the delimiter character.

An even broader list of tools can be found here: [Structured text tools](https://github.com/dbohdan/structured-text-tools).
