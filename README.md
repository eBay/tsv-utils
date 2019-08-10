# Command line utilities for tabular data files

This is a set of command line utilities for manipulating large tabular data files. Files of numeric and text data commonly found in machine learning, data mining, and similar environments. Filtering, sampling, statistical calculations, joins, and more.

These tools are especially useful when working with large data sets. They run faster than other tools providing similar functionality, often by significant margins. See [Performance Studies](docs/Performance.md) for benchmark comparisons with other tools.

File an [issue](https://github.com/eBay/tsv-utils/issues) if you have problems, questions or suggestions.

**In this README:**
* [Tools overview](#tools-overview) - Descriptions of each tool.
* [Obtaining and installation](#obtaining-and-installation)

**Additional documents:**
* [Tools reference](docs/ToolReference.md)
* [Release notes (releases page)](https://github.com/eBay/tsv-utils/releases)
* [Tips and tricks](docs/TipsAndTricks.md)
* [Performance Studies](docs/Performance.md)
* [Comparing TSV and CSV formats](docs/comparing-tsv-and-csv.md)
* [Building with Link Time Optimization (LTO) and Profile Guided Optimization (PGO)](docs/BuildingWithLTO.md)
* [About the code](docs/AboutTheCode.md) (see also: [tsv-utils code documentation](https://tsv-utils.dpldocs.info/))
* [Other toolkits](docs/OtherToolkits.md)

**Talks and blog posts:**
* [Faster Command Line Tools in D](https://dlang.org/blog/2017/05/24/faster-command-line-tools-in-d/). May 24, 2017. A blog post showing a few ways to optimize performance in command line tools. Many of the ideas in the post were identified while developing the TSV Utilities.
* [Experimenting with Link Time Optimization](docs/dlang-meetup-14dec2017.pdf). Dec 14, 2017. A presentation at the [Silicon Valley D Meetup](https://www.meetup.com/D-Lang-Silicon-Valley/) describing experiments using LTO based on eBay's TSV Utilities.
* [Exploring D via Benchmarking of eBay's TSV Utilities](http://dconf.org/2018/talks/degenhardt.html). May 2, 2018. A presentation at [DConf 2018](http://dconf.org/2018/) describing performance benchmark studies conducted using eBay's TSV Utilities (slides [here](docs/dconf2018.pdf)).

[![Travis](https://img.shields.io/travis/eBay/tsv-utils.svg)](https://travis-ci.org/eBay/tsv-utils)
[![Codecov](https://img.shields.io/codecov/c/github/eBay/tsv-utils.svg)](https://codecov.io/gh/eBay/tsv-utils)
[![GitHub release](https://img.shields.io/github/release/eBay/tsv-utils.svg)](https://github.com/eBay/tsv-utils/releases)
[![Github commits (since latest release)](https://img.shields.io/github/commits-since/eBay/tsv-utils/latest.svg)](https://github.com/eBay/tsv-utils/commits/master)
[![GitHub last commit](https://img.shields.io/github/last-commit/eBay/tsv-utils.svg)](https://github.com/eBay/tsv-utils/commits/master)
[![license](https://img.shields.io/github/license/eBay/tsv-utils.svg)](https://github.com/eBay/tsv-utils/blob/master/LICENSE.txt)

## Tools overview

These tools perform data manipulation and statistical calculations on tab delimited data. They are intended for large files. Larger than ideal for loading entirely in memory in an application like R, but not so big as to necessitate moving to Hadoop or similar distributed compute environments. The features supported are useful both for standalone analysis and for preparing data for use in R, Pandas, and similar toolkits.

The tools work like traditional Unix command line utilities such as `cut`, `sort`,  `grep` and `awk`, and are intended to complement these tools. Each tool is a standalone executable. They follow common Unix conventions for pipeline programs. Data is read from files or standard input, results are written to standard output. The field separator defaults to TAB, but any character can be used. Input and output is UTF-8, and all operations are Unicode ready, including regular expression match (`tsv-filter`). Documentation is available for each tool by invoking it with the `--help` option. TSV format is similar to CSV, see [Comparing TSV and CSV formats](docs/comparing-tsv-and-csv.md) for the differences.

The rest of this section contains descriptions of each tool. Click on the links below to jump directly to one of the tools. Full documentation is available in the [tool reference](docs/ToolReference.md).

* [tsv-filter](#tsv-filter) - Filter lines using numeric, string and regular expression comparisons against individual fields.
* [tsv-sample](#tsv-sample) - Sample input lines or randomize their order. A number of sampling methods are available.
* [tsv-summarize](#tsv-summarize) - Summary statistics on selected fields, against the full data set or grouped by key.
* [tsv-pretty](#tsv-pretty) - Print TSV data aligned for easier reading on the command-line.
* [tsv-select](#tsv-select) - Keep a subset of columns (fields). Like `cut`, but with field reordering.
* [tsv-join](#tsv-join) - Join lines from multiple files using fields as a key.
* [tsv-uniq](#tsv-uniq) - Filter out duplicate lines using fields as a key.
* [csv2tsv](#csv2tsv) - Convert CSV files to TSV.
* [tsv-append](#tsv-append) - Concatenate TSV files. Header-aware; supports source file tracking.
* [number-lines](#number-lines) - Number the input lines.
* [keep-header](#keep-header) - Run a shell command in a header-aware fashion.

### tsv-filter

Filters lines by making tests against individual fields. Multiple tests can be specified in a single call. A variety of numeric and string comparison operators are available as well as regular expressions. Example:
```
$ tsv-filter --ge 3:100 --le 3:200 --str-eq 4:red file.tsv
```

This outputs lines where field 3 satisfies (100 <= fieldval <= 200) and field 4 matches 'red'.

`tsv-filter` is the most widely applicable of the tools, as dataset pruning is a common task. It is stream oriented, so it can handle arbitrarily large files. It is fast, quite a bit faster than other tools the author has tried. This makes it ideal for preparing data for applications like R and Pandas. It is also convenient for quickly answering simple questions about a dataset. For example, to count the number of records with a non-zero value in field 3, use the command:
```
$ tsv-filter --ne 3:0 file.tsv | wc -l
```

See the [tsv-filter reference](docs/ToolReference.md#tsv-filter-reference) for details.

### tsv-sample

`tsv-sample` randomizes line order or selects subsamples of lines from input data. Several sampling methods are available, including simple random sampling, weighted random sampling, Bernoulli sampling, and distinct sampling. Data can be read from files or standard input. These sampling methods are made available through several modes of operation:

* Line order randomization - This is the default mode of operation. All lines are read into memory and written out in a random order. All orderings are equally likely. This can be used for simple random sampling by specifying the `-n|--num` option, producing a random subset of the specified size.

* Weighted line order randomization - This extends the previous method to weighted random sampling by the use of a weight taken from each line. The weight field is specified with the `-w|--weight-field` option.

* Sampling with replacement - All lines are read into memory, then lines are selected one at a time at random and output. Lines can be output multiple times. Output continues until `-n|--num` samples have been output.

* Bernoulli sampling - Sampling can be done in streaming mode by using the `-p|--prob` option. This specifies the desired portion of lines that should be included in the sample. e.g. `-p 0.1` specifies that 10% of lines should be included in the sample. In this mode lines are read one at a time, a random selection choice made, and those lines selected are immediately output. All lines have an equal likelihood of being output.

* Distinct sampling - This is another streaming mode form of sampling. However, instead of each line being subject to an independent selection choice, lines are selected based on a key contained in each line. A portion of keys are randomly selected for output, and every line containing a selected key is included in the output. Consider a query log with records consisting of <user, query, clicked-url> triples. It may be desirable to sample records for one percent of the users, but include all records for the selected users. Distinct sampling is specified using the `-k|--key-fields` and `-p|--prob` options.

`tsv-sample` is designed for large data sets. Streaming algorithms make immediate decisions on each line. They do not accumulate memory and can run on infinite length input streams. Line order randomization algorithms need to hold the full output set into memory and are therefore limited by available memory. Memory requirements can be reduced by specifying a sample size (`-n|--num`). This enables reservoir sampling, which is often dramatically faster than full permutations. By default, a new random order is generated every run, but options are available for using the same randomization order over multiple runs. The random values assigned to each line can be printed, either to observe the behavior or even run further customized selected algorithms.

See the [tsv-sample reference](docs/ToolReference.md#tsv-sample-reference) for further details.

### tsv-summarize

`tsv-summarize` performs statistical calculations on fields. For example, generating the sum or median of a field's values. Calculations can be run across the entire input or can be grouped by key fields. Consider the file `data.tsv`:
```
color   weight
red     6
red     5
blue    15
red     4
blue    10
```
Calculations of the sum and mean of the `weight` column is shown below. The first command runs calculations on all values. The second groups them by color.
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

### tsv-pretty

tsv-pretty prints TSV data in an aligned format for better readability when working on the command-line. Text columns are left aligned, numeric columns are right aligned. Floats aligned on the decimal point and precision can be specified. Header lines are detected automatically. If desired, the header line can be repeated at regular intervals. An example, first printed without formatting:
```
$ cat sample.tsv
Color   Count   Ht      Wt
Brown   106     202.2   1.5
Canary Yellow   7       106     0.761
Chartreuse	1139	77.02   6.22
Fluorescent Orange	422     1141.7  7.921
Grey	19	140.3	1.03
```
Now with `tsv-pretty`, using header underlining and float formatting:
```
$ tsv-pretty -u -f sample.tsv
Color               Count       Ht     Wt
-----               -----       --     --
Brown                 106   202.20  1.500
Canary Yellow           7   106.00  0.761
Chartreuse           1139    77.02  6.220
Fluorescent Orange    422  1141.70  7.921
Grey                   19   140.30  1.030
```
See the [tsv-pretty reference](docs/ToolReference.md#tsv-pretty-reference) for details.

### tsv-select

A version of the Unix `cut` utility with the additional ability to re-order the fields. It also helps with header lines by keeping only the header from the first file (`--header` option). The following command writes fields [4, 2, 9, 10, 11] from a pair of files to stdout:
```
$ tsv-select -f 4,2,9-11 file1.tsv file2.tsv
```

See the [tsv-select reference](docs/ToolReference.md#tsv-select-reference) for details.

### tsv-join

Joins lines from multiple files based on a common key. One file, the 'filter' file, contains the records (lines) being matched. The other input files are scanned for matching records. Matching records are written to standard output, along with any designated fields from the filter file. In database parlance this is a hash semi-join. Example:
```
$ tsv-join --filter-file filter.tsv --key-fields 1,3 --append-fields 5,6 data.tsv
```

This reads `filter.tsv`, creating a lookup table keyed on fields 1 and 3. `data.tsv` is read, lines with a matching key are written to standard output with fields 5 and 6 from `filter.tsv` appended. This is a form of inner-join. Outer-joins and anti-joins can also be done.

Common uses for `tsv-join` are to join related datasets or to filter one dataset based on another. Filter file entries are kept in memory, this limits the ultimate size that can be handled effectively. The author has found that filter files up to about 10 million lines are processed effectively, but performance starts to degrade after that.

See the [tsv-join reference](docs/ToolReference.md#tsv-join-reference) for details.

### tsv-uniq

Similar in spirit to the Unix `uniq` tool, `tsv-uniq` filters a dataset so there is only one copy of each unique line. `tsv-uniq` goes beyond Unix `uniq` in a couple ways. First, data does not need to be sorted. Second, equivalence can be based on a subset of fields rather than the full line.

`tsv-uniq` can also be run in 'equivalence class identification' mode, where lines with equivalent keys are marked with a unique id rather than filtered out. Another variant is 'number' mode, which generates lines numbers grouped by the key.

An example uniq'ing a file on fields 2 and 3:
```
$ tsv-uniq -f 2,3 data.tsv
```

`tsv-uniq` operates on the entire line when no fields are specified. This is a useful alternative to the traditional `sort -u` or `sort | uniq` paradigms for identifying unique lines in unsorted files, as it is quite a bit faster.

As with `tsv-join`, this uses an in-memory lookup table to record unique entries. This ultimately limits the data sizes that can be processed. The author has found that datasets with up to about 10 million unique entries work fine, but performance degrades after that.

See the [tsv-uniq reference](docs/ToolReference.md#tsv-uniq-reference) for details.

### csv2tsv

`csv2tsv` does what you expect: convert CSV data to TSV. Example:
```
$ csv2tsv data.csv > data.tsv
```

A strict delimited format like TSV has many advantages for data processing over an escape oriented format like CSV. However, CSV is a very popular data interchange format and the default export format for many database and spreadsheet programs. Converting CSV files to TSV allows them to be processed reliably by both this toolkit and standard Unix utilities like `awk` and `sort`.

Note that many CSV files do not use escapes, and in-fact follow a strict delimited format using comma as the delimiter. Such files can be processed reliably by this toolkit and Unix tools by specifying the delimiter character. However, when there is doubt, using a `csv2tsv` converter adds reliability.

The `csv2tsv` converter often has a second benefit: regularizing newlines. CSV files are often exported using Windows newline conventions. `csv2tsv` converts all newlines to Unix format.

There are many variations of CSV file format. See the [csv2tsv reference](docs/ToolReference.md#csv2tsv-reference) for details the format variations supported by this tool.

### tsv-append

`tsv-append` concatenates multiple TSV files, similar to the Unix `cat` utility. It is header-aware, writing the header from only the first file. It also supports source tracking, adding a column indicating the original file to each row.

Concatenation with header support is useful when preparing data for traditional Unix utilities like `sort` and `sed` or applications that read a single file.

Source tracking is useful when creating long/narrow form tabular data. This format is used by many statistics and data mining packages. (See [Wide & Long Data - Stanford University](https://stanford.edu/~ejdemyr/r-tutorials/wide-and-long/) or Hadley Wickham's [Tidy data](http://vita.had.co.nz/papers/tidy-data.html) for more info.)

In this scenario, files have been used to capture related data sets, the difference between data sets being a condition represented by the file. For example, results from different variants of an experiment might each be recorded in their own files. Retaining the source file as an output column preserves the condition represented by the file. The source values default to the file names, but this can be customized.

See the [tsv-append reference](docs/ToolReference.md#tsv-append-reference) for the complete list of options available.

### number-lines

A simpler version of the Unix `nl` program. It prepends a line number to each line read from files or standard input. This tool was written primarily as an example of a simple command line tool. The code structure it uses is the same as followed by all the other tools. Example:
```
$ number-lines myfile.txt
```

Despite it's original purpose as a code sample, `number-lines` turns out to be quite convenient. It is often useful to add a unique row ID to a file, and this tool does this in a manner that maintains proper TSV formatting.

See the [number-lines reference](docs/ToolReference.md#number-lines-reference) for details.

### keep-header

A convenience utility that runs unix commands in a header-aware fashion. It is especially useful with `sort`, which puts the header line wherever it falls in the sort order. Using `keep-header`, the header line retains its position as the first line. For example:
```
$ keep-header myfile.txt -- sort
```

It is also useful with `grep`, `awk`, `sed`, similar tools, when the header line should be excluded from the command's action.

Multiple files can be provided, only the header from the first is retained. The command is executed as specified, so additional command options can be provided. See the [keep-header reference](docs/ToolReference.md#keep-header-reference) for more information.

---

## Obtaining and installation

There are several ways to obtain the tools: [prebuilt binaries](#prebuilt-binaries); [building from source code](#build-from-source-files); and [installing using the DUB package manager](#install-using-dub). The tools have been tested on Linux and Mac OS X. They have not been tested on Windows, but there are no obvious impediments to running on Windows as well.

### Prebuilt binaries

Prebuilt binaries are available for Linux and Mac, these can be found on the [Github releases](https://github.com/eBay/tsv-utils/releases) page. Download and unpack the tar.gz file. Executables are in the `bin` directory. Add the `bin` directory or individual tools to the `PATH` environment variable. As an example, the 1.4.2 releases for Linux and MacOS can be downloaded and unpacked with these commands:
```
$ curl -L https://github.com/eBay/tsv-utils/releases/download/v1.4.2/tsv-utils-v1.4.2_linux-x86_64_ldc2.tar.gz | tar xz
$ curl -L https://github.com/eBay/tsv-utils/releases/download/v1.4.2/tsv-utils-v1.4.2_osx-x86_64_ldc2.tar.gz | tar xz
```

See the [Github releases](https://github.com/eBay/tsv-utils/releases) page for the latest release.

For some distributions a package can directly be installed:

| Distribution | Command               |
| ------------ | --------------------- |
| Arch Linux   | `pacaur -S tsv-utils` (see [`tsv-utils`](https://aur.archlinux.org/packages/tsv-utils/))

*Note: The distributions above are not updated as frequently as the [Github releases](https://github.com/eBay/tsv-utils/releases) page.*

### Build from source files

[Download a D compiler](https://dlang.org/download.html). These tools have been tested with the DMD and LDC compilers, on Mac OSX and Linux. Use DMD version 2.076.1 or later, LDC version 1.6.0 or later.

Clone this repository, select a compiler, and run `make` from the top level directory:
```
$ git clone https://github.com/eBay/tsv-utils.git
$ cd tsv-utils
$ make         # For LDC: make DCOMPILER=ldc2
```

Executables are written to `tsv-utils/bin`, place this directory or the executables in the PATH. The compiler defaults to DMD, this can be changed on the make command line (e.g. `make DCOMPILER=ldc2`). DMD is the reference compiler, but LDC produces faster executables. (For some tools LDC is quite a bit faster than DMD.)

The makefile supports other typical development tasks such as unit tests and code coverage reports. See [Building and makefile](docs/AboutTheCode.md#building-and-makefile) for more details.

For fastest performance, use LDC with Link Time Optimization (LTO) and Profile Guided Optimization (PGO) enabled:
```
$ git clone https://github.com/eBay/tsv-utils.git
$ cd tsv-utils
$ make DCOMPILER=ldc2 LDC_LTO_RUNTIME=1 LDC_PGO=2
$ # Run the test suite
$ make test-nobuild DCOMPILER=ldc2
```

The above requires LDC 1.9.0 or later. See [Building with Link Time Optimization](docs/BuildingWithLTO.md) for more information. The prebuilt binaries are built using LTO and PGO, but these must be explicitly enabled when building from source. LTO and PGO are still early stage technologies, issues may surface in some system configurations. Running the test suite (shown above) is a good way to detect issues that may arise.

### Install using DUB

If you are a D user you likely use DUB, the D package manager. DUB comes packaged with DMD starting with DMD 2.072. You can install and build using DUB as follows (replace `1.3.2` with the current version):
```
$ dub fetch tsv-utils --cache=local
$ cd tsv-utils-1.3.2/tsv-utils
$ dub run    # For LDC: dub run -- --compiler=ldc2
```

The `dub run` command compiles all the tools. The executables are written to `tsv-utils/bin`. Add this directory or individual executables to the PATH.

See [Building and makefile](docs/AboutTheCode.md#building-and-makefile) for more information about the DUB setup.

The applications can be built with LTO and PGO when source code is fetched by DUB. However, the DUB build system does not support this. `make` must be used instead. See [Building with Link Time Optimization](docs/BuildingWithLTO.md).

### Setup customization

There are a number of simple ways to ways to improve the utility of these tools, these are listed on the [Tips and tricks](docs/TipsAndTricks.md) page. [Bash aliases](docs/TipsAndTricks.md#useful-bash-aliases), [Unix sort command customization](docs/TipsAndTricks.md#customize-the-unix-sort-command), and [bash completion](docs/TipsAndTricks.md#enable-bash-completion) are especially useful.
