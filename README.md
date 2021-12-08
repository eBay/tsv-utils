# Command line utilities for tabular data files

This is a set of command line utilities for manipulating large tabular data files. Files of numeric and text data commonly found in machine learning and data mining environments. Filtering, sampling, statistics, joins, and more.

These tools are especially useful when working with large data sets. They run faster than other tools providing similar functionality, often by significant margins. See [Performance Studies](docs/Performance.md) for comparisons with other tools.

File an [issue](https://github.com/eBay/tsv-utils/issues) if you have problems, questions or suggestions.

**In this README:**
* [Tools overview](#tools-overview) - Toolkit introduction and descriptions of each tool.
* [Obtaining and installation](#obtaining-and-installation)

**Additional documents:**
* [Tools Reference](docs/ToolReference.md) - Detailed documentation.
* [Releases](https://github.com/eBay/tsv-utils/releases) - Prebuilt binaries and release notes. Recent updates:
  * Current release: [version 2.2.0](https://github.com/eBay/tsv-utils/releases/tag/v2.2.0).
  * Improved `csv2tsv` performance and functionality. See [version 2.1 release notes](https://github.com/eBay/tsv-utils/releases/tag/v2.1.0).
  * Named fields! See [version 2.0 release notes](https://github.com/eBay/tsv-utils/releases/tag/v2.0.0).
* [Tips and tricks](docs/TipsAndTricks.md) - Simpler and faster command line tool use.
* [Performance Studies](docs/Performance.md) - Benchmarks against similar tools and other performance studies.
* [Comparing TSV and CSV formats](docs/comparing-tsv-and-csv.md)
* [Building with Link Time Optimization (LTO) and Profile Guided Optimization (PGO)](docs/BuildingWithLTO.md)
* [About the code](docs/AboutTheCode.md) (see also: [tsv-utils code documentation](https://tsv-utils.dpldocs.info/))
* [Other toolkits](docs/OtherToolkits.md)

**Talks and blog posts:**
* [Faster Command Line Tools in D](https://dlang.org/blog/2017/05/24/faster-command-line-tools-in-d/). May 24, 2017. A blog post showing a few ways to optimize performance in command line tools. Many of the ideas in the post were identified while developing the TSV Utilities.
* [Experimenting with Link Time Optimization](docs/dlang-meetup-14dec2017.pdf). Dec 14, 2017. A presentation at the [Silicon Valley D Meetup](https://www.meetup.com/D-Lang-Silicon-Valley/) describing experiments using LTO based on eBay's TSV Utilities.
* [Exploring D via Benchmarking of eBay's TSV Utilities](http://dconf.org/2018/talks/degenhardt.html). May 2, 2018. A presentation at [DConf 2018](http://dconf.org/2018/) describing performance benchmark studies conducted using eBay's TSV Utilities (slides [here](docs/dconf2018.pdf)).

[![GitHub Workflow Status](https://img.shields.io/github/workflow/status/eBay/tsv-utils/build-test)](https://github.com/eBay/tsv-utils/actions/workflows/build-test.yml)
[![Codecov](https://img.shields.io/codecov/c/github/eBay/tsv-utils.svg)](https://codecov.io/gh/eBay/tsv-utils)
[![GitHub release](https://img.shields.io/github/release/eBay/tsv-utils.svg)](https://github.com/eBay/tsv-utils/releases)
[![Github commits (since latest release)](https://img.shields.io/github/commits-since/eBay/tsv-utils/latest.svg)](https://github.com/eBay/tsv-utils/commits/master)
[![GitHub last commit](https://img.shields.io/github/last-commit/eBay/tsv-utils.svg)](https://github.com/eBay/tsv-utils/commits/master)
[![license](https://img.shields.io/github/license/eBay/tsv-utils.svg)](https://github.com/eBay/tsv-utils/blob/master/LICENSE.txt)

## Tools overview

These tools perform data manipulation and statistical calculations on tab delimited data. They are intended for large files. Larger than ideal for loading entirely in memory in an application like R, but not so big as to necessitate moving to Hadoop or similar distributed compute environments. The features supported are useful both for standalone analysis and for preparing data for use in R, Pandas, and similar toolkits.

The tools work like traditional Unix command line utilities such as `cut`, `sort`, `grep` and `awk`, and are intended to complement these tools. Each tool is a standalone executable. They follow common Unix conventions for pipeline programs. Data is read from files or standard input, results are written to standard output. Fields are identified either by field name or field number. The field separator defaults to TAB, but any character can be used. Input and output is UTF-8, and all operations are Unicode ready, including regular expression match (`tsv-filter`). Documentation is available for each tool by invoking it with the `--help` option. Most tools provide a `--help-verbose` option offering more extensive, reference style documentation. TSV format is similar to CSV, see [Comparing TSV and CSV formats](docs/comparing-tsv-and-csv.md) for the differences.

The rest of this section contains descriptions of each tool. Click on the links below to jump directly to one of the tools. Full documentation is available in the [Tools Reference](docs/ToolReference.md). The first tool listed, [tsv-filter](#tsv-filter), provides a tutorial introduction to features found throughout the toolkit.

* [tsv-filter](#tsv-filter) - Filter lines using numeric, string and regular expression comparisons against individual fields.
* [tsv-select](#tsv-select) - Keep a subset of columns (fields). Like `cut`, but supporting named fields, field reordering, and field exclusions.
* [tsv-uniq](#tsv-uniq) - Filter out duplicate lines using either the full line or individual fields as a key.
* [tsv-summarize](#tsv-summarize) - Summary statistics on selected fields, against the full data set or grouped by key.
* [tsv-sample](#tsv-sample) - Sample input lines or randomize their order. A number of sampling methods are available.
* [tsv-join](#tsv-join) - Join lines from multiple files using fields as a key.
* [tsv-pretty](#tsv-pretty) - Print TSV data aligned for easier reading on the command-line.
* [csv2tsv](#csv2tsv) - Convert CSV files to TSV.
* [tsv-split](#tsv-split) - Split data into multiple files. Random splits, random splits by key, and splits by blocks of lines.
* [tsv-append](#tsv-append) - Concatenate TSV files. Header-aware; supports source file tracking.
* [number-lines](#number-lines) - Number the input lines.
* [keep-header](#keep-header) - Run a shell command in a header-aware fashion.

### tsv-filter

Filter lines by running tests against individual fields. Multiple tests can be specified in a single call. A variety of numeric and string comparison tests are available, including regular expressions.

Consider a file having 4 fields: `id`, `color`, `year`, `count`. Using [tsv-pretty](#tsv-pretty) to view the first few lines:
```
$ tsv-pretty data.tsv | head -n 5
 id  color   year  count
100  green   1982    173
101  red     1935    756
102  red     2008   1303
103  yellow  1873    180
```

The following command finds all entries where 'year' (field 3) is 2008:
```
$ tsv-filter -H --eq year:2008 data.tsv
```

The `-H` option indicates the first input line is a header. The `--eq` operator performs a numeric equality test. String comparisons are also available. The following command finds entries where 'color' (field 2) is "red":
```
$ tsv-filter -H --str-eq color:red data.tsv
```

Fields can also be identified by field number, same as traditional Unix tools. This works for files with and without header lines. The following commands are equivalent to the previous two:
```
$ tsv-filter -H --eq 3:2008 data.tsv
$ tsv-filter -H --str-eq 2:red data.tsv
```

Multiple tests can be specified. The following command finds `red` entries with `year` between 1850 and 1950:
```
$ tsv-filter -H --str-eq color:red --ge year:1850 --lt year:1950 data.tsv
```

Viewing the first few results produced by this command:
```
$ tsv-filter -H --str-eq color:red --ge year:1850 --lt year:1950 data.tsv | tsv-pretty | head -n 5
 id  color  year  count
101  red    1935    756
106  red    1883   1156
111  red    1907   1792
114  red    1931   1412
```

The `--count` option switches from filtering to counting matched records. Header lines are excluded from the count. The following command prints the number of `red` entries in `data.tsv` (there are nine):
```
$ tsv-filter -H --count --str-eq color:red data.tsv
9
```

The `--label` option is another alternative to filtering. In this mode, a new field is added to every record indicating if it satisfies the criteria. The next command marks records to indicate if `year` is in the 1900s:
```
$  tsv-filter -H --label 1900s --ge year:1900 --lt year:2000 data.tsv | tsv-pretty | head -n 5
 id  color   year  count  1900s
100  green   1982    173      1
101  red     1935    756      1
102  red     2008   1303      0
103  yellow  1873    180      0
```

The `--label-values` option can be used to customize the values used to mark records.

Files can be placed anywhere on the command line. Data will be read from standard input if a file is not specified. The following commands are equivalent:
```
$ tsv-filter -H --str-eq color:red --ge year:1850 --lt year:1950 data.tsv
$ tsv-filter data.tsv -H --str-eq color:red --ge year:1850 --lt year:1950
$ cat data.tsv | tsv-filter -H --str-eq color:red --ge year:1850 --lt year:1950
```

Multiple files can be provided. Only the header line from the first file will be kept when the `-H` option is used:
```
$ tsv-filter -H data1.tsv data2.tsv data3.tsv --str-eq 2:red --ge 3:1850 --lt 3:1950
$ tsv-filter -H *.tsv --str-eq 2:red --ge 3:1850 --lt 3:1950
```

Numeric comparisons are among the most useful tests. Numeric operators include:
* Equality: `--eq`, `--ne` (equal, not-equal).
* Relational: `--lt`, `--le`, `--gt`, `--ge` (less-than, less-equal, greater-than, greater-equal).

Several filters are available to help with invalid data. Assume there is a messier version of the 4-field file where some fields are not filled in. The following command will filter out all lines with an empty value in any of the four fields:
```
$ tsv-filter -H messy.tsv --not-empty 1-4
```

The above command uses a "field list" to run the test on each of fields 1-4. The test can be "inverted" to see the lines that were filtered out:
```
$ tsv-filter -H messy.tsv --invert --not-empty 1-4 | head -n 5 | tsv-pretty
 id  color   year  count
116          1982     11
118  yellow          143
123  red              65
126                   79
```

There are several filters for testing characteristics of numeric data. The most useful are:
* `--is-numeric` - Test if the data in a field can be interpreted as a number.
* `--is-finite` - Test if the data in a field can be interpreted as a number, but not NaN (not-a-number) or infinity. This is useful when working with data where floating point calculations may have produced NaN or infinity values.

By default, all tests specified must be satisfied for a line to pass a filter. This can be changed using the `--or` option. For example, the following command finds records where 'count' (field 4) is less than 100 or greater than 1000:
```
$ tsv-filter -H --or --lt 4:100 --gt 4:1000 data.tsv | head -n 5 | tsv-pretty
 id  color  year  count
102  red    2008   1303
105  green  1982     16
106  red    1883   1156
107  white  1982      0
```

A number of string and regular expression tests are available. These include:
* Equality: `--str-eq`, `--str-ne`
* Partial match: `--str-in-fld`, `--str-not-in-fld`
* Relational operators: `--str-lt`, `--str-gt`, etc.
* Case insensitive tests: `--istr-eq`, `--istr-in-fld`, etc.
* Regular expressions: `--regex`, `--not-regex`, etc.
* Field length: `--char-len-lt`, `--byte-len-gt`, etc.

The earlier `--not-empty` example uses a "field list". Fields lists specify a set of fields and can be used with most operators. For example, the following command ensures that fields 1-3 and 7 are less-than 100:
```
$ tsv-filter -H --lt 1-3,7:100 file.tsv
```

Field names can be used in field lists as well. The following command selects lines where both 'color' and 'count' fields are not empty:
```
$ tsv-filter -H messy.tsv --not-empty color,count
```

Field names can be matched using wildcards. The previous command could also be written as:
```
$ tsv-filter -H messy.tsv --not-empty 'co*'
```

The `co*` matches both the 'color' and 'count' fields. (Note: Single quotes are used to prevent the shell from interpreting the asterisk character.)

All TSV Utilities tools use the same syntax for specifying fields. See [Field syntax](docs/tool_reference/common-options-and-behavior.md#field-syntax) in the [Tools Reference](docs/ToolReference.md) document for details.

Bash completion is especially helpful with `tsv-filter`. It allows quickly seeing and selecting from the different operators available. See [bash completion](docs/TipsAndTricks.md#enable-bash-completion) on the [Tips and tricks](docs/TipsAndTricks.md) page for setup information.

`tsv-filter` is perhaps the most broadly applicable of the TSV Utilities tools, as dataset pruning is such a common task. It is stream oriented, so it can handle arbitrarily large files. It is fast, quite a bit faster than other tools the author has tried. (See the "Numeric row filter" and "Regular expression row filter" tests in the [2018 Benchmark Summary](docs/Performance.md#2018-benchmark-summary).)

This makes `tsv-filter` ideal for preparing data for applications like R and Pandas. It is also convenient for quickly answering simple questions about a dataset.

See the [tsv-filter reference](docs/tool_reference/tsv-filter.md) for more details and the full list of operators.

### tsv-select

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

See the [tsv-select reference](docs/tool_reference/tsv-select.md) for details on `tsv-select`. See [Field syntax](docs/tool_reference/common-options-and-behavior.md#field-syntax) for more information on selecting fields by name.

### tsv-uniq

Similar in spirit to the Unix `uniq` tool, `tsv-uniq` filters a dataset so there is only one copy of each unique line. `tsv-uniq` goes beyond Unix `uniq` in a couple ways. First, data does not need to be sorted. Second, equivalence can be based on a subset of fields rather than the full line.

`tsv-uniq` can also be run in 'equivalence class identification' mode, where lines with equivalent keys are marked with a unique id rather than filtered out. Another variant is 'number' mode, which generates line numbers grouped by the key.

`tsv-uniq` operates on the entire line when no fields are specified. This is a useful alternative to the traditional `sort -u` or `sort | uniq` paradigms for identifying unique lines in unsorted files, as it is quite a bit faster, especially when there are many duplicate lines. As a bonus, order of the input lines is retained.

Examples:
```
$ # Unique a file based on the full line.
$ tsv-uniq data.tsv

$ # Unique a file with fields 2 and 3 as the key.
$ tsv-uniq -f 2,3 data.tsv

$ # Unique a file using the 'RecordID' field as the key.
$ tsv-uniq -H -f RecordID data.tsv
```

An in-memory lookup table is used to record unique entries. This ultimately limits the data sizes that can be processed. The author has found that datasets with up to about 10 million unique entries work fine, but performance starts to degrade after that. Even then it remains faster than the alternatives.

See the [tsv-uniq reference](docs/tool_reference/tsv-uniq.md) for details.

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
$ tsv-summarize --header --sum weight --mean weight data.tsv
weight_sum  weight_mean
40          8

$ tsv-summarize --header --group-by color --sum weight --mean color data.tsv
color  weight_sum  weight_mean
red    15          5
blue   25          12.5
```

Multiple fields can be used as the `--group-by` key. The file's sort order does not matter, there is no need to sort in the `--group-by` order first. Fields can be specified either by name or field number, like other tsv-utils tools. 

See the [tsv-summarize reference](docs/tool_reference/tsv-summarize.md) for the list of statistical and other aggregation operations available.

### tsv-sample

`tsv-sample` randomizes line order (shuffling) or selects random subsets of lines (sampling) from input data. Several methods are available, including shuffling, simple random sampling, weighted random sampling, Bernoulli sampling, and distinct sampling. Data can be read from files or standard input. These sampling methods are made available through several modes of operation:

* Shuffling - The default mode of operation. All lines are read in and written out in random order. All orderings are equally likely.
* Simple random sampling (`--n|num N`) - A random sample of `N` lines are selected and written out in random order. The `--i|inorder` option preserves the original input order.
* Weighted random sampling (`--n|num N`, `--w|weight-field F`) - A weighted random sample of N lines are selected using weights from a field on each line. Output is in weighted selection order unless the `--i|inorder` option is used. Omitting `--n|num` outputs all lines in weighted selection order (weighted shuffling).
* Sampling with replacement (`--r|replace`, `--n|num N`) - All lines are read in, then lines are randomly selected one at a time and written out. Lines can be selected multiple times. Output continues until `N` samples have been output.
* Bernoulli sampling (`--p|prob P`) - A streaming form of sampling. Lines are read one at a time and selected for output using probability `P`. e.g. `-p 0.1` specifies that 10% of lines should be included in the sample.
* Distinct sampling (`--k|key-fields F`, `--p|prob P`) - Another streaming form of sampling. However, instead of each line being subject to an independent selection choice, lines are selected based on a key contained in each line. A portion of keys are randomly selected for output, with probability P. Every line containing a selected key is included in the output. Consider a query log with records consisting of <user, query, clicked-url> triples. It may be desirable to sample records for one percent of the users, but include all records for the selected users.

`tsv-sample` is designed for large data sets. Streaming algorithms make immediate decisions on each line. They do not accumulate memory and can run on infinite length input streams. Both shuffling and sampling with replacement read the entire dataset all at once and are limited by available memory. Simple and weighted random sampling use reservoir sampling and only need to hold the specified sample size (`--n|num`) in memory. By default, a new random order is generated every run, but options are available for using the same randomization order over multiple runs. The random values assigned to each line can be printed, either to observe the behavior or to run custom algorithms on the results.

See the [tsv-sample reference](docs/tool_reference/tsv-sample.md) for further details.

### tsv-join

Joins lines from multiple files based on a common key. One file, the 'filter' file, contains the records (lines) being matched. The other input files are scanned for matching records. Matching records are written to standard output, along with any designated fields from the filter file. In database parlance this is a hash semi-join. This is similar to the "stream-static" joins available in Spark Structured Streaming and "KStream-KTable" joins in Kafka. (The filter file plays the same role as the Spark static dataset or Kafka KTable.)

Example:
```
$ tsv-join -H --filter-file filter.tsv --key-fields Country,City --append-fields Population,Elevation data.tsv
```

This reads `filter.tsv`, creating a lookup table keyed on the `Country` and `City` fields. `data.tsv` is read, lines with a matching key are written to standard output with the `Population` and `Elevation` fields from `filter.tsv` appended. This is an inner join. Left outer joins and anti-joins are also supported.

Common uses for `tsv-join` are to join related datasets or to filter one dataset based on another. Filter file entries are kept in memory, this limits the ultimate size that can be handled effectively. The author has found that filter files up to about 10 million lines are processed effectively, but performance starts to degrade after that.

See the [tsv-join reference](docs/tool_reference/tsv-join.md) for details.

### tsv-pretty

tsv-pretty prints TSV data in an aligned format for better readability when working on the command-line. Text columns are left aligned, numeric columns are right aligned. Floats are aligned on the decimal point and precision can be specified. Header lines are detected automatically. If desired, the header line can be repeated at regular intervals. An example, first printed without formatting:
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
See the [tsv-pretty reference](docs/tool_reference/tsv-pretty.md) for details.

### csv2tsv

`csv2tsv` does what you expect: convert CSV data to TSV. Example:
```
$ csv2tsv data.csv > data.tsv
```

A strict delimited format like TSV has many advantages for data processing over an escape oriented format like CSV. However, CSV is a very popular data interchange format and the default export format for many database and spreadsheet programs. Converting CSV files to TSV allows them to be processed reliably by both this toolkit and standard Unix utilities like `awk` and `sort`.

Note that many CSV files do not use escapes, and in-fact follow a strict delimited format using comma as the delimiter. Such files can be processed reliably by this toolkit and Unix tools by specifying the delimiter character. However, when there is doubt, using a `csv2tsv` converter adds reliability.

`csv2tsv` differs from many csv-to-tsv conversion tools in that it produces output free of CSV escapes. Many conversion tools produce data with CSV style escapes, but switching the field delimiter from comma to TAB. Such data cannot be reliably processed by Unix tools like `cut`, `awk`, `sort`, etc.

`csv2tsv` avoids escapes by replacing TAB and newline characters in the data with a single space. These characters are rare in data mining scenarios, and space is usually a good substitute in cases where they do occur. The replacement strings are customizable to enable alternate handling when needed.

The `csv2tsv` converter often has a second benefit: regularizing newlines. CSV files are often exported using Windows newline conventions. `csv2tsv` converts all newlines to Unix format.

See [Comparing TSV and CSV formats](docs/comparing-tsv-and-csv.md) for more information on CSV escapes and other differences between CSV and TSV formats.

There are many variations of CSV file format. See the [csv2tsv reference](docs/tool_reference/csv2tsv.md) for details of the format variations supported by this tool.

### tsv-split

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

See the [tsv-split reference](docs/tool_reference/tsv-split.md) for more information.

### tsv-append

`tsv-append` concatenates multiple TSV files, similar to the Unix `cat` utility. It is header-aware, writing the header from only the first file. It also supports source tracking, adding a column indicating the original file to each row.

Concatenation with header support is useful when preparing data for traditional Unix utilities like `sort` and `sed` or applications that read a single file.

Source tracking is useful when creating long/narrow form tabular data. This format is used by many statistics and data mining packages. (See [Wide & Long Data - Stanford University](https://stanford.edu/~ejdemyr/r-tutorials/wide-and-long/) or Hadley Wickham's [Tidy data](http://vita.had.co.nz/papers/tidy-data.html) for more info.)

In this scenario, files have been used to capture related data sets, the difference between data sets being a condition represented by the file. For example, results from different variants of an experiment might each be recorded in their own files. Retaining the source file as an output column preserves the condition represented by the file. The source values default to the file names, but this can be customized.

See the [tsv-append reference](docs/tool_reference/tsv-append.md) for the complete list of options available.

### number-lines

A simpler version of the Unix `nl` program. It prepends a line number to each line read from files or standard input. This tool was written primarily as an example of a simple command line tool. The code structure it uses is the same as followed by all the other tools. Example:
```
$ number-lines myfile.txt
```

Despite its original purpose as a code sample, `number-lines` turns out to be quite convenient. It is often useful to add a unique row ID to a file, and this tool does this in a manner that maintains proper TSV formatting.

See the [number-lines reference](docs/tool_reference/number-lines.md) for details.

### keep-header

A convenience utility that runs Unix commands in a header-aware fashion. It is especially useful with `sort`. `sort` does not know about headers, so the header line ends up wherever it falls in the sort order.  Using `keep-header`, the header line is output first and the rest of the sorted file follows. For example:
```
$ # Sort a file, keeping the header line at the top.
$ keep-header myfile.txt -- sort
```

The command to run is placed after the double dash (`--`). Everything after the initial double dash is part of the command. For example, `sort --ignore-case` is run as follows:
```
$ # Case-insensitive sort, keeping the header line at the top.
$ keep-header myfile.txt -- sort --ignore-case
```

Multiple files can be provided, only the header from the first is retained. For example:

```
$ # Sort a set of files in reverse order, keeping only one header line.
$ keep-header *.txt -- sort -r
```

`keep-header` is especially useful for commands like `sort` and `shuf` that reorder input lines. It is also useful with filtering commands like `grep`, many `awk` uses, and even `tail`, where the header should be retained without filtering or evaluation.

Examples:
```
$ # 'grep' a file, keeping the header line without needing to match it.
$ keep-header file.txt -- grep 'some text'

$ # Print the last 10 lines of a file, but keep the header line
$ keep-header file.txt -- tail

$ # Print lines 100-149 of a file, plus the header
$ keep-header file.txt -- tail -n +100 | head -n 51

$ # Sort a set of TSV files numerically on field 2, keeping one header.
$ keep-header *.tsv -- sort -t $'\t' -k2,2n

$ # Same as the previous example, but using the 'tsv-sort-fast' bash
$ # script described on the "Tips and Tricks" page.
$ keep-header *.tsv -- tsv-sort-fast -k2,2n
```

See the [keep-header reference](docs/tool_reference/keep-header.md) for more information.

---

## Obtaining and installation

There are several ways to obtain the tools: [prebuilt binaries](#prebuilt-binaries); [building from source code](#build-from-source-files); and [installing using the DUB package manager](#install-using-dub).

The tools are tested on Linux and MacOS. Windows users are encouraged to use either [Windows Subsystem for Linux (WSL)](https://docs.microsoft.com/en-us/windows/wsl/) or [Docker for Windows](https://docs.docker.com/docker-for-windows/) and run Linux builds of the tools. See [issue #317](https://github.com/eBay/tsv-utils/issues/317) for the status of Windows builds. 

### Prebuilt binaries

Prebuilt binaries are available for Linux and Mac, these can be found on the [Github releases](https://github.com/eBay/tsv-utils/releases) page. Download and unpack the tar.gz file. Executables are in the `bin` directory. Add the `bin` directory or individual tools to the `PATH` environment variable. As an example, the 2.2.0 releases for Linux and MacOS can be downloaded and unpacked with these commands:
```
$ curl -L https://github.com/eBay/tsv-utils/releases/download/v2.2.0/tsv-utils-v2.2.0_linux-x86_64_ldc2.tar.gz | tar xz
$ curl -L https://github.com/eBay/tsv-utils/releases/download/v2.2.0/tsv-utils-v2.2.0_osx-x86_64_ldc2.tar.gz | tar xz
```

See the [Github releases](https://github.com/eBay/tsv-utils/releases) page for the latest release.

For some distributions a package can directly be installed:

| Distribution | Command               |
| ------------ | --------------------- |
| Arch Linux   | `pacaur -S tsv-utils` (see [`tsv-utils`](https://aur.archlinux.org/packages/tsv-utils/))
| bioconda     | `conda install -c bioconda tsv-utils` (see [`tsv-utils`](http://bioconda.github.io/recipes/tsv-utils/README.html))

*Note: The distributions above are not updated as frequently as the [Github releases](https://github.com/eBay/tsv-utils/releases) page.*

### Build from source files

[Download a D compiler](https://dlang.org/download.html). These tools have been tested with the DMD and LDC compilers on MacOS and Linux. Use DMD version 2.088.1 or later, LDC version 1.18.0 or later.

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

If you are a D user you likely use DUB, the D package manager. DUB comes packaged with DMD starting with DMD 2.072. You can install and build using DUB as follows (replace `2.2.0` with the current version):
```
$ dub fetch tsv-utils --cache=local
$ cd tsv-utils-2.2.0/tsv-utils
$ dub run    # For LDC: dub run -- --compiler=ldc2
```

The `dub run` command compiles all the tools. The executables are written to `tsv-utils/bin`. Add this directory or individual executables to the PATH.

See [Building and makefile](docs/AboutTheCode.md#building-and-makefile) for more information about the DUB setup.

The applications can be built with LTO and PGO when source code is fetched by DUB. However, the DUB build system does not support this. `make` must be used instead. See [Building with Link Time Optimization](docs/BuildingWithLTO.md).

### Setup customization

There are a number of simple ways to improve the utility of these tools, these are listed on the [Tips and tricks](docs/TipsAndTricks.md) page. [Bash aliases](docs/TipsAndTricks.md#useful-bash-aliases), [Unix sort command customization](docs/TipsAndTricks.md#customize-the-unix-sort-command), and [bash completion](docs/TipsAndTricks.md#enable-bash-completion) are especially useful.
