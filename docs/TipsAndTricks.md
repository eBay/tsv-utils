_Visit the [main page](../README.md)_

# Tips and Tricks

Contents:

* [Useful bash aliases and shell scripts](#useful-bash-aliases-and-shell-scripts)
* [macOS: Install GNU versions of Unix command line tools](#macos-install-gnu-versions-of-unix-command-line-tools)
* [Customize the sort command](#customize-the-sort-command)
* [Enable bash-completion](#enable-bash-completion)
* [Convert newline format and character encoding with dos2unix and iconv](#convert-newline-format-and-character-encoding-with-dos2unix-and-iconv)
* [Using grep and tsv-filter together](#using-grep-and-tsv-filter-together)
* [Faster processing using GNU parallel](#faster-processing-using-gnu-parallel)
* [Reading data in R](#reading-data-in-r)
* [Shuffling large files](#shuffling-large-files)

## Useful bash aliases and shell scripts

### Bash aliases

A bash alias is a keystroke shortcut known by the shell. They are setup in the user's `~/.bashrc` or another shell init file. A convenient alias when working with TSV files is `tsv-header` which lists the field numbers for each field in a TSV file. To define it, put the following in `~/.bashrc` or other init file:
```
tsv-header () { head -n 1 "$@" | tr $'\t' $'\n' | nl -ba ; }
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

A similar alias can be setup for CSV files. Here are two. The first uses [csv2tsv](ToolReference.md#csv2tsv-reference) to interpret the CSV header line, including CSV escape characters. The second uses only standard Unix tools. It won't interpret CSV escapes, but many header lines don't use escapes. (Define only one):
```
csv-header () { csv2tsv "$@" | head -n 1 | tr $'\t' $'\n' | nl -ba ; }
csv-header () { head -n 1 "$@" | tr $',' $'\n' | nl -ba ; }
```

Many useful aliases can be defined. Here is another the author finds useful with TSV files. It prints a file excluding the first line (the header line):
```
but-first () { tail -n +2 "$@" ; }
```

These aliases can be created in most shells. Non-bash shells may have a different syntax though.

### Shell scripts

Shell scripts are an alternative to bash aliases. They function similarly, but shell scripts are preferred for longer scripts or commands that need to be invoked by other programs. Here's an example of the `tsv-header` command written as a script rather than an alias. It extends the alias by printing help when invoked with the `-h` or `--help` options.
```
#!/bin/sh
if [ "$1" == "-h" ] || [ "$1" == "--h" ] || [ "$1" = "--help" ]; then
    program_filename=$(basename $0)
    echo "synopsis: $program_filename <tsv-file>"
    echo ""
    echo "Print field numbers and header text from the first line of <tsv-file>."
else
    head -n 1 "$@" | tr $'\t' $'\n' | nl -ba
fi
```

Put the above in the file `tsv-header` somewhere on the PATH. A common location is the `~/bin` directory, but this is not required. Run the command `$ chmod a+x tsv-header` to make it executable. Now it can be invoked just like the alias version of `tsv-header`.

The are a couple of simple sample scripts in the [Customize the sort command](#customize-the-sort-command) section.

## macOS: Install GNU versions of Unix command line tools

If you're using a Mac, one of best things you can do is install GNU versions of the typical Unix text processing tools. `cat`, `cut`, `grep`, `awk`, etc. The versions shipped with macOS are older and quite slow compared to the newer GNU versions, which are often more than five times faster. The [2017 Comparative Benchmarks](comparative-benchmarks-2017.md) includes several benchmarks showing these deltas.

The [Homebrew](https://brew.sh/) and [MacPorts](https://www.macports.org/) package managers are good ways to install these tools and many others. Useful packages for data processing include:
* `coreutils` - The key Unix command line tools, including `cp`, `cat`, `cut`, `head`, `tail`, `wc`, `sort`, `uniq`, `shuf` and quite a few others.
* `gawk` - GNU awk.
* `gnu-sed` (Homebrew), `gsed` (MacPorts)  - GNU sed.
* `grep` - GNU grep.

Note that in many cases the default installation process will install the tools with alternative names to avoid overriding the built-in versions. This is often done by adding a leading `g`. For example, `gawk`, `gsort`, `ggrep`, `gwc`, etc. Each package manager provides instructions for installing using the standard names.

## Customize the sort command

The standard Unix `sort` utility works quite well on TSV files. The syntax for sorting on individual fields (`-k|--key` option) takes getting used to, but once learned `sort` becomes a very capable tool. However, there are few simple tweaks that can improve convenience and performance.

### Install an updated sort utility (especially on macOS)

Installing an up-to-date utility is a worthwhile step on all platforms. This is especially so on macOS, as the the default `sort` program is a bit slow. The `sort` utility available as part of [GNU Core Utils](https://www.gnu.org/software/coreutils/coreutils.html) is typically quite a bit faster. As of late 2019, the current GNU `sort` (version 8.31) is often more than twice as fast as the `sort` utility shipped with OS X Mojave.

Use your system's package manager to upgrade to the latest sort utility and consider installing GNU `sort` if it's not currently on your system. (Two popular package managers on the Mac are Homebrew and MacPorts.) Note that in some cases the GNU `sort` routine may be installed under a different name than the built-in `sort` utility, typically `gsort`.

### Specify TAB as a delimiter in a shell command

Unix `sort` utilities are able to sort using fields as keys. To use this feature on TSV files the TAB character must be passed as the field delimiter. This is easy enough, but specifying it on every sort invocation is a nuisance.

The way to fix this is to create either a `bash` alias or a shell script. A shell script is a better fit for `sort`, as shell commands can be invoked by other programs. This is convenient when using tools like [keep-header](ToolReference.md#keep-header-reference).

Put the lines below in a file, eg. `tsv-sort`. Run `$ chmod a+x tsv-sort` and add the file to the PATH:

*file: tsv-sort*
```
#!/bin/sh
sort -t $'\t' "$@"
```

Now `tsv-sort` will run `sort` with TAB as the delimiter. The following command sorts on field 2:
```
$ tsv-sort worldcitiespop.tsv -k2,2
```

### Set the buffer size for reading from standard input

GNU `sort` uses a small buffer by default when reading from standard input. This causes it to run much more slowly than when reading files directly. On the author's system the delta is about 2-3x. This will happen when using Unix pipelines. The [keep-header](ToolReference.md#keep-header-reference) tool uses a pipe internally, so it is affected as well. Examples:
```
$ grep green file.txt | sort
$ keep-header file.txt -- sort
```

Most of the performance of direct file reads can be regained by specifying a buffer size in the `sort` command invocation. The author has had good results with a 2 GB buffer on machines having 16 to 64 GB of RAM, and a 1 GB buffer obtains most of improvement. The change to the above commands:
```
$ grep green file.txt | sort --buffer-size=2G
$ keep-header file.txt -- sort --buffer-size=2G
```

These can be added to the shell script shown earlier. The revised shell script:

*file: tsv-sort*
```
#!/bin/sh
sort  -t $'\t' --buffer-size=2G "$@"
```

Now the commands are once again simple and have good performance:
```
$ grep green file.txt | tsv-sort
$ keep-header file.txt -- tsv-sort
```

Remember to use the correct `sort` program name if an updated version has been installed under a different name. This may be `gsort` on some systems.

A sample implementation of this script can be found in the `extras/scripts` directory in the tsv-utils GitHub repository. This sample script is also included in the prebuilt binaries package.

*More details*: The `--buffer-size` option may affect `sort` programs differently depending on whether input is being read from files or standard input. This is the case for [GNU sort](https://www.gnu.org/software/coreutils/manual/coreutils.html#sort-invocation), perhaps the most common `sort` program available. This is because by default `sort` uses different methods to choose an internal buffer size when reading from files and when reading from standard input. `--buffer-size` controls both. On a machine with large amounts of RAM, e.g. 64 GB, picking a 1 or 2 GB buffer size may actually slow `sort` down when reading from files while speeding it up when reading from standard input. The author has not experimented with enough systems to make a universal recommendation, but a bit of experimentation on any specific system should help. [GNU sort](https://www.gnu.org/software/coreutils/manual/coreutils.html#sort-invocation) has additional options when optimum performance is needed.

### Turn off locale sensitive sorting when not needed

GNU `sort` performs locale sensitive sorting, obeying the locale setting of the shell. Locale sensitive sorting is designed to produce standard dictionary sort orders across all languages and character sets. However, it is quite a bit slower than sorting using byte values for comparisons, in some cases by an order of magnitude.

This affects shells set to a non-default locale ("C" or "POSIX"). Setting the locale is normally preferred and is especially useful when working with Unicode data. Run the `locale` command to check the settings.

Locale sensitive sorting can be turned off when not needed. This is done by setting environment variable `LC_ALL=C` for the duration of the `sort` command. Here is a version of the sort shell script that does this:

*file: tsv-sort-fast*
```
#!/bin/sh
(LC_ALL=C sort -t $'\t' --buffer-size=2G "$@")
```

The `tsv-sort-fast` script can be used the same way as the `tsv-sort` script shown earlier.

A sample implementation of this script can be found in the `extras/scripts` directory in the tsv-utils GitHub repository. This sample script is also included in the prebuilt binaries package.

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

After enabling bash-completion, add completions for the tsv-utils package. Completions are available in the `tsv-utils` file in the `bash_completion` directory in the tsv-utils GitHub repository. This file is also included with the prebuilt binary release packages. One way to add them is to 'source' the file from the `~/.bash_completion` file. A line like the following will achieve this:
```
if [ -r ~/tsv-utils/bash_completion/tsv-utils ]; then
    . ~/tsv-utils/bash_completion/tsv-utils
fi
```

The file can also be added to the bash completions system directory on your system. The location is system specific, see the bash-completion installation instructions for details.

## Convert newline format and character encoding with dos2unix and iconv

The TSV Utilities expect input data to be utf-8 encoded and on Unix, to use Unix newlines. The `dos2unix` and `iconv` command line tools are useful when conversion is required.

Needing to convert newlines from DOS/Windows format to Unix is relatively common. Data files may have been prepared for Windows, and a number of spreadsheet programs generate Windows line feeds when exporting data. The `csv2tsv` tool converts Windows newlines as part of its operation. The other TSV Utilities detect Window newlines when running on a Unix platform, including macOS. The following `dos2unix` commands convert files to use Unix newlines:
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

## Using grep and tsv-filter together

`tsv-filter` is fast, but a quality Unix `grep` implementation is faster. There are good reasons for this, notably, `grep` can ignore line boundaries during initial matching (see ["why GNU grep is fast", Mike Haertel](https://lists.freebsd.org/pipermail/freebsd-current/2010-August/019310.html)).

Much of the time this won't matter, as `tsv-filter` can process gigabyte files in a couple seconds. However, when working with much larger files or slow I/O devices, the wait may be longer. In these cases, it may be possible to speed things up using `grep` as a first pass filter. This will work if there is a string, preferably several characters long, that is found on every line expected in the output, but also filtering out a fair number of non-matching lines.

An example, using a set of files from the [Google Books Ngram Viewer data-sets](https://storage.googleapis.com/books/ngrams/books/datasetsv2.html). In these files, each line holds stats for an ngram, field 2 is the year the stats apply to. In this test, `ngram_*.tsv` consists of 1.2 billion lines, 23 GB of data in 26 files. To get the lines for the year 1850, this command would be run:
```
$ tsv-filter --str-eq 2:1850 ngram_*.tsv
```

This took 72 seconds on a Mac Mini (6-core, 64 GB RAM, SSD drives) and output 2,493,403 records. Grep can also be used:
```
$ grep 1850 ngram_*.tsv
```

This took 38 seconds, quite a bit faster, but produced too many records (2,504,846), as "1850" appears in places other than the year. But the correct result can generated by using `grep` and `tsv-filter` together:
```
$ grep 1850 ngram_*.tsv | tsv-filter --str-eq 2:1850
```

This took 39 seconds, nearly as fast `grep` by itself. `grep` and `tsv-filter` run in parallel, and `tsv-filter` keeps up easily as it is processing fewer records.

Using `grep` as a pre-filter won't always be helpful, that will depend on the specific case, but on occasion it can be quite handy.

### Using ripgrep and tsv-filter together

[ripgrep](https://github.com/BurntSushi/ripgrep) is a popular alternative to `grep`, and one of the fastest grep style programs available. It can be used with `tsv-filter` in the same way as `grep`. It has built-in support for parallel processing when operating on multiple files. This creates an interesting comparison point, one useful in conjunction with the next topic, [Faster processing using GNU parallel](#faster-processing-using-gnu-parallel).

This experiment uses the same Google ngram files, but a more complex expression. We'll find stats lines for years 1850 through 1950 on ngrams tagged as verbs. The `tsv-filter` expression:
```
tsv-filter --str-in-fld 1:_VERB --ge 2:1850 --le 2:1950
```

This produces 26,956,517 lines. Prefiltering with grep/ripgrep using `_VERB` reduces the set passed to `tsv-filter` to 81,626,466 (from the original 1,194,956,817).

For the first test the data is piped through standard input rather read directly from files. This has the effect of forcing ripgrep (`rg` command) to run in single threaded mode. This is similar to running against a single large file. The command lines:
```
$ cat ngram-*.tsv | tsv-filter --str-in-fld 1:_VERB --ge 2:1850 --le 2:1950
$ cat ngram-*.tsv | grep _VERB | tsv-filter --str-in-fld 1:_VERB --ge 2:1850 --le 2:1950
$ cat ngram-*.tsv | rg _VERB | tsv-filter --str-in-fld 1:_VERB --ge 2:1850 --le 2:1950
```

Timing results, standard input test (Mac Mini; 6-cores; 64 GB RAM; SSD drive):

|              Command | Elapsed |  User | System |  CPU |
|---------------------:|--------:|------:|-------:|-----:|
|           tsv-filter |   79.08 | 75.49 |   8.97 | 106% |
|    grep & tsv-filter |   25.56 | 32.98 |   7.16 | 157% |
| ripgrep & tsv-filter |   14.27 | 16.29 |  11.46 | 194% |

The ripgrep version is materially faster on this test. A larger set of tests on different types of files would be needed to determine if this holds generally, but the result is certainly promising for ripgrep. In these tests, `tsv-filter` was able to keep up with `grep`, but not ripgrep, which on its own finishes in about 12 seconds. Of course, both `grep` and `ripgrep` as prefilters are material improvements over `tsv-filter` standalone.

The next test runs against the 26 files directly, allowing ripgrep's parallel capabilities to be used. Runs with combining GNU `parallel` with `grep` and `tsv-filter` standalone are included for comparison. The commands:
```
$ tsv-filter ngram-*.tsv --str-in-fld 1:_VERB --ge 2:1850 --le 2:1950
$ grep _VERB ngram-*.tsv | tsv-filter --ge 2:1850 --le 2:195
$ rg _VERB ngram-*.tsv | tsv-filter --str-in-fld 1:_VERB --ge 2:1850 --le 2:1950
$ parallel tsv-filter --str-in-fld 1:_VERB --ge 2:1850 --le 2:1950 ::: ngram-*.tsv
$ parallel grep _VERB ::: ngram-*.tsv | tsv-filter --str-in-fld 1:_VERB --ge 2:1850 --le 2:1950
```

Timing results, multiple files test:

|                            | Elapsed |   User | System |  CPU |
|---------------------------:|--------:|-------:|-------:|-----:|
|                 tsv-filter |   76.06 |  74.00 |   3.21 | 101% |
|          grep & tsv-filter |   30.65 |  37.22 |   4.05 | 134% |
|       ripgrep & tsv-filter |   11.04 |  20.94 |  10.32 | 283% |
| parallel grep & tsv-filter |   16.48 | 134.54 |   6.27 | 854% |
|        parallel tsv-filter |   16.36 | 134.39 |   6.12 | 858% |

The ripgrep version, using multiple threads, is the fastest. For these tests, the single threaded use of `tsv-filter` is the limitation in both ripgrep and parallelized `grep` cases. By themselves, parallel grep and ripgrep finish the prefiltering steps in 6.3 and 3.5 seconds respectively. Very nicely, GNU `parallel` with `tsv-filter` standalone is a nice improvement.

These results show promise for ripgrep and using GNU `parallel`. Actual results will depend on the specific data files and tasks. The machine configuration will matter for multi-threading cases. See the next section, [Faster processing using GNU parallel](#faster-processing-using-gnu-parallel), for more info about GNU `parallel`.

Version information for the timing tests:
* tsv-filter v1.4.4
* GNU grep 3.3
* ripgrep 11.0.2

## Faster processing using GNU parallel

The TSV Utilities tools are singled threaded. Multiple cores available on today's processors are utilized primarily when the tools are run in a Unix command pipeline. The example shown using in [Using grep and tsv-filter together](#using-grep-and-tsv-filter-together) uses the Unix pipeline approach to some gain parallelism.

This often leaves processing power on the table, power that can be used to run commands considerably faster. This is especially true when reading from fast IO devices such as the newer generations of SSD drives. These fast devices often read much faster than a single CPU core can keep up with.

[GNU parallel](https://www.gnu.org/software/parallel/) provides a convenient way to parallelize many Unix command line tools and take advantage of multiple CPU cores. TSV Utilities tools can use GNU parallel as well, several examples are given in this section. The techniques shown can applied to many other command line tools as well. If you are using a machine with multiple cores you may gain performance benefit from using GNU parallel.

GNU `parallel` may need to be installed, use your system's package manager to do this. GNU `parallel` provides a large feature set, only a subset is shown in these examples. See the [GNU parallel documentation](https://www.gnu.org/software/parallel/) for more details.

### GNU parallel and TSV Utilities

The simplest uses of GNU `parallel` involve processing multiple files that do not contain header lines. In these scenarios, `parallel` is used to start multiple instances of a command in parallel, each command invocation run against a different file. The results from each command are written to standard output.

Line counting (`wc -l`) will be used to illustrate the process. The same Google ngram files used in the examples in [Using grep and tsv-filter together](#using-grep-and-tsv-filter-together) will be used here (26 files, 1.2 billion lines, 23 GB). All the examples in this section were timed on a 6-core Mac Mini with 64 GB RAM and SSD drives.

The standalone command to count lines in each file is below (output truncated for brevity):
```
$ wc -l ngram-*.tsv
   86618505 ngram-a.tsv
   61551917 ngram-b.tsv
   97689325 ngram-c.tsv
   ... more files ...
    3929235 ngram-x.tsv
    6869307 ngram-y.tsv
 1194956817 Total
```

`parallel` is invoked by passing both the list of files and the command to run. The file names can be provided in standard input or by using the `:::` operator. The following command lines show these two methods:
```
$ ls ngram-*.tsv | parallel wc -l
$ parallel wc -l ::: ngram-*.tsv
```

Here are the results with parallel:
```
$ parallel wc -l ::: ngram-*.tsv
17008269 ngram-j.tsv
27279767 ngram-k.tsv
39861295 ngram-g.tsv
... more files ...
88562873 ngram-p.tsv
110075424 ngram-s.tsv
```

Notice that there is no summary line. That is because `wc` produces the summary when processing multiple files, but using parallel `wc` is invoked once per file. Also, the result order has changed. This is because results are output in the order they finish rather than the order the files are listed in. The input order can be preserved using the `--keep-order` (or `-k`) option:
```
`$ parallel --keep-order wc -l ::: ngram-*.tsv
86618505 ngram-a.tsv
61551917 ngram-b.tsv
97689325 ngram-c.tsv
... more files ...
3929235 ngram-x.tsv
6869307 ngram-y.tsv
```

Timing info from these runs shows substantial performance gains using `parallel`:

| Command                             | Elapsed | User | System |  CPU |
|:------------------------------------|--------:|-----:|-------:|-----:|
| `wc -l ngram-*.tsv`                 |   11.95 | 8.26 |   3.55 |  98% |
| `parallel wc -l ::: ngram-*.tsv`    |    2.07 | 9.88 |   5.33 | 734% |
| `parallel -k wc -l ::: ngram-*.tsv` |    2.03 | 9.88 |   5.27 | 743% |

Now for some examples using TSV Utilities.

#### GNU parallel and tsv-filter

An example using `parallel` on `tsv-filter` was shown earlier in the section [Using ripgrep and tsv-filter together](#using-ripgrep-and-tsv-filter-together). That example was for a case where a grep program could be used as a prefilter. But `parallel` and `tsv-filter` will also work in cases where a grep style prefilter is not appropriate. Repeating the earlier example:

```
$ tsv-filter --str-in-fld 1:_VERB --ge 2:1850 --le 2:1950 ngram-*.tsv
$ parallel tsv-filter --str-in-fld 1:_VERB --ge 2:1850 --le 2:1950 ::: ngram-*.tsv
```

|                     | Elapsed |   User | System |  CPU |
|--------------------:|--------:|-------:|-------:|-----:|
|          tsv-filter |   76.06 |  74.00 |   3.21 | 101% |
| parallel tsv-filter |   16.36 | 134.39 |   6.12 | 858% |

This works the same way as the `wc -l` example. The output from all the individual invocations of `tsv-filter` are concatenated together, just as in the standalone invocation of `tsv-filter`. (Use the `--keep-order` option to preserve the input order.)

It's a valuable performance gain for a minor change in the command structure. Notice though that if the files had header lines additional steps would be needed, as the above commands would do nothing to suppress repeated header lines from the multiple files.

#### GNU parallel and tsv-select

`tsv-select` can be parallelized in the same fashion as `tsv-filter`. This example selects the first, second, and fourth fields from the ngram files. The `cut` utility is shown as well (`cut` from GNU coreutils 8.31). The commands and timing results:
```
$ cut -f 1,2,4 ngram-*.tsv
$ tsv-select -f 1,2,4 ngram-*.tsv
$ parallel -k cut -f 1,2,4 ::: ngram-*.tsv
$ parallel -k tsv-select -f 1,2,4 ::: ngram-*.tsv
```

|                     | Elapsed |   User | System |  CPU |
|--------------------:|--------:|-------:|-------:|-----:|
|                 cut |  158.78 | 153.82 |   4.95 |  99% |
|          tsv-select |  100.42 |  98.44 |   3.04 | 101% |
|        parallel cut |   41.07 | 278.71 |  66.65 | 840% |
| parallel tsv-select |   29.33 | 179.39 |  63.78 | 828% |

#### GNU parallel and tsv-sample

Bernoulli sampling is relatively easy to parallelize. Let's say we want to take a 0.1% sample from the ngram files. The standalone and parallelized versions of the command are similar:
```
$ tsv-sample -p 0.001 ngram-*.tsv
$ parallel -k tsv-sample -p 0.001 ::: ngram-*.tsv
```

The standalone version takes about 46 seconds to complete, the parallelized version less than 9.

|                     | Elapsed |  User | System |  CPU |
|--------------------:|--------:|------:|-------:|-----:|
|          tsv-sample |   46.08 | 44.16 |   2.47 | 101% |
| parallel tsv-sample |    8.57 | 67.09 |   3.56 | 833% |

Suppose we want to do this with simple random sampling? In simple random sampling, a specified number of records are chosen at random. Picking a 1 million random set would be done with a command like:
```
$ tsv-sample -n 1000000 ngram-*.tsv
```

We can't parallelize the `tsv-sample -n` command itself. However, a trick that can be played is to over-sample using Bernoulli sampling, then get the desired number of records with random sampling. Our earlier formula for the Bernoulli sample produces on average about 1.19 million records, a reasonable over-sampling for the 1 million records desired. (It is possible for the Bernoulli sample to produce less than 1 million records, but that would be exceptionally rare with this over-sampling rate.) The resulting formula:
```
$ tsv-sample -p 0.001 ngram-*.tsv | tsv-sample -n 1000000
```

The initial Bernoulli stage can be parallelized, just as before:
```
$ parallel -k tsv-sample -p 0.001 ::: ngram-*.tsv | tsv-sample -n 1000000
```

The timing results:

|                                      | Elapsed |  User | System |  CPU |
|-------------------------------------:|--------:|------:|-------:|-----:|
|                      random sampling |   60.14 | 58.20 |   2.68 | 101% |
|          Bernoulli & random sampling |   47.11 | 45.37 |   2.95 | 102% |
| Parallel Bernoulli & random sampling |    8.96 | 70.86 |   3.79 | 832% |

Bernoulli sampling is a bit faster than simple random sampling, so there is some benefit from using this technique in single process mode. The real win is when the Bernoulli sampling stage is parallelized.

#### GNU parallel and tsv-summarize

Many `tsv-summary` calculations require seeing all the data all at once and cannot be readily parallelized. Computations like `mean`, `median`, `stdev`, and `quantile` fall into this bucket. However, there are operations that can parallelized. Operations like `sum`, `min` and `max`. We'll use `max` to show an example of how this works. First, we'll `tsv-summarize` to find the largest occurrence count (3rd column) in the ngram files:
```
$ tsv-summarize --max 3 ngram-*.tsv
927838975
```

That works, but took 85 seconds. Here's a version that parallelizes the invocations:
```
$ parallel tsv-summarize --max 3 ::: ngram-*.tsv
11383300
12112865
11794164
...
32969204
```

That worked, but produced a result line for each file. To get the final results we need to make another `tsv-summarize` call aggregating the intermediate results:

```
$ parallel tsv-summarize --max 3 ::: ngram-*.tsv | tsv-summarize --max 1
927838975
```

This produced the correct result and finished in 18 seconds, much more palatable than the 85 seconds in the single process version.

We could find the maximim occurrence count for each year (column 2) in a similar fashion. This example sorts the results by year for good measure.
```
$ tsv-summarize --group-by 2 --max 3 ngram-*.tsv | tsv-sort-fast -k1,1n
1505	1267
1507	1938
1515	19549
...
2005	658292423
2006	703340664
2007	749205383
2008	927838975
```

This took 110 seconds. Here's the parallel version. It produces the same results, but finishes in 23 seconds, nearly 5 times faster.
```
$ parallel tsv-summarize --group-by 2 --max 3 ::: ngram-*.tsv | tsv-summarize --group-by 1 --max 2 | tsv-sort-fast -k1,1n
```

Notice that in the "group-by year" example, the second `tsv-summarize` pass is necessary because the entries for each year occur in multiple files. If the files are organized by the group-by key, then the second pass is not necessary. The google ngram files are organized by first letter of the ngram (a file for "a", a file for "b", etc.), so "group-by" operations on the ngram field would not need the second pass. The [tsv-split](ToolReference.md#tsv-split-reference) tool's "random assignment by key" feature can be used to split a data set into files sharded by key. This is especially helpful when the number of unique keys in the data set is very large.

### Using GNU Parallel on files with header lines

All the examples shown so far involve multiple files without header lines. Correctly handling header lines is a more involved. The main issue is that results from multiple files get concatenated together when results are reassembled. One way to deal with this is to drop the headers from each file as they are processed, arranging to have the header from the first file preserved if necessary. Other methods are possible, but more involved than will be discussed here.

### GNU Parallel on standard input or a single large file

All the examples shown so far run against multiple files. This is a natural fit for `parallel`'s capabilities. `parallel` also has facilities for automatically splitting up individual files as well as standard input into smaller chunks and invoking commands on these smaller chunks in parallel.

Unfortunately, performance when using these facilities is more variable than when running against multiple input files. This is because the work to split up the file or input stream is itself single threaded and can be a bottleneck. Performance gains are unlikely to match the gains seen on multiple files, and performance may actually get worse. Performance appears dependent on the specific task, the nature of the files or input stream, and the computation being performed. Some experimentation may needed to identify the best parameter tuning.

For these reasons, paralellizing tasks on standard input or against single files may be most appropriate for repeated tasks. Tasks run on a regular basis against similar data sets, where time invested in performance tuning gets paid back over multiple runs.

Of the two cases, performance gains are more likely when running against a single file than when running against standard input. That is because the mechanism used to split a file (`--pipepart`) is much faster than the mechanism used to split up standard input (`--pipe`).

Here are examples of the command syntax. The Bernoulli sampling example used earlier is shown:
```
$ # Standalone invocation
$ tsv-sample -p 0.001 bigfile.txt

$ # Reading from standard input and splitting via --pipe
$ cat bigfile.txt | parallel --pipe --blocksize=64M tsv-sample -p 0.001

$ # Reading from a single file and splitting via --pipepart
$ parallel -a bigfile.txt --pipepart --blocksize=64M tsv-sample -p 0.001
```

Consult the [GNU parallel documentation](https://www.gnu.org/software/parallel/) for more information about these features. Experiment with them in your environment to see what works for your use cases.

## Reading data in R

It's common to perform transformations on data prior to loading into applications like R or Pandas. This especially useful when data sets are large and loading entirely into memory is undesirable. One approach is to create modified files and load those. In R it can also be done as part of the different read routines, most of which allow reading from a shell command. This enables filtering rows, selecting, sampling, etc. This will work with any command line tool. Some examples below. These use `read.table` from the base R package, `read_tsv` from the `tidyverse/readr` package, and `fread` from the `data.table` package:
```
> df1 = read.table(pipe("tsv-select -f 1,2,7 data.tsv | tsv-sample -H -n 50000"), sep="\t", header=TRUE, quote="")
> df2 = read_tsv(pipe("tsv-select -f 1,2,7 data.tsv | tsv-sample -H -n 50000"))
> df3 = fread("tsv-select -f 1,2,7 train.tsv | tsv-sample -H -n 50000")
```

The first two use the `pipe` function to create the shell command. `fread` does this automatically.

*Note: One common issue is not having the PATH environment setup correctly. Depending on setup, the R application might not have the full path normally available in a command shell. See the R documentation for details.*

## Shuffling large files

Line order randomization, or "shuffling", is one of the operations supported by [tsv-sample](ToolReference.md#tsv-sample-reference). Most `tsv-sample` operations can be performed with limited system memory. However, system memory becomes a limitation when shuffling very large data sets, as the entire data set must be loaded into memory. ([GNU shuf](https://www.gnu.org/software/coreutils/manual/html_node/shuf-invocation.html) has the same limitation.)

In many cases the most effective solution is simply to get more memory, or find a machine with enough memory. However, when more memory is not an option, another solution to consider is disk-based shuffling. This is approach described here.

One option for disk-based shuffling is [GNU sort](https://www.gnu.org/software/coreutils/manual/html_node/sort-invocation.html)'s random sort feature (`sort --random-sort`). This can be used for unweighted randomization. However, there are couple of downsides. One is that it places duplicates lines next to each other, a problem for many shuffling use cases. Another is that it is rather slow.

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

Performance of the approaches described will vary considerably based on the hardware and data sets. As one comparison point the author ran both `sort --random-sort` and the unweighted, disk based approach shown above on a 294 million line, 5.8 GB data set. A 16 GB macOS box with SSD disk storage was used. This data set fits in memory on this machine, so the in-memory approach was tested as well. Both `tsv-sample` and GNU `shuf` were used. The `sort --random-sort` metric was run with [locale sensitive sorting](#turn-off-locale-sensitive-sort-when-not-needed) both on and off to show the difference.

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
