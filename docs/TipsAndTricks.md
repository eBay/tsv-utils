_Visit the [main page](../README.md)_

# Tips and Tricks

Contents:

* [Useful bash aliases](#useful-bash-aliases)
* [Customize the Unix sort command](#customize-the-unix-sort-command)
* [MacOS: Install GNU versions of Unix command line tools](#macos-install-gnu-versions-of-unix-command-line-tools)
* [Reading data in R](#reading-data-in-r)
* [Using grep and tsv-filter together](#using-grep-and-tsv-filter-together)
* [Shuffling large files](#shuffling-large-files)
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

*file: tsv-sort*
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

These can be added to the shell script described eariler. The revised shell script:

*file: tsv-sort*
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

#### Turn off locale sensitive sort when not needed

GNU `sort` performs locale sensitive sorting, obeying the locale setting of the shell. Locale sensitive sorting is designed to produce standard dictionary sort orders across all languages and character sets. However, it is quite a bit slower than sorts using byte value, in some cases by an order of magnitude.

This affects shells set to a non-default locale ("C" or "POSIX"). Setting the locale is normally preferred and is especially useful when working with Unicode data. Run the `locale` command to check the settings.

Locale sensitive sorting can be turned off when not needed. This is done by setting environment variable `LC_ALL=C` for the duration of the sort command. Here is a version of the sort shell script that does this:

*file: tsv-sort-fast*
```
#!/bin/sh
(LC_ALL=C sort -t $'\t' --buffer-size=2G $*)
```

This `tsv-sort-fast` script can be used the same way the `tsv-sort` script described earlier can be used.

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

Line order randomization, or "shuffling", is one of the operations supported by [tsv-sample](ToolReference.md#tsv-sample-reference). Most `tsv-sample` operations can be performed with limited system memory. However, system memory becomes a limitation when shuffling very large data sets, as the entire data set must be loaded into memory. ([GNU shuf](https://www.gnu.org/software/coreutils/manual/html_node/shuf-invocation.html) has the same limitation.) The solution is to use disk-based shuffling.

One option is [GNU sort](https://www.gnu.org/software/coreutils/manual/html_node/sort-invocation.html)'s random sort feature (`sort --random-sort`). This can be used for unweighted randomization. However, there are couple of downsides. One is that it places duplicates lines next to each other, a problem for many shuffling use cases. Another is that it is rather slow.

An better approach is to combine `tsv-sample --gen-random-inorder` with disk-based sorting. [GNU sort](https://www.gnu.org/software/coreutils/manual/html_node/sort-invocation.html) serves the latter purpose well. A random value is generated for each input line, the lines are sorted, and the random values removed. GNU sort will use disk if necessary. This technique can be used for both weighted and unweighted line order randomization. There is a catch: GNU sort is dramatically faster when sorting numbers written in decimal notation, without exponents. However, random value generation may generate values with exponents in some cases. This is discussed in more detail at the end of this section.

Here's an example.
```
$ # In-memory version
$ tsv-sample file.txt > randomized-file.txt

$ # Using disk-based sorting
$ tsv-sample --gen-random-inorder file.txt | tsv-sort-fast -k1,1nr | cut -f 2- > randomized-file.txt
```

(*Note: These examples uses the `tsv-sort-fast` shell script described earlier, under [Customize the Unix sort command](#customize-the-unix-sort-command). Substitute `tsv-sort-fast -k1,1nr` with `(LC_ALL=C sort -t $'\t' --buffer-size=2G -k1,1nr)` to use the `sort` command directly.*)

The above example prepends a random value to each line, sorts, and removes the random values. Now available disk space is the limiting factor, not memory.

This can be done with weighted sampling when the weights are integer values. This is shown in the next example, using a weight from field 3.
```
$ # In-memory version
$ tsv-sample -w 3 file.tsv > randomized-file.tsv

$ # Using disk-based sampling, with integer weights
$ tsv-sample -w 3 --gen-random-inorder file.tsv | tsv-sort-fast -k1,1nr | cut -f 2- > randomized-file.tsv
```

The examples so far use "numeric" sorting. When values contain exponents "general numeric" sorting should be used. This is specified using `-k1,1gr` rather than `-k1,1nr`. Here's an example:
```
$ # Using disk-based sampling, with floating point weights
$ tsv-sample -w 3 --gen-random-inorder file.tsv | tsv-sort-fast -k1,1gr | cut -f 2- > randomized-file.tsv
```

Performance of the approaches described will vary considerably based on the hardware and data sets. As one comparison point the author ran both `sort --random-sort` and the unweighted, disk based approach shown above on a 294 million line, 5.8 GB data set. A 16 GB MacOS box with SSD disk storage was used. This data set fits in memory on this machine, so the in-memory approach was tested as well. Both `tsv-sample` and GNU `shuf` were used. The `sort --random-sort` metric was run with [locale sensitive sorting](#turn-off-locale-sensitive-sort-when-not-needed) both on and off to show the difference.

The in-memory versions are of course faster. But if disk is necessary, combining `tsv-sample --gen-random-inorder` with `sort` is about twice as fast as `sort --random-sort` and doesn't have the undesirable behavior of grouping duplicate lines.

| Command/Method                                           | Disk? |           Time |
| -------------------------------------------------------- | ------| -------------: |
| `tsv-sample file.txt > out.txt`                          | No    |  1 min, 52 sec |
| `shuf file.txt > out.txt`                                | No    |  3 min,  9 sec |
| Method: _tsv-sample --gen-random-inorder_, _cut_, _sort_ | Yes   | 13 min, 24 sec |
| `tsv-sort-fast --random-sort file.txt > out.txt`         | Yes   | 27 min, 44 sec |
| `tsv-sort --random-sort file.txt > out.txt`              | Yes   |  4 hrs, 55 min |

Notes:
* The "_tsv-sample --gen-random-inorder_, _cut_, _sort_" command:
  ```
  tsv-sample --gen-random-inorder file.txt | tsv-sort-fast -k1,1nr | cut -f 2- > out.txt
  ```
* `tsv-sort` and `tsv-sort-fast` are described in [Customize the Unix sort command](#customize-the-unix-sort-command). They are covers for `sort`. `tsv-sort-fast` turns locale sensitivity off, `tsv-sort` leaves it on. `tsv-sort` was run with `LANG="en_US.UTF-8`.
* Program versions: `tsv-sample` version 1.4.4; GNU `sort` version 8.31; GNU `shuf` version 8.31.

**Regarding exponential notation**: The faster "numeric" sort will incorrectly order lines where the random value contains an exponent. In version 1.3.2, `tsv-sample` changed random number printing to limit exponent printing. This was done by using exponents only when numbers are smaller than 1e-12. Though not guaranteed, this does not occur in practice with unweighted sampling or weighted sampling with integer weights. The author has run more than a billion trials without an occurrence. (It may be a property of the random number generator used.) It will occur if floating point weights are used. Use "general numeric" ('g') form when using floating point weights or if a guarantee is needed. However, in many cases regular "numeric" sort ('n') will suffice, and be dramatically faster.

**Regarding unweighted shuffling**: A faster version of unweighted shuffling appears very doable. One possibility would be to read all input lines and write each to a randomly chosen temporary file. Then read and shuffle each temporary file in-memory and write it to the final output, appending each shuffled file. This would replace sorting with a faster shuffling operation. It would also avoid printing random numbers, which is slow. See Daniel Lemire's blog post [External-memory shuffling in linear time?](https://lemire.me/blog/2010/03/15/external-memory-shuffling-in-linear-time/) for a more detailed discussion.

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
