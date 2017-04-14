# Build commands

*Note: This file is no longer being updated. However, should it be necessary to run build commands manually, the information here should be a good starting point.* 

Using the make system if make runs on your system. Simply running `make` from the top-level will build the release executables. DUB is also a good way to build, see the install section of the readme file. However, if these are not options, the individual build commands are easy enough to run manually. The commands below are the same issued by the make system. Replace ${DCOMPILER} with the compiler being used, e.g. `dmd` or `ldc2`. If using `dmd`, performance can be improved further by adding the `-inline` switch to the compiler line. 

## tsv-filter

```
$ tsv-filter
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../bin/tsv-filter -I../common/src src/tsv-filter.d ../common/src/tsvutil.d ../common/src/getopt_inorder.d ../common/src/unittest_utils.d
```

## tsv-select

```
$ cd tsv-select
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../bin/tsv-select -I../common/src src/tsv-select.d ../common/src/tsvutil.d ../common/src/getopt_inorder.d ../common/src/unittest_utils.d
```

## tsv-summarize

```
$ cd tsv-summarize
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../bin/tsv-summarize -I../common/src src/tsv-summarize.d ../common/src/tsvutil.d ../common/src/getopt_inorder.d ../common/src/unittest_utils.d
```

## tsv-join

```
$ cd tsv-join
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../bin/tsv-join -I../common/src src/tsv-join.d ../common/src/tsvutil.d ../common/src/getopt_inorder.d ../common/src/unittest_utils.d
```

## tsv-sample

```
$ cd tsv-sample
$ ${DCOMPILER} -release -O -boundscheck=off -odobj  -of../bin/tsv-sample -I../common/src src/tsv-sample.d ../common/src/tsvutil.d ../common/src/getopt_inorder.d ../common/src/unittest_utils.d
```

## tsv-append

```
$ cd tsv-append
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../bin/tsv-append -I../common/src src/tsv-append.d ../common/src/tsvutil.d ../common/src/getopt_inorder.d ../common/src/unittest_utils.d
```

## tsv-uniq

```
$ cd tsv-uniq
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../bin/tsv-uniq -I../common/src src/tsv-uniq.d ../common/src/tsvutil.d ../common/src/getopt_inorder.d ../common/src/unittest_utils.d
```

## csv2tsv

```
$ cd csv2tsv
$ ${DCOMPILER} -release -O -boundscheck=off -odob -of../bin/csv2tsv -I../common/src src/csv2tsv.d ../common/src/tsvutil.d ../common/src/getopt_inorder.d ../common/src/unittest_utils.d
```

## number-lines

```
$ cd number-lines
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../bin/number-lines -I../common/src src/number-lines.d ../common/src/tsvutil.d ../common/src/getopt_inorder.d ../common/src/unittest_utils.d
```
