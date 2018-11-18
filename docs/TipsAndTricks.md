_Visit the [main page](../README.md)_

# Tips and Tricks

Contents:

* [Useful bash aliases](#useful-bash-aliases)
* [Customize the Unix sort command](#customize-the-unix-sort-command)
* [MacOS: Install GNU versions of Unix command line tools](#macos-install-gnu-versions-of-unix-command-line-tools)
* [Reading data in R](#reading-data-in-r)
* [A faster way to unique a file](#a-faster-way-to-unique-a-file)
* [Using grep and tsv-filter together](#using-grep-and-tsv-filter-together)
* [Shuffling large files)(#shuffling-large-files)
* [Enable bash-completion](#enable-bash-completion)
* [Convert newline format and character encoding with dos2unix and iconv](#convert-newline-format-and-character-encoding-with-dos2unix-and-iconv)

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

GNU sort uses a small buffer by default when reading from standard input. This causes it to run much more slowly than when reading files directly. On the author's system the delta is about 2-3x. This will happen when using Unix pipelines. The [keep-header](ToolReference.md#keep-header-reference) tool uses a pipe internally, so it is affected as well. Examples:
```
$ grep green file.txt | sort
$ keep-header file.txt -- sort
```

Most of the performance of direct file reads can be regained by suggesting a buffer size in the sort command. The author has had good results with a 2 GB buffer on a 16 GB Macbook, and a 1 GB buffer obtains most of improvement. The change to the above commands:
```
$ grep green file.txt | sort --buffer-size=2G
$ keep-header file.txt -- sort --buffer-size=2G
```

These can be added to the shell script described eariler. The revised shell script (file: `tsv-sort`):
```
#!/bin/sh
sort  -t $'\t' --buffer-size=2G $*
```

Now the commands are once again simple and have good performance:
```
$ grep green file.txt | tsv-sort
$ keep-header file.txt -- tsv-sort
```

Remember to use the correct `sort` program name if an updated version has been installed under a different name. This may be `gsort` on some systems.

*More details*: The `--buffer-size` option may affect sort programs differently depending on whether input is being read from files or standard input. This is the case for [GNU sort](https://www.gnu.org/software/coreutils/manual/coreutils.html#sort-invocation), perhaps the most common sort program available. This is because by default sort uses different methods to choose an internal buffer size when reading from files and when reading from standard input. `--buffer-size` controls both. On a machine with very large amounts of RAM, say, 64 GB, picking a 1 or 2 GB buffer size may actually slow sort down when reading from files, while speeding it up when reading from standard input. The author has not experimented with enough systems to make a universal recommendation, but a bit of experimentation on any specific system should help. [GNU sort](https://www.gnu.org/software/coreutils/manual/coreutils.html#sort-invocation) has additional options when optimum performance is needed.

## MacOS: Install GNU versions of Unix command line tools

If you're using a Mac, one of best things you can do is install GNU versions of the typical Unix text processing tools. `cat`, `cut`, `grep`, `awk`, etc. The versions shipped with MacOS are older and quite slow compared to the newer GNU versions, which are typically more than five times faster. The [2017 Comparative Benchmarks](comparative-benchmarks-2017.md) includes several benchmarks showing these deltas.

The [Homebrew](https://brew.sh/) and [MacPorts](https://www.macports.org/) package managers are good ways to install these tools and many others. Useful packages for data processing include:
* `coreutils` - The key Unix command line tools, including `cp`, `cat`, `cut`, `head`, `tail`, `wc`, `sort`, `uniq`, `shuf` and quite a few others.
* `gawk` - GNU awk.
* `gnu-sed` (Homebrew), `gsed` (MacPorts)  - GNU sed.
* `grep` - GNU grep.

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

## Shuffling large files

[tsv-sample](ToolReference.md#tsv-sample-reference) has several sampling modes which limit the amount of memory used. However, system memory becomes a limitation when randomizing line order of very large files, as the entire file must be loaded into memory. ([GNU shuf](https://www.gnu.org/software/coreutils/manual/html_node/shuf-invocation.html) has the same limitation.) The solution is to use disk when the files become too large for memory.

The tsv-sample `--gen-random-inorder` option be combined with [GNU sort](https://www.gnu.org/software/coreutils/manual/html_node/sort-invocation.html) to do disk-based shuffling. A random value is generated for each line, written out, sorted, and the random value removed. This works because `sort` will use disk if necessary. This technique can be used with both weighted and unweighted line order randomization. There is a catch: GNU sort is dramatically faster when sorting numbers written in decimal notation, without exponents. However, random value generation may generate values with exponents in some cases. This is discussed in more detail below.

Here's an example. This example uses the `tsv-sort` shell script described earlier ([Customize the Unix sort command](#customize-the-unix-sort-command)). Substitute `tsv-sort` with `sort  -t $'\t' --buffer-size=2G` to use the `sort` command directly.
```
$ # In-memory version
$ tsv-sample file.txt > randomized-file.txt

$ # Using disk-based sorting
$ tsv-sample --gen-random-inorder file.txt | tsv-sort -k1,1nr | cut -f 2- > randomized-file.txt
```

The above prepends a random value to each line, sorts, and removes the random value. Now available disk space is the limiting factor, not memory.

This can be done with weighted sampling when the weights are integer values. These examples use a weight from field 3.
```
$ # In-memory version
$ tsv-sample -w 3 file.tsv > randomized-file.tsv

$ # Using disk-based sampling, with integer weights
$ tsv-sample -w 3 --gen-random-inorder file.tsv | tsv-sort -k1,1nr | cut -f 2- > randomized-file.tsv
```

The examples above use "numeric" sorting. When values contain exponents then "general numeric" sorting should be used. This is specified using the '-k1,1gr' rather than '-k1,1nr'. Here's an example:
```
$ # Using disk-based sampling, with floating point weights
$ tsv-sample -w 3 --gen-random-inorder file.tsv | tsv-sort -k1,1gr | cut -f 2- > randomized-file.tsv
```

Regarding exponential notation: The faster "numeric" sort will incorrectly order lines where the random value contains an exponent. `tsv-utils` version 1.3.2 changed random number printing to limit exponent printing. This was done by using exponents only when numbers are smaller than 1e-12. Though not guaranteed, this does not occur in practice with unweighted sampling or weighted sampling with integer weights. The author has run more than a billion trials without an occurrence. (It may be a property of the random number generator used.) It will occur if floating point weights are used. Use "general numeric" ('g') form when using floating point weights or if a guarantee is needed. However, in many cases regular "numeric" sort ('n') will suffice, and be dramatically faster.

Note: For unweighted shuffling it's likely faster version could be implemented. The idea would be to read all input lines and write each to a randomly chosen temporary file. Then read and shuffle each temporary file in-memory and write it to the final output, appending each shuffled file. This would replace the sorting with faster shuffling. It'd also avoid printing random numbers, which is slow. See Daniel Lemire's blog post [External-memory shuffling in linear time?](https://lemire.me/blog/2010/03/15/external-memory-shuffling-in-linear-time/) for a more detailed discussion.

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

After enabling bash-completion, add completions for the tsv-utils package. Completions are available in the `bash_completion/tsv-utils` file. One way to add them is to 'source' the file from the `~/.bash_completion` file. A line like the following will do this.
```
if [ -r ~/tsv-utils/bash_completion/tsv-utils ]; then
    . ~/tsv-utils/bash_completion/tsv-utils
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
