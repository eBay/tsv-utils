# Performance Benchmarks

Contents:
* [Summary](#summary)
* [Comparative Benchmarks](#comparative-benchmarks)
* [DMD vs LDC](#dmd-vs-ldc)
* [Relative performance of the tools](#relative-performance-of-the-tools)

## Summary

Performance is a key motivation for writing tools like this in D rather an interpreted language like Python or Perl. It is also a consideration in choosing between D and C/C++.

As a way to gauge D's performance, benchmarks were run using the `tsv-utils-dlang` tools and a number of other native language tools providing similar functionality. Included were traditional Unix tools as well as several more specialized tool-kits. Programming languages involved were C, Go, and Rust.

The D programs performed extremely well on these benchmarks, exceeding the author's expectations. They were the fastest on five of the six benchmarks run, by significant margins. This is impressive given that very little low-level programming was done. High level language constructs were used throughout, including the simplest forms of file I/O (no manual buffer management), GC (no manual memory management), built-in associative arrays and other facilities from the standard library, liberal used of functional programming constructs, etc. Performance tuning was done to identify some poorly performing constructs, and templates were used in a few places to improve performance, but nothing extensive. (See [Coding philosophy](AboutTheCode.md#coding-philosophy) for the rationale behind these choices.)

As with most benchmarks, there are important caveats. The tools tested are not exact equivalents, and in many cases have different design goals and capabilities likely to impact performance. The operations are highly I/O dependent, follow similar computational patterns, and so the results may not transfer to other applications.

Despite any limitations in the benchmarks, this is certainly a good result. The different tests involve a fair range of programming constructs, and the comparison basis includes nine distinct implementations and several long tenured Unix tools. As a practical matter, performance of the tools has changed the author's personal work habits, as calculations that used to take 15-20 seconds are now instantaneous, and calculations that took minutes often finish in 10 seconds or so.

## Comparative benchmarks

Six different operations were used for benchmarks. Two forms of row filtering: numeric comparisons and regular expression match. Column selection (Unix `cut`). Join two files on a common key. Simple statistical calculations (e.g. mean of column values). Convert CSV files to TSV. These tests were chosen because there were at least two other tools providing similar functionality. Reasonably large files were used in these tests, one 4.8 GB, 7 million rows, the other 2.7 GB, 14 million rows. The author also ran the tests on smaller files, in the 500 MB - 1 GB range, results were consistent with those reported here. The tests were conducted on a MacBook Pro, 2.8 GHz, 16 GB RAM, 4 cores, 500 GB of flash storage. All tools tested were updated to current releases the day the benchmark was performed (Feb 18, 2017). Several of the specialty tool-kits were built from scratch from current source. Compilers used were: LDC 1.1 (D compiler); clang 8.0.0 (C/C++); Rust 1.15.1; Go 1.8. Run-time and maximum memory used was measured using the Linux `time` facility. Each benchmark was run three times and the fastest run recorded.

The specialty tool-kits have been anonymized in the descriptions below, except in the csv-to-tsv test, where two of these tool-kits were the best performers. (The purpose of these benchmarks is to gauge performance of the D tools, not to make a detailed comparison of tool-kits.) Tool-kits used are from the set listed under [Other toolkits](../README.md#other-toolkits) in the README file. Python tools were not benchmarked, this would be a useful comparison to add. Tools that run in in-memory environments like R were excluded from the benchmarks.

The worst performing tools in these tests were the Unix tools shipped with the Mac (`cut`, etc). It's worth installing the latest GNU coreutils versions if you use command line tools on a Mac. (MacPorts and Homebrew are popular package managers that can install GNU tools.)

### Numeric filter benchmark

This operation filters rows from a TSV file based on a numeric comparison (less than, greater than, etc) of two fields in a line. A 7 million line, 29 column, 4.8 GB numeric data file was used in this test. The filter matched 1.2 million lines.

| Tool                   | Time (secs) | Max Memory (kbytes) |
| ---------------------- |-----------: | ------------------: |
| **tsv-filter**         |             |                     |
| mawk (M. Brennan Awk)  |             |                     |
| GNU awk                |             |                     |
| Toolkit 1              |             |                     |
| awk (Mac built-in)     |             |                     |

### Regular expression filter benchmark

This operation filters rows from a TSV file based on a regular comparison against a field. The regular expression used was '[RD].*(ION[0-2])', it matched against a text field. The input file was 14 million rows, 49 columns, 2.7 GB. The filter matched 150K rows. Other regular expressions were tried, results were similar.

| Tool                   | Time (secs) | Max Memory (kbytes) |
| ---------------------- |-----------: | ------------------: |
| **tsv-filter**         |             |                     |
| GNU awk                |             |                     |
| mawk (M. Brennan Awk)  |             |                     |
| Toolkit 1              |             |                     |
| Toolkit 2              |             |                     |
| awk (Mac built-in)     |             |                     |
| Toolkit 3              |             |                     |

### Column selection (aka. `cut`) benchmark

This is the traditional Unix `cut` operation. Surprisingly, the `cut` implementations were not the fastest. The test selected fields 1, 8, 19 from a 7 million line, 29 column, 4.8 GB numeric data file.

| Tool                   | Time (secs) | Max Memory (kbytes) |
| ---------------------- |-----------: | ------------------: |
| **tsv-select**         |             |                     |
| mawk (M. Brennan Awk)  |             |                     |
| GNU cut                |             |                     |
| Toolkit 1              |             |                     |
| GNU awk                |             |                     |
| Toolkit 2              |             |                     |
| Toolkit 3              |             |                     |
| cut (Mac built-in)     |             |                     |
| awk (Mac built-in)     |             |                     |

### Join two files

This test was done taking a 7 million line, 29 column numeric data file, splitting it into two files, one containing columns 1-15, the second columns 16-29. Each line contained a unique row key shared by both files. The rows of each file were randomized. The join task reassembles the original file based on the shared row key. The original file is 4.8 GB, each half is 2.4 GB.

| Tool                   | Time (secs) | Max Memory (kbytes) |
| ---------------------- |-----------: | ------------------: |
| **tsv-join**           |             |                     |
| Toolkit 1              |             |                     |
| Toolkit 2              |             |                     |
| Toolkit 3              |             |                     |

### Statistical summary

This test generated set of summary statistics from the columns in a TSV file. The exact measures were based on summary statistics available in the different available tools that had high overlap. The sets were not identical, but were close enough for rough comparison. Roughly, the count, sum, min, max, mean, and standard deviation of three fields from a 7 million row, 4.8 GB data file.

| Tool                   | Time (secs) | Max Memory (kbytes) |
| ---------------------- |-----------: | ------------------: |
| **tsv-summarize**      |             |                     |
| Toolkit 1              |             |                     |
| Toolkit 2              |             |                     |
| Toolkit 3              |             |                     |
| Toolkit 4              |             |                     |

### CSV to TSV conversion

This test converted a CSV file to TSV format. The file used was 14 million rows, 49 columns, 2.7 GB. This is the one benchmark where the D tools were outperformed by other tools.

| Tool                   | Time (secs) | Max Memory (kbytes) |
| ---------------------- |-----------: | ------------------: |
| abc                    |             |                     |
| def                    |             |                     |
| **csv2tsv**            |             |                     |

## DMD vs LDC

It is generally understood that the LDC compiler produces faster executables than the DMD compiler. The same benchmarks used to compare against other tools were used to compare to LDC and DMD. In this case, DMD version 2.073.1 was compared to LDC 1.1. LDC 1.1 uses an older version of the standard library (Phobos), version 2.071.2. LDC was faster on all benchmarks, in some cases up to a 2x delta.

| Test/tool                     | LDC Time (secs) | DMD Time (secs) |
| ----------------------------- |---------------: | --------------: |
| Numeric filter (tsv-filter)   |            4.31 |            5.54 |
| Regex filter (tsv-filter)     |            7.14 |           11.33 |
| Column select (tsv-select)    |            4.06 |            9.46 |
| Join files (tsv-join)         |           20.56 |           40.97 |
| Stats summary (tsv-summarize) |           15.77 |           18.25 |
| CSV-to-TSV (csv2tsv)          |           53.27 |           64.91 |

## Relative performance of the tools

Runs against a 4.5 million line, 279 MB file were used to get a relative comparison of the tools. The original file was a CSV file, allowing inclusion of `csv2tsv`. The TSV file generated was used in the other runs. Running time of routines filtering data is dependent on the amount output, so a different output sizes were used. `tsv-join` depends on the size of the filter file, a file the same size as the output was used in these tests. Performance of these tools also depends on the options selected, so actuals will vary.

**Macbook Pro (2.8 GHz Intel I7, 16GB ram, flash storage); File: 4.46M lines, 8 fields, 279MB**:

| Tool         | Records output | Time (seconds) | Max Memory (kbytes) |
| ------------ | -------------: | -------------: | ------------------: |
| tsv-filter   |         513788 |           0.65 |           8,192,000 |
| number-lines |        4465613 |           0.97 |           6,324,224 |
| cut (GNU)    |        4465613 |           0.98 |           5,373,952 |
| tsv-filter   |        4125057 |           1.02 |           8,192,000 |
| tsv-join     |          65537 |           1.19 |         125,255,680 |
| tsv-select   |        4465613 |           1.20 |          10,534,912 |
| tsv-uniq     |          65537 |           1.23 |          95,420,416 |
| tsv-uniq     |        4465613 |           3.51 |       2,344,206,336 |
| csv2tsv      |        4465613 |           5.13 |          10,354,688 |
| tsv-join     |        4465613 |           5.87 |       1,413,578,752 |

Performance of `tsv-filter` looks especially good, even when outputting a large number of records. It's not far off GNU `cut`. `tsv-join` and `tsv-uniq` are fast, but show an impact when larger hash tables are needed (4.5M entries in the slower cases). `csv2tsv` is a bit slower than the other tools. Investigation indicates this is likely due to the byte-by-byte output style it uses.
