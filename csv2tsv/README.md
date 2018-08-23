_Visit the eBay TSV utilities [main page](../README.md)_

# csv2tsv

This tool does what you expect: convert CSV data to TSV. Example:
```
$ csv2tsv data.csv > data.tsv
```

TSV files have many advantages over CSV files for large scale data processing, but CSV is a very common exchange format. Data from spreadsheets, databases, and other tools is often exported in CSV format.

The main issue when working with CSV data is the potential for CSV escapes in the data. Standard Unix tools like `cut`, `awk`, and `sort` do not work properly if the data contains CSV escapes, and neither do eBay's TSV Utilities. The `csv2tsv` tool eliminates issues with CSV escapes, allowing the resulting data to be processed correctly by both eBay's TSV Utilities and standard Unix tools.

Another useful benefit of the `csv2tsv` converter is that it normalizes newlines. Many programs generate Windows newlines when exporting in CSV format, even on Unix systems.

CSV files come in different formats. See the [csv2tsv reference](../docs/ToolReference.md#csv2tsv-reference) for details of how this tool operates and the format variations handled.

See [Comparing TSV and CSV formats](../docs/comparing-tsv-and-csv.md) for more information on CSV escapes and other differences between CSV and TSV formats.
