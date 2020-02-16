_Visit the eBay TSV utilities [main page](../README.md)_

# tsv-filter

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
$ tsv-filter -H --eq 3:2008 data.tsv
```

The `--eq` operator performs a numeric equality test. String comparisons are also available. The following command finds entries where 'color' (field 2) is "red":
```
$ tsv-filter -H --str-eq 2:red data.tsv
```

Fields are identified by a 1-up field number, same as traditional Unix tools. The `-H` option preserves the header line.

Multiple tests can be specified. The following command finds `red` entries with years between 1850 and 1950:
```
$ tsv-filter -H --str-eq 2:red --ge 3:1850 --lt 3:1950 data.tsv
```

Viewing the first few results produced by this command:
```
$ tsv-filter -H --str-eq 2:red --ge 3:1850 --lt 3:1950 data.tsv | tsv-pretty | head -n 5
 id  color  year  count
101  red    1935    756
106  red    1883   1156
111  red    1907   1792
114  red    1931   1412
```

Files can be placed anywhere on the command line. Data will be read from standard input if a file is not specified. The following commands are equivalent:
```
$ tsv-filter -H --str-eq 2:red --ge 3:1850 --lt 3:1950 data.tsv
$ tsv-filter data.tsv -H --str-eq 2:red --ge 3:1850 --lt 3:1950
$ cat data.tsv | tsv-filter -H --str-eq 2:red --ge 3:1850 --lt 3:1950
```

Multiple files can be provided. Only the header line from the first file will be kept when the `-H` option is used:
```
$ tsv-filter -H data1.tsv data2.tsv data3.tsv --str-eq 2:red --ge 3:1850 --lt 3:1950
$ tsv-filter -H *.tsv --str-eq 2:red --ge 3:1850 --lt 3:1950
```

Numeric comparisons are among the most useful tests. Numeric operators include:
* Equality: `--eq`, `--ne` (equal, not-equal).
* Relational: `--lt`, `--le`, `--gt`, `--ge` (less-than, less-equal, greater-than, greater-equal).

Several filters are available to help with invalid entries. Assume there is a messier version of the 4-field file where some fields are not filled in. The following command will filter out all lines with an empty value in any of the four fields:
```
$ tsv-filter -H messy.tsv --not-empty 1-4
```

The above command uses a "field list" to specify running the test on each of fields 1-4. The test can be "inverted" to see the lines that were filtered out:
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

Most of the TSV Utilities tools support field lists. See [Field numbers and field-lists](docs/ToolReference.md#field-numbers-and-field-lists) in the [Tools reference](docs/ToolReference.md) document for details.

Bash completion is especially helpful with `tsv-filter`. It allows quickly seeing and selecting from the different operators available. See [bash completion](docs/TipsAndTricks.md#enable-bash-completion) on the [Tips and tricks](docs/TipsAndTricks.md) page for setup information.

`tsv-filter` is perhaps the most broadly applicable of the TSV Utilities tools, as dataset pruning is such a common task. It is stream oriented, so it can handle arbitrarily large files. It is fast, quite a bit faster than other tools the author has tried. (See the "Numeric row filter" and "Regular expression row filter" tests in the [2018 Benchmark Summary](docs/Performance.md#2018-benchmark-summary).)

This makes `tsv-filter` ideal for preparing data for applications like R and Pandas. It is also convenient for quickly answering simple questions about a dataset. For example, to count the number of records with a non-zero value in field 4, use the command:
```
$ tsv-filter --ne 4:0 file.tsv | wc -l
```

See the [tsv-filter reference](../docs/ToolReference.md#tsv-filter-reference) for more details and the full list of operators.
