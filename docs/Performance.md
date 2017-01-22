# Performance

Performance is a key motivation for writing tools like this in D rather an interpreted language like Python or Perl. It is also a consideration in choosing between D and C/C++.

The tools created don't by themselves enable proper benchmark comparison. Equivalent tools written in the other languages would be needed for that. Still, there were a couple benchmarks that could be done to get a high level view of performance. These are given in this section.

Overall the D programs did well. Not as fast as a highly optimized C/C++ program, but meaningfully better than Python and Perl. Perl in particular fared quite poorly in these comparisons.

Perhaps the most surprising result is the poor performance of the utilities shipped with the Mac (`cut`, etc). It's worth installing the latest GNU coreutils versions if you are running on a Mac. (MacPorts and Homebrew are popular package managers that can install GNU tools.)

## tsv-select performance

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

## tsv-filter performance

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

## Relative performance of the tools

Runs against a 4.5 million line, 279 MB file were used to get a relative comparison of the tools. The original file was a CSV file, allowing inclusion of `csv2tsv`. The TSV file generated was used in the other runs. Running time of routines filtering data is dependent on the amount output, so a different output sizes were used. `tsv-join` depends on the size of the filter file, a file the same size as the output was used in these tests. Performance of these tools also depends on the options selected, so actuals will vary.

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

Performance of `tsv-filter` looks especially good, even when outputting a large number of records. It's not far off GNU `cut`. `tsv-join` and `tsv-uniq` are fast, but show an impact when larger hash tables are needed (4.5M entries in the slower cases). `csv2tsv` is a bit slower than the other tools for reasons that are not clear. It uses mechanisms not used in the other tools.
