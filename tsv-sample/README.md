_Visit the eBay TSV utilities [main page](../README.md)_

# tsv-sample

`tsv-sample` randomizes or sample lines from input data. Several sampling methods are available, including simple random sampling, weighted random sampling, and distinct sampling.

Simple random sampling operates in the customary fashion, randomly selecting lines with equal probability. When reordering a file, lines are randomly selected from the entire file and output in the order selected. In streaming mode, a subset of input lines are selected and output. This occurs in the order of the input. Streaming mode operates on arbitrary large inputs.

Weighted random sampling selects input lines in a weighted fashion, using weights from a field in the data. Lines are output in the order selected, reordering the file.

Distinct sampling selects a subset based on a key in data. Consider a query log with records consisting of <user, query, clicked-url> triples. Simple random sampling selects a random subset of all records. Distinct sampling selects all records matching a subset of values from one of fields. For example, all events for ten percent of the users. This is important for certain types of statistical analysis.

`tsv-sample` is designed for large data sets. Algorithms make one pass over the data, using reservoir sampling and hashing when possible to limit the memory required. By default, a new random order is generated every run, but options are available for using the same randomization order over multiple runs.

See the [tsv-sample reference](../docs/ToolReference.md#tsv-sample-reference) for further details.
