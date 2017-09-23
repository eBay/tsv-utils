_Visit the [main page](../README.md)_

# csv2tsv

TSV files have many advantages over CSV files for data processing, but CSV is a very common exchange format. This tool does what you expect: convert CSV data to TSV. Example:
```
$ csv2tsv data.csv > data.tsv
```

Using a `csv2tsv` converter is worthwhile even when a CSV file is not believed to use CSV escapes, as it eliminates any doubts. This allows the data to be used reliably with tools from the TSV utilities toolkit as well as traditional Unix tools like `awk` and `cut`.

Another useful benefit of the `csv2tsv` converter is that it normalizes newlines. Many programs generate Windows newlines when exporting in CSV format, even on Unix systems.

CSV files come in different formats. See the [csv2tsv reference](../docs/ToolReference.md#csv2tsv-reference) for details of how this tool operates and the format variations handled.
