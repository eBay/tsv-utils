_Visit the eBay TSV utilities [main page](../README.md)_

# tsv-sample

`tsv-sample` randomizes line order (shuffling) or selects random subsets of lines (sampling) from input data. Several methods are available, including shuffling, simple random sampling, weighted random sampling, Bernoulli sampling, and distinct sampling. Data can be read from files or standard input. These sampling methods are made available through several modes of operation:

* Shuffling - The default mode of operation. All lines are read in and written out in random order. All orderings are equally likely.
* Simple random sampling (`--n|num N`) - A random sample of `N` lines are selected and written out in random order. The `--i|inorder` option preserves the original input order.
* Weighted random sampling (`--n|num N`, `--w|weight-field F`) - A weighted random sample of N lines are selected using weights from a field on each line. Output is in weighted selection order unless the `--i|inorder` option is used. Omitting `--n|num` outputs all lines in weighted selection order (weighted shuffling).
* Sampling with replacement (`--r|replace`, `--n|num N`) - All lines are read in, then lines are randomly selected one at a time and written out. Lines can be selected multiple times. Output continues until `N` samples have been output.
* Bernoulli sampling (`--p|prob P`) - A streaming form of sampling. Lines are read one at a time and selected for output using probability `P`. e.g. `-p 0.1` specifies that 10% of lines should be included in the sample.
* Distinct sampling (`--k|key-fields F`, `--p|prob P`) - Another streaming form of sampling. However, instead of each line being subject to an independent selection choice, lines are selected based on a key contained in each line. A portion of keys are randomly selected for output, with probability P. Every line containing a selected key is included in the output. Consider a query log with records consisting of <user, query, clicked-url> triples. It may be desirable to sample records for one percent of the users, but include all records for the selected users.

`tsv-sample` is designed for large data sets. Streaming algorithms make immediate decisions on each line. They do not accumulate memory and can run on infinite length input streams. Shuffling algorithms need to hold the full output set in memory and are therefore limited by available memory. Simple and weighted random sampling use reservoir sampling and only need to hold the specified sample size (`--n|num`) in memory. By default, a new random order is generated every run, but options are available for using the same randomization order over multiple runs. The random values assigned to each line can be printed, either to observe the behavior or to run custom selection algorithms on the results.

See the [tsv-sample reference](../docs/tool_reference/tsv-sample.md) for further details.
