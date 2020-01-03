/**
Utility functions used by tsv-utils programs.

A few of the utilities that may be of more general interest:

$(LIST
    * [tsv_utils.common.utils.InputFieldReordering] - A class that creates a reordered
      subset of fields from an input line. Used to operate on a subset of fields in the
      order specified on the command line.
    * [tsv_utils.common.utils.BufferedOutputRange] - An OutputRange with an internal
      buffer used to buffer output. Intended for use with stdout, it is a significant
      performance benefit.
    * [tsv_utils.common.utils.bufferedByLine] - An input range that reads from a File
      handle line by line. It is similar to standard library method std.stdio.File.byLine,
      but quite a bit faster. This is achieved by reading in larger blocks and buffering.
    * [tsv_utils.common.numerics.quantile] - Calculates a cummulative probability for
      values in a data set. Supports the same interpolation methods as the quantile
      function in R and many other statistical packages.
    * [tsv_utils.common.numerics.rangeMedian] - Finds the median in a range. Implements
      via the faster of std.algorithm.topN or std.algorithm.sort depending on the
      Phobos version.
    * [tsv_utils.common.numerics.formatNumber] - An alternate print format for numbers,
      especially useful when doubles are being used to represent integer and float values.
    * [tsv_utils.common.getopt_inorder.getoptInorder] - A cover for std.getopt that
      processes command line arguments in the order given on the command line.
)

Copyright (c) 2015-2020, eBay Inc.
Initially written by Jon Degenhardt

License: Boost License 1.0 (http://boost.org/LICENSE_1_0.txt)
*/
module tsv_utils.common;
