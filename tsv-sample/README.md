_Visit the eBay TSV utilities [main page](../README.md)_

# tsv-sample

`tsv-sample` randomizes line order (shuffling) or selects random subset of lines (sampling) from input data. Several techniques are available, including shuffling, simple random sampling, weighted random sampling, Bernoulli sampling, and distinct sampling. Data can be read from files or standard input. These sampling and shuffling methods are made available through several modes of operation:

* Line order randomization (Shuffling) - This is the default mode of operation. All lines are read into memory and written out in a random order. All orderings are equally likely. This can be used for simple random sampling by specifying the `-n|--num` option, producing a random subset of the specified size. (Subsets are in random order.)

* Weighted line order randomization - This extends the previous method to weighted shuffling or weighted random sampling by the use of a weight taken from each line. The weight field is specified with the `-w|--weight-field` option.

* Sampling with replacement - All lines are read into memory, then lines are selected one at a time at random and output. Lines can be output multiple times. Output continues until `-n|--num` samples have been output.

* Bernoulli sampling - Sampling can be done in streaming mode by using the `-p|--prob` option. This specifies the desired portion of lines that should be included in the sample. e.g. `-p 0.1` specifies that 10% of lines should be included in the sample. In this mode lines are read one at a time, a random selection choice made, and those lines selected are immediately output. All lines have an equal likelihood of being output.

* Distinct sampling - This is another streaming mode form of sampling. However, instead of each line being subject to an independent selection choice, lines are selected based on a key contained in each line. A portion of keys are randomly selected for output, and every line containing a selected key is included in the output. Consider a query log with records consisting of <user, query, clicked-url> triples. It may be desirable to sample records for one percent of the users, but include all records for the selected users. Distinct sampling is specified using the `-k|--key-fields` and `-p|--prob` options.

`tsv-sample` is designed for large data sets. Streaming algorithms make immediate decisions on each line. They do not accumulate memory and can run on infinite length input streams. Line order randomization algorithms need to hold the full output set into memory and are therefore limited by available memory. Memory requirements can be reduced by specifying a sample size (`-n|--num`). This enables reservoir sampling, which is often dramatically faster than full permutations. By default, a new random order is generated every run, but options are available for using the same randomization order over multiple runs. The random values assigned to each line can be printed, either to observe the behavior or even run further customized selected algorithms.

See the [tsv-sample reference](../docs/ToolReference.md#tsv-sample-reference) for further details.
