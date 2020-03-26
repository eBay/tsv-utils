_Visit the eBay TSV utilities [main page](../README.md)_

# keep-header

`keep-header` is a convenience utility that runs unix commands in a header-aware fashion. It is especially useful with `sort`. `sort` does not know about headers, so the header line ends up wherever it falls in the sort order.  Using `keep-header`, the header line is output first and the rest of the sorted file follows. For example:
```
$ # Sort a file, keeping the header line at the top.
$ keep-header myfile.txt -- sort
```

The command to run is placed after the double dash (`--`). Everything after the initial double dash is part of the command. For example, `sort --ignore-case` is run as follows:
```
$ keep-header myfile.txt -- sort --ignore-case
```

Multiple files can be provided, only the header from the first is retained. For example:

```
$ # Sort a set of files in reverse order, keeping only one header line.
$ keep-header *.txt -- sort -r
```

`keep-header` is especially useful for commands like `sort` and `shuf` that reorder input lines. It is also useful with filtering commands like `grep`, many `awk` uses, and even `tail`, where the header should be retained without filtering or evaluation.

Examples:
```
$ # 'grep' a file, keeping the header line without needing to match it.
$ keep-header file.txt -- grep 'some text'

$ # Print the last 10 lines of a file, but keep the header line
$ keep-header file.txt -- tail

$ # Print lines 100-149 of a file, plus the header
$ keep-header file.txt -- tail -n +100 | head -n 51

$ # Sort a set of TSV files numerically on field 2, keeping one header.
$ keep-header *.tsv -- sort -t $'\t' -k2,2n

$ # Same as the previous example, but using the 'tsv-sort-fast' bash
$ # script described on the "Tips and Tricks" page.
$ keep-header *.tsv -- tsv-sort-fast -k2,2n
```

See the [keep-header reference](../docs/ToolReference.md#keep-header-reference) for more information.
