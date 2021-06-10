_Visit the eBay TSV utilities [main page](../README.md)_

# tsv-join

Joins lines from multiple files based on a common key. One file, the 'filter' file, contains the records (lines) being matched. The other input files are scanned for matching records. Matching records are written to standard output, along with any designated fields from the filter file. In database parlance this is a hash semi-join. This is similar to the "stream-static" joins available in Spark Structured Streaming and "KStream-KTable" joins in Kafka. (The filter file plays the same role as the Spark static dataset or Kafka KTable.)

Example:
```
$ tsv-join -H --filter-file filter.tsv --key-fields Country,City --append-fields Population,Elevation data.tsv
```

This reads `filter.tsv`, creating a lookup table keyed on the `Country` and `City` fields. `data.tsv` is read, lines with a matching key are written to standard output with the `Population` and `Elevation` fields from `filter.tsv` appended. This is an inner join. Left outer joins and anti-joins are also supported.

Common uses for `tsv-join` are to join related datasets or to filter one dataset based on another. Filter file entries are kept in memory, this limits the ultimate size that can be handled effectively. The author has found that filter files up to about 10 million lines are processed effectively, but performance starts to degrade after that.

See the [tsv-join reference](../docs/tool_reference/tsv-join.md) for details.
