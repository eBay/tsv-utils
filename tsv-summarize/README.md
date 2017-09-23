_Visit the eBay TSV utilities [main page](../README.md)_

# tsv-summarize

`tsv-summarize` runs aggregation operations on fields. For example, generating the sum or median of a field's values. Summarization calculations can be run across the entire input or can be grouped by key fields. As an example, consider the file `data.tsv`:
```
color   weight
red     6
red     5
blue    15
red     4
blue    10
```
Calculation of the sum and mean of the `weight` column are below. The first command runs calculations on all values. The second groups them by color.
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

See the [tsv-summarize reference](../docs/ToolReference.md#tsv-summarize-reference) for the list of statistical and other aggregation operations available.
