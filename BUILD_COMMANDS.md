# Build commands

Using the make system if make runs on your system. Simply running `make` from the top-level will build the release executables. DUB is also a good way to build, see the install section of the readme file. However, if these are not options, the individual build commands are easy enough to run manually. The commands below are the same issued by the make system. Replace ${DCOMPILER} with the compiler being used, e.g. `dmd` or `ldc2`. If using `dmd`, performance can be improved further by adding the `-inline` switch to the compiler line. 

## tsv-filter

```
$ tsv-filter
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../tsv-utils-dlang/bin/tsv-filter -I../tsv-utils-dlang/common/src src/tsv-filter.d ../tsv-utils-dlang/common/src/tsvutil.d ../tsv-utils-dlang/common/src/getopt_inorder.d ../tsv-utils-dlang/common/src/unittest_utils.d
```

## tsv-select

```
$ cd tsv-select
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../tsv-utils-dlang/bin/tsv-select -I../tsv-utils-dlang/common/src src/tsv-select.d ../tsv-utils-dlang/common/src/tsvutil.d ../tsv-utils-dlang/common/src/getopt_inorder.d ../tsv-utils-dlang/common/src/unittest_utils.d
```

## tsv-summarize

```
$ cd tsv-summarize
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../tsv-utils-dlang/bin/tsv-summarize -I../tsv-utils-dlang/common/src src/tsv-summarize.d ../tsv-utils-dlang/common/src/tsvutil.d ../tsv-utils-dlang/common/src/getopt_inorder.d ../tsv-utils-dlang/common/src/unittest_utils.d
```

## tsv-join

```
$ cd tsv-join
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../tsv-utils-dlang/bin/tsv-join -I../tsv-utils-dlang/common/src src/tsv-join.d ../tsv-utils-dlang/common/src/tsvutil.d ../tsv-utils-dlang/common/src/getopt_inorder.d ../tsv-utils-dlang/common/src/unittest_utils.d
```

## tsv-append

```
$ cd tsv-append
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../tsv-utils-dlang/bin/tsv-append -I../tsv-utils-dlang/common/src src/tsv-append.d ../tsv-utils-dlang/common/src/tsvutil.d ../tsv-utils-dlang/common/src/getopt_inorder.d ../tsv-utils-dlang/common/src/unittest_utils.d
```

## tsv-uniq

```
$ cd tsv-uniq
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../tsv-utils-dlang/bin/tsv-uniq -I../tsv-utils-dlang/common/src src/tsv-uniq.d ../tsv-utils-dlang/common/src/tsvutil.d ../tsv-utils-dlang/common/src/getopt_inorder.d ../tsv-utils-dlang/common/src/unittest_utils.d
```

## csv2tsv

```
$ cd csv2tsv
$ ${DCOMPILER} -release -O -boundscheck=off -odob -of../tsv-utils-dlang/bin/csv2tsv -I../tsv-utils-dlang/common/src src/csv2tsv.d ../tsv-utils-dlang/common/src/tsvutil.d ../tsv-utils-dlang/common/src/getopt_inorder.d ../tsv-utils-dlang/common/src/unittest_utils.d
```

## number-lines

```
$ cd number-lines
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../tsv-utils-dlang/bin/number-lines -I../tsv-utils-dlang/common/src src/number-lines.d ../tsv-utils-dlang/common/src/tsvutil.d ../tsv-utils-dlang/common/src/getopt_inorder.d ../tsv-utils-dlang/common/src/unittest_utils.d
```
