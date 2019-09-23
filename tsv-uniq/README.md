_Visit the eBay TSV utilities [main page](../README.md)_

# tsv-uniq

Similar in spirit to the Unix `uniq` tool, `tsv-uniq` filters a dataset so there is only one copy of each unique line. `tsv-uniq` goes beyond Unix `uniq` in a couple ways. First, data does not need to be sorted. Second, equivalence can be based on a subset of fields rather than the full line.

`tsv-uniq` can also be run in 'equivalence class identification' mode, where lines with equivalent keys are marked with a unique id rather than filtered out. Another variant is 'number' mode, which generates lines numbers grouped by the key.

An example uniq'ing a file on fields 2 and 3:
```
$ tsv-uniq -f 2,3 data.tsv
```

`tsv-uniq` operates on the entire line when no fields are specified. This is a useful alternative to the traditional `sort -u` or `sort | uniq` paradigms for identifying unique lines in unsorted files, as it is quite a bit faster.

As with `tsv-join`, this uses an in-memory lookup table to record unique entries. This ultimately limits the data sizes that can be processed. The author has found that datasets with up to about 10 million unique entries work fine, but performance starts degrade after that. Even then it remains quite a bit faster than the alternatives.

See the [tsv-uniq reference](../docs/ToolReference.md#tsv-uniq-reference) for details.
