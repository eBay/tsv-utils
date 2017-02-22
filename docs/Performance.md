# Performance Benchmarks

* [Summary](#summary)
* [Comparative Benchmarks](#comparative-benchmarks)
* [DMD vs LDC](#dmd-vs-ldc)
* [Relative performance of the tools](#relative-performance-of-the-tools)

## Summary

Performance is a key motivation for writing tools like this in D rather an interpreted language like Python or Perl. It is also a consideration in choosing between D and C/C++.

As a way to gauge D's performance, benchmarks were run using `tsv-utils-dlang` tools and a number of other native language tools providing similar functionality. Included were traditional Unix tools as well as several more specialized toolkits. Programming languages involved were C, Go, and Rust.

The D programs performed extremely well on these benchmarks, exceeding the author's expectations. They were the fastest on five of the six benchmarks run, by often by significant margins. This is impressive given that very little low-level programming was done. High level language constructs were used throughout, including the simplest forms of file I/O (no manual buffer management), GC (no manual memory management), built-in associative arrays and other facilities from the standard library, liberal used of functional programming constructs, etc. Performance tuning was done to identify poorly performing constructs, and templates were used in several places to improve performance, but nothing extensive. See [Coding philosophy](AboutTheCode.md#coding-philosophy) for the rationale behind these choices.

As with most benchmarks, there are important caveats. The tools tested are not exact equivalents, and in many cases have different design goals and capabilities likely to impact performance. Tasks performed are highly I/O dependent and follow similar computational patterns, so the results may not transfer to other applications.

Despite limitations in the benchmarks, this is certainly a good result. The different benchmarks engage a fair range of programming constructs, and the comparison basis includes nine distinct implementations and several long tenured Unix tools. As a practical matter, performance of the tools has changed the author's personal work habits, as calculations that used to take 15-20 seconds are now instantaneous, and calculations that took minutes often finish in 10 seconds or so.

## Comparative benchmarks

Six different tasks were used as benchmarks. Two forms of row filtering: numeric comparisons and regular expression match. Column selection (aka 'cut'). Join two files on a common key. Simple statistical calculations (e.g. mean of column values). Convert CSV files to TSV. For each there are at least two other tools providing the same functionality. Reasonably large files were used, one 4.8 GB, 7 million rows, the other 2.7 GB, 14 million rows. Smaller files were also tested, in the 500 MB - 1 GB range. Those results are not reported, but were consistent with the larger file results given below.

Tests were conducted on a MacBook Pro, 2.8 GHz, 16 GB RAM, 4 cores, 500 GB of flash storage. All tools were updated to current releases the day the benchmarks were run (Feb 18, 2017). Several of the specialty toolkits were built from current source code. Compilers used were: LDC 1.1 (D compiler, Phobos 2.071.2); clang 8.0.0 (C/C++); Rust 1.15.1; Go 1.8. Run-time was measured using the `time` facility. Each benchmark was run three times and the fastest run recorded.

The specialty toolkits have been anonymized in the tables below. The purpose of these benchmarks is to gauge performance of the D tools, not make comparisons between other toolkits. The exception is the csv-to-tsv test, where the fastest toolkit is named. Toolkits used are from the set listed under [Other toolkits](../README.md#other-toolkits) in the README. Python tools were not benchmarked, this would be a useful addition. Tools that run in in-memory environments like R were excluded.

The worst performers were the Unix tools shipped with the Mac (`cut`, etc). It's worth installing the GNU coreutils package if you use command line tools on the Mac. (MacPorts and Homebrew can install these tools.)

### Numeric filter benchmark

This operation filters rows from a TSV file based on a numeric comparison (less than, greater than, etc) of two fields in a line. A 7 million line, 29 column, 4.8 GB numeric data file was used. The filter matched 1.2 million lines.

| Tool                  | Time (seconds) |
| --------------------- | -------------: |
| **tsv-filter**        |           4.31 |
| mawk (M. Brennan Awk) |          11.66 |
| GNU awk               |          21.80 |
| Toolkit 1             |          52.92 |
| awk (Mac built-in)    |         284.96 |

_Version info: GNU awk: GNU coreutils 8.26; mawk 1.3.4; OS X awk 20070501._

### Regular expression filter benchmark

This operation filters rows from a TSV file based on a regular comparison against a field. The regular expression used was '[RD].*(ION[0-2])', it matched against a text field. The input file was 14 million rows, 49 columns, 2.7 GB. The filter matched 150K rows. Other regular expressions were tried, results were similar.

| Tool                  | Time (seconds) |
| --------------------- | -------------: |
| **tsv-filter**        |           7.14 |
| GNU awk               |          15.29 |
| mawk (M. Brennan Awk) |          16.45 |
| Toolkit 1             |          28.46 |
| Toolkit 2             |          41.86 |
| awk (Mac built-in)    |         113.05 |
| Toolkit 3             |         123.22 |

### Column selection benchmark

This is the traditional Unix `cut` operation. Surprisingly, the `cut` implementations were not the fastest. The test selected fields 1, 8, 19 from a 7 million line, 29 column, 4.8 GB numeric data file.

| Tool                  | Time (seconds) |
| --------------------- |--------------: |
| **tsv-select**        |           4.06 |
| mawk (M. Brennan Awk) |           9.12 |
| GNU cut               |          12.22 |
| Toolkit 1             |          19.05 |
| GNU awk               |          32.94 |
| Toolkit 2             |          36.44 |
| Toolkit 3             |          46.06 |
| cut (Mac built-in)    |          77.79 |
| awk (Mac built-in)    |         286.29 |

_Version info: GNU cut: GNU coreutils 8.26_

_Note: GNU cut is faster than tsv-select on small files, e.g. 250 MB. See [Relative performance of the tools](#relative-performance-of-the-tools) for an example._

### Join two files

This test was done taking a 7 million line, 29 column numeric data file, splitting it into two files, one containing columns 1-15, the second columns 16-29. Each line contained a unique row key shared by both files. The rows of each file were randomized. The join task reassembles the original file based on the shared row key. The original file is 4.8 GB, each half is 2.4 GB.

| Tool         | Time (seconds) |
| ------------ |--------------: |
| **tsv-join** |          20.56 |
| Toolkit 1    |         111.55 |
| Toolkit 2    |         192.90 |
| Toolkit 3    |         244.02 |

### Summary statistics

This test generates a set of summary statistics from the columns in a TSV file. The specific calculations were based on summary statistics available in the different available tools that had high overlap. The sets were not identical, but were close enough for rough comparison. Roughly, the count, sum, min, max, mean, and standard deviation of three fields from a 7 million row, 4.8 GB data file.

| Tool              | Time (seconds) |
| ------------------|--------------: |
| **tsv-summarize** |          15.77 |
| Toolkit 1         |          39.90 |
| Toolkit 2         |          47.87 |
| Toolkit 3         |          62.88 |
| Toolkit 4         |          67.44 |

### CSV to TSV conversion

This test converted a CSV file to TSV format. The file used was 14 million rows, 49 columns, 2.7 GB. This is the one benchmark where the D tools were outperformed by other tools.

| Tool        | Time (seconds) |
| ----------- |--------------: |
| csvtk       |          37.01 |
| Toolkit 2   |          40.18 |
| **csv2tsv** |          53.27 |

## DMD vs LDC

It is understood that the LDC compiler produces faster executables than the DMD compiler. But how much faster? To get some data, the set of benchmarks described above was used to compare to LDC and DMD. In this case, DMD version 2.073.1 was compared to LDC 1.1. LDC 1.1 uses an older version of the standard library (Phobos), version 2.071.2. LDC was faster on all benchmarks, in some cases up to a 2x delta.

| Test/tool                     | LDC Time (seconds) | DMD Time (seconds) |
| ----------------------------- |------------------: | -----------------: |
| Numeric filter (tsv-filter)   |               4.31 |               5.54 |
| Regex filter (tsv-filter)     |               7.14 |              11.33 |
| Column select (tsv-select)    |               4.06 |               9.46 |
| Join files (tsv-join)         |              20.56 |              40.97 |
| Stats summary (tsv-summarize) |              15.77 |              18.25 |
| CSV-to-TSV (csv2tsv)          |              53.27 |              64.91 |

## Relative performance of the tools

Runs against a 4.5 million line, 279 MB file were used to get a relative comparison of the tools. The original file was a CSV file, allowing inclusion of `csv2tsv`. The TSV file generated was used in the other runs. Execution time when filtering data is highly dependent on the amount of output, so different output sizes were tried. `tsv-join` depends on the size of the filter file, a file the same size as the output was used in these tests. Performance also depends on the specific command line options selected, so actuals will vary.

| Tool         | Records output | Time (seconds) |
| ------------ | -------------: | -------------: |
| tsv-filter   |        513,788 |           0.65 |
| number-lines |      4,465,613 |           0.97 |
| cut (GNU)    |      4,465,613 |           0.98 |
| tsv-filter   |      4,125,057 |           1.02 |
| tsv-join     |         65,537 |           1.19 |
| tsv-select   |      4,465,613 |           1.20 |
| tsv-uniq     |         65,537 |           1.23 |
| tsv-uniq     |      4,465,613 |           3.51 |
| csv2tsv      |      4,465,613 |           5.13 |
| tsv-join     |      4,465,613 |           5.87 |

Performance of `tsv-filter` looks especially good. Even when outputting a large number of records it is not far off GNU `cut`. Unlike the larger file tests, GNU `cut` is faster than `tsv-select`. This suggests GNU `cut` may have superior buffer management strategies when smaller files. `tsv-join` and `tsv-uniq` are fast, but show an impact when larger hash tables are needed (4.5M entries in the slower cases). `csv2tsv` is decidely slower than the other tools given the work it is doing. Investigation indicates this is likely due to the byte-at-at-time output style it uses.
