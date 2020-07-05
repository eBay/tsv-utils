_Visit the [Tools Reference main page](../ToolReference.md)_<br>
_Visit the [TSV Utilities main page](../../README.md)_

# tsv-join reference

**Synopsis:** tsv-join --filter-file file [options] [file...]

tsv-join matches input lines (the 'data stream') against lines from a 'filter' file. The match is based on exact match comparison of one or more 'key' fields. The data stream is read from files or standard input. Matching lines are written to standard output, along with any additional fields from the filter file that have been specified.

This is similar to the "stream-static" joins available in Spark Structured Streaming and "KStream-KTable" joins in Kafka. The filter file plays the same role as the Spark static dataset or Kafka KTable.

The filter file needs to fit into available memory (the join key and append fields). The data stream is processed one line at a time and can be arbitrarily large.

**Options:**
* `--h|help` - Print help.
* `--h|help-verbose` - Print detailed help.
* `--help-fields ` - Print help on specifying fields.
* `--V|version` - Print version information and exit.
* `--f|filter-file FILE` - (Required) File with records to use as a filter.
* `--k|key-fields <field-list>` - Fields to use as join key. Default: 0 (entire line).
* `--d|data-fields <field-list>` - Data stream fields to use as join key, if different than `--key-fields`.
* `--a|append-fields <field-list>` - Filter file fields to append to matched records.
* `--H|header` - Treat the first line of each file as a header.
* `--p|prefix STR` - String to use as a prefix for `--append-fields` when writing a header line.
* `--w|write-all STR` - Output all data stream records. STR is the `--append-fields` value when writing unmatched records. This is a left outer join. (The data stream is the 'left'.)
* `--e|exclude` - Exclude matching records. This is an anti-join.
* `--delimiter CHR` - Field delimiter. Default: TAB. (Single byte UTF-8 characters only.)
* `--z|allow-duplicate-keys` - Allow duplicate keys with different append values (last entry wins). Default behavior is that this is an error.

**Examples:**

Join using the `Name` field as the key. The `Name` field may be in different columns in the filter file and data stream files. All matching rows from `data.tsv` are written to standard output. The output order is the same as in `data.tsv`.
```
$ tsv-join -H --filter-file filter.tsv --key-fields Name data.tsv
```

Join using the `Name` field as key, but also append the `RefID` field from the filter file.
```
$ tsv-join -H -f filter.tsv -k Name --append-fields RefID data.tsv
```

Exclude lines from the data stream having the same `RecordNum` as a line in the filter file.
```
$ tsv-join -H -f filter.tsv -k RecordNum --exclude data.tsv
```

Filter multiple files, using field numbers 2 & 3 as the join key.
```
$ tsv-join -f filter.tsv -k 2,3 data1.tsv data2.tsv data3.tsv
```

Same as previous, except use fields 4 & 5 from the data files as the key.
```
$ tsv-join -f filter.tsv -k 2,3 -d 4,5 data1.tsv data2.tsv data3.tsv
```

Same as the previous command, but reading the data stream from standard input.
```
$ cat data*.tsv | tsv-join -f filter.tsv -k 2,3 -d 4,5
```

Add population data from `cities.tsv` to a data stream.
```
$ tsv-join -H -f cities.tsv -k CityID --append-fields Population data.tsv
```

As in the previous example, add population data, but this time write all records. Use the value '-1' if the city does not appear in the `cities.tsv` file. This is a left outer join, with the data stream as 'left'.
```
$ tsv-join -H -f cities.tsv -k CityID -a Population --write-all -1 Population data.tsv
```

Filter one file based on another, using the full line as the key.
```
$ tsv-join -f filter.txt data.txt
```

Modifying output headers: Often it's useful to append a field that has a name identical to a field already in the data stream files. The '--p|prefix' option can be used to rename the appended field and avoid name duplication. The following command joins on the `test_id` field, appending the `time` field to matched records. The header for the appended field is `run1_time`, differentiating it from an existing `time` field in the data file (run2.tsv).
```
$ tsv-join -f run1.tsv run2.tsv -H -k test_id --append-fields time --prefix run1_
```

The prefix will be applied to all appended fields. The next example is similar to the previous one, except that it appends all fields ending in `_time`, prefixing `run1_` to all the appended field names:
```
$ tsv-join -f run1.tsv run2.tsv -H -k test_id -a '*_time' --prefix run1_
```
