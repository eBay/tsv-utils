_Visit the eBay TSV utilities [main page](../README.md)_

# tsv-sample

`tsv-sample` randomizes line order or selects subsamples of lines from input data. Several sampling methods are available, including simple and weighted random sampling, Bernoulli sampling, and distinct sampling. Data can be read from files or standard input.

Line order randomization is the default mode of operation. All lines are read into memory and written out in a random order. All orderings are equally likely. This can be used for simple random sampling by specifying the `-n|--num` option, producing a random subset of the specified size.

This can be extended to weighted versions using `-w|--weight-field` option. In this version a weight field from each line determines the relative likelihood of the line being selected for each position in the output. This is a form of weighted random sampling.

Sampling can be done in streaming mode by using the `-r|rate` option. This specifies the desired portion of lines that should be included in the sample. e.g. `-r 0.1` specifies that 10% of lines should be included in the sample. In this mode lines are read one at a time, a random selection choice made, and those lines selected are immediately output. All lines have an equal likelihood of being output. This is known as Bernoulli sampling.

Distinct sampling also operates in streaming mode. However, instead of each line being subject to an independent selection choice, lines are selected based on a key contained in each line. A portion of keys are randomly selected for output, and every line containing a selected key is included in the output. Consider a query log with records consisting of <user, query, clicked-url> triples. It may be desirable to sample records for one percent of the users, but include all records for the selected users. Distinct sampling is specified using the `-k|--key-fields` and `-r|--rate` options.

`tsv-sample` is designed for large data sets. Streaming algorithms make immediate decisions on each line. They do not accumulate memory and can run on infinite length input streams. Line order randomization algorithms need to hold the full output set into memory and are therefore limited by available memory. Memory requirements can be reduced by specifying a sample size (`-n|--num`). This enables reservoir sampling, which is often dramatically faster than full permutations. By default, a new random order is generated every run, but options are available for using the same randomization order over multiple runs. The random values assigned to each line can be printed, either to observe the behavior or even run further customized selected algorithms.

See the [tsv-sample reference](../docs/ToolReference.md#tsv-sample-reference) for further details.
