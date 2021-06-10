_Visit the [Tools Reference main page](../ToolReference.md)_<br>
_Visit the [TSV Utilities main page](../../README.md)_

# tsv-sample reference

**Synopsis:** tsv-sample [options] [file...]

`tsv-sample` subsamples input lines or randomizes their order. Several techniques are available: shuffling, simple random sampling, weighted random sampling, Bernoulli sampling, and distinct sampling. These are provided via several different modes operation:

* **Shuffling** (_default_): All lines are read into memory and output in random order. All orderings are equally likely.
* **Simple random sampling** (`--n|num N`): A random sample of `N` lines is selected and written to standard output. Selected lines are written in random order, similar to shuffling. All sample sets and orderings are equally likely. Use `--i|inorder` to preserve the original input order.
* **Weighted random sampling** (`--n|num N`, `--w|weight-field F`): A weighted sample of N lines is selected using weights from a field on each line. Selected lines are written in weighted selection order. Use `--i|inorder` to preserve the original input order. Omit `--n|num` to shuffle all input lines (weighted shuffling).
* **Sampling with replacement** (`--r|replace`, `--n|num N`): All lines are read into memory, then lines are selected one at a time at random and written out. Lines can be selected multiple times. Output continues until `N` samples have been written. Output continues forever if `--n|num` is zero or not specified.
* **Bernoulli sampling** (`--p|prob P`): Lines are read one-at-a-time in a streaming fashion and a random subset is output based on the inclusion probability. For example, `--prob 0.2` gives each line a 20% chance of being selected. All lines have an equal likelihood of being selected. The order of the lines is unchanged.
* **Distinct sampling** (`--k|key-fields F`, `--p|prob P`): Input lines are sampled based on a key from each line. A key is made up of one or more fields. A subset of the keys are chosen based on the inclusion probability (a "distinct" set of keys). All lines with one of the selected keys are output. This is a streaming operation: a decision is made on each line as it is read. The order of the lines is not changed.

**Sample size**: The `--n|num` option controls the sample size for all sampling methods. In the case of simple and weighted random sampling it also limits the amount of memory required.

**Performance and memory use**: `tsv-sample` is designed for large data sets. Algorithms make one pass over the data, using reservoir sampling and hashing when possible to limit the memory required. Bernoulli sampling and distinct sampling make immediate decisions on each line, with no memory accumulation. They can operate on arbitrary length data streams. Sampling with replacement reads all lines into memory and is limited by available memory. Shuffling also reads all lines into memory and is similarly limited. Simple and weighted random sampling use reservoir sampling algorithms and only need to hold the sample size (`--n|num`) in memory. See [Shuffling large files](../TipsAndTricks.md#shuffling-large-files) for ways to use disk when available memory is not sufficient.

**Controlling randomization**: Each run produces a different randomization. Using `--s|static-seed` changes this so multiple runs produce the same randomization. This works by using the same random seed each run. The random seed can be specified using `--v|seed-value`. This takes a non-zero, 32-bit positive integer. A zero value is a no-op and ignored.

**Weighted sampling**: Weighted line order randomization is done using an algorithm for weighted reservoir sampling described by Pavlos Efraimidis and Paul Spirakis. Weights should be positive values representing the relative weight of the entry in the collection. Counts and similar can be used as weights, it is *not* necessary to normalize to a [0,1] interval. Negative values are not meaningful and given the value zero. Input order is not retained, instead lines are output ordered by the randomized weight that was assigned. This means that a smaller valid sample can be produced by taking the first N lines of output. For more information see:
* Wikipedia: https://en.wikipedia.org/wiki/Reservoir_sampling
* "Weighted Random Sampling over Data Streams", Pavlos S. Efraimidis (https://arxiv.org/abs/1012.0256)

**Distinct sampling**: Distinct sampling selects a subset based on a key in data. Consider a query log with records consisting of <user, query, clicked-url> triples. Distinct sampling selects all records matching a subset of values from one of the fields. For example, all events for ten percent of the users. This is important for certain types of analysis. Distinct sampling works by converting the specified probability (`--p|prob`) into a set of buckets and mapping every key into one of the buckets. One bucket is used to select records in the sample. Buckets are equal size and therefore may be a bit larger than the inclusion probability. Since every key is assigned a bucket, this method can also be used to fully divide a set of records into distinct groups. (See *Printing random values* below.) The term "distinct sampling" originates from algorithms estimating the number of distinct elements in extremely large data sets.

**Printing random values**: Most of these algorithms work by generating a random value for each line. (See also "Compatibility mode" below.) The nature of these values depends on the sampling algorithm. They are used for both line selection and output ordering. The `--print-random` option can be used to print these values. The random value is prepended to the line separated by the `--d|delimiter` char (TAB by default). The `--gen-random-inorder` option takes this one step further, generating random values for all input lines without changing the input order. The types of values currently used are specific to the sampling algorithm:
* Shuffling, simple random sampling, Bernoulli sampling: Uniform random value in the interval [0,1].
* Weighted random sampling: Value in the interval [0,1]. Distribution depends on the values in the weight field.
* Distinct sampling: An integer, zero and up, representing a selection group (aka. "bucket"). The inclusion probability determines the number of selection groups.
* Sampling with replacement: Random value printing is not supported.

The specifics behind these random values are subject to change in future releases.

**Compatibility mode**: As described above, many of the sampling algorithms assign a random value to each line. This is useful when printing random values. It has another occasionally useful property: repeated runs with the same static seed but different selection parameters are more compatible with each other, as each line gets assigned the same random value on every run. This property comes at a cost: in some cases there are faster algorithms that don't assign random values to each line. By default, `tsv-sample` will use the fastest algorithm available. The `--compatibility-mode` option changes this, switching to algorithms that assign a random value per line. Printing random values also engages compatibility mode. Compatibility mode is beneficial primarily when using Bernoulli sampling or random sampling:
* Bernoulli sampling - A run with a larger probability will be a superset of a smaller probability. In the example below, all lines selected in the first run are also selected in the second.
  ```
  $ tsv-sample --static-seed --compatibility-mode --prob 0.2 data.tsv
  $ tsv-sample --static-seed --compatibility-mode --prob 0.3 data.tsv
  ```
* Random sampling - A run with a larger sample size will be a superset of a smaller sample size. In the example below, all lines selected in the first run are also selected in the second.
  ```
  $ tsv-sample --static-seed --compatibility-mode -n 1000 data.tsv
  $ tsv-sample --static-seed --compatibility-mode -n 1500 data.tsv
  ```
  This works for weighted sampling as well.

**Options:**

* `--h|help` - This help information.
* `--help-verbose` - Print more detailed help.
* `--help-fields ` - Print help on specifying fields.
* `--V|version` - Print version information and exit.
* `--H|header` - Treat the first line of each file as a header.
  * `--n|num NUM` - Maximum number of lines to output. All selected lines are output if not provided or zero.
* `--p|prob NUM` - Inclusion probability (0.0 < NUM <= 1.0). For Bernoulli sampling, the probability of each line being selected. For distinct sampling, the probability of each unique key being selected.
* `--k|key-fields <field-list>` - Fields to use as key for distinct sampling. Use with `--p|prob`. Specify `--k|key-fields 0` to use the entire line as the key.
* `--w|weight-field NUM` - Field containing weights. All lines get equal weight if not provided or zero.
* `--r|replace` - Simple random sampling with replacement. Use `--n|num` to specify the sample size.
* `--s|static-seed` - Use the same random seed every run.
* `--v|seed-value NUM` - Sets the random seed. Use a non-zero, 32 bit positive integer. Zero is a no-op.
* `--print-random` - Output the random values that were assigned.
* `--gen-random-inorder` - Output all lines with assigned random values prepended, no changes to the order of input.
* `--random-value-header` - Header to use with `--print-random` and `--gen-random-inorder`. Default: `random_value`.
* `--compatibility-mode` - Turns on "compatibility mode".
* `--d|delimiter CHR` - Field delimiter.
* `--line-buffered` - Immediately output every sampled line. Applies to Bernoulli and distinct sampling. Ignored in modes where all input data must be read before generating output.
* `--prefer-skip-sampling` - (Internal) Prefer the skip-sampling algorithm for Bernoulli sampling. Used for testing and diagnostics.
* `--prefer-algorithm-r` - (Internal) Prefer Algorithm R for unweighted line order randomization. Used for testing and diagnostics.
