_Visit the eBay TSV utilities [main page](../README.md)_

# tsv-filter

`tsv-filter` outputs select lines by making numeric and string comparisons against individual fields. Multiple comparisons can be specified in a single call. A variety of numeric and string comparison operators are available, including regular expressions.

Consider a file having 4 fields: `id`, `color`, `year`, `count`. Using [tsv-pretty](../docs/ToolReference.md#tsv-pretty-reference) to view the first few lines:
```
$ tsv-pretty data.tsv | head -n 5
 id  color   year  count
100  green   1982    173
101  red     1935    756
102  red     2008   1303
103  yellow  1873    180
```

The following command will find all `red` entries with years between 1850 and 1950:

```
$ tsv-filter -H --str-eq 2:red --ge 3:1850 --lt 3:1950 data.tsv
```

Viewing the first few results:
```
$ tsv-filter -H --str-eq 2:red --ge 3:1850 --lt 3:1950 data.tsv | tsv-pretty | head -n 5
 id  color  year  count
101  red    1935    756
106  red    1883   1156
111  red    1907   1792
114  red    1931   1412
```

`tsv-filter` is the most widely applicable of the tools, as dataset pruning is a common task. It is stream oriented, so it can handle arbitrarily large files. It is quite fast, faster than other tools the author has tried. This makes it idea for preparing data for applications like R and Pandas. It is also convenient for quickly answering simple questions about a dataset. For example, to count the number of records with a non-zero value in field 4, use the command:
```
$ tsv-filter --ne 4:0 file.tsv | wc -l
```

Many filtering options are available. See the [tsv-filter reference](../docs/ToolReference.md#tsv-filter-reference) for details.
