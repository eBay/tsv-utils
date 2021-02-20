_Visit the [Tools Reference main page](../ToolReference.md)_<br>
_Visit the [TSV Utilities main page](../../README.md)_

# tsv-pretty reference

**Synopsis:** tsv-pretty [options] [file...]

`tsv-pretty` outputs TSV data in a format intended to be more human readable when working on the command line. This is done primarily by lining up data into fixed-width columns. Text is left aligned, numbers are right aligned. Floating points numbers are aligned on the decimal point when feasible.

Processing begins by reading the initial set of lines into memory to determine the field widths and data types of each column. This look-ahead buffer is used for header detection as well. Output begins after this processing is complete.

By default, only the alignment is changed, the actual values are not modified. Several of the formatting options do modify the values.

Features:

* Floating point numbers: Floats can be printed in fixed-width precision, using the same precision for all floats in a column. This makes then line up nicely. Precision is determined by values seen during look-ahead processing. The max precision defaults to 9, this can be changed when smaller or larger values are desired. See the `--f|format-floats` and `--p|precision` options.

* Header lines: Headers are detected automatically when possible. This can be overridden when automatic detection doesn't work as desired. Headers can be underlined and repeated at regular intervals.

* Missing values: A substitute value can be used for empty fields. This is often less confusing than spaces. See `--e|replace-empty` and `--E|empty-replacement`.

* Exponential notation: As part of float formatting, `--f|format-floats` re-formats columns where exponential notation is found so all the values in the column are displayed using exponential notation and the same precision.

* Preamble: A number of initial lines can be designated as a preamble and output unchanged. The preamble is before the header, if a header is present. Preamble lines can be auto-detected via the heuristic that they lack field delimiters. This works well when the field delimiter is a TAB.

* Fonts: Fixed-width fonts are assumed. CJK characters are assumed to be double width. This is not always correct, but works well in most cases.

**Options:**

* `--help-verbose` - Print full help.
* `--H|header` - Treat the first line of each file as a header.
* `--x|no-header` -  Assume no header. Turns off automatic header detection.
* `--l|lookahead NUM` - Lines to read to interpret data before generating output. Default: 1000
* `--r|repeat-header NUM` - Lines to print before repeating the header. Default: No repeating header
* `--u|underline-header` - Underline the header.
* `--f|format-floats` - Format floats for better readability. Default: No
* `--p|precision NUM` - Max floating point precision. Implies --format-floats. Default: 9
* `--e|replace-empty` - Replace empty fields with `--`.
* `--E|empty-replacement STR` - Replace empty fields with a string.
* `--d|delimiter CHR` - Field delimiter. Default: TAB. (Single byte UTF-8 characters only.)
* `--s|space-between-fields NUM` - Spaces between each field (Default: 2)
* `--m|max-text-width NUM` - Max reserved field width for variable width text fields. Default: 40
* `--a|auto-preamble` - Treat initial lines in a file as a preamble if the line contains no field delimiters. The preamble is output unchanged.
* `--b|preamble NUM` - Treat the first NUM lines as a preamble and output them unchanged.
* `--V|version` - Print version information and exit.
* `--h|help` - This help information.

**Examples:**

A tab-delimited file printed without any formatting:
```
$ cat sample.tsv
Color   Count   Ht      Wt
Brown   106     202.2   1.5
Canary Yellow   7       106     0.761
Chartreuse	1139	77.02   6.22
Fluorescent Orange	422     1141.7  7.921
Grey	19	140.3	1.03
```
The same file printed with `tsv-pretty`:
```
$ tsv-pretty sample.tsv
Color               Count       Ht     Wt
Brown                 106   202.2   1.5
Canary Yellow           7   106     0.761
Chartreuse           1139    77.02  6.22
Fluorescent Orange    422  1141.7   7.921
Grey                   19   140.3   1.03
```
Printed with float formatting and header underlining:
```
$ tsv-pretty -f -u sample.tsv
Color               Count       Ht     Wt
-----               -----       --     --
Brown                 106   202.20  1.500
Canary Yellow           7   106.00  0.761
Chartreuse           1139    77.02  6.220
Fluorescent Orange    422  1141.70  7.921
Grey                   19   140.30  1.030
```
Printed with setting the precision to one:
```
$ tsv-pretty -u -p 1 sample.tsv
Color               Count      Ht   Wt
-----               -----      --   --
Brown                 106   202.2  1.5
Canary Yellow           7   106.0  0.8
Chartreuse           1139    77.0  6.2
Fluorescent Orange    422  1141.7  7.9
Grey                   19   140.3  1.0
```

