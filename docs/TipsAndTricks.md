_Visit the [main page](../README.md)_

# Tips and Tricks

Contents:

* [Useful bash aliases](#useful-bash-aliases)
* [Customize the Unix sort command](#customize-the-unix-sort-command)
* [Reading data in R](#reading-data-in-r)
* [A faster way to unique a file](#a-faster-way-to-unique-a-file)
* [Using grep and tsv-filter together](#using-grep-and-tsv-filter-together)
* [Enable bash-completion](#enable-bash-completion)
* [Convert newline format and character encoding with dos2unix and iconv](#convert-newline-format-and-character-encoding-with-dos2unix-and-iconv)
* [Comparing TSV and CSV formats](#comparing-tsv-and-csv-formats)

### Useful bash aliases

A bash alias is a keystroke shortcut known by the shell. They are setup in the user's `~/.bashrc` or another shell init file. There's one that's really valuable when working with TSV files: `tsv-header`, which lists the field numbers for each field in a TSV file. To define it, put the following in `~/.bashrc` or other init file:
```
tsv-header () { head -n 1 $* | tr $'\t' '\n' | nl ; }
```

Once this is defined, use it as follows:
```
$ tsv-header worldcitiespop.tsv
     1	Country
     2	City
     3	AccentCity
     4	Region
     5	Population
     6	Latitude
     7	Longitude
```

A similar alias can be setup for CSV files. Here are two, the first one takes advantage of a csv-to-tsv converter. The second one uses only standard Unix tools. It won't interpret CSV escapes, but many header lines don't use escapes. (Define only one):
```
csv-header () { csv2tsv $* | head -n 1 | tr $'\t' '\n' | nl ; }
csv-header () { head -n 1 $* | tr ',' '\n' | nl ; }
```

There are any number of useful aliases that can be defined. Here is another the author finds useful with TSV files. It prints a file excluding the first line (the header line):
```
but-first () { tail -n +2 $* ; }
```

These aliases can be created in most shells. Non-bash shells may have a different syntax though.

## Customize the Unix sort command

The typical Unix `sort` utility works fine on TSV files. However, there are few simple tweaks that can improve convenience and performance.

#### Install an updated sort utility (especially on Mac OS X)

Especially on a Mac, the default `sort` program is rather old. On OS X Sierra, the default `sort` is GNU sort version 5.93 (2005). As of March 2017, the latest GNU sort is version 8.26. It is about 3 times faster than the 2005 version. Use your system's package manager to install the latest GNU coreutils package. (Two popular package managers on the Mac are Homebrew and MacPorts.) Note that in some cases the revised GNU sort routine may be installed under a different name, for example, `gsort`.

#### Specify TAB as a delimiter in a shell command

Specifying TAB as the delimiter every invocation is a nuisance. The way to fix this is to create either a `bash` alias or a shell script. A shell script is a better fit for `sort`, as shell commands can be invoked by other programs. This is convenient when using tools like [keep-header](ToolReference.md#keep-header-reference).

Put the lines below in a file, eg. `tsv-sort`. Run `$ chmod a+x tsv-sort`, and add the file to the PATH:
```
#!/bin/sh
sort -t $'\t' $*
```

Now `tsv-sort` will run sort with TAB as the delimiter. The following sorts on column 2:
```
$ tsv-sort worldcitiespop.tsv -k2,2
```

#### Set the buffer size for reading from standard input

GNU sort uses a small buffer by default when reading from standard input. This causes it to run much more slowly than when reading files directly. On the author's system the delta is about 2x. This will happen when using Unix pipelines. The [keep-header](ToolReference.md#keep-header-reference) tool uses a pipe internally, so it is affected as well. Examples:
```
$ grep green file.txt | sort
$ keep-header file.txt -- sort
```

Most of the performance of direct file reads can be regained by suggesting a buffer size in the sort command. The author has had good results with a 1 GB buffer. The change to the above commands:
```
$ grep green file.txt | sort --buffer-size=1073741824
$ keep-header file.txt -- sort --buffer-size=1073741824
```

These can be added to the shell script described eariler. The revised shell script (file: `tsv-sort`):
```
#!/bin/sh
sort  -t $'\t' --buffer-size=1073741824 $*
```

Now the commands are once again simple and have good performance:
```
$ grep green file.txt | tsv-sort
$ keep-header file.txt -- tsv-sort
```

Remember to use the correct `sort` program name if an updated version has been installed under a different name. This may be `gsort` on some systems.

## Reading data in R

It's common to perform transformations on data prior to loading into applications like R or Pandas. This especially useful when data sets are large and loading entirely into memory is undesirable. One approach is to create modified files and load those. In R it can also be done as part of the different read routines, most of which allow reading from a shell command. This enables filtering rows, selecting, sampling, etc. This will work with any command line tool. Some examples below. These use `read.table` from the base R package, `read_tsv` from the `tidyverse/readr` package, and `fread` from the `data.table` package:
```
> df1 = read.table(pipe("tsv-select -f 1,2,7 data.tsv | tsv-sample -H -n 50000"), sep="\t", header=TRUE, quote="")
> df2 = read_tsv(pipe("tsv-select -f 1,2,7 data.tsv | tsv-sample -H -n 50000"))
> df3 = fread("tsv-select -f 1,2,7 train.tsv | tsv-sample -H -n 50000")
```

The first two use the `pipe` function to create the shell command. `fread` does this automatically.

*Note: One common issue is not having the PATH environment setup correctly. Depending on setup, the R application might not have the full path normally available in a command shell. See the R documentation for details.*

## A faster way to unique a file

The commands `sort | uniq` and `sort -u` are common ways to remove duplicates from a unsorted file. However, `tsv-uniq` is faster, generally by quite a bit. As a bonus, it preserves the original input order, including the header line. The following commands are equivalent, apart from sort order:
```
$ sort data.txt | uniq > data_unique.txt
$ sort -u data.txt > data_unique.txt
$ tsv-uniq data.txt > data_unique.txt
```

Run-times for the above commands are show below. Two different files were used, one 12 MB, 500,000 lines, the other 127 MB, 5 million lines. The files contained 339,185 and 3,394,172 unique lines respectively. Timing was done on a Macbook Pro with 16 GB of memory and flash storage. The `sort` and `uniq` programs are from GNU coreutils version 8.26. Run-times using `tsv-uniq` are nearly 10 times faster in these cases.

| Command                 | File size         | Time (seconds) |
| ----------------------- | ----------------- | -------------: |
| sort data.txt \| uniq | 12 MB; 500K lines |           2.19 |
| sort -u data.txt      | 12 MB; 500K lines |           2.37 |
| tsv-uniq data.txt     | 12 MB; 500K lines |           0.29 |
| sort data.txt \| uniq | 127 MB; 5M lines  |          26.13 |
| sort -u data.txt      | 127 MB; 5M lines  |          29.02 |
| tsv-uniq data.txt     | 127 MB; 5M lines  |           3.14 |

For more info, see the [tsv-uniq reference](ToolReference.md#tsv-uniq-reference).

## Using grep and tsv-filter together

`tsv-filter` is fast, but a quality Unix `grep` implementation is faster. There are good reasons for this, notably, `grep` can ignore line boundaries during initial matching (see ["why GNU grep is fast", Mike Haertel](https://lists.freebsd.org/pipermail/freebsd-current/2010-August/019310.html)).

Much of the time this won't matter, as `tsv-filter` can process gigabyte files in a couple seconds. However, when working with much larger files or slow I/O devices, the wait may be longer. In these cases, it may be possible to speed things up using `grep` as a first pass filter. This will work if there is a string, preferably several characters long, that is found on every line expected in the output, but winnows out a fair number of non-matching lines.

An example, using a number of files from the [Google Books Ngram Viewer data-sets](https://storage.googleapis.com/books/ngrams/books/datasetsv2.html). In these files, each line holds stats for an ngram, field 2 is the year the stats apply to. In this test, `ngram_*.tsv` consists of 1.4 billion lines, 27.5 GB of data in 39 files. To get the lines for the year 1850, this command would be run:
```
$ tsv-filter --str-eq 2:1850 ngram_*.tsv
```

This took 157 seconds on Macbook Pro and output 2770512 records. Grep can also be used:
```
$ grep 1850 ngram_*.tsv
```

This took 37 seconds, quite a bit faster, but produced too many records (2943588), as "1850" appears in places other than the year. But the correct result can generated by using `grep` and `tsv-filter` together:
```
$ grep 1850 ngram_*.tsv | tsv-filter --str-eq 2:1850
```

This took 37 seconds, same as `grep` by itself. `grep` and `tsv-filter` run in parallel, and `tsv-filter` keeps up easily as it is processing fewer records.

The above example can be done entirely in `grep` by using regular expressions, but it's easy to get wrong and actually slower due to the regular expression use. For example (syntax may be different in your environment):
```
$ grep $'^[^\t]*\t1850\t' ngram_*.tsv
```

This produced the correct results, but took 48 seconds. It is feasible because only string comparisons are needed. It wouldn't work if numeric comparisons were also involved.

The google ngram files don't have headers, if they did, `grep` as used above would drop them. Use the [keep-header](ToolReference.md#keep-header-reference) tool to preserve the header. For example:
```
$ keep-header ngram_with_header_*.tsv -- grep 1850 | tsv-filter -H --str-eq 2:1850
```

Using `grep` as a pre-filter won't always be helpful, that will depend on the specific case, but on occasion it can be quite handy.

## Enable bash-completion

Bash command completion is quite handy for command line tools. Command names complete by default, already useful. Adding completion of command options is even better. As an example, with bash completion turned on, enter the command name, then a single dash (-):
```
$ tsv-select -
```
Now type a TAB (or pair of TABs depending on setup). A list of possible completions is printed and the command line restored for continued entry.
```
$ tsv-select -
--delimiter  --fields     --header     --help       --rest
$ tsv-select --
```
Now type 'r', then TAB, and the command will complete up to `$ tsv-select --rest`.

Enabling bash completion is a bit more involved than other packages, but still not too hard. It will often be necessary to install a package. The way to do this is system specific. A good source of instructions can be found at the [bash-completion GitHub repository](https://github.com/scop/bash-completion). Mac users may find the MacPorts [How to use bash-completion](https://trac.macports.org/wiki/howto/bash-completion) guide useful. Procedures for Homebrew are similar, but the details differ a bit.

After enabling bash-completion, add completions for the tsv-utils-dlang package. Completions are available in the `bash_completion/tsv-utils-dlang` file. One way to add them is to 'source' the file from the `~/.bash_completion` file. A line like the following will do this.
```
if [ -r ~/tsv-utils-dlang/bash_completion/tsv-utils-dlang ]; then
    . ~/tsv-utils-dlang/bash_completion/tsv-utils-dlang
fi
```

The file can also be added to the bash completions system directory on your system. The location is system specific, see the bash-completion installation instructions for details.

## Convert newline format and character encoding with dos2unix and iconv

The TSV Utilities expect input data to be utf-8 encoded and on Unix, to use Unix newlines. The `dos2unix` and `iconv` command line tools are useful when conversion is required.

Needing to convert newlines from DOS/Windows format to Unix is relatively common. Data files may have been prepared for Windows, and a number of spreadsheet programs generate Windows line feeds when exporting data. The `csv2tsv` tool converts Windows newlines as part of its operation. The other TSV Utilities detect Window newlines when running on a Unix platform, including MacOS. The following `dos2unix` commands convert files to use Unix newlines:
```
$ # In-place conversion.
$ dos2unix file.tsv

$ # Conversion writing to a new file. The existing file is not modified.
$ dos2unix -n file_dos.tsv file_unix.tsv

$ # Reading from standard input writes to standard output
$ cat file_dos.tsv | dos2unix | tsv-select -f 1-3 > newfile.tsv
```

Most applications and databases will export data in utf-8 encoding, but it can still be necessary to convert to utf-8. `iconv` serves this purpose nicely. An example converting Windows Latin-1 (code page 1252) to utf-8:
```
$ iconv -f CP1252 -t UTF-8 file_latin1.tsv > file_utf8.tsv
```

The above can be combined with `dos2unix` to perform both conversions at once:
```
$ iconv -f CP1252 -t UTF-8 file_window.tsv | dos2unix > file_unix.tsv
```

See the `dos2unix` and `iconv` man pages for more details.

### Comparing TSV and CSV formats

The differences between TSV and CSV formats can be confusing. The obvious distinction is the default field delimiter: TSV uses TAB, and CSV uses comma. Both use newline as the record delimiter.

By itself, different default field delimiters is not especially significant. Far more important is the approach to delimiters occurring in the data. CSV uses an escape syntax to represent comma and newlines in the data. TSV takes a different approach, disallowing TABs and newlines in the data.

The escape syntax enables CSV to fully represent common written text. This is a good fit for human edited documents, notably spreadsheets. This generality has a cost: reading it requires programs to parse the escape syntax. While not overly difficult, it is still easy to do incorrectly, especially when writing one-off programs. It is good practice is to use a CSV parser when processing CSV files. Traditional Unix tools like `cut` and `awk` do not process CSV escapes, alternate tools are needed.

By contrast, parsing TSV data is simple. Records can be read using the typical `readline` routines. The fields in each record can be found using a `split` or `splitter` routine available in most programming languages. No special parser is needed. This is much more reliable. It is also faster, no CPU time is used parsing the escape syntax.

This makes TSV format well suited for the large, tabular data sets common in data mining and machine learning environments. These data sets rarely need TAB and newline characters in the fields.

The similarity between TSV and CSV can lead to confusion about which tools are appropriate. Furthering this confusion, it is somewhat common to have data files using comma as the field delimiter, but without CSV escapes. These are sometimes referred to as "simple CSV". They are equivalent to TSV files with comma as a field delimiter. The TSV Utilities and traditional Unix tools like `cut` and `awk` process these files correctly by specifying the field delimiter.

The most common CSV escape format uses quotes to delimit fields containing delimiter characters. Quote characters in data are represented by a pair of quotes. Consider the data in this table:

| Field-1 | Field-2              | Field-3 |
| ------- | -------------------- | ------- |
| abc     | hello, world!        | def     |
| ghi     | Say "hello, world!"  | jkl     |

In field2, the first value contains a comma, the second value contain both quotes and a comma. Here is the CSV representation, using escapes:

```
Field1,Field2,Field3
abc,"hello, world!",def
ghi,"Say ""hello, world!""",jkl
```

Here is the same data represented in TSV format:
```
Field1	Field2	Field3
abc	hello, world	def
ghi	Say "hello, world!"	jkl
```

