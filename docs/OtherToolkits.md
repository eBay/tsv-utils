_Visit the [main page](../README.md)_

# Other open-source tools

There are a number of open-source toolkits with functionality similar to the TSV Utilities. Several are listed below. Those handling CSV files handle TSV files as well:

* [clarkgrubb/data-tools](https://github.com/clarkgrubb/data-tools) - A variety of tools, especially rich in format converters. Written in Python, Ruby, and C.
* [csvkit](https://github.com/wireservice/csvkit) - CSV tools, written in Python.
* [csvtk](https://github.com/shenwei356/csvtk) - CSV tools, written in Go.
* [GNU Datamash](https://www.gnu.org/software/datamash/) - Performs numeric, textual and statistical operations on TSV files. Has many similarities to  [tsv-summarize](ToolReference.md#tsv-summarize-reference). Written in C.
* [dplyr](https://github.com/hadley/dplyr) - Tools for tabular data in R storage formats. Runs in an R environment, code is in C++.
* [miller](https://github.com/johnkerl/miller) - CSV and JSON tools, written in C.
* [GNU shuf](https://www.gnu.org/software/coreutils/manual/html_node/shuf-invocation.html), part of [GNU Core Utils](https://www.gnu.org/software/coreutils/coreutils.html) - Generates permutations of input lines. Sampling with and without replacement is supported. This tool has many of the same features as [tsv-sample](ToolReference.md#tsv-sample-reference). Written in C.
* [brendano/tsvutils](https://github.com/brendano/tsvutils) - TSV tools, especially rich in format converters. Written in Python.
* [xsv](https://github.com/BurntSushi/xsv) - CSV tools, written in Rust.

A much more comprehensive list of tools can be found here: [Structured text tools](https://github.com/dbohdan/structured-text-tools).

The different toolkits are certainly worth investigating if you work with tabular data files. Several have quite extensive feature sets. Each toolkit has its own strengths, your workflow and preferences are likely to fit some toolkits better than others.

File format is perhaps the most important dimension. CSV files cannot be processed reliably by traditional unix tools, a fundamental consideration. CSV toolkits naturally extend into the space of traditional Unix tools. For example, many CSV toolkits have their own "sort" functionality, as the Unix `sort` function cannot reliably operate on CSV files. Same for basic operations like `head` and `tail`. Though most CSV toolkits operate on TSV files as well, it is often more complicated and error prone than using tools that default to TSV. This is especially true if the TSV data includes comma and quote characters that would be escaped in CSV format. CSV tools often require additional command line arguments specifying quoting rules when working with TSV data.

Tradeoffs between file formats is its own topic. Appropriate choice of format is often dependent on the specifics of the environment and tasks being performed. See [Comparing TSV and CSV formats](comparing-tsv-and-csv.md) for a discussion of TSV and CSV formats. The [brendano/tsvutils README](https://github.com/brendano/tsvutils#the-philosophy-of-tsvutils) (Brendan O'Conner) has a nice discussion of the rationale for using TSV files.
