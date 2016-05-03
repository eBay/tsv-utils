# Command line TSV Utilities in D

This is a set of command line utilities for working with tab-separated value files. They were originally developed in Perl and used for day-to-day work in a large scale data mining environment. One of the tools was re-written in D as an exercise exploring the language. Significant performance gains and agreeable programmer characteristics soon led to writing the other utilities D as well.

The tools have been made available in the hope they will benefit others needing similar tools or who are considering D as a programming language.

Information on the D programming language is available at: http://dlang.org/.

**Contents:**
* [The tools](#the-tools)
* [Installation](#installation)
* [The code](#the-code)
* [Performance](#performance)
* [Tool reference](#tool-reference)

## The tools

These tools were developed for working with reasonably large data files. Perhaps larger than ideal for direct use in an application like R, but not so big as to necessitate moving to Hadoop or similar distributed compute environments. They work like traditional Unix command line utilities such as `cut`, `sort`, `grep`, etc., and are intended to complement these tools. Each tool is a standalone executable. They follow common Unix conventions for pipeline programs. Data is read from files or standard input, results are written to standard output. Documentation is available for each tool by invoking it with the `--help` option. If reading the code, look for the `helpText` variable near the top of the file.

A short description of each tool follows. There is more detail in the [tool reference](#tool-reference) section later in this file.

* [tsv-filter](#tsv-filter)
* [tsv-join](#tsv-join)
* [tsv-uniq](#tsv-uniq)
* [tsv-select](#tsv-select)
* [csv2tsv](#csv2tsv)
* [number-lines](#number-lines)
* [Useful bash aliases](#useful-bash-aliases)
* [Other toolkits](#other-toolkits)

### tsv-filter

Outputs select lines by making numeric and string comparisons against individual fields. Multiple comparisons can be specified in a single call. A variety of numeric and string comparison operators are available as well as regular expressions. Example:
```
$ tsv-filter --ge 3:100 --le 3:200 --str-eq 4:red file.tsv
```

This outputs lines where field 3 satisfies (100 <= fieldval <= 200) and field 4 matches 'red'.

`tsv-filter` is the most widely applicable of the tools, as dataset pruning is a common task. Because it's stream oriented, it can handle arbitrarily large files. It is also be convenient for quickly answering simple questions about a dataset. For example, to count the number of records with a non-zero value in field 3, use the command:
```
$ tsv-filter --ne 3:0 file.tsv | wc -l
```

### tsv-join

Joins lines from multiple files based on a common key. One file, the 'filter' file, contains the records (lines) being matched. The other input files are scanned for matching records. Matching records are written to standard output, along with any designated fields from the filter file. In database parlance this is a hash semi-join. Example:
```
$ tsv-join --filter-file filter.tsv --key-fields 1,3 --append-fields 5,6 data.tsv
```

This reads `filter.tsv`, creating a lookup table keyed on fields 1 and 3. `data.tsv` is read, lines with a matching key are written to standard output with fields 5 and 6 from `filter.tsv` appended. This is a form of inner-join. Outer-joins and anti-joins can also be done.

Common uses for `tsv-join` are to join related datasets or to filter one dataset based on another. Filter file entries are kept in memory, this limits the ultimate size that can be handled effectively. The author has found that filter files up to about 10 million lines are processed effectively, but performance starts to degrade after that.

### tsv-uniq

Similar in spirit to the Unix `uniq` tool, `tsv-uniq` filters a dataset so there is only one copy of each line. `tsv-uniq` goes beyond Unix `uniq` in a couple ways. First, data does not need to be sorted. Second, equivalence is based on a subset of fields rather than the full line. `tsv-uniq` can also be run in an 'equivalence class identification' mode, where equivalent entries are marked with a unique id rather than being filtered. An example uniq'ing a file on fields 2 and 3:
```
$ tsv-uniq -f 2,3 data.tsv
```

`tsv-uniq` operates on the entire line when no fields are specified. This is a useful alternative to the traditional `sort -u` or `sort | uniq` paradigms for identifying unique lines in unsorted files, as it is often quite a bit faster.

As with `tsv-join`, this uses an in-memory lookup table to record unique entries. This ultimately limits the data sizes that can be processed. The author has found that datasets with up to about 10 million unique entries work fine, but performance degrades after that.

### tsv-select

A version of the Unix `cut` utility with the additional ability to re-order the fields. The following command writes fields [4, 2, 9] from a pair of files to stdout:
```
$ tsv-select -f 4,2,9 file1.tsv file2.tsv
```

Reordering fields is a useful enhancement over `cut`. However, much of the motivation for writing it was to explore the D programming language and provide a comparison point against other common approaches to this task. Code for `tsv-select` is bit more liberal with comments pointing out D programming constructs than code for the other tools.

### csv2tsv

Sometimes you have a CSV file. This program does what you expect: convert CSV data to TSV. Example:
```
$ csv2tsv data.csv > data.tsv
```

See the [csv2tsv reference](#csv2tsv-program) section for details.

### number-lines

A simpler version of the Unix 'nl' program. It prepends a line number to each line read from files or standard input. This tool was written primarily as an example of a simple command line tool. The code structure it uses is the same as followed by all the other tools. Example:
```
$ number-lines myfile.txt
```

### Useful bash aliases

Any number of convenient utilities can be created using shell facilities. A couple are given below. One of the most useful is `tsv-header`, which shows the field number for each column name in the header. Very useful when using numeric field indexes.

* `tsv-header <file>` - Outputs the column numbers and fields names for the file header (first line).
* `tsv-sort [options] [file...]` - Runs sort, but with field separator set to TAB. Convenient when sorting on specific fields.

If you using a bash shell, add the definitions below to `.bashrc` or another init file. Similar aliases can be created for shells other than bash.
```
tsv-header () { head -n 1 $* | tr $'\t' '\n' | nl ; }
tsv-sort () { sort -t $'\t' $* ; }
```

### Other toolkits

There are a number of toolkits with similar functionality. Here are a few:

* [csvkit](https://github.com/wireservice/csvkit) - CSV tools, written in Python.
* [csvtk](https://github.com/shenwei356/csvtk) - CSV tools, written in Go.
* [dplyr](https://github.com/hadley/dplyr) - Tools for tabular data in R storage formats. Written in R and C++.
* [miller](https://github.com/johnkerl/miller) - CSV and JSON tools, written in C.
* [tsvutils](https://github.com/brendano/tsvutils) - TSV tools, especially rich in format converters. Written in Python.
* [xsv](https://github.com/BurntSushi/xsv) - CSV tools, written in Rust.

## Installation

Download a D compiler (http://dlang.org/download.html). These tools have been tested with the DMD and LDC compilers, on Mac OSX and Linux. Use DMD version 2.068 or later, LDC version 0.17.0 or later.

Clone this repository, select a compiler, and run `make` from the top level directory:
```
$ git clone https://github.com/eBay/tsv-utils-dlang.git
$ cd tsv-utils-dlang
$ make
```

Executables are written to `tsv-utils-dlang/bin`, place this directory or the executables in the PATH. The compiler defaults to DMD, this can be changed on the make command line (e.g. `make DCOMPILER=ldc2`). LDC is a common choice as it generates fast code. See [BUILD_COMMANDS](BUILD_COMMANDS.md) for alternate build steps if `make` is not available on your system.

### Install using DUB

If you are already a D user you likely use DUB, the D package manager. You can install and build using DUB as follows:
```
$ dub fetch tsv-utils-dlang
$ dub run tsv-utils-dlang
```

The `dub run` commands compiles all the tools. Use a command like `dub run tsv-utils-dlang -- --compiler=ldc2` to use a different compiler. The executables are written to a DUB package repository directory. For example: `~/.dub/packages/tsv-utils-dlang-1.0.2/bin`. Add the executables to the PATH. As an alternative, clone the repository and run as follows:
```
$ git clone https://github.com/eBay/tsv-utils-dlang.git
$ dub add-local tsv-utils-dlang
$ cd tsv-utils-dlang
$ dub run
```

See the [Building and makefile](#building-and-makefile) section for more information.

## The code

In this section:
* [Code structure](#code-structure)
* [Coding philosophy](#coding-philosophy)
* [Building and makefile](#building-and-makefile)
* [Unit tests](#unit-tests)

### Code structure

There is directory for each tool, plus one directory for shared code (`common`). The tools all have a similar structure. Code is typically in one file, e.g. `tsv-uniq.d`. Functionality is broken into three pieces:

* A class managing command line options. e.g. `tsvUniqOptions`.
* A function reading reading input and processing each line. e.g. `tsvUniq`.
* A `main` routine putting it all together.

Documentation for each tool is found near the top of the main file, both in the help text and the option documentation.

The simplest tool is `number-lines`. It is useful as an illustration of the code outline followed by the other tools.  `tsv-select` and `tsv-uniq` also have straightforward functionality, but employ a few more D programming concepts. `tsv-select` uses templates and compile-time programming in a somewhat less common way, it may be clearer after gaining some familiarity with D templates. A non-templatized version of the source code is included for comparison. 

`tsv-join` and `tsv-filter` also have relatively straightforward functionality, but support more use cases resulting in more code. `tsv-filter` in particular has more elaborate setup steps that take a bit more time to understand. `tsv-filter` uses several features like delegates (closures) and regular expressions not used in the other tools.

The `common` directory has code shared by the tools. At present this very limited, one helper class written as template. In addition to being an example of a simple template, it also makes use of a D ranges, a very useful sequence abstraction, and built-in unit tests.

New tools can be added by creating a new directory and a source tree following the same pattern as one of existing tools.

### Coding philosophy

The tools were written in part to explore D for use in a data science environment. Value provided may be more as a starting point for similar tools than from the specific features provided. Data mining environments have custom data and application needs. This leads to custom tools, which in turn raises the productivity vs execution speed question. This trade-off is exemplified by interpreted languages like Python on the one hand and system languages like C/C++ on the other. The D programming language occupies an interesting point on this spectrum. D's programmer experience is somewhere in the middle ground between interpreted languages and C/C++, but run-time performance is closer to C/C++. Execution speed is a very practical consideration in data mining environments: it increases dataset sizes that can handled on the researcher's personal machine. There is additional value in having data science practitioners program these tools quickly, themselves, without needing to invest time in low-level programming.

These tools were implemented with these trade-offs in mind. The code was deliberately kept at a reasonably high level. The obvious built-in facilities were used, notably the standard library. A certain amount of performance optimization was done to explore this dimension of D programming, but low-level optimizations were generally avoided. Indeed, there are options likely to improve performance, notably:

* Custom I/O buffer management, including reading entire files into memory.
* Custom hash tables rather than built-in associative arrays.
* Avoiding garbage collection

A useful aspect of D is that is additional optimization can be made as the need arises. Coding of these tools did utilize a several optimizations that might not have been done in an initial effort. These include:

* The helper class in the `common` directory. This is an optimization for processing only the first N fields needed to for the particular invocation of the tool.
* The template expansion done in `tsv-select`.
* Reusing arrays every input line, without re-allocating. Some programmers would do this naturally on the first attempt, for others it would be a second pass optimization.

### Building and makefile

#### Make setup

The makefile setup is very simplistic. It works reasonably in this case because the tools are small and have a very simple code structure, but it is not a setup that will scale to more complex programs. `make` can be run from the top level directory or from the individual tool directories. Available commands:

* `make release` (default) - This builds the tools in release mode. Executables go in the bin directory.
* `make debug` - Makes debug versions of the tools (with a `.dbg` extension).
* `make clean` - Deletes executables and intermediate files.
* `make test` - Makes debug versions of the tools and runs all tests.
* `make test-release` - Makes release versions of the tools and runs all tests.
* `make test-nobuild` - Runs tests against the current app builds. This is useful when using DUB to build.

Builds can be customized by changing the settings in `makedefs.mk`. The most basic customization is the compiler choice, this controlled by the `DCOMPILER` variable.

#### DUB package setup

A parallel build setup was created using DUB packages. This was done to better align with the D ecosystem. However, at present DUB does not have first class support for multiple executables, and this setup pushes the boundaries of what works smoothly. That said, the setup appears to work well. One specific functionality not supported are the test capabilities. However, after building with DUB tests can be run using the makefile setup. Here's an example:
```
$ cd tsv-utils-dlang
$ dub run
$ dub test tsv-utils-dlang:common
$ make test-nobuild
```

### Unit tests

D has an excellent facility for adding unit tests right with the code. The `common` utility functions in this package take advantage of built-in unit tests. However, most of the command line executables do not, and instead use more traditional invocation of the command line executables and diffs the output against a "gold" result set. The exception is `csv2tsv`, which uses both built-in unit tests and tests against the executable. The built-in unit tests are much nicer, and also the advantage of being naturally cross-platform. The command line executable tests assume a Unix shell.

Tests for the command line executables are in the `tests` directory of each tool. Overall the tests cover a fair number of cases and are quite useful checks when modifying the code. They may also be helpful as an examples of command line tool invocations. See the `tests.sh` file in each `test` directory, and the `test` makefile target in `makeapp.mk`.

The unit test built into the common code (`common/src/tsvutil.d`) illustrates a useful interaction with templates: it is quite easy and natural to unit test template instantiations that might not occur naturally in the application being written along with the template.

## Performance

Performance is a key motivation for writing tools like this in D rather an interpreted language like Python or Perl. It is also a consideration in choosing between D and C/C++.

The tools created don't by themselves enable proper benchmark comparison. Equivalent tools written in the other languages would be needed for that. Still, there were a couple benchmarks that could be done to get a high level view of performance. These are given in this section.

Overall the D programs did well. Not as fast as a highly optimized C/C++ program, but meaningfully better than Python and Perl. Perl in particular fared quite poorly in these comparisons.

Perhaps the most surprising result is the poor performance of the utilities shipped with the Mac (`cut`, etc). It's worth installing the latest GNU coreutils versions if you are running on a Mac. (MacPorts and Homebrew are popular package managers that can install GNU tools.)

### tsv-select performance

`tsv-select` is a variation on Unix `cut`, so `cut` is a reasonable comparison. Another popular option for this task is `awk`, which can be used to reorder fields. Simple versions of `cut` can be written easily in Python and Perl, which is what was done for these tests. (Code is in the `benchmarks` directory.) Timings were run on both a Macbook Pro (2.8 GHz Intel I7, 16GB ram, flash storage) and a Linux server (Ubuntu, Intel Xeon, 6 cores). They were run against a 2.5GB TSV file with 78 million lines, 11 fields per line. Most fields contained numeric data. These runs use `cut -f 1,4,7` or the equivalent. Each program was run several times and the best time recorded.

**Macbook Pro (2.8 GHz Intel I7, 16GB ram, flash storage); File: 78M lines, 11 fields, 2.5GB**:

| Tool                   | version        | time (seconds) |
| ---------------------- |--------------- | -------------: |
| cut (GNU)              | 8.25           |           17.4 |
| tsv-select (D)         | ldc 1.0        |           31.4 |
| mawk (M. Brennan Awk)  | 1.3.4 20150503 |           51.1 |
| cut (Mac built-in)     |                |           81.8 |
| gawk (GNU awk)         | 4.1.3          |           97.4 |
| python                 | 2.7.10         |          144.1 |
| perl                   | 5.22.1         |          231.3 |
| awk (Mac built-in)     | 20070501       |          247.3 |

**Linux server (Ubuntu, Intel Xeon, 6 cores); File: 78M lines, 11 fields, 2.5GB**:

| Tool                   | version        | time (seconds) |
| ---------------------- | -------------- | -------------: |
| cut (GNU)              | 8.25           |           19.8 |
| tsv-select (D)         | ldc 1.0        |           29.7 |
| mawk (M. Brennan Awk)  | 1.3.3 Nov 1996 |           51.3 |
| gawk (GNU awk)         | 3.1.8          |          128.1 |
| python                 | 2.7.3          |          179.4 |
| perl                   | 5.14.2         |          665.0 |

GNU `cut` is best viewed as baseline for a well optimized program, rather than a C/C++ vs D comparison point. D's performance for this tool seems quite reasonable. The D version also handily beat the version of `cut` shipped with the Mac, also a C program, but clearly not as well optimized. 

### tsv-filter performance

`tsv-filter` can be compared to Awk, and the author already had a perl version of tsv-filter. These measurements were run against four Google ngram files. 256 million lines, 4 fields, 5GB. Same compute boxes as for the tsv-select tests. The tsv-filter and awk/gawk/mawk invocations:

```
$ cat <ngram-files> | tsv-filter --ge 4:50 > /dev/null
$ cat <ngram-files> | awk  -F'\t' '{ if ($4 >= 50) print $0 }' > /dev/null
```

Each line in the file has statistics for an ngram in a single year. The above commands return all lines where the ngram-year pair occurs in more than 50 books.

**Macbook Pro (2.8 GHz Intel I7, 16GB ram, flash storage); File: 256M lines, 4 fields, 4GB**:

| Tool                   | version        | time (seconds) |
| ---------------------- | -------------- | -------------: |
| tsv-filter (D)         | ldc 1.0        |           33.5 |
| mawk (M. Brennan Awk)  | 1.3.4 20150503 |           52.0 |
| gawk (GNU awk)         | 4.1.3          |          103.4 |
| awk (Mac built-in)     | 20070501       |          314.2 |
| tsv-filter (Perl)      |                |         1075.6 |

**Linux server (Ubuntu, Intel Xeon, 6 cores); File: 256M lines, 4 fields, 4GB**:

| Tool                    | version        | time (seconds) |
| ----------------------- | -------------- | -------------: |
| tsv-filter (D)          | ldc 1.0        |           34.2 |
| mawk  (M. Brennan Awk)  | 1.3.3 Nov 1996 |           72.9 |
| gawk (GNU awk)          | 3.1.8          |          215.4 |
| tsv-filter (Perl)       | 5.14.2         |         1255.2 |

### Relative performance of the tools

Runs against a 4.5 million line, 279 MB file were used to get a relative comparision of the tools. The original file was a CSV file, allowing inclusion of `csv2tsv`. The TSV file generated was used in the other runs. Running time of routines filtering data is dependent on the amount output, so a different output sizes were used. `tsv-join` depends on the size of the filter file, a file the same size as the output was used in these tests. Performance of these tools also depends on the options selected, so actuals will vary.

**Macbook Pro (2.8 GHz Intel I7, 16GB ram, flash storage); File: 4.46M lines, 8 fields, 279MB**:
| Tool         | Records output | Time (seconds) |
| ------------ | -------------: |--------------: |
| tsv-filter   |         513788 |           0.76 |
| cut (GNU)    |        4465613 |           1.16 |
| number-lines |        4465613 |           1.21 |
| tsv-filter   |        4125057 |           1.25 |
| tsv-uniq     |          65537 |           1.56 |
| tsv-join     |          65537 |           1.61 |
| tsv-select   |        4465613 |           1.81 |
| tsv-uniq     |        4465613 |           4.34 |
| csv2tsv      |        4465613 |           6.49 |
| tsv-join     |        4465613 |           7.51 |

Performace of `tsv-filter` looks especially good, even when outputing a lorge number of records. It's not far off the GNU `cut`. `tsv-join` and `tsv-uniq` are fast, but show an impact when larger hash tables are needed (4.5M entries cases in the slower cases). `csv2tsv` is a bit slower than the other tools for reasons that are not clear. It has a relatively different structure than the other tools.

## Tool reference

This section provides more detailed documentation about the different tools as well as examples. Material for the individual tools is also available via the `--help` option.

* [Common options and behavior](#common-options-and-behavior)
* [tsv-filter reference](#tsv-filter-reference)
* [tsv-join reference](#tsv-join-reference)
* [tsv-uniq reference](#tsv-uniq-reference)
* [tsv-select reference](#tsv-select-reference)
* [csv2tsv reference](#csv2tsv-reference)
* [number-lines reference](#number-lines-reference)

### Common options and behavior

Information in this section applies to all the tools.

#### Specifying options

Multi-letter options are specified with a double dash. Single letter options can be specified with a single dash or double dash. For example:

```
$ tsv-uniq -h      # Valid
$ tsv-uniq --h     # Valid
$ tsv-uniq --help  # Valid
$ tsv-uniq -help   # Invalid.
```

#### Help (-h, --help, --help-brief)

All tools print help if given the `-h` or `--help` option. Several tools provide a brief form of help with the `--help-brief` option.

#### Field indices

Field indices are one-upped integers, following Unix conventions. Some tools use zero to represent the entire line (`tsv-join`, `tsv-uniq`).

#### UTF-8 input

These tools assume data is utf-8 encoded.

#### File format and alternate delimiters (-d, --delimiter)

Any character can be used as a delimiter, TAB is the default. However, there is no escaping for including the delimiter character or newlines within a field. This differs from CSV file format which provides an escaping mechanism. In practice the lack of an escaping mechanism is not a meaningful limitation for data oriented files.

Aside from a header line, all lines are expected to have data. There is no comment mechanism and no special handling for blank lines. Tools taking field indices as arguments expect the specified fields to be available on every line.

#### Headers (--header)

Most tools handle the first line of files as a header when given the `--header` option. For example, `tsv-filter` passes the header through without filtering it. When `--header` is used, all files and stdin are assumed to have header lines. Only one header line is written to stdout. If multiple files are being processed, header lines from subsequent files are discarded.

#### Multiple files and standard input

Tools can read from any number of files and from standard input. As per typical Unix behavior, a single dash represents standard input when included in a list of files. Terminate non-file arguments with a double dash (--) when using a single dash in this fashion. Example:
```
$ head -n 1000 file-c.tsv | tsv-filter --eq 2:1000 -- file-a.tsv file-b.tsv - > out.tsv
```

The above passes `file-a.tsv`, `file-b.tsv`, and the first 1000 lines of `file-c.tsv` to `tsv-filter` and write the results to `out.tsv`.

### tsv-filter reference

**Synopsis:** tsv-filter [options] [file...]

Filter lines of tab-delimited files via comparison tests against fields. Multiple tests can be specified, by default they are evaluated as AND clause. Lines satisfying the tests are written to standard output.

**General options:**
* `--help` - Print help.
* `--help-brief` - Print brief help (option summary).
* `--header` - Treat the first line of each file as a header.
* `--d|delimiter CHR` - Field delimiter. Default: TAB. (Single byte UTF-8 characters only.)
* `--or` - Evaluate tests as an OR rather than an AND. This applies globally.
* `--v|invert` - Invert the filter, printing lines that do not match. This applies globally.

**Tests:**

Empty and blank field tests:
* `--empty FIELD` - True if field is empty (no characters)
* `--not-empty FIELD` - True if field is not empty.
* `--blank FIELD` - True if field is empty or all whitespace.
* `--not-blank FIELD` - True if field contains a non-whitespace character.

Numeric comparisons:
* `--le FIELD:NUM` - FIELD <= NUM (numeric).
* `--lt FIELD:NUM` - FIELD <  NUM (numeric).
* `--ge FIELD:NUM` - FIELD >= NUM (numeric).
* `--gt FIELD:NUM` - FIELD >  NUM (numeric).
* `--eq FIELD:NUM` - FIELD == NUM (numeric).
* `--ne FIELD:NUM` - FIELD != NUM (numeric).

String comparisons:
* `--str-le FIELD:STR` - FIELD <= STR (string).
* `--str-lt FIELD:STR` - FIELD <  STR (string).
* `--str-ge FIELD:STR` - FIELD >= STR (string).
* `--str-gt FIELD:STR` - FIELD >  STR (string).
* `--str-eq FIELD:STR` - FIELD == STR (string).
* `--istr-eq FIELD:STR` - FIELD == STR (string, case-insensitive).
* `--str-ne FIELD:STR` - FIELD != STR (string).
* `--istr-ne FIELD:STR` - FIELD != STR (string, case-insensitive).
* `--str-in-fld FIELD:STR` - FIELD contains STR (substring search).
* `--istr-in-fld FIELD:STR` - FIELD contains STR (substring search, case-insensitive).
* `--str-not-in-fld FIELD:STR` - FIELD does not contain STR (substring search).
* `--istr-not-in-fld FIELD:STR` - FIELD does not contain STR (substring search, case-insensitive).

Regular expression tests:
* `--regex FIELD:REGEX` - FIELD matches regular expression.
* `--iregex FIELD:REGEX` - FIELD matches regular expression, case-insensitive.
* `--not-regex FIELD:REGEX` - FIELD does not match regular expression.
* `--not-iregex FIELD:REGEX` - FIELD does not match regular expression, case-insensitive.

Field to field comparisons:
* `--ff-le FIELD1:FIELD2` - FIELD1 <= FIELD2 (numeric).
* `--ff-lt FIELD1:FIELD2` - FIELD1 <  FIELD2 (numeric).
* `--ff-ge FIELD1:FIELD2` - FIELD1 >= FIELD2 (numeric).
* `--ff-gt FIELD1:FIELD2` - FIELD1 >  FIELD2 (numeric).
* `--ff-eq FIELD1:FIELD2` - FIELD1 == FIELD2 (numeric).
* `--ff-ne FIELD1:FIELD2` - FIELD1 != FIELD2 (numeric).
* `--ff-str-eq FIELD1:FIELD2` - FIELD1 == FIELD2 (string).
* `--ff-istr-eq FIELD1:FIELD2` - FIELD1 == FIELD2 (string, case-insensitive).
* `--ff-str-ne FIELD1:FIELD2` - FIELD1 != FIELD2 (string).
* `--ff-istr-ne FIELD1:FIELD2` - FIELD1 != FIELD2 (string, case-insensitive).
* `--ff-absdiff-le FIELD1:FIELD2:NUM` - abs(FIELD1 - FIELD2) <= NUM
* `--ff-absdiff-gt FIELD1:FIELD2:NUM` - abs(FIELD1 - FIELD2)  > NUM
* `--ff-reldiff-le FIELD1:FIELD2:NUM` - abs(FIELD1 - FIELD2) / min(abs(FIELD1), abs(FIELD2)) <= NUM
* `--ff-reldiff-gt FIELD1:FIELD2:NUM` - abs(FIELD1 - FIELD2) / min(abs(FIELD1), abs(FIELD2))  > NUM

**Examples:**

Basic comparisons:
```
$ # Field 2 non-zero
$ tsv-filter --ne 2:0 data.tsv

$ # Field 1 == 0 and Field 2 >= 100, first line is a header.
$ tsv-filter --header --eq 1:0 --ge 2:100 data.tsv

$ # Field 1 == -1 or Field 1 > 100
$ tsv-filter --or --eq 1:-1 --gt 1:100

$ # Field 3 is foo, Field 4 contains bar
$ tsv-filter --header --str-eq 3:foo --str-in-fld 4:bar data.tsv

$ # Field 3 == field 4 (numeric test)
$ tsv-filter --header --ff-eq 3:4 data.tsv
```

Regular expressions:

Official regular expression syntax defined by D (<http://dlang.org/phobos/std_regex.html>), however, basic syntax is rather standard, and forms commonly used with other tools usually work as expected. This includes unicode character classes.

```
$ # Field 2 has a sequence with two a's, one or more digits, then 2 a's.
$ tsv-filter --regex '2:aa[0-9]+aa' data.tsv

$ # Same thing, except the field starts and ends with the two a's.
$ tsv-filter --regex '2:^aa[0-9]+aa$' data.tsv

$ # Field 2 is a sequence of "word" characters with two or more embedded whitespace sequences
$ tsv-filter --regex '2:^\w+\s+(\w+\s+)+\w+$' data.tsv

$ # Field 2 containing at least one cyrillic character.
$ tsv-filter --regex '2:\p{Cyrillic}' data.tsv
```

### tsv-join reference

**Synopsis:** tsv-join --filter-file file [options] file [file...]

tsv-join matches input lines against lines from a 'filter' file. The match is based on exact match comparison of one or more 'key' fields. Fields are TAB delimited by default. Matching lines are written to standard output, along with any additional fields from the key file that have been specified.

**Options:**
* `--f|filter-file FILE` - (Required) File with records to use as a filter.
* `--k|key-fields n[,n...]` - Fields to use as join key. Default: 0 (entire line).
* `--d|data-fields n[,n...]` - Data record fields to use as join key, if different than --key-fields.
* `--a|append-fields n[,n...]` - Filter fields to append to matched records.
* `--header` - Treat the first line of each file as a header.
* `--p|prefix STR` - String to use as a prefix for --append-fields when writing a header line.
* `--w|write-all STR` - Output all data records. STR is the --append-fields value when writing unmatched records. This is an outer join.
* `--e|exclude` - Exclude matching records. This is an anti-join.
* `-d|delimiter CHR` - Field delimiter. Default: TAB. (Single byte UTF-8 characters only.)
* `--z|allow-duplicate-keys` - Allow duplicate keys with different append values (last entry wins). Default behavior is that this is an error.
* `--h|help` - Print help.
* `--h|help-brief` - Print brief help.

**Examples:**

Filter one file based on another, using the full line as the key.
```
$ # Output lines in data.txt that appear in filter.txt
$ tsv-join -f filter.txt data.txt

$ # Output lines in data.txt that do not appear in filter.txt
$ tsv-join -f filter.txt --exclude data.txt
```

Filter multiple files, using fields 2 & 3 as the filter key.
```
$ tsv-join -f filter.tsv --key-fields 2,3 data1.tsv data2.tsv data3.tsv
```

Same as previous, except use field 4 & 5 from the data files.
```
$ tsv-join -f filter.tsv --key-fields 2,3 --data-fields 4,5 data1.tsv data2.tsv data3.tsv
```

Append a field from the filter file to matched records.
```
$ tsv-join -f filter.tsv --key-fields 1 --append-fields 2 data.tsv
```

Write out all records from the data file, but when there is no match, write the 'append fields' as NULL. This is an outer join.
```
$ tsv-join -f filter.tsv --key-fields 1 --append-fields 2 --write-all NULL data.tsv
```

Managing headers: Often it's useful to join a field from one data file to anther, where the data fields are related and the headers have the same name in both files. They can be kept distinct by adding a prefix to the filter file header. Example:
```
$ tsv-join -f run1.tsv --header --key-fields 1 --append-fields 2 --prefix run1_ run2.tsv
```

### tsv-uniq reference

tsv-uniq identifies equivalent lines in tab-separated value files. Input is read line by line, recording a key based on one or more of the fields. Two lines are equivalent if they have the same key. When operating in 'uniq' mode, the first time a key is seen the line is written to standard output, but subsequent lines are discarded. This is similar to the Unix 'uniq' program, but based on individual fields and without requiring sorted data.

The alternate to 'uniq' mode is 'equiv-class' identification. In this mode, all lines are written to standard output, but with a new field added marking equivalent entries with an ID. The ID is simply a one-upped counter.

**Synopsis:** tsv-uniq [options] [file...]

**Options:**
* `--header` - Treat the first line of each file as a header.
* `--f|fields n[,n...]` - Fields to use as the key. Default: 0 (entire line).
* `--i|ignore-case` - Ignore case when comparing keys.
* `--e|equiv` - Output equiv class IDs rather than uniq'ing entries.
* `--equiv-header STR` - Use STR as the equiv-id field header. Applies when using '--header --equiv'. Default: 'equiv_id'.
* `--equiv-start INT` - Use INT as the first equiv-id. Default: 1.
* `--d|delimiter CHR` - Field delimiter. Default: TAB. (Single byte UTF-8 characters only.)
* `-h|help` - Print help.
* `--help-brief` - Print brief help.

**Examples:**
```
$ # Uniq a file, using the full line as the key
$ tsv-uniq data.txt

$ # Same as above, but case-insensitive
$ tsv-uniq --ignore-case data.txt

$ # Unique a file based on one field
$ tsv-unique -f 1 data.tsv

$ # Unique a file based on two fields
$ tsv-uniq -f 1,2 data.tsv

$ # Output all the lines, generating an ID for each unique entry
$ tsv-uniq -f 1,2 --equiv data.tsv

$ # Generate uniq IDs, but account for headers
$ tsv-uniq -f 1,2 --equiv --header data.tsv
```

### tsv-select reference

**Synopsis:** tsv-select -f n[,n...] [options] [file...]

tsv-select reads files or standard input and writes specified fields to standard output in the order listed. Similar to 'cut' with the ability to reorder fields. Fields can be listed more than once, and fields not listed can be output using the --rest option.

**Options:**
* `--f|fields n[,n...]` - (Required) Fields to extract. Fields are output in the order listed.
* `--r|rest none|first|last` - Location for remaining fields. Default: none
* `--d|delimiter CHR` - Character to use as field delimiter. Default: TAB. (Single byte UTF-8 characters only.)
* `--h|help` - Print help.

**Examples:**
```
$ # Output fields 2 and 1, in that order
$ tsv-select -f 2,1 --rest first data.tsv

$ # Move field 1 to the end of the line
$ tsv-select -f 1 --rest first data.tsv

$ # Move fields 7 and 3 to the start of the line
$ tsv-select -f 7,3 --rest last data.tsv
```

### csv2tsv reference

**Synopsis:** csv2tsv [options] [file...]

csv2tsv converts CSV (comma-separated) text to TSV (tab-separated) format. Records are read from files or standard input, converted records are written to standard output.

Both formats represent tabular data, each record on its own line, fields separated by a delimiter character. The key difference is that CSV uses escape sequences to represent newlines and field separators in the data, whereas TSV disallows these characters in the data. The most common field delimiters are comma for CSV and tab for TSV, but any character can be used.

Conversion to TSV is done by removing CSV escape syntax, changing field delimiters, and replacing newlines and field delimiters in the data. By default, newlines and field delimiters in the data are replaced by spaces. Most details are customizable.

There is no single spec for CSV, any number of variants can be found. The escape syntax is common enough: fields containing newlines or field delimiters are placed in double quotes. Inside a quoted field, a double quote is represented by a pair of double quotes. As with field separators, the quoting character is customizable.

Behaviors of this program that often vary between CSV implementations:
* Newlines are supported in quoted fields.
* Double quotes are permitted in a non-quoted field. However, a field starting with a quote must follow quoting rules.
* Each record can have a different numbers of fields.
* The three common forms of newlines are supported: CR, CRLF, LF.
* A newline will be added if the file does not end with one.
* No whitespace trimming is done.

This program does not validate CSV correctness, but will terminate with an error upon reaching an inconsistent state. Improperly terminated quoted fields are the primary cause.

UTF-8 input is assumed. Convert other encodings prior to invoking this tool.

**Options:**
* `--header` - Treat the first line of each file as a header. Only the header of the first file is output.
* `--q|quote CHR` - Quoting character in CSV data. Default: double-quote (")
* `--c|csv-delim CHR` - Field delimiter in CSV data. Default: comma (,).
* `--t|tsv-delim CHR` - Field delimiter in TSV data. Default: TAB
* `--r|replacement STR` - Replacement for newline and TSV field delimiters found in CSV input. Default: Space.
* `--h|help` - Print help.

### number-lines reference

**Synopsis:** number-lines [options] [file...]

number-lines reads from files or standard input and writes each line to standard output preceded by a line number. It is a simplified version of the Unix 'nl' program. It supports one feature 'nl' does not: the ability to treat the first line of files as a header. This is useful when working with tab-separated-value files. If header processing used, a header line is written for the first file, and the header lines are dropped from any subsequent files.

**Options:**
* `--header` - Treat the first line of each file as a header. The first input file's header is output, subsequent file headers are discarded.
* `--s|header-string STR` - String to use as the header for the line number field. Implies --header. Default: 'line'.
* `--n|start-number NUM` - Number to use for the first line. Default: 1.
* `--d|delimiter CHR` - Character appended to line number, preceding the rest of the line. Default: TAB (Single byte UTF-8 characters only.)
* `--h|help` - Print help.

**Examples:**
```
$ # Number lines in a file
$ number-lines file.tsv

$ # Number lines from multiple files. Treat the first line each file as a header.
$ number-lines --header data*.tsv
```
