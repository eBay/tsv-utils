# Build commands

Using the make system is preferred if make runs on your system. Simply running `make` from the top-level will build the release executables. However, if `make` isn't available, the individual build commands are easy enough to run manually. The commands below are the same issued by the make system. Replace ${DCOMPILER} with the compiler being used, e.g. `dmd` or `ldc2`. If using `dmd`, performance can be improved further by adding the `-inline` switch to the compiler line. 

## number-lines

```
$ cd number-lines
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../bin/number-lines -I../common/src src/number-lines.d
```

## tsv-select

```
$ cd tsv-select
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -L-w -of../bin/tsv-select -I../common/src src/tsv-select.d ../common/src/tsvutil.d
```

## tsv-filter

```
$ tsv-filter
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../bin/tsv-filter -I../common/src src/tsv-filter.d
```

## tsv-join

```
$ cd tsv-join
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../bin/tsv-join -I../common/src src/tsv-join.d ../common/src/tsvutil.d
```

## tsv-uniq

```
$ cd tsv-uniq
$ ${DCOMPILER} -release -O -boundscheck=off -odobj -of../bin/tsv-uniq -I../common/src src/tsv-uniq.d ../common/src/tsvutil.d
```
