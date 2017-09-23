_Visit the eBay TSV utilities [main page](../README.md)_

# tsv-pretty

tsv-pretty prints TSV data in an aligned format for better readability when working on the command-line. Text columns are left aligned, numeric columns are right aligned. Floats aligned on the decimal point and precision can be specified. Header lines are detected automatically. If desired, the header line can be repeated at regular intervals.

An example, first printed without formatting:
```
$ cat sample.tsv
Color   Count   Ht      Wt
Brown   106     202.2   1.5
Canary Yellow   7       106     0.761
Chartreuse	1139	77.02   6.22
Fluorescent Orange	422     1141.7  7.921
Grey	19	140.3	1.03
```
Now with `tsv-pretty`, using header underlining and float formatting:
```
$ tsv-pretty -u -f sample.tsv
Color               Count       Ht     Wt
-----               -----       --     --
Brown                 106   202.20  1.500
Canary Yellow           7   106.00  0.761
Chartreuse           1139    77.02  6.220
Fluorescent Orange    422  1141.70  7.921
Grey                   19   140.30  1.030
```
See the [tsv-pretty reference](../docs/ToolReference.md#tsv-pretty-reference) for details.
