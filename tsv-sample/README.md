_Visit the eBay TSV utilities [main page](../README.md)_

# tsv-sample

`tsv-sample` does uniform and weighted random sampling of files. For uniform random sampling, the GNU `shuf` program is quite good and widely available. For weighted random sampling the choices are limited, especially when working with large files. This is where `tsv-sample` is especially useful. It implements weighted reservoir sampling, with the weights taken from a field in the input data. Uniform random sampling is supported as well. Performance is good, it works quite well on large files.

See the [tsv-sample reference](../docs/ToolReference.md#tsv-sample-reference) for details.
