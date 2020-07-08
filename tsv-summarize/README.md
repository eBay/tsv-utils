_Visit the eBay TSV utilities [main page](../README.md)_

# tsv-summarize

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

See the [tsv-summarize reference](../docs/tool_reference/tsv-summarize.md) for the list of statistical and other aggregation operations available.
