_Visit the [main page](../README.md)_

# Comparing TSV and CSV formats

The differences between TSV and CSV formats can be confusing. The obvious distinction is the default field delimiter: TSV uses TAB, CSV uses comma. Both use newline as the record delimiter.

By itself, having different default field delimiters is not especially significant. Far more important is the approach to delimiters occurring in the data. CSV uses an escape syntax to represent comma and newlines in the data. TSV takes a different approach, disallowing TABs and newlines in the data.

The escape syntax enables CSV to fully represent common written text. This is a good fit for human edited documents, notably spreadsheets. This generality has a cost: reading it requires programs to parse the escape syntax. While not overly difficult, it is still easy to do incorrectly, especially when writing one-off programs. It is good practice is to use a CSV parser when processing CSV files. Traditional Unix tools like `cut` and `awk` do not process CSV escapes, alternate tools are needed.

By contrast, parsing TSV data is simple. Records can be read using the typical `readline` routines. The fields in each record can be found using a `split` or `splitter` routine available in most programming languages. No special parser is needed. This is much more reliable. It is also faster, no CPU time is used parsing the escape syntax.

This makes TSV format well suited for the large tabular data sets common in data mining and machine learning environments. These data sets rarely need TAB and newline characters in the fields.

The most common CSV escape format uses quotes to delimit fields containing delimiters. Quotes must also be escaped, this is done by using a pair of quotes to represent a single quote. Consider the data in this table:

| Field-1 | Field-2              | Field-3 |
| ------- | -------------------- | ------- |
| abc     | hello, world!        | def     |
| ghi     | Say "hello, world!"  | jkl     |

In field2, the first value contains a comma, the second value contain both quotes and a comma. Here is the CSV representation, using escapes to represent commas and quotes in the data.
```
Field-1,Field-2,Field-3
abc,"hello, world!",def
ghi,"Say ""hello, world!""",jkl
```

In the above example, only fields with delimiters are quoted. It is also common to quote all fields whether or not they contain delimiters. The following CSV file is equivalent:
```
"Field-1","Field-2","Field-3"
"abc","hello, world!","def"
"ghi","Say ""hello, world!""","jkl"
```

Here's the same data in TSV. It is much simpler as no escapes are involved:
```
Field-1	Field-2	Field-3
abc	hello, world	def
ghi	Say "hello, world!"	jkl
```

The similarity between TSV and CSV can lead to confusion about which tools are appropriate. Furthering this confusion, it is somewhat common to have data files using comma as the field delimiter, but without comma, quote, or newlines in the data. No CSV escapes are needed in these files, with the implication that traditional Unix tools like `cut` and `awk` can be used to process these files. Such files are sometimes referred to as "simple CSV". They are equivalent to TSV files with comma as a field delimiter. Traditional Unix tools and the TSV Utilities can process these files correctly by specifying the field delimiter. However, "simple csv" is a very ad hoc and ill defined notion. A simple precaution when working with these files is to run a CSV-to-TSV converter like the [csv2tsv](ToolReference.md#csv2tsv-reference) prior to other processing steps.

References:
- [Wikipedia: Tab-separated values](https://en.wikipedia.org/wiki/Tab-separated_values) - Useful description of TSV format.
- [IANA TSV specification](https://www.iana.org/assignments/media-types/text/tab-separated-values) - Formal definition of the tab-separated-values mime type.
- [Wikipedia: Comma-separated-values](https://en.wikipedia.org/wiki/Comma-separated_values) - Describes CSV and related formats.
- [RFC 4180](https://tools.ietf.org/html/rfc4180) - IETF CSV format description, the closest thing to an actual standard for CSV.
- [brendano/tsvutils: The philosophy of tsvutils](https://github.com/brendano/tsvutils#the-philosophy-of-tsvutils) - Brendan O'Connor's discussion of the rationale for using TSV format in his open source toolkit.
