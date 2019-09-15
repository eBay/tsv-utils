_Visit the [Performance Benchmarks main page](Performance.md)_<br>
_Visit the [TSV Utilities main page](../README.md)_

# March 2017 Comparative Benchmarks

* [Summary](#summary)
* [Comparative Benchmarks](#comparative-benchmarks)
* [DMD vs LDC](#dmd-vs-ldc)
* [Relative performance of the tools](#relative-performance-of-the-tools)

## Summary

This performance benchmark study compared eBay's TSV Utilities to similar tools written in other native lanugages. These studies were intended to guage D's performance when writing code in a straightforward fashion, as might occur in the context of a software development team. See the [main performance benchmarks page](Performance.md) for additional discussion of the goals and motivations behind the study. See the [April 2018 Comparative Benchmarks Update](comparative-benchmarks-2018.md) for an update to this study.

## Comparative benchmarks

Six tasks were used as benchmarks. Two forms of row filtering: numeric comparisons and regular expression match. Column selection (aka 'cut'). Join two files on a common key. Simple statistical calculations (e.g. mean of column values). Convert CSV files to TSV. Reasonably large files were used, one 4.8 GB, 7 million rows, the other 2.7 GB, 14 million rows. Tests against smaller files gave results consistent with the larger file tests.

Tests were conducted on a MacBook Pro, 16 GB RAM, 4 cores, and flash storage. All tools were updated to current versions, and several of the specialty toolkits were built from current source code. Run-time was measured using the `time` facility. Each benchmark was run three times and the fastest run recorded.

Specialty toolkit times have been anonymized in the tables below. The intent of this study is to gauge performance of the D tools, not create a shootout between toolkits. However, the specific tools and command lines are given, enabling tests to be reproduced. (The csv-to-tsv times are shown, see [CSV to TSV conversion](#csv-to-tsv-conversion) for rationale.) See [Other toolkits](OtherToolkits.md) for links to the tools, and [Details](#details) for version info, compilers, and test file details. Python tools were not benchmarked, this would be a useful addition. Tools that run in in-memory environments like R were excluded.

The worst performers were the Unix tools shipped with the Mac (`cut`, etc). It's worth installing the GNU coreutils package if you use command line tools on the Mac. (MacPorts and Homebrew can install these tools.)

Specific considerations to keep in mind when comparing individual tools:
* Tools accepting CSV data must handle escape characters. This is computationally more expensive than a strict delimited format like TSV. Supporting both CSV and TSV makes optimizing the TSV case challenging.
* Some CSV implementations support embedded newlines, others do not. Embedded newline support is more challenging because highly optimized "readline" routines cannot be used to find record boundaries.
* Handling arbitrary expression trees (ala `Awk`) is more computationally complex than the handling a single conjunctive or disjunctive expression list as `tsv-filter` does.
* Some tools use multi-threading, others do not. (The D tools do not.) This is a design tradeoff. Running multiple threads can improve run-times of individual tools. However, this may reduce overall throughput when several tools are chained in a command pipeline.

### Top four in each benchmark

This table shows fastest times for each benchmark. Times are in seconds. Complete results for each benchmark are in the succeeding sections. eBay's TSV Utilities were the fastest on each test.

| Benchmark              |       Tool/Time | Tool/Time | Tool/Time | Tool/Time |
| ---------------------- | --------------: | --------: | --------: | --------: |
| **Numeric row filter** |    _tsv-filter_ |      mawk |   GNU awk | Toolkit 1 |
| (4.8 GB, 7M lines)     |            4.34 |     11.71 |     22.02 |     53.11 |
| **Regex row filter**   |    _tsv-filter_ |   GNU awk |      mawk | Toolkit 1 |
| (2.7 GB, 14M lines)    |            7.11 |     15.41 |     16.58 |     28.59 |
| **Column selection**   |    _tsv-select_ |      mawk |   GNU cut | Toolkit 1 |
| (4.8 GB, 7M lines)     |            4.09 |      9.38 |     12.27 |     19.12 |
| **Join two files**     |      _tsv-join_ | Toolkit 1 | Toolkit 2 | Toolkit 3 |
| (4.8 GB, 7M lines)     |           20.78 |    104.06 |    194.80 |    266.42 |
| **Summary statistics** | _tsv-summarize_ | Toolkit 1 | Toolkit 2 | Toolkit 3 |
| (4.8 GB, 7M lines)     |           15.83 |     40.27 |     48.10 |     62.97 |
| **CSV-to-TSV**         |       _csv2tsv_ |     csvtk |       xsv |           |
| (2.7 GB, 14M lines)    |           27.41 |     36.26 |     40.40 |           |

### Numeric filter benchmark

This operation filters rows from a TSV file based on a numeric comparison (less than, greater than, etc) of two fields in a line. A 7 million line, 29 column, 4.8 GB numeric data file was used. The filter matched 1.2 million lines.

| Tool                  | Time (seconds) |
| --------------------- | -------------: |
| **tsv-filter**        |           4.34 |
| mawk (M. Brennan Awk) |          11.71 |
| GNU awk               |          22.02 |
| Toolkit 1             |          53.11 |
| awk (Mac built-in)    |         286.57 |

Command lines:
```
$ [awk|mawk|gawk] -F $'\t' -v OFS='\t' '{ if ($4 > 0.000025 && $16 > 0.3) print $0 }' hepmass_all_train.tsv >> /dev/null
$ tsv-filter -H --gt 4:0.000025 --gt 16:0.3 hepmass_all_train.tsv >> /dev/null
```
*Note: Only one specialty toolkit supports this feature, so its command line is not shown.*

### Regular expression filter benchmark

This operation filters rows from a TSV file based on a regular comparison against a field. The regular expression used was '[RD].*(ION[0-2])', it was matched against a text field. The input file was 14 million rows, 49 columns, 2.7 GB. The filter matched 150K rows. Other regular expressions were tried, results were similar.

| Tool                  | Time (seconds) |
| --------------------- | -------------: |
| **tsv-filter**        |           7.11 |
| GNU awk               |          15.41 |
| mawk (M. Brennan Awk) |          16.58 |
| Toolkit 1             |          28.59 |
| Toolkit 2             |          42.72 |
| awk (Mac built-in)    |         113.55 |
| Toolkit 3             |         125.31 |

Command lines:
```
$ [awk|gawk|mawk] -F $'\t' -v OFS='\t' '$10 ~ /[RD].*(ION[0-2])/' TREE_GRM_ESTN_14mil.tsv >> /dev/null
$ cat TREE_GRM_ESTN_14mil.tsv | csvtk grep -t -l -f 10 -r -p '[RD].*(ION[0-2])' >> /dev/null
$ mlr --tsvlite --rs lf filter '$COMPONENT =~ "[RD].*(ION[0-2])"' TREE_GRM_ESTN_14mil.tsv >> /dev/null
$ xsv search -s COMPONENT '[RD].*(ION[0-2])' TREE_GRM_ESTN_14mil.tsv >> /dev/null
$ tsv-filter -H --regex 10:'[RD].*(ION[0-2])' TREE_GRM_ESTN_14mil.tsv >> /dev/null
```

Note: For `xsv`, the more correct way to operate on unescaped TSV files is to first pipe the data through `xsv input --no-quoting` first. e.g.
```
$ xsv input --no-quoting TREE_GRM_ESTN_14mil.tsv | xsv search -s COMPONENT '[RD].*(ION[0-2])' >> /dev/null
```

However, adding an additional command invocation runs counter to the goals of the benchmark exercise, so it was not used in these tests. This is the case for all the `xsv` command lines, except for csv-to-tsv conversion.

### Column selection benchmark

This is the traditional Unix `cut` operation. Surprisingly, the `cut` implementations were not the fastest. The test selected fields 1, 8, 19 from a 7 million line, 29 column, 4.8 GB numeric data file.

| Tool                  | Time (seconds) |
| --------------------- |--------------: |
| **tsv-select**        |           4.09 |
| mawk (M. Brennan Awk) |           9.38 |
| GNU cut               |          12.27 |
| Toolkit 1             |          19.12 |
| Toolkit 2             |          32.90 |
| GNU awk               |          33.09 |
| Toolkit 3             |          46.32 |
| cut (Mac built-in)    |          78.01 |
| awk (Mac built-in)    |         287.19 |

_Note: GNU cut is faster than tsv-select on small files, e.g. 250 MB. See [Relative performance of the tools](#relative-performance-of-the-tools) for an example._

Command lines:
```
$ [awk|gawk|mawk] -F $'\t' -v OFS='\t' '{ print $1,$8,$19 }' hepmass_all_train.tsv >> /dev/null
$ csvtk cut -t -l -f 1,8,19 hepmass_all_train.tsv >> /dev/null
$ cut -f 1,8,19 hepmass_all_train.tsv >> /dev/null
$ mlr --tsvlite --rs lf cut -f label,f6,f17 hepmass_all_train.tsv >> /dev/null
$ tsv-select -f 1,8,19 hepmass_all_train.tsv >> /dev/null
$ xsv select 1,8,19 hepmass_all_train.tsv >> /dev/null
```

### Join two files

This test was done taking a 7 million line, 29 column numeric data file, splitting it into two files, one containing columns 1-15, the second columns 16-29. Each line contained a unique row key shared by both files. The rows of each file were randomized. The join task reassembles the original file based on the shared row key. The original file is 4.8 GB, each half is 2.4 GB.

| Tool         | Time (seconds) |
| ------------ |--------------: |
| **tsv-join** |          20.78 |
| Toolkit 1    |         104.06 |
| Toolkit 2    |         194.80 |
| Toolkit 3    |         266.42 |

Command lines:
```
$ csvtk join -t -l -f 1 hepmass_left.shuf.tsv hepmass_right.shuf.tsv >> /dev/null
$ mlr --tsvlite --rs lf join -u -j line -f hepmass_left.shuf.tsv hepmass_right.shuf.tsv >> /dev/null
$ tsv-join -H -f hepmass_right.shuf.tsv -k 1 hepmass_left.shuf.tsv -a 2,3,4,5,6,7,8,9,10,11,12,13,14,15 >> /dev/null
$ xsv join 1 -d $'\t' hepmass_left.shuf.tsv 1 hepmass_right.shuf.tsv >> /dev/null
```

Creating the left and right data files:
```
$ number-lines -s line hepmass_all_train.tsv > hepmass_numbered.tsv
$ tsv-select -f 1-16 hepmass_numbered.tsv | tsv-sample -H > hepmass_left.shuf.tsv
$ tsv-select -f 1,17-30 hepmass_numbered.tsv | tsv-sample -H > hepmass_right.shuf.tsv
$ rm hepmass_numbered.tsv
```

*Note: The `tsv-select` call above uses field range notation introduced in version 1.1.11. List each field individually if using an earlier version. The Unix `nl`, `cut`, and `shuf` can also be used. The header line must be handled specially if `nl` or `shuf` are used.*

### Summary statistics

This test generates a set of summary statistics from the columns in a TSV file. The specific calculations were based on summary statistics available in the different available tools that had high overlap. The sets were not identical, but were close enough for rough comparison. Roughly, the count, sum, min, max, mean, and standard deviation of three fields from a 7 million row, 4.8 GB data file.

| Tool              | Time (seconds) |
| ------------------|--------------: |
| **tsv-summarize** |          15.83 |
| Toolkit 1         |          40.27 |
| Toolkit 2         |          48.10 |
| Toolkit 3         |          62.97 |
| Toolkit 4         |          67.17 |

Command lines:
```
$ csvtk stat2 -t -l -f 3,5,20 hepmass_all_train.tsv >> /dev/null
$ cat hepmass_all_train.tsv | datamash -H count 3 sum 3,5,20 min 3,5,20 max 3,5,20 mean 3,5,20 sstdev 3,5,20 >> /dev/null
$ mlr --tsvlite --rs lf stats1 -f f1,f3,f18 -a count,sum,min,max,mean,stddev hepmass_all_train.tsv >> /dev/null
$ tsv-summarize -H --count --sum 3,5,20 --min 3,5,20 --max 3,5,20 --mean 3,5,20 --stdev 3,5,20 hepmass_all_train.tsv >> /dev/null
$ xsv stats -s 3,5,20 hepmass_all_train.tsv >> /dev/null
```

### CSV to TSV conversion

This test converted a CSV file to TSV format. The file used was 14 million rows, 49 columns, 2.7 GB. This is the most competitive of the benchmarks, each of the tools having been the fastest in a previous version of this report. The D tool, `csv2tsv`, was third fastest until buffered writes were used in version 1.1.1.

| Tool        | Time (seconds) |
| ----------- |--------------: |
| **csv2tsv** |          27.41 |
| csvtk       |          36.26 |
| xsv         |          40.40 |

_Note: Speciality toolkits times are shown for this test. That is because previous versions of this report gave the fastest toolkit time. Each tool was at one point the fastest, so these times were previously reported._

Command lines:
```
$ csvtk csv2tab TREE_GRM_ESTN_14mil.csv >> /dev/null
$ csv2tsv TREE_GRM_ESTN_14mil.csv >> /dev/null
$ xsv fmt -t '\t' TREE_GRM_ESTN_14mil.csv >> /dev/null
```

### Details

* Machine: MacBook Pro, 2.8 GHz, 16 GB RAM, 4 cores, 500 GB flash storage, OS X Sierra.
* Test files:
  * hepmass_all_train.tsv - 7 million lines, 4.8 GB. The HEPMASS training set from the UCI Machine Learning repository, available [here](https://archive.ics.uci.edu/ml/datasets/HEPMASS).
  * TREE_GRM_ESTN_14mil.[csv\|tsv] - 14 million lines, 2.7 GB. From the Forest Inventory and Analysis Database, U.S. Department of Agriculture. The first 14 million lines from the TREE_GRM_ESTN.csv file, available [here](https://apps.fs.usda.gov/fia/datamart/CSV/datamart_csv.html).
* Tools and version info (latest versions as of 3/3/2017). Several built from current source:
  * OS X awk; version 20070501; written in C.
  * [GNU Awk](https://www.gnu.org/software/gawk/) version 4.1.4 (gawk); written in C.
  * [mawk](http://invisible-island.net/mawk/mawk.html) version 1.3.4 (Michael Brennan awk); written in C.
  * OS X cut (from OS X Sierra, no version info); written in C.
  * GNU cut ([GNU coreutils](https://www.gnu.org/software/coreutils/coreutils.html)) version 8.26; written in C.
  * [GNU datamash](https://www.gnu.org/software/datamash/) version 1.1.1; written in C.
  * [csvtk](https://github.com/shenwei356/csvtk) version v0.5.0; written in Go.
  * [Miller](https://github.com/johnkerl/miller) (mlr) version 5.0.0; written in C.
  * [eBay's TSV Utilities](https://github.com/eBay/tsv-utils) version v1.1.1 (this toolkit); written in D.
  * [xsv](https://github.com/BurntSushi/xsv) version 0.10.3; written in Rust.
* Compilers:
  * LDC 1.1 (D compiler, Phobos 2.071.2)
  * Apple clang 8.0.0 (C/C++)
  * Go 1.8.
  * Rust 1.15.1

## DMD vs LDC

It is understood that the LDC compiler produces faster executables than the DMD compiler. But how much faster? To get some data, the set of benchmarks described above was used to compare to LDC and DMD. In this case, DMD version 2.073.1 was compared to LDC 1.1. LDC 1.1 uses an older version of the standard library (Phobos), version 2.071.2. LDC was faster on all benchmarks, in some cases up to a 2x delta.

| Test/tool                     | LDC Time (seconds) | DMD Time (seconds) |
| ----------------------------- |------------------: | -----------------: |
| Numeric filter (tsv-filter)   |               4.34 |               5.56 |
| Regex filter (tsv-filter)     |               7.11 |              11.29 |
| Column select (tsv-select)    |               4.09 |               9.46 |
| Join files (tsv-join)         |              20.78 |              41.23 |
| Stats summary (tsv-summarize) |              15.83 |              18.37 |
| CSV-to-TSV (csv2tsv)          |              27.41 |              56.08 |

## Relative performance of the tools

Runs against a 4.5 million line, 279 MB file were used to get a relative comparison of the tools. The original file was a CSV file, allowing inclusion of `csv2tsv`. The TSV file generated was used in the other runs. Execution time when filtering data is highly dependent on the amount of output, so different output sizes were tried. `tsv-join` depends on the size of the filter file, a file the same size as the output was used in these tests. Performance also depends on the specific command line options selected, so actuals will vary.

| Tool         | Records output | Time (seconds) |
| ------------ | -------------: | -------------: |
| tsv-filter   |        513,788 |           0.66 |
| number-lines |      4,465,613 |           0.98 |
| cut (GNU)    |      4,465,613 |           0.99 |
| tsv-filter   |      4,125,057 |           1.03 |
| tsv-join     |         65,537 |           1.20 |
| tsv-select   |      4,465,613 |           1.21 |
| tsv-uniq     |         65,537 |           1.26 |
| csv2tsv      |      4,465,613 |           2.55 |
| tsv-uniq     |      4,465,613 |           3.52 |
| tsv-join     |      4,465,613 |           5.86 |

Performance of `tsv-filter` looks especially good. Even when outputting a large number of records it is not far off GNU `cut`. Unlike the larger file tests, GNU `cut` is faster than `tsv-select` on this metric. This suggests GNU `cut` may have superior buffer management strategies when operating on smaller files. `tsv-join` and `tsv-uniq` are fast, but show an impact when larger hash tables are needed (4.5M entries in the slower cases). `csv2tsv` has improved significantly in the latest release, but is still slower than the other tools given the work it is doing.
