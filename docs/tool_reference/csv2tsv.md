_Visit the [Tools Reference main page](../ToolReference.md)_<br>
_Visit the [TSV Utilities main page](../../README.md)_

# csv2tsv reference

**Synopsis:** csv2tsv [options] [file...]

csv2tsv converts CSV (comma-separated) text to TSV (tab-separated) format. Records are read from files or standard input, converted records are written to standard output.

Both formats represent tabular data, each record on its own line, fields separated by a delimiter character. The key difference is that CSV uses escape sequences to represent newlines and field separators in the data, whereas TSV disallows these characters in the data. The most common field delimiters are comma for CSV and TAB for TSV, but any character can be used. See [Comparing TSV and CSV formats](../comparing-tsv-and-csv.md) for additional discussion of the formats.

Conversion to TSV is done by removing CSV escape syntax, changing field delimiters, and replacing newlines and TABs in the data. By default, newlines and TABs in the data are replaced by spaces. Most details are customizable.

There is no single spec for CSV, any number of variants can be found. The escape syntax is common enough: fields containing newlines or field delimiters are placed in double quotes. Inside a quoted field, a double quote is represented by a pair of double quotes. As with field separators, the quoting character is customizable.

Behaviors of this program that often vary between CSV implementations:
* Newlines are supported in quoted fields.
* Double quotes are permitted in a non-quoted field. However, a field starting with a quote must follow quoting rules.
* Each record can have a different numbers of fields.
* The three common forms of newlines are supported: CR, CRLF, LF. Output is written using Unix newlines (LF).
* A newline will be added if the file does not end with one.
* A UTF-8 Byte Order Mark (BOM) at the start of an input file will be removed.
* No whitespace trimming is done.

This program does not validate CSV correctness, but will terminate with an error upon reaching an inconsistent state. Improperly terminated quoted fields are the primary cause.

UTF-8 input is assumed. Convert other encodings prior to invoking this tool.

**Options:**
* `--h|help` - Print help.
* `--help-verbose` - Print detailed help.
* `--V|version` - Print version information and exit.
* `--H|header` - Treat the first line of each file as a header. Only the header of the first file is output.
* `--q|quote CHR` - Quoting character in CSV data. Default: double-quote (")
* `--c|csv-delim CHR` - Field delimiter in CSV data. Default: comma (,).
* `--t|tsv-delim CHR` - Field delimiter in TSV data. Default: TAB
* `--r|tab-replacement STR` - Replacement for TSV field delimiters (typically TABs) found in CSV input. Default: Space.
* `--n|newline-replacement STR` - Replacement for newlines found in CSV input. Default: Space.
