# TSV-Utils Toolkit: Other open-source tools

There are a number of open-source toolkits with functionality similar to those in tsv-utils-dlang. A number of the richer toolkits are listed below. Those handling CSV files handle TSV files as well:

* [clarkgrubb/data-tools](https://github.com/clarkgrubb/data-tools) - A variety of tools, especially rich in format converters. Written in Python, Ruby, and C.
* [csvkit](https://github.com/wireservice/csvkit) - CSV tools, written in Python.
* [csvtk](https://github.com/shenwei356/csvtk) - CSV tools, written in Go.
* [GNU datamash](https://www.gnu.org/software/datamash/) - Performs numeric, textual and statistical operations on TSV files. Written in C.
* [dplyr](https://github.com/hadley/dplyr) - Tools for tabular data in R storage formats. Runs in an R environment, code is in C++.
* [miller](https://github.com/johnkerl/miller) - CSV and JSON tools, written in C.
* [brendano/tsvutils](https://github.com/brendano/tsvutils) - TSV tools, especially rich in format converters. Written in Python.
* [xsv](https://github.com/BurntSushi/xsv) - CSV tools, written in Rust.

The different toolkits are certainly worth investigating if you work with tabular data files. Several have quite extensive feature sets. Each toolkit has its own strengths, your workflow and preferences are likely to fit some toolkits better than others.

File format is perhaps the most important dimension. CSV files cannot be processed reliably by traditional unix tools, so CSV toolkits naturally extend further into this space. However, this tends to increase complexity of the tools when working with TSV files.

Tradeoffs between file formats is its own topic. The [brendano/tsvutils README](https://github.com/brendano/tsvutils#the-philosophy-of-tsvutils) (Brendan O'Conner) has a nice discussion of the rationale for using TSV files. Note that many numeric CSV data sets use comma as a separator, but don't use CSV escapes. Such data sets can be processed reliabily by Unix tools and this toolset by setting the delimiter character.

An even broader list of tools can be found here: [Structured text tools](https://github.com/dbohdan/structured-text-tools).
