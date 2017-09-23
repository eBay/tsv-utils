_Visit the eBay TSV utilities [main page](../README.md)_

# number-lines

A simpler version of the Unix `nl` program. It prepends a line number to each line read from files or standard input. This tool was written primarily as an example of a simple command line tool. The code structure it uses is the same as followed by all the other tools. Example:
```
$ number-lines myfile.txt
```

Despite it's original purpose as a code sample, `number-lines` turns out to be quite convenient. It is often useful to add a unique row ID to a file, and this tool does this in a manner that maintains proper TSV formatting.

See the [number-lines reference](../docs/ToolReference.md#tsv-number-lines-reference) for further details.
