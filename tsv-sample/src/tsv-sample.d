/**
Command line tool for randomizing or sampling lines from input streams. Several
sampling methods are available, including simple random sampling, weighted random
sampling, Bernoulli sampling, and distinct sampling.

Copyright (c) 2017-2018, eBay Software Foundation
Initially written by Jon Degenhardt

License: Boost License 1.0 (http://boost.org/LICENSE_1_0.txt)
*/
module tsv_sample;

import std.range;
import std.stdio;
import std.typecons : tuple, Flag;

version(unittest)
{
    // When running unit tests, use main from -main compiler switch.
}
else
{
    int main(string[] cmdArgs)
    {
        /* When running in DMD code coverage mode, turn on report merging. */
        version(D_Coverage) version(DigitalMars)
        {
            import core.runtime : dmd_coverSetMerge;
            dmd_coverSetMerge(true);
        }

        TsvSampleOptions cmdopt;
        auto r = cmdopt.processArgs(cmdArgs);
        if (!r[0]) return r[1];
        version(LDC_Profile)
        {
            import ldc.profile : resetAll;
            resetAll();
        }
        try
        {
            import tsv_utils.common.util : BufferedOutputRange;
            auto bufferedOutput = BufferedOutputRange!(typeof(stdout))(stdout);

            tsvSample(cmdopt, bufferedOutput);
        }
        catch (Exception exc)
        {
            stderr.writefln("Error [%s]: %s", cmdopt.programName, exc.msg);
            return 1;
        }
        return 0;
    }
}

auto helpText = q"EOS
Synopsis: tsv-sample [options] [file...]

Sample input lines or randomize their order. Several modes of operation
are available:
* Line order randomization (the default): All input lines are output in a
  random order. All orderings are equally likely.
* Weighted line order randomization (--w|weight-field): Lines are selected
  using weighted random sampling, with the weight taken from a field.
  Lines are output in weighted selection order, reordering the lines.
* Sampling with replacement (--r|replace, --n|num): All input is read into
  memory, then lines are repeatedly selected at random and written out. This
  continues until --n|num samples are output. Lines can be selected multiple
  times. Output continues forever if --n|num is zero or not specified.
* Bernoulli sampling (--p|prob): A random subset of lines is output based
  on an inclusion probability. This is a streaming operation. A selection
  decision is made on each line as is it read. Line order is not changed.
* Distinct sampling (--k|key-fields, --p|prob): Input lines are sampled
  based on the values in the key field. A subset of the keys are chosen
  based on the inclusion probability (a 'distinct' set of keys). All lines
  with one of the selected keys are output. Line order is not changed.

The '--n|num' option limits the sample size produced. It speeds up line
order randomization and weighted sampling significantly. It is also used
to terminate sampling with replacement.

Use '--help-verbose' for detailed information.

Options:
EOS";

auto helpTextVerbose = q"EOS
Synopsis: tsv-sample [options] [file...]

Sample input lines or randomize their order. Several modes of operation
are available:
* Line order randomization (the default): All input lines are output in a
  random order. All orderings are equally likely.
* Weighted line order randomization (--w|weight-field): Lines are selected
  using weighted random sampling, with the weight taken from a field.
  Lines are output in weighted selection order, reordering the lines.
* Sampling with replacement (--r|replace, --n|num): All input is read into
  memory, then lines are repeatedly selected at random and written out. This
  continues until --n|num samples are output. Lines can be selected multiple
  times. Output continues forever if --n|num is zero or not specified.
* Bernoulli sampling (--p|prob): A random subset of lines is output based
  on an inclusion probability. This is a streaming operation. A selection
  decision is made on each line as is it read. Lines order is not changed.
* Distinct sampling (--k|key-fields, --p|prob): Input lines are sampled
  based on the values in the key field. A subset of the keys are chosen
  based on the inclusion probability (a 'distinct' set of keys). All lines
  with one of the selected keys are output. Line order is not changed.

Sample size: The '--n|num' option limits the sample size produced. This
speeds up line order randomization and weighted sampling significantly
(details below). It is also used to terminate sampling with replacement.

Controlling the random seed: By default, each run produces a different
randomization or sampling. Using '--s|static-seed' changes this so
multiple runs produce the same results. This works by using the same
random seed each run. The random seed can be specified using
'--v|seed-value'. This takes a non-zero, 32-bit positive integer. (A zero
value is a no-op and ignored.)

Memory use: Bernoulli sampling and distinct sampling make decisions on
each line as it is read, so there is no memory accumulation. These
algorithms support arbitrary size inputs. Sampling with replacement reads
all lines into memory and is limited by available memory. The line order
randomization algorithms hold the full output set in memory prior to
generating results. This ultimately limits the size of the output set. For
these memory needs can be reduced by using a sample size (--n|num). This
engages reservior sampling. Output order is not affected. Both
'tsv-sample -n 1000' and 'tsv-sample | head -n 1000' produce the same
results, but the former is quite a bit faster.

Weighted sampling: Weighted random sampling is done using an algorithm
described by Pavlos Efraimidis and Paul Spirakis. Weights should be
positive values representing the relative weight of the entry in the
collection. Counts and similar can be used as weights, it is *not*
necessary to normalize to a [0,1] interval. Negative values are not
meaningful and given the value zero. Input order is not retained, instead
lines are output ordered by the randomized weight that was assigned. This
means that a smaller valid sample can be produced by taking the first N
lines of output. For more info on the sampling approach see:
* Wikipedia: https://en.wikipedia.org/wiki/Reservoir_sampling
* "Weighted Random Sampling over Data Streams", Pavlos S. Efraimidis
  (https://arxiv.org/abs/1012.0256)

Printing random values: Most of the sampling algorithms work by generating
a random value for each line. (See "Compatibility mode" below.) The nature
of these values depends on the sampling algorithm. They are used for both
line selection and output ordering. The '--p|print-random' option can be
used to print these values. The random value is prepended to the line
separated by the --d|delimiter char (TAB by default). The
'--q|gen-random-inorder' option takes this one step further, generating
random values for all input lines without changing the input order. The
types of values currently used by these sampling algorithms:
* Unweighted sampling: Uniform random value in the interval [0,1]. This
  includes Bernoulli sampling and unweighted line order randomization.
* Weighted sampling: Value in the interval [0,1]. Distribution depends on
  the values in the weight field. It is used as a partial ordering.
* Distinct sampling: An integer, zero and up, representing a selection
  group. The inclusion probability determines the number of selection groups.
* Sampling with replacement: Random value printing is not supported.

The specifics behind these random values are subject to change in future
releases.

Compatibility mode: As described above, many of the sampling algorithms
assign a random value to each line. This is useful when printing random
values. It has another occasionally useful property: repeated runs with
the same static seed but different selection parameters are more
compatible with each other, as each line gets assigned the same random
value on every run. For example, if Bernoulli sampling is run with
'--prob 0.2 --static-seed', then run again with '--prob 0.3 --static-seed',
all the lines selected in the first run will be selected in the second.
This comes at a cost: in some cases there are faster algorithms that don't
preserve this property. By default, tsv-sample will use faster algorithms
when available. However, the '--compatibility-mode' option switches to
algorithms that assign a random value per line. Printing random values
also engages compatibility mode.

Options:
EOS";

/** Container for command line options.
 */
struct TsvSampleOptions
{
    string programName;
    string[] files;
    bool helpVerbose = false;                  // --help-verbose
    bool hasHeader = false;                    // --H|header
    size_t sampleSize = 0;                     // --n|num - Size of the desired sample
    double inclusionProbability = double.nan;  // --p|prob - Inclusion probability
    size_t[] keyFields;                        // --k|key-fields - Used with inclusion probability
    size_t weightField = 0;                    // --w|weight-field - Field holding the weight
    bool srsWithReplacement = false;           // --r|replace
    bool staticSeed = false;                   // --s|static-seed
    uint seedValueOptionArg = 0;               // --v|seed-value
    bool printRandom = false;                  // --print-random
    bool genRandomInorder = false;             // --gen-random-inorder
    string randomValueHeader = "random_value"; // --random-value-header
    bool compatibilityMode = false;            // --compatibility-mode
    char delim = '\t';                         // --d|delimiter
    bool versionWanted = false;                // --V|version
    bool preferSkipSampling = false;           // --prefer-skip-sampling
    bool preferAlgorithmR = false;             // --prefer-algorithm-r
    bool hasWeightField = false;               // Derived.
    bool useBernoulliSampling = false;         // Derived.
    bool useDistinctSampling = false;          // Derived.
    bool usingUnpredictableSeed = true;        // Derived from --static-seed, --seed-value
    uint seed = 0;                             // Derived from --static-seed, --seed-value

    auto processArgs(ref string[] cmdArgs)
    {
        import std.algorithm : canFind;
        import std.getopt;
        import std.math : isNaN;
        import std.path : baseName, stripExtension;
        import std.typecons : Yes, No;
        import tsv_utils.common.util : makeFieldListOptionHandler;

        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

        try
        {
            arraySep = ",";    // Use comma to separate values in command line options
            auto r = getopt(
                cmdArgs,
                "help-verbose",    "     Print more detailed help.", &helpVerbose,

                std.getopt.config.caseSensitive,
                "H|header",        "     Treat the first line of each file as a header.", &hasHeader,
                std.getopt.config.caseInsensitive,

                "n|num",           "NUM  Maximim number of lines to output. All selected lines are output if not provided or zero.", &sampleSize,
                "p|prob",          "NUM  Inclusion probability (0.0 < NUM <= 1.0). For Bernoulli sampling, the probability each line is selected output. For distinct sampling, the probability each unique key is selected for output.", &inclusionProbability,

                "k|key-fields",    "<field-list>  Fields to use as key for distinct sampling. Use with --p|prob.",
                keyFields.makeFieldListOptionHandler!(size_t, Yes.convertToZeroBasedIndex),

                "w|weight-field",  "NUM  Field containing weights. All lines get equal weight if not provided or zero.", &weightField,
                "r|replace",       "     Simple random sampling with replacement. Use --n|num to specify the sample size.", &srsWithReplacement,
                "s|static-seed",   "     Use the same random seed every run.", &staticSeed,

                std.getopt.config.caseSensitive,
                "v|seed-value",    "NUM  Sets the random seed. Use a non-zero, 32 bit positive integer. Zero is a no-op.", &seedValueOptionArg,
                std.getopt.config.caseInsensitive,

                "print-random",       "     Include the assigned random value (prepended) when writing output lines.", &printRandom,
                "gen-random-inorder", "     Output all lines with assigned random values prepended, no changes to the order of input.", &genRandomInorder,
                "random-value-header",  "     Header to use with --print-random and --gen-random-inorder. Default: 'random_value'.", &randomValueHeader,
                "compatibility-mode", "     Turns on 'compatibility-mode'. Use --help-verbose for information.", &compatibilityMode,

                "d|delimiter",     "CHR  Field delimiter.", &delim,

                std.getopt.config.caseSensitive,
                "V|version",       "     Print version information and exit.", &versionWanted,
                std.getopt.config.caseInsensitive,

                "prefer-skip-sampling", "     (Internal) Prefer the skip-sampling algorithm for Bernoulli sampling. Used for testing and diagnostics.",
                &preferSkipSampling,

                "prefer-algorithm-r",   "     (Internal) Prefer Algorithm R for unweighted line order randomization. Used for testing and diagnostics.",
                &preferAlgorithmR,
                );

            if (r.helpWanted)
            {
                defaultGetoptPrinter(helpText, r.options);
                return tuple(false, 0);
            }
            else if (helpVerbose)
            {
                defaultGetoptPrinter(helpTextVerbose, r.options);
                return tuple(false, 0);
            }
            else if (versionWanted)
            {
                import tsv_utils.common.tsvutils_version;
                writeln(tsvutilsVersionNotice("tsv-sample"));
                return tuple(false, 0);
            }

            /* Derivations and validations. */
            if (weightField > 0)
            {
                hasWeightField = true;
                weightField--;    // Switch to zero-based indexes.
            }

            if (srsWithReplacement)
            {
                if (hasWeightField)
                {
                    throw new Exception("Sampling with replacement (--r|replace) does not support wieghts (--w|weight-field).");
                }
                else if (!inclusionProbability.isNaN)
                {
                    throw new Exception("Sampling with replacement (--r|replace) cannot be used with probabilities (--p|prob).");
                }
                else if (keyFields.length > 0)
                {
                    throw new Exception("Sampling with replacement (--r|replace) cannot be used with distinct sampling (--k|key-fields).");
                }
                else if (printRandom || genRandomInorder)
                {
                    throw new Exception("Sampling with replacement (--r|replace) does not support random value printing (--print-random, --gen-random-inorder).");
                }
            }

            if (keyFields.length > 0)
            {
                if (inclusionProbability.isNaN) throw new Exception("--p|prob is required when using --k|key-fields.");
            }

            /* Inclusion probability (--p|prob) is used for both Bernoulli sampling and distinct sampling. */
            if (!inclusionProbability.isNaN)
            {
                if (inclusionProbability <= 0.0 || inclusionProbability > 1.0)
                {
                    import std.format : format;
                    throw new Exception(
                        format("Invalid --p|prob option: %g. Must satisfy 0.0 < prob <= 1.0.", inclusionProbability));
                }

                if (keyFields.length > 0) useDistinctSampling = true;
                else useBernoulliSampling = true;

                if (hasWeightField) throw new Exception("--w|weight-field and --p|prob cannot be used together.");

                if (genRandomInorder && !useDistinctSampling)
                {
                    throw new Exception("--q|gen-random-inorder and --p|prob can only be used together if --k|key-fields is also used.");
                }
            }
            else if (genRandomInorder && !hasWeightField)
            {
                useBernoulliSampling = true;
            }

            if (randomValueHeader.length == 0 || randomValueHeader.canFind('\n') ||
                randomValueHeader.canFind(delim))
            {
                throw new Exception("--randomValueHeader must be at least one character and not contain field delimiters or newlines.");
            }

            /* Random value printing implies compatibility-mode, otherwise user's selection is used. */
            if (printRandom || genRandomInorder) compatibilityMode = true;

            /* Seed. */
            import std.random : unpredictableSeed;

            usingUnpredictableSeed = (!staticSeed && seedValueOptionArg == 0);

            if (usingUnpredictableSeed) seed = unpredictableSeed;
            else if (seedValueOptionArg != 0) seed = seedValueOptionArg;
            else if (staticSeed) seed = 2438424139;
            else assert(0, "Internal error, invalid seed option states.");

            /* Assume remaining args are files. Use standard input if files were not provided. */
            files ~= (cmdArgs.length > 1) ? cmdArgs[1..$] : ["-"];
            cmdArgs.length = 1;
        }
        catch (Exception exc)
        {
            stderr.writefln("[%s] Error processing command line arguments: %s", programName, exc.msg);
            return tuple(false, 1);
        }
        return tuple(true, 0);
    }
}
/** Invokes the appropriate sampling routine based on the command line arguments.
 */
void tsvSample(OutputRange)(TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    if (cmdopt.srsWithReplacement)
    {
        simpleRandomSamplingWithReplacement(cmdopt, outputStream);
    }
    else if (cmdopt.useBernoulliSampling)
    {
        bernoulliSamplingCommand(cmdopt, outputStream);
    }
    else if (cmdopt.useDistinctSampling)
    {
        if (cmdopt.genRandomInorder) distinctSampling!(Yes.generateRandomAll)(cmdopt, outputStream);
        else distinctSampling!(No.generateRandomAll)(cmdopt, outputStream);
    }
    else if (cmdopt.genRandomInorder)
    {
        /* Note that the preceeding cases handle gen-random-inorder themselves (Bernoulli,
         * Distinct), or don't handle it (SRS w/ Replacement).
         */
        assert(cmdopt.hasWeightField);
        generateWeightedRandomValuesInorder(cmdopt, outputStream);
    }
    else if (cmdopt.sampleSize != 0)
    {
        reservoirSamplingCommand(cmdopt, outputStream);
    }
    else
    {
        randomizeLinesCommand(cmdopt, outputStream);
    }
}

/** Bernoulli sampling on the input stream.
 *
 * This routine selects the appropriate bernoulli sampling function and template
 * instantiation to use based on the command line arguments.
 *
 * See the bernoulliSkipSampling routine for a discussion of the choices behind the
 * skipSamplingProbabilityThreshold used here.
 */
void bernoulliSamplingCommand(OutputRange)(TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    assert(!cmdopt.hasWeightField);

    immutable double skipSamplingProbabilityThreshold = 0.04;

    if (cmdopt.compatibilityMode ||
        (cmdopt.inclusionProbability > skipSamplingProbabilityThreshold && !cmdopt.preferSkipSampling))
    {
        if (cmdopt.genRandomInorder)
        {
            bernoulliSampling!(Yes.generateRandomAll)(cmdopt, outputStream);
        }
        else
        {
            bernoulliSampling!(No.generateRandomAll)(cmdopt, outputStream);
        }
    }
    else
    {
        bernoulliSkipSampling(cmdopt, outputStream);
    }
}

/** Bernoulli sampling on the input stream.
 *
 * Each input line is a assigned a random value and output if less than
 * cmdopt.inclusionProbability. The order of the lines is not changed.
 *
 * This routine supports random value printing and gen-random-inorder value printing.
 */
void bernoulliSampling(Flag!"generateRandomAll" generateRandomAll, OutputRange)
    (TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.format : formatValue, singleSpec;
    import std.random : Random = Mt19937, uniform01;
    import tsv_utils.common.util : throwIfWindowsNewlineOnUnix;

    static if (generateRandomAll) assert(cmdopt.genRandomInorder);
    else assert(!cmdopt.genRandomInorder);

    auto randomGenerator = Random(cmdopt.seed);
    immutable randomValueFormatSpec = singleSpec("%.17g");

    /* Process each line. */
    bool headerWritten = false;
    size_t numLinesWritten = 0;
    foreach (filename; cmdopt.files)
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (fileLineNum, line; inputStream.byLine(KeepTerminator.no).enumerate(1))
        {
            if (fileLineNum == 1) throwIfWindowsNewlineOnUnix(line, filename, fileLineNum);
            if (fileLineNum == 1 && cmdopt.hasHeader)
            {
                if (!headerWritten)
                {
                    static if (generateRandomAll)
                    {
                        outputStream.put(cmdopt.randomValueHeader);
                        outputStream.put(cmdopt.delim);
                    }
                    else if (cmdopt.printRandom)
                    {
                        outputStream.put(cmdopt.randomValueHeader);
                        outputStream.put(cmdopt.delim);
                    }

                    outputStream.put(line);
                    outputStream.put("\n");
                    headerWritten = true;
                }
            }
            else
            {
                double lineScore = uniform01(randomGenerator);

                static if (generateRandomAll)
                {
                    outputStream.formatValue(lineScore, randomValueFormatSpec);
                    outputStream.put(cmdopt.delim);
                    outputStream.put(line);
                    outputStream.put("\n");

                    if (cmdopt.sampleSize != 0)
                    {
                        ++numLinesWritten;
                        if (numLinesWritten == cmdopt.sampleSize) return;
                    }
                }
                else if (lineScore < cmdopt.inclusionProbability)
                {
                    if (cmdopt.printRandom)
                    {
                        outputStream.formatValue(lineScore, randomValueFormatSpec);
                        outputStream.put(cmdopt.delim);
                    }
                    outputStream.put(line);
                    outputStream.put("\n");

                    if (cmdopt.sampleSize != 0)
                    {
                        ++numLinesWritten;
                        if (numLinesWritten == cmdopt.sampleSize) return;
                    }
                }
            }
        }
    }
}

/* bernoulliSkipSampling is an alternate implementation of bernoulliSampling that
 * uses skip sampling.
 *
 * Skip sampling works by skipping a random number of lines between selections. This
 * can be faster than assigning a random value to each line when the inclusion
 * probability is low, as it reduces the number of calls to the random number
 * generator. Both the random number generator and the log() function as called when
 * calculating the next skip size. These additional log() calls add up as the
 * probability increases.
 *
 * Performance tests indicate the break-even point is about 4-5% (--prob 0.04) for
 * file-oriented line sampling. This is obviously environment specific. In the
 * environments this implementation has been tested in the perfmance improvements
 * remain small, less than 7%, even with an inclusion probability as low as 0.0001.
 *
 * The algorithm does not assign random values to individual lines. This makes it
 * incompatible with random value printing. It is not suitable for compatibility mode
 * either. As an example, in compatibility mode a line selected with '--prob 0.2' should
 * also be selected with '--prob 0.3' (assuming the same random seed). Skip sampling
 * does not have this property.
 *
 * The algorithm for calculating the skip size has been described by multiple sources.
 * There are two key variants depending on whether the total number of lines in the
 * data set is known in advance. (This implementation does not know the total.)
 * Useful references:
 * - Jeffrey Scott Vitter, "An Efficient Algorithm for Sequential Random Sampling",
 *   ACM Trans on Mathematical Software, 1987. On-line:
 *   http://www.ittc.ku.edu/~jsv/Papers/Vit87.RandomSampling.pdf
 * - P.J. Haas, "Data-Stream Sampling: Basic Techniques and Results", from the book
 *   "Data Stream Management", Springer-Verlag, 2016. On-line:
 *   https://www.springer.com/cda/content/document/cda_downloaddocument/9783540286073-c2.pdf
 * - Erik Erlandson, "Faster Random Samples With Gap Sampling", 2014. On-line:
 *   http://erikerlandson.github.io/blog/2014/09/11/faster-random-samples-with-gap-sampling/
 */
void bernoulliSkipSampling(OutputRange)(TsvSampleOptions cmdopt, OutputRange outputStream)
    if (isOutputRange!(OutputRange, char))
{
    import std.conv : to;
    import std.math : log, trunc;
    import std.random : Random = Mt19937, uniform01;
    import tsv_utils.common.util : throwIfWindowsNewlineOnUnix;

    assert(cmdopt.inclusionProbability > 0.0 && cmdopt.inclusionProbability < 1.0);
    assert(!cmdopt.printRandom);
    assert(!cmdopt.compatibilityMode);

    auto randomGenerator = Random(cmdopt.seed);

    immutable double discardRate = 1.0 - cmdopt.inclusionProbability;
    immutable double logDiscardRate = log(discardRate);

    /* Note: The '1.0 - uniform01(randomGenerator)' expression flips the half closed
     * interval to (0.0, 1.0], excluding 0.0.
     */
    size_t remainingSkips = (log(1.0 - uniform01(randomGenerator)) / logDiscardRate).trunc.to!size_t;

    /* Process each line. */
    bool headerWritten = false;
    size_t numLinesWritten = 0;
    foreach (filename; cmdopt.files)
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (fileLineNum, line; inputStream.byLine(KeepTerminator.no).enumerate(1))
        {
            if (fileLineNum == 1) throwIfWindowsNewlineOnUnix(line, filename, fileLineNum);
            if (fileLineNum == 1 && cmdopt.hasHeader)
            {
                if (!headerWritten)
                {
                    outputStream.put(line);
                    outputStream.put("\n");
                    headerWritten = true;
                }
            }
            else if (remainingSkips > 0)
            {
                --remainingSkips;
            }
            else
            {
                outputStream.put(line);
                outputStream.put("\n");

                if (cmdopt.sampleSize != 0)
                {
                    ++numLinesWritten;
                    if (numLinesWritten == cmdopt.sampleSize) return;
                }

                remainingSkips = (log(1.0 - uniform01(randomGenerator)) / logDiscardRate).trunc.to!size_t;
            }
        }
    }
}

/** Sample a subset of the unique values from the key fields.
 *
 * Distinct sampling is done by hashing the key and mapping the hash value into
 * buckets matching the inclusion probability. Records having a key mapping to bucket
 * zero are output.
 *
 * TODO: Add whole line as key.
 */
void distinctSampling(Flag!"generateRandomAll" generateRandomAll, OutputRange)
    (TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.algorithm : splitter;
    import std.conv : to;
    import std.digest.murmurhash;
    import std.math : lrint;
    import tsv_utils.common.util : InputFieldReordering, throwIfWindowsNewlineOnUnix;

    static if (generateRandomAll) assert(cmdopt.genRandomInorder);
    else assert(!cmdopt.genRandomInorder);

    assert(cmdopt.keyFields.length > 0);
    assert(0.0 < cmdopt.inclusionProbability && cmdopt.inclusionProbability <= 1.0);

    static if (generateRandomAll)
    {
        import std.format : formatValue, singleSpec;
        immutable randomValueFormatSpec = singleSpec("%d");
    }

    immutable ubyte[1] delimArray = [cmdopt.delim]; // For assembling multi-field hash keys.

    uint numBuckets = (1.0 / cmdopt.inclusionProbability).lrint.to!uint;

    /* Create a mapping for the key fields. */
    auto keyFieldsReordering = new InputFieldReordering!char(cmdopt.keyFields);

    /* Process each line. */
    bool headerWritten = false;
    size_t numLinesWritten = 0;
    foreach (filename; cmdopt.files)
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (fileLineNum, line; inputStream.byLine(KeepTerminator.no).enumerate(1))
        {
            if (fileLineNum == 1) throwIfWindowsNewlineOnUnix(line, filename, fileLineNum);
            if (fileLineNum == 1 && cmdopt.hasHeader)
            {
                if (!headerWritten)
                {
                    static if (generateRandomAll)
                    {
                        outputStream.put(cmdopt.randomValueHeader);
                        outputStream.put(cmdopt.delim);
                    }
                    else if (cmdopt.printRandom)
                    {
                        outputStream.put(cmdopt.randomValueHeader);
                        outputStream.put(cmdopt.delim);
                    }

                    outputStream.put(line);
                    outputStream.put("\n");
                    headerWritten = true;
                }
            }
            else
            {
                /* Gather the key field values and assemble the key. */
                keyFieldsReordering.initNewLine;
                foreach (fieldIndex, fieldValue; line.splitter(cmdopt.delim).enumerate)
                {
                    keyFieldsReordering.processNextField(fieldIndex, fieldValue);
                    if (keyFieldsReordering.allFieldsFilled) break;
                }

                if (!keyFieldsReordering.allFieldsFilled)
                {
                    import std.format : format;
                    throw new Exception(
                        format("Not enough fields in line. File: %s, Line: %s",
                               (filename == "-") ? "Standard Input" : filename, fileLineNum));
                }

                auto hasher = MurmurHash3!32(cmdopt.seed);
                foreach (count, key; keyFieldsReordering.outputFields.enumerate)
                {
                    if (count > 0) hasher.put(delimArray);
                    hasher.put(cast(ubyte[]) key);
                }
                hasher.finish;

                static if (generateRandomAll)
                {
                    import std.conv : to;
                    outputStream.formatValue(hasher.get % numBuckets, randomValueFormatSpec);
                    outputStream.put(cmdopt.delim);
                    outputStream.put(line);
                    outputStream.put("\n");

                    if (cmdopt.sampleSize != 0)
                    {
                        ++numLinesWritten;
                        if (numLinesWritten == cmdopt.sampleSize) return;
                    }
                }
                else if (hasher.get % numBuckets == 0)
                {
                    if (cmdopt.printRandom)
                    {
                        outputStream.put('0');
                        outputStream.put(cmdopt.delim);
                    }
                    outputStream.put(line);
                    outputStream.put("\n");

                    if (cmdopt.sampleSize != 0)
                    {
                        ++numLinesWritten;
                        if (numLinesWritten == cmdopt.sampleSize) return;
                    }
                }
            }
        }
    }
}

/** Reservoir sampling on the input stream.
 *
 * This routine selects the appropriate reservior sampling function and template
 * instantiation to use based on the command line arguments.
 *
 * Reservoir sampling is used when a fixed size sample is being pulled from an input
 * stream. Weighted and unweighted sampling is supported. These routines also
 * randomize the order of the selected lines. This is consistent with line order
 * randomization of the entire input stream (handled by randomizeLinesCommand).
 *
 * For unweighted sampling, there is a performance tradeoff choice between the two
 * available implementations. See the reservoirSampling documentation for
 * information. The threshold used here was chosen based on performance tests.
 */

void reservoirSamplingCommand(OutputRange)(TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    assert(cmdopt.sampleSize != 0);

    immutable size_t algorithmRSampleSizeThreshold = 128 * 1024;

    if (cmdopt.hasWeightField)
    {
        reservoirSamplingViaHeap!(Yes.isWeighted)(cmdopt, outputStream);
    }
    else if (cmdopt.compatibilityMode ||
             (cmdopt.sampleSize < algorithmRSampleSizeThreshold && !cmdopt.preferAlgorithmR))
    {
        reservoirSamplingViaHeap!(No.isWeighted)(cmdopt, outputStream);
    }
    else
    {
        reservoirSamplingAlgorithmR(cmdopt, outputStream);
    }
}

/** Reservior sampling using a heap. Both weighted and unweighted random sampling are
 * supported.
 *
 * The algorithm used here is based on the one-pass algorithm described by Pavlos
 * Efraimidis and Paul Spirakis ("Weighted Random Sampling over Data Streams", Pavlos S.
 * Efraimidis, https://arxiv.org/abs/1012.0256). In the unweighted case weights are
 * simply set to one.
 *
 * The implementation uses a heap (priority queue) large enough to hold the desired
 * number of lines. Input is read line-by-line, assigned a random value, and added to
 * the heap. The role of the identify the lines with the highest assigned random
 * values. Once the heap is full, adding a new line means dropping the line with the
 * lowest score. A "min" heap used for this reason.
 *
 * When done reading all lines, the "min" heap is in the opposite order needed for
 * output. The desired order is obtained by removing each element one at at time from
 * the heap. The underlying data store will have the elements in correct order.
 *
 * Generating output in weighted order matters for several reasons:
 *  - For weighted sampling, it preserves the property that smaller valid subsets can be
 *    created by taking the first N lines.
 *  - For unweighted sampling, it ensures that all output permutations are possible, and
 *    are not influences by input order or the heap data structure used.
 *  - Order consistency when making repeated use of the same random seeds, but with
 *    different sample sizes.
 *
 * There are use cases where only the selection set matters, for these some performance
 * could be gained by skipping the reordering and simply printing the backing store
 * array in-order, but making this distinction seems an unnecessary complication.
 *
 * Notes:
 *  - In tsv-sample versions 1.2.1 and earlier this routine also supported randomization
 *    of all input lines. This was dropped in version 1.2.2 in favor of the approach
 *    used in randomizeLines. The latter has significant advantages given that all data
 *    data must be read into memory.
 *  - For larger reservoir sizes better performance can be achieved by using
 *    reservoirSamplingAlgorithmR. See the documentation for that function for details.
 */
void reservoirSamplingViaHeap(Flag!"isWeighted" isWeighted, OutputRange)
    (TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.container.array;
    import std.container.binaryheap;
    import std.format : formatValue, singleSpec;
    import std.random : Random = Mt19937, uniform01;
    import tsv_utils.common.util : throwIfWindowsNewlineOnUnix;

    static if (isWeighted) assert(cmdopt.hasWeightField);
    else assert(!cmdopt.hasWeightField);

    assert(cmdopt.sampleSize > 0);

    auto randomGenerator = Random(cmdopt.seed);

    struct Entry
    {
        double score;
        char[] line;
    }

    /* Create the heap and backing data store.
     *
     * Note: An std.container.array is used as the backing store to avoid some issues in
     * the standard library (Phobos) binaryheap implementation. Specifically, when an
     * std.container.array is used as backing store, the heap can efficiently reversed by
     * removing the heap elements. This leaves the backing store in the reversed order.
     * However, the current binaryheap implementation does not support this for all
     * backing stores. See: https://issues.dlang.org/show_bug.cgi?id=17094.
     */

    Array!Entry dataStore;
    dataStore.reserve(cmdopt.sampleSize);
    auto reservoir = dataStore.heapify!("a.score > b.score")(0);  // Min binaryheap

    /* Process each line. */
    bool headerWritten = false;
    foreach (filename; cmdopt.files)
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (fileLineNum, line; inputStream.byLine(KeepTerminator.no).enumerate(1))
        {
            if (fileLineNum == 1) throwIfWindowsNewlineOnUnix(line, filename, fileLineNum);
            if (fileLineNum == 1 && cmdopt.hasHeader)
            {
                if (!headerWritten)
                {
                    if (cmdopt.printRandom)
                    {
                        outputStream.put(cmdopt.randomValueHeader);
                        outputStream.put(cmdopt.delim);
                    }
                    outputStream.put(line);
                    outputStream.put("\n");
                    headerWritten = true;
                }
            }
            else
            {
                static if (!isWeighted)
                {
                    double lineScore = uniform01(randomGenerator);
                }
                else
                {
                    double lineWeight =
                        getFieldValue!double(line, cmdopt.weightField, cmdopt.delim, filename, fileLineNum);
                    double lineScore =
                        (lineWeight > 0.0)
                        ? uniform01(randomGenerator) ^^ (1.0 / lineWeight)
                        : 0.0;
                }

                if (reservoir.length < cmdopt.sampleSize)
                {
                    reservoir.insert(Entry(lineScore, line.dup));
                }
                else if (reservoir.front.score < lineScore)
                {
                    reservoir.replaceFront(Entry(lineScore, line.dup));
                }
            }
        }
    }

    /* All entries are in the reservoir. Time to print. The heap is in reverse order
     * of assigned weights. Reversing order is done by removing all elements from the
     * heap, this leaves the backing store in the correct order for output.
     *
     * The asserts here avoid issues with the current binaryheap implementation. They
     * detect use of backing stores having a length not synchronized to the reservoir.
     */
    size_t numLines = reservoir.length;
    assert(numLines == dataStore.length);

    while (!reservoir.empty) reservoir.removeFront;
    assert(numLines == dataStore.length);

    immutable randomValueFormatSpec = singleSpec("%.17g");

    foreach (entry; dataStore)
    {
        if (cmdopt.printRandom)
        {
            outputStream.formatValue(entry.score, randomValueFormatSpec);
            outputStream.put(cmdopt.delim);
        }
        outputStream.put(entry.line);
        outputStream.put("\n");
    }
 }

/** Generates weighted random values for all input lines, preserving input order.
 *
 * This complements weighted reservoir sampling, but instead of using a reservoir it
 * simply iterates over the input lines generating the values. The weighted random
 * values are generated with the same formula used by reservoirSampling.
 */
void generateWeightedRandomValuesInorder(OutputRange)(TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.format : formatValue, singleSpec;
    import std.random : Random = Mt19937, uniform01;
    import tsv_utils.common.util : throwIfWindowsNewlineOnUnix;

    assert(cmdopt.hasWeightField);

    auto randomGenerator = Random(cmdopt.seed);
    immutable randomValueFormatSpec = singleSpec("%.17g");

    /* Process each line. */
    bool headerWritten = false;
    size_t numLinesWritten = 0;
    foreach (filename; cmdopt.files)
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (fileLineNum, line; inputStream.byLine(KeepTerminator.no).enumerate(1))
        {
            if (fileLineNum == 1) throwIfWindowsNewlineOnUnix(line, filename, fileLineNum);
            if (fileLineNum == 1 && cmdopt.hasHeader)
            {
                if (!headerWritten)
                {
                    outputStream.put(cmdopt.randomValueHeader);
                    outputStream.put(cmdopt.delim);
                    outputStream.put(line);
                    outputStream.put("\n");
                    headerWritten = true;
                }
            }
            else
               {
                double lineWeight = getFieldValue!double(line, cmdopt.weightField, cmdopt.delim,
                                                         filename, fileLineNum);
                double lineScore =
                    (lineWeight > 0.0)
                    ? uniform01(randomGenerator) ^^ (1.0 / lineWeight)
                    : 0.0;

                outputStream.formatValue(lineScore, randomValueFormatSpec);
                outputStream.put(cmdopt.delim);
                outputStream.put(line);
                outputStream.put("\n");

                if (cmdopt.sampleSize != 0)
                {
                    ++numLinesWritten;
                    if (numLinesWritten == cmdopt.sampleSize) return;
                }
            }
        }
    }
}

/** Reservoir sampling, Algorithm R
 *
 * This is an implementation of reservoir sampling using what is commonly known as
 * "Algorithm R", credited to Alan Waterman by Donald Knuth in the "The Art of
 * Computer Programming, Volume 2: Seminumerical Algorithms". More information about
 * the algorithm can be found in Jeffrey Vitter's classic paper "Random Sampling with
 * a Reservoir" (1985) as well as the Wikipedia article "Reservoir Sampling"
 * (https://en.wikipedia.org/wiki/Reservoir_sampling#Algorithm_R).
 *
 * Algorithm R is used for unweighted sampling without replacement. The heap-based
 * algorithm in reservoirSamplingViaHeap is used for weighted sampling.
 *
 * The classic algorithm stops after identifying the selected set of items. This
 * implementation goes one step further and randomizes the order of the selected
 * lines. This supports the tsv-sample use-case, which is line order randomization.
 *
 * This algorithm is faster than reservoirSamplingViaHeap when the sample size
 * (reservoir size) is large. Heap insertion is O(log k), where k is the sample size.
 * Insertion in this algorithm is O(1). Similarly, generating the random order in the
 * heap is O(k * log k), while in this algorithm the final randomization step is O(k).
 *
 * This speed advantage may be offset a certain amount by using a more expensive random
 * value generator. reservoirSamplingViaHeap generates values between zero and one,
 * whereas reservoirSamplingAlgorithR generates random integers over and ever growing
 * interval. The latter is expected to be more expensive. This is consistent with
 * performance test indicating that reservoirSamplingViaHeap is faster when using
 * small-to-medium size reservoirs and large input streams.
 */
void reservoirSamplingAlgorithmR(OutputRange)(TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.random : Random = Mt19937, randomShuffle, uniform;
    import tsv_utils.common.util : throwIfWindowsNewlineOnUnix;

    assert(cmdopt.sampleSize > 0);
    assert(!cmdopt.hasWeightField);
    assert(!cmdopt.compatibilityMode);
    assert(!cmdopt.printRandom);
    assert(!cmdopt.genRandomInorder);

    string[] reservoir;
    auto reservoirAppender = appender(&reservoir);
    reservoirAppender.reserve(cmdopt.sampleSize);

    auto randomGenerator = Random(cmdopt.seed);

    /* Process each line. */

    bool headerWritten = false;
    size_t totalLineNum = 0;
    foreach (filename; cmdopt.files)
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (fileLineNum, line; inputStream.byLine(KeepTerminator.no).enumerate(1))
        {
            if (fileLineNum == 1) throwIfWindowsNewlineOnUnix(line, filename, fileLineNum);
            if (fileLineNum == 1 && cmdopt.hasHeader)
            {
                if (!headerWritten)
                {
                    outputStream.put(line);
                    outputStream.put("\n");
                    headerWritten = true;
                }
            }
            else
            {
                /* Add lines to the reservoir until the reservoir is filled.
                 * After that lines are added with decreasing likelihood, based on
                 * the total number of lines seen. If added to the reservoir, the
                 * line replaces a randomly chosen existing line.
                 */
                if (totalLineNum < cmdopt.sampleSize)
                {
                    reservoirAppender ~= line.idup;
                }
                else
                {
                    size_t i = uniform(0, totalLineNum, randomGenerator);
                    if (i < reservoir.length) reservoir[i] = line.idup;
                }

                ++totalLineNum;
            }
        }
    }

    /* The random sample is now in the reservior. Shuffle it and print. */

    reservoir.randomShuffle(randomGenerator);

    foreach (ref line; reservoir)
    {
        outputStream.put(line);
        outputStream.put("\n");
    }
}

/** Randomize all the lines in files or standard input.
 *
 * This routine selects the appropriate randomize-lines function and template instantiation
 * to use based on the command line arguments.
 */
void randomizeLinesCommand(OutputRange)(TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    if (cmdopt.hasWeightField)
    {
        randomizeLinesViaSort!(Yes.isWeighted)(cmdopt, outputStream);
    }
    else if (cmdopt.compatibilityMode)
    {
        randomizeLinesViaSort!(No.isWeighted)(cmdopt, outputStream);
    }
    else
    {
        randomizeLinesViaShuffle(cmdopt, outputStream);
    }
}

/** Randomize all the lines in files or standard input.
 *
 * All lines in files and/or standard input are read in and written out in random
 * order. This algorithm assigns a random value to each line and sorts. This approach
 * supports both weighted sampling and simple random sampling (unweighted).
 *
 * This is significantly faster than heap-based reservoir sampling in the case where
 * the entire file is being read. See also randomizeLinesViaShuffle for the unweighted
 * case, as it is a little faster, at the cost not supporting random value printing or
 * compatibility-mode.
 *
 * Input data size is limited by available memory. Disk oriented techniques are needed
 * when data sizes are larger. For example, generating random values line-by-line (ala
 * --gen-random-inorder) and sorting with a disk-backed sort program like GNU sort.
 */
void randomizeLinesViaSort(Flag!"isWeighted" isWeighted, OutputRange)(TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.algorithm : map, sort;
    import std.format : formatValue, singleSpec;

    static if (isWeighted) assert(cmdopt.hasWeightField);
    else assert(!cmdopt.hasWeightField);

    assert(cmdopt.sampleSize == 0);

    /*
     * Read all file data into memory. Then split the data into lines and assign a
     * random value to each line. identifyFileLines also writes the first header line.
     */
    auto fileData = cmdopt.files.map!FileData.array;
    auto inputLines = fileData.identifyFileLines!(Yes.hasRandomValue, isWeighted)(cmdopt, outputStream);

    /*
     * Sort by the weight and output the lines.
     */
    inputLines.sort!((a, b) => a.randomValue > b.randomValue);

    immutable randomValueFormatSpec = singleSpec("%.17g");

    foreach (lineEntry; inputLines)
    {
        if (cmdopt.printRandom)
        {
            outputStream.formatValue(lineEntry.randomValue, randomValueFormatSpec);
            outputStream.put(cmdopt.delim);
        }
        outputStream.put(lineEntry.data);
        outputStream.put("\n");
    }
}

/** Randomize all the lines in files or standard input.
 *
 * All lines in files and/or standard input are read in and written out in random
 * order. This routine uses array shuffling, which is faster than sorting. This makes
 * this routine a good alternative to randomizeLinesViaSort when doing unweighted
 * randomization.
 *
 * Input data size is limited by available memory. Disk oriented techniques are needed
 * when data sizes are larger. For example, generating random values line-by-line (ala
 * --gen-random-inorder) and sorting with a disk-backed sort program like GNU sort.
 *
 * This routine does not support random value printing or compatibility-mode.
 */
void randomizeLinesViaShuffle(OutputRange)(TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.algorithm : map;
    import std.random : Random = Mt19937, randomShuffle;

    assert(cmdopt.sampleSize == 0);
    assert(!cmdopt.hasWeightField);
    assert(!cmdopt.printRandom);
    assert(!cmdopt.genRandomInorder);

    /*
     * Read all file data into memory and split into lines.
     */
    auto fileData = cmdopt.files.map!FileData.array;
    auto inputLines = fileData.identifyFileLines!(No.hasRandomValue, No.isWeighted)(cmdopt, outputStream);

    /*
     * Randomly shuffle and print each line.
     *
     * Note: Also tried randomCover, but that was exceedingly slow.
     */
    import std.random : randomShuffle;

    auto randomGenerator = Random(cmdopt.seed);
    inputLines.randomShuffle(randomGenerator);

    foreach (ref line; inputLines)
    {
        outputStream.put(line.data);
        outputStream.put("\n");
    }
}

/** Simple random sampling with replacement.
 *
 * All lines in files and/or standard input are read in. Then random lines are selected
 * one at a time and output. Lines can be selected multiple times. This process continues
 * until the desired number of samples (--n|num) has been output. Output continues
 * indefinitely if a sample size was not provided.
 */
void simpleRandomSamplingWithReplacement(OutputRange)(TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.algorithm : map;
    import std.format : formatValue, singleSpec;
    import std.random : Random = Mt19937, uniform;

    /*
     * Read all file data into memory and split the data into lines.
     */
    auto fileData = cmdopt.files.map!FileData.array;
    auto inputLines = fileData.identifyFileLines!(No.hasRandomValue, No.isWeighted)(cmdopt, outputStream);

    if (inputLines.length > 0)
    {
        auto randomGenerator = Random(cmdopt.seed);

        /* Repeat forever is sampleSize is zero, otherwise print sampleSize lines. */
        size_t numLeft = (cmdopt.sampleSize == 0) ? 1 : cmdopt.sampleSize;
        while (numLeft != 0)
        {
            size_t index = uniform(0, inputLines.length, randomGenerator);
            outputStream.put(inputLines[index].data);
            outputStream.put("\n");
            if (cmdopt.sampleSize != 0) numLeft--;
        }
    }
}

/** A container and reader data form a file or standard input.
 *
 * The FileData struct is used to read data from a file or standard input. It is used
 * by passing a filename to the constructor. The constructor reads the file data.
 * If the filename is a single hyphen ('-') then data is read from standard input.
 *
 * The struct make the data available through two members: 'filename', which is the
 * filename, and 'data', which is a character array of the data.
 */
struct FileData
{
    string filename;
    char[] data;

    this(string fname)
    {
        import std.algorithm : min;
        import std.array : appender;

        filename = fname;

        ubyte[1024 * 128] fileRawBuf;
        auto dataAppender = appender(&data);
        auto ifile = (filename == "-") ? stdin : filename.File;

        if (filename != "-")
        {
            ulong filesize = ifile.size;
            if (filesize < ulong.max) dataAppender.reserve(min(filesize, size_t.max));
        }

        foreach (ref ubyte[] buffer; ifile.byChunk(fileRawBuf)) dataAppender.put(cast(char[]) buffer);
    }
}

/** HasRandomValue is a boolean flag used at compile time by identifyFileLines to
 * distinguish use cases needing random value assignments from those that don't.
 */
alias HasRandomValue = Flag!"hasRandomValue";

/** An InputLine array is returned by identifyFileLines to represent each non-header line
 * line found in a FileData array. The 'data' element contains the line. A 'randomValue'
 * line is included if random values are being generated.
 */
struct InputLine(HasRandomValue hasRandomValue)
{
    char[] data;
    static if (hasRandomValue) double randomValue;
}

/** identifyFileLines is used by algorithms that read all files into memory prior to
 * processing. It does the initial processing of the file data.
 *
 * Three primary tasks are performed. One is splitting all input data into lines. The
 * second is writting the header line from the first file to the output stream. Header
 * lines from subsequent files are ignored. Third is assigning a random value to the
 * line, if random values are being generated.
 *
 * The key input is a FileData array, one element for each file. The FileData reads
 * the file when instantiated.
 *
 * The return value is an array of InputLine structs. The struct will have a 'randomValue'
 * member if random values are being assigned.
 */
InputLine!hasRandomValue[] identifyFileLines(HasRandomValue hasRandomValue, Flag!"isWeighted" isWeighted, OutputRange)
(ref FileData[] fileData, TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.algorithm : splitter;
    import std.array : appender;
    import std.random : Random = Mt19937, uniform01;
    import tsv_utils.common.util : throwIfWindowsNewlineOnUnix;

    static assert(hasRandomValue || !isWeighted);
    static if(!hasRandomValue) assert(!cmdopt.printRandom);

    InputLine!hasRandomValue[] inputLines;

    auto linesAppender = appender(&inputLines);
    static if (hasRandomValue) auto randomGenerator = Random(cmdopt.seed);
    bool headerWritten = false;

    foreach (fd; fileData)
    {
        /* Drop the last newline to avoid adding an extra empty line. */
        auto data = (fd.data.length > 0 && fd.data[$ - 1] == '\n') ? fd.data[0 .. $ - 1] : fd.data;
        foreach (fileLineNum, ref line; data.splitter('\n').enumerate(1))
        {
            if (fileLineNum == 1) throwIfWindowsNewlineOnUnix(line, fd.filename, fileLineNum);
            if (fileLineNum == 1 && cmdopt.hasHeader)
            {
                if (!headerWritten)
                {
                    if (cmdopt.printRandom)
                    {
                        outputStream.put(cmdopt.randomValueHeader);
                        outputStream.put(cmdopt.delim);
                    }
                    outputStream.put(line);
                    outputStream.put("\n");
                    headerWritten = true;
                }
            }
            else
            {
                static if (!hasRandomValue)
                {
                    linesAppender.put(InputLine!hasRandomValue(line));
                }
                else
                {
                    static if (!isWeighted)
                    {
                        double randomValue = uniform01(randomGenerator);
                    }
                    else
                    {
                        double lineWeight =
                            getFieldValue!double(line, cmdopt.weightField, cmdopt.delim,
                                                 fd.filename, fileLineNum);
                        double randomValue =
                            (lineWeight > 0.0)
                            ? uniform01(randomGenerator) ^^ (1.0 / lineWeight)
                            : 0.0;
                    }

                    linesAppender.put(InputLine!hasRandomValue(line, randomValue));
                }
            }
        }
    }

    return inputLines;
}


/** Convenience function for extracting a single field from a line. See getTsvFieldValue in
 * common/src/tsvutils.d for details. This wrapper creates error text tailored for this program.
 */
import std.traits : isSomeChar;
T getFieldValue(T, C)(const C[] line, size_t fieldIndex, C delim, string filename, size_t lineNum) pure @safe
if (isSomeChar!C)
{
    import std.conv : ConvException, to;
    import std.format : format;
    import tsv_utils.common.util : getTsvFieldValue;

    T val;
    try
    {
        val = getTsvFieldValue!T(line, fieldIndex, delim);
    }
    catch (ConvException exc)
    {
        throw new Exception(
            format("Could not process line: %s\n  File: %s Line: %s%s",
                   exc.msg, (filename == "-") ? "Standard Input" : filename, lineNum,
                   (lineNum == 1) ? "\n  Is this a header line? Use --H|header to skip." : ""));
    }
    catch (Exception exc)
    {
        /* Not enough fields on the line. */
        throw new Exception(
            format("Could not process line: %s\n  File: %s Line: %s",
                   exc.msg, (filename == "-") ? "Standard Input" : filename, lineNum));
    }

    return val;
}

unittest
{
    /* getFieldValue unit tests. getTsvFieldValue has it's own tests.
     * These tests make basic sanity checks on the getFieldValue wrapper.
     */
    import std.exception;

    assert(getFieldValue!double("123", 0, '\t', "unittest", 1) == 123);
    assert(getFieldValue!double("123.4", 0, '\t', "unittest", 1) == 123.4);
    assertThrown(getFieldValue!double("abc", 0, '\t', "unittest", 1));
    assertThrown(getFieldValue!double("abc", 0, '\t', "unittest", 2));
    assertThrown(getFieldValue!double("123", 1, '\t', "unittest", 1));
    assertThrown(getFieldValue!double("123", 1, '\t', "unittest", 2));
}

/* Unit tests for the main program start here.
 *
 * Portability note: Many of the tests here rely on generating consistent random numbers
 * across different platforms when using the same random seed. So far this has succeeded
 * on several different platorm, compiler, and library versions. However, it is certainly
 * possible this condition will not hold on other platforms.
 *
 * For tsv-sample, this portability implies generating the same results on different
 * platforms when using the same random seed. This is NOT part of tsv-sample guarantees,
 * but it is convenient for testing. If platforms are identified that do not generate
 * the same results these tests will need to be adjusted.
 */
version(unittest)
{
    /* Unit test helper functions. */

    import tsv_utils.common.unittest_utils;   // tsv unit test helpers, from common/src/.
    import std.conv : to;

    void testTsvSample(string[] cmdArgs, string[][] expected)
    {
        import std.array : appender;
        import std.format : format;

        assert(cmdArgs.length > 0, "[testTsvSample] cmdArgs must not be empty.");

        auto formatAssertMessage(T...)(string msg, T formatArgs)
        {
            auto formatString = "[testTsvSample] %s: " ~ msg;
            return format(formatString, cmdArgs[0], formatArgs);
        }

        TsvSampleOptions cmdopt;
        auto savedCmdArgs = cmdArgs.to!string;
        auto r = cmdopt.processArgs(cmdArgs);
        assert(r[0], formatAssertMessage("Invalid command lines arg: '%s'.", savedCmdArgs));
        auto output = appender!(char[])();

        tsvSample(cmdopt, output);    // This invokes the main code line.

        auto expectedOutput = expected.tsvDataToString;

        assert(output.data == expectedOutput,
               formatAssertMessage(
                   "Result != expected:\n=====Expected=====\n%s=====Actual=======\n%s==================",
                   expectedOutput.to!string, output.data.to!string));
    }
 }

unittest
{
    import std.path : buildPath;
    import std.file : rmdirRecurse;
    import std.format : format;

    auto testDir = makeUnittestTempDir("tsv_sample");
    scope(exit) testDir.rmdirRecurse;

    /* Tabular data sets and expected results use the built-in static seed.
     * Tests are run by writing the data set to a file, then calling the main
     * routine to process. The function testTsvSample plays the role of the
     * main program. Rather than writing to expected output, the results are
     * matched against expected. The expected results were verified by hand
     * prior to inclusion in the test.
     *
     * The initial part of this section is simply setting up data files and
     * expected results.
     *
     * Expected results naming conventions:
     *  - Prefix: dataNxMExpected. N and M are numbers. e.g. data3x6Expected
     *  - Sampling Type (required): Permute, Replace, Bernoulli, Distinct
     *  - Compatibility: Compat, AlgoR, Skip, Swap
     *  - Weight Field: Wt<num>, e.g. Wt3
     *  - Sample Size: Num<num>, eg. Num3
     *  - Seed Value: V<num>, eg. V77
     *  - Key Field: K<num>, e.g. K2
     *  - Probability: P<num>, e.g P05 (5%)
     *  - Printing Probalities: Probs
     *  - Printing Probs in order: ProbsInorder
     *  - Printing Probs with custom header: RVCustom
     */

    /* Empty file. */
    string[][] dataEmpty = [];
    string fpath_dataEmpty = buildPath(testDir, "dataEmpty.tsv");
    writeUnittestTsvFile(fpath_dataEmpty, dataEmpty);

    /* 3x1, header only. */
    string[][] data3x0 = [["field_a", "field_b", "field_c"]];
    string fpath_data3x0 = buildPath(testDir, "data3x0.tsv");
    writeUnittestTsvFile(fpath_data3x0, data3x0);

    /* 3x1 */
    string[][] data3x1 =
        [["field_a", "field_b", "field_c"],
         ["tan", "タン", "8.5"]];

    string fpath_data3x1 = buildPath(testDir, "data3x1.tsv");
    string fpath_data3x1_noheader = buildPath(testDir, "data3x1_noheader.tsv");
    writeUnittestTsvFile(fpath_data3x1, data3x1);
    writeUnittestTsvFile(fpath_data3x1_noheader, data3x1[1..$]);

    string[][] data3x1ExpectedReplaceNum3 =
        [["field_a", "field_b", "field_c"],
         ["tan", "タン", "8.5"],
         ["tan", "タン", "8.5"],
         ["tan", "タン", "8.5"]];

    /* 3x2 */
    string[][] data3x2 =
        [["field_a", "field_b", "field_c"],
         ["brown", "褐色", "29.2"],
         ["gray", "グレー", "6.2"]];

    string fpath_data3x2 = buildPath(testDir, "data3x2.tsv");
    string fpath_data3x2_noheader = buildPath(testDir, "data3x2_noheader.tsv");
    writeUnittestTsvFile(fpath_data3x2, data3x2);
    writeUnittestTsvFile(fpath_data3x2_noheader, data3x2[1..$]);

    string[][] data3x2PermuteCompat =
        [["field_a", "field_b", "field_c"],
         ["gray", "グレー", "6.2"],
         ["brown", "褐色", "29.2"]];

    string[][] data3x2PermuteShuffle =
        [["field_a", "field_b", "field_c"],
         ["gray", "グレー", "6.2"],
         ["brown", "褐色", "29.2"]];

    /* 3x3 */
    string[][] data3x3 =
        [["field_a", "field_b", "field_c"],
         ["orange", "オレンジ", "2.5"],
         ["pink", "ピンク", "1.1"],
         ["purple", "紫の", "42"]];

    string fpath_data3x3 = buildPath(testDir, "data3x3.tsv");
    string fpath_data3x3_noheader = buildPath(testDir, "data3x3_noheader.tsv");
    writeUnittestTsvFile(fpath_data3x3, data3x3);
    writeUnittestTsvFile(fpath_data3x3_noheader, data3x3[1..$]);

    string[][] data3x3ExpectedPermuteCompat =
        [["field_a", "field_b", "field_c"],
         ["purple", "紫の", "42"],
         ["pink", "ピンク", "1.1"],
         ["orange", "オレンジ", "2.5"]];

    string[][] data3x3ExpectedPermuteSwap =
        [["field_a", "field_b", "field_c"],
         ["purple", "紫の", "42"],
         ["orange", "オレンジ", "2.5"],
         ["pink", "ピンク", "1.1"]];

    /* 3x6 */
    string[][] data3x6 =
        [["field_a", "field_b", "field_c"],
         ["red", "赤", "23.8"],
         ["green", "緑", "0.0072"],
         ["white", "白", "1.65"],
         ["yellow", "黄", "12"],
         ["blue", "青", "12"],
         ["black", "黒", "0.983"]];
    string fpath_data3x6 = buildPath(testDir, "data3x6.tsv");
    string fpath_data3x6_noheader = buildPath(testDir, "data3x6_noheader.tsv");
    writeUnittestTsvFile(fpath_data3x6, data3x6);
    writeUnittestTsvFile(fpath_data3x6_noheader, data3x6[1..$]);

    // Randomization, all lines
    string[][] data3x6ExpectedPermuteCompat =
        [["field_a", "field_b", "field_c"],
         ["yellow", "黄", "12"],
         ["black", "黒", "0.983"],
         ["blue", "青", "12"],
         ["white", "白", "1.65"],
         ["green", "緑", "0.0072"],
         ["red", "赤", "23.8"]];

    string[][] data3x6ExpectedPermuteSwap =
        [["field_a", "field_b", "field_c"],
         ["black", "黒", "0.983"],
         ["green", "緑", "0.0072"],
         ["red", "赤", "23.8"],
         ["yellow", "黄", "12"],
         ["white", "白", "1.65"],
         ["blue", "青", "12"]];

    string[][] data3x6ExpectedPermuteCompatProbs =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.96055546286515892", "yellow", "黄", "12"],
         ["0.7571015392895788", "black", "黒", "0.983"],
         ["0.52525980887003243", "blue", "青", "12"],
         ["0.49287854949943721", "white", "白", "1.65"],
         ["0.15929344086907804", "green", "緑", "0.0072"],
         ["0.010968807619065046", "red", "赤", "23.8"]];

    /* Note: data3x6ExpectedAlgoRNum6 is identical to data3x6ExpectedPermuteSwap because
     * both are effectively the same algorithm given that --num is data length. Both read
     * in the full data in order then call randomShuffle.
     */
    string[][] data3x6ExpectedPermuteAlgoRNum6 =
        [["field_a", "field_b", "field_c"],
         ["black", "黒", "0.983"],
         ["green", "緑", "0.0072"],
         ["red", "赤", "23.8"],
         ["yellow", "黄", "12"],
         ["white", "白", "1.65"],
         ["blue", "青", "12"]];

    string[][] data3x6ExpectedPermuteAlgoRNum5 =
        [["field_a", "field_b", "field_c"],
         ["red", "赤", "23.8"],
         ["black", "黒", "0.983"],
         ["white", "白", "1.65"],
         ["green", "緑", "0.0072"],
         ["yellow", "黄", "12"]];

    string[][] data3x6ExpectedPermuteAlgoRNum4 =
        [["field_a", "field_b", "field_c"],
         ["blue", "青", "12"],
         ["green", "緑", "0.0072"],
         ["black", "黒", "0.983"],
         ["white", "白", "1.65"]];

    string[][] data3x6ExpectedPermuteAlgoRNum3 =
        [["field_a", "field_b", "field_c"],
         ["red", "赤", "23.8"],
         ["black", "黒", "0.983"],
         ["green", "緑", "0.0072"]];

    string[][] data3x6ExpectedPermuteAlgoRNum2 =
        [["field_a", "field_b", "field_c"],
         ["black", "黒", "0.983"],
         ["red", "赤", "23.8"]];

    string[][] data3x6ExpectedPermuteAlgoRNum1 =
        [["field_a", "field_b", "field_c"],
         ["green", "緑", "0.0072"]];

    string[][] data3x6ExpectedBernoulliProbsP100 =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.010968807619065046", "red", "赤", "23.8"],
         ["0.15929344086907804", "green", "緑", "0.0072"],
         ["0.49287854949943721", "white", "白", "1.65"],
         ["0.96055546286515892", "yellow", "黄", "12"],
         ["0.52525980887003243", "blue", "青", "12"],
         ["0.7571015392895788", "black", "黒", "0.983"]];

    string[][] data3x6ExpectedBernoulliCompatProbsP60 =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.010968807619065046", "red", "赤", "23.8"],
         ["0.15929344086907804", "green", "緑", "0.0072"],
         ["0.49287854949943721", "white", "白", "1.65"],
         ["0.52525980887003243", "blue", "青", "12"]];

    string[][] data3x6ExpectedBernoulliSkipP40 =
        [["field_a", "field_b", "field_c"],
         ["red", "赤", "23.8"],
         ["green", "緑", "0.0072"],
         ["yellow", "黄", "12"]];

    string[][] data3x6ExpectedBernoulliCompatP60 =
        [["field_a", "field_b", "field_c"],
         ["red", "赤", "23.8"],
         ["green", "緑", "0.0072"],
         ["white", "白", "1.65"],
         ["blue", "青", "12"]];

    string[][] data3x6ExpectedDistinctK1K3P60 =
        [["field_a", "field_b", "field_c"],
         ["green", "緑", "0.0072"],
         ["white", "白", "1.65"],
         ["blue", "青", "12"]];

    string[][] data3x6ExpectedDistinctK1K3P60Probs =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0", "green", "緑", "0.0072"],
         ["0", "white", "白", "1.65"],
         ["0", "blue", "青", "12"]];

    string[][] data3x6ExpectedDistinctK1K3P60ProbsRVCustom =
        [["custom_random_value_header", "field_a", "field_b", "field_c"],
         ["0", "green", "緑", "0.0072"],
         ["0", "white", "白", "1.65"],
         ["0", "blue", "青", "12"]];

    string[][] data3x6ExpectedDistinctK2P2ProbsInorder =
        [["random_value", "field_a", "field_b", "field_c"],
         ["1", "red", "赤", "23.8"],
         ["0", "green", "緑", "0.0072"],
         ["0", "white", "白", "1.65"],
         ["1", "yellow", "黄", "12"],
         ["3", "blue", "青", "12"],
         ["2", "black", "黒", "0.983"]];

    string[][] data3x6ExpectedPermuteWt3Probs =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.9966519875764539", "yellow", "黄", "12"],
         ["0.94775884809836686", "blue", "青", "12"],
         ["0.82728234682286661", "red", "赤", "23.8"],
         ["0.75346697377181959", "black", "黒", "0.983"],
         ["0.65130103496422487", "white", "白", "1.65"],
         ["1.5636943712879866e-111", "green", "緑", "0.0072"]];

    string[][] data3x6ExpectedWt3ProbsInorder =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.82728234682286661", "red", "赤", "23.8"],
         ["1.5636943712879866e-111", "green", "緑", "0.0072"],
         ["0.65130103496422487", "white", "白", "1.65"],
         ["0.9966519875764539", "yellow", "黄", "12"],
         ["0.94775884809836686", "blue", "青", "12"],
         ["0.75346697377181959", "black", "黒", "0.983"]];

    string[][] data3x6ExpectedPermuteWt3 =
        [["field_a", "field_b", "field_c"],
         ["yellow", "黄", "12"],
         ["blue", "青", "12"],
         ["red", "赤", "23.8"],
         ["black", "黒", "0.983"],
         ["white", "白", "1.65"],
         ["green", "緑", "0.0072"]];

    string[][] data3x6ExpectedReplaceNum10 =
        [["field_a", "field_b", "field_c"],
         ["black", "黒", "0.983"],
         ["green", "緑", "0.0072"],
         ["green", "緑", "0.0072"],
         ["red", "赤", "23.8"],
         ["yellow", "黄", "12"],
         ["red", "赤", "23.8"],
         ["white", "白", "1.65"],
         ["yellow", "黄", "12"],
         ["yellow", "黄", "12"],
         ["white", "白", "1.65"],
        ];

    string[][] data3x6ExpectedReplaceNum10V77 =
        [["field_a", "field_b", "field_c"],
         ["black", "黒", "0.983"],
         ["red", "赤", "23.8"],
         ["black", "黒", "0.983"],
         ["yellow", "黄", "12"],
         ["green", "緑", "0.0072"],
         ["green", "緑", "0.0072"],
         ["green", "緑", "0.0072"],
         ["yellow", "黄", "12"],
         ["blue", "青", "12"],
         ["white", "白", "1.65"],
        ];

    /* Using a different static seed. */
    string[][] data3x6ExpectedPermuteCompatV41Probs =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.68057272653095424", "green", "緑", "0.0072"],
         ["0.67681624367833138", "blue", "青", "12"],
         ["0.32097338931635022", "yellow", "黄", "12"],
         ["0.25092361867427826", "red", "赤", "23.8"],
         ["0.15535934292711318", "black", "黒", "0.983"],
         ["0.04609582107514143", "white", "白", "1.65"]];

    string[][] data3x6ExpectedBernoulliCompatP60V41Probs =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.25092361867427826", "red", "赤", "23.8"],
         ["0.04609582107514143", "white", "白", "1.65"],
         ["0.32097338931635022", "yellow", "黄", "12"],
         ["0.15535934292711318", "black", "黒", "0.983"]];

    string[][] data3x6ExpectedPermuteWt3V41Probs =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.96799377498910666", "blue", "青", "12"],
         ["0.94356245792573568", "red", "赤", "23.8"],
         ["0.90964601024271996", "yellow", "黄", "12"],
         ["0.15491658409260103", "white", "白", "1.65"],
         ["0.15043620392537033", "black", "黒", "0.983"],
         ["6.1394674830701461e-24", "green", "緑", "0.0072"]];

    string[][] data3x6ExpectedWt3V41ProbsInorder =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.94356245792573568", "red", "赤", "23.8"],
         ["6.1394674830701461e-24", "green", "緑", "0.0072"],
         ["0.15491658409260103", "white", "白", "1.65"],
         ["0.90964601024271996", "yellow", "黄", "12"],
         ["0.96799377498910666", "blue", "青", "12"],
         ["0.15043620392537033", "black", "黒", "0.983"]];


    /* Combo 1: 3x3, 3x1, 3x6, 3x2. No data files, only expected results. */
    string[][] combo1ExpectedPermuteCompat =
        [["field_a", "field_b", "field_c"],
         ["yellow", "黄", "12"],
         ["tan", "タン", "8.5"],
         ["brown", "褐色", "29.2"],
         ["green", "緑", "0.0072"],
         ["red", "赤", "23.8"],
         ["purple", "紫の", "42"],
         ["black", "黒", "0.983"],
         ["white", "白", "1.65"],
         ["gray", "グレー", "6.2"],
         ["blue", "青", "12"],
         ["pink", "ピンク", "1.1"],
         ["orange", "オレンジ", "2.5"]];

    string[][] combo1ExpectedPermuteCompatProbs =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.97088520275428891", "yellow", "黄", "12"],
         ["0.96055546286515892", "tan", "タン", "8.5"],
         ["0.81756894313730299", "brown", "褐色", "29.2"],
         ["0.7571015392895788", "green", "緑", "0.0072"],
         ["0.52525980887003243", "red", "赤", "23.8"],
         ["0.49287854949943721", "purple", "紫の", "42"],
         ["0.47081507067196071", "black", "黒", "0.983"],
         ["0.38388182921335101", "white", "白", "1.65"],
         ["0.29215990612283349", "gray", "グレー", "6.2"],
         ["0.24033216014504433", "blue", "青", "12"],
         ["0.15929344086907804", "pink", "ピンク", "1.1"],
         ["0.010968807619065046", "orange", "オレンジ", "2.5"]];

    /* Combo 1: 3x3, 3x1, 3x6, 3x2. No data files, only expected results. */
    string[][] combo1ExpectedProbsInorder =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.010968807619065046", "orange", "オレンジ", "2.5"],
         ["0.15929344086907804", "pink", "ピンク", "1.1"],
         ["0.49287854949943721", "purple", "紫の", "42"],
         ["0.96055546286515892", "tan", "タン", "8.5"],
         ["0.52525980887003243", "red", "赤", "23.8"],
         ["0.7571015392895788", "green", "緑", "0.0072"],
         ["0.38388182921335101", "white", "白", "1.65"],
         ["0.97088520275428891", "yellow", "黄", "12"],
         ["0.24033216014504433", "blue", "青", "12"],
         ["0.47081507067196071", "black", "黒", "0.983"],
         ["0.81756894313730299", "brown", "褐色", "29.2"],
         ["0.29215990612283349", "gray", "グレー", "6.2"]];

    string[][] combo1ExpectedBernoulliCompatP50Probs =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.010968807619065046", "orange", "オレンジ", "2.5"],
         ["0.15929344086907804", "pink", "ピンク", "1.1"],
         ["0.49287854949943721", "purple", "紫の", "42"],
         ["0.38388182921335101", "white", "白", "1.65"],
         ["0.24033216014504433", "blue", "青", "12"],
         ["0.47081507067196071", "black", "黒", "0.983"],
         ["0.29215990612283349", "gray", "グレー", "6.2"]];

    string[][] combo1ExpectedBernoulliCompatP40 =
        [["field_a", "field_b", "field_c"],
         ["orange", "オレンジ", "2.5"],
         ["pink", "ピンク", "1.1"],
         ["white", "白", "1.65"],
         ["blue", "青", "12"],
         ["gray", "グレー", "6.2"]];

    string[][] combo1ExpectedDistinctK1P40 =
        [["field_a", "field_b", "field_c"],
         ["orange", "オレンジ", "2.5"],
         ["red", "赤", "23.8"],
         ["green", "緑", "0.0072"],
         ["blue", "青", "12"],
         ["black", "黒", "0.983"]];

    string[][] combo1ExpectedPermuteWt3Probs =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.99754077523718754", "yellow", "黄", "12"],
         ["0.99527665440088786", "tan", "タン", "8.5"],
         ["0.99312578945741659", "brown", "褐色", "29.2"],
         ["0.98329602553389361", "purple", "紫の", "42"],
         ["0.9733096193808366", "red", "赤", "23.8"],
         ["0.88797551521739648", "blue", "青", "12"],
         ["0.81999230489041786", "gray", "グレー", "6.2"],
         ["0.55975569204250941", "white", "白", "1.65"],
         ["0.46472135609205739", "black", "黒", "0.983"],
         ["0.18824582704191337", "pink", "ピンク", "1.1"],
         ["0.1644613185329992", "orange", "オレンジ", "2.5"],
         ["1.6438086931020549e-17", "green", "緑", "0.0072"]];

    string[][] combo1ExpectedPermuteWt3 =
        [["field_a", "field_b", "field_c"],
         ["yellow", "黄", "12"],
         ["tan", "タン", "8.5"],
         ["brown", "褐色", "29.2"],
         ["purple", "紫の", "42"],
         ["red", "赤", "23.8"],
         ["blue", "青", "12"],
         ["gray", "グレー", "6.2"],
         ["white", "白", "1.65"],
         ["black", "黒", "0.983"],
         ["pink", "ピンク", "1.1"],
         ["orange", "オレンジ", "2.5"],
         ["green", "緑", "0.0072"]];

        string[][] combo1ExpectedPermuteAlgoRNum4 =
        [["field_a", "field_b", "field_c"],
         ["blue", "青", "12"],
         ["gray", "グレー", "6.2"],
         ["brown", "褐色", "29.2"],
         ["white", "白", "1.65"]];

    string[][] combo1ExpectedReplaceNum10 =
        [["field_a", "field_b", "field_c"],
         ["gray", "グレー", "6.2"],
         ["yellow", "黄", "12"],
         ["yellow", "黄", "12"],
         ["white", "白", "1.65"],
         ["tan", "タン", "8.5"],
         ["white", "白", "1.65"],
         ["blue", "青", "12"],
         ["black", "黒", "0.983"],
         ["tan", "タン", "8.5"],
         ["purple", "紫の", "42"]];

    /* 1x200 - Needed for testing bernoulliSkipSampling, invoked with prob < 0.04. */
    string[][] data1x200 =
        [["field_a"],
         ["000"], ["001"], ["002"], ["003"], ["004"], ["005"], ["006"], ["007"], ["008"], ["009"],
         ["010"], ["011"], ["012"], ["013"], ["014"], ["015"], ["016"], ["017"], ["018"], ["019"],
         ["020"], ["021"], ["022"], ["023"], ["024"], ["025"], ["026"], ["027"], ["028"], ["029"],
         ["030"], ["031"], ["032"], ["033"], ["034"], ["035"], ["036"], ["037"], ["038"], ["039"],
         ["040"], ["041"], ["042"], ["043"], ["044"], ["045"], ["046"], ["047"], ["048"], ["049"],
         ["050"], ["051"], ["052"], ["053"], ["054"], ["055"], ["056"], ["057"], ["058"], ["059"],
         ["060"], ["061"], ["062"], ["063"], ["064"], ["065"], ["066"], ["067"], ["068"], ["069"],
         ["070"], ["071"], ["072"], ["073"], ["074"], ["075"], ["076"], ["077"], ["078"], ["079"],
         ["080"], ["081"], ["082"], ["083"], ["084"], ["085"], ["086"], ["087"], ["088"], ["089"],
         ["090"], ["091"], ["092"], ["093"], ["094"], ["095"], ["096"], ["097"], ["098"], ["099"],
         ["100"], ["101"], ["102"], ["103"], ["104"], ["105"], ["106"], ["107"], ["108"], ["109"],
         ["110"], ["111"], ["112"], ["113"], ["114"], ["115"], ["116"], ["117"], ["118"], ["119"],
         ["120"], ["121"], ["122"], ["123"], ["124"], ["125"], ["126"], ["127"], ["128"], ["129"],
         ["130"], ["131"], ["132"], ["133"], ["134"], ["135"], ["136"], ["137"], ["138"], ["139"],
         ["140"], ["141"], ["142"], ["143"], ["144"], ["145"], ["146"], ["147"], ["148"], ["149"],
         ["150"], ["151"], ["152"], ["153"], ["154"], ["155"], ["156"], ["157"], ["158"], ["159"],
         ["160"], ["161"], ["162"], ["163"], ["164"], ["165"], ["166"], ["167"], ["168"], ["169"],
         ["170"], ["171"], ["172"], ["173"], ["174"], ["175"], ["176"], ["177"], ["178"], ["179"],
         ["180"], ["181"], ["182"], ["183"], ["184"], ["185"], ["186"], ["187"], ["188"], ["189"],
         ["190"], ["191"], ["192"], ["193"], ["194"], ["195"], ["196"], ["197"], ["198"], ["199"],
        ];

    string fpath_data1x200 = buildPath(testDir, "data1x200.tsv");
    string fpath_data1x200_noheader = buildPath(testDir, "data1x200_noheader.tsv");
    writeUnittestTsvFile(fpath_data1x200, data1x200);
    writeUnittestTsvFile(fpath_data1x200_noheader, data1x200[1..$]);

    string[][] data1x200ExpectedBernoulliSkipV333P01 =
        [["field_a"],
         ["077"],
         ["119"]];

    string[][] data1x200ExpectedBernoulliSkipV333P02 =
        [["field_a"],
         ["038"],
         ["059"],
         ["124"],
         ["161"],
         ["162"],
         ["183"]];

    string[][] data1x200ExpectedBernoulliSkipV333P03 =
        [["field_a"],
         ["025"],
         ["039"],
         ["082"],
         ["107"],
         ["108"],
         ["122"],
         ["136"],
         ["166"],
         ["182"]];

    string[][] data1x200ExpectedBernoulliCompatV333P01 =
        [["field_a"],
         ["072"]];

    string[][] data1x200ExpectedBernoulliCompatV333P02 =
        [["field_a"],
         ["004"],
         ["072"]];

    string[][] data1x200ExpectedBernoulliCompatV333P03 =
        [["field_a"],
         ["004"],
         ["072"],
         ["181"]];

    /* Combo 2, for bernoulli skip sampling: 3x0, 3x1, 1x200, empty, 1x10. No data files,
     * only expected results. The header is from 3x0, the results are offset 1-position
     * from data1x200ExpectedBernoulliSkipV333P03 due to insertion of a single preceding line.
     */
    string[][] combo2ExpectedBernoulliSkipV333P03 =
        [["field_a", "field_b", "field_c"],
         ["024"],
         ["038"],
         ["081"],
         ["106"],
         ["107"],
         ["121"],
         ["135"],
         ["165"],
         ["181"]];


    /* 1x10 - Simple 1-column file. */
    string[][] data1x10 =
        [["field_a"], ["1"], ["2"], ["3"], ["4"], ["5"], ["6"], ["7"], ["8"], ["9"], ["10"]];
    string fpath_data1x10 = buildPath(testDir, "data1x10.tsv");
    string fpath_data1x10_noheader = buildPath(testDir, "data1x10_noheader.tsv");
    writeUnittestTsvFile(fpath_data1x10, data1x10);
    writeUnittestTsvFile(fpath_data1x10_noheader, data1x10[1..$]);

    string[][] data1x10ExpectedPermuteCompat =
        [["field_a"], ["8"], ["4"], ["6"], ["5"], ["3"], ["10"], ["7"], ["9"], ["2"], ["1"]];

    string[][] data1x10ExpectedPermuteWt1 =
        [["field_a"], ["8"], ["4"], ["6"], ["10"], ["5"], ["7"], ["9"], ["3"], ["2"], ["1"]];

    /* 2x10a - Uniform distribution [0,1]. */
    string[][] data2x10a =
        [["line", "weight"],
         ["1", "0.26788837"],
         ["2", "0.06601298"],
         ["3", "0.38627527"],
         ["4", "0.47379424"],
         ["5", "0.02966641"],
         ["6", "0.05636231"],
         ["7", "0.70529242"],
         ["8", "0.91836862"],
         ["9", "0.99103720"],
         ["10", "0.31401740"]];

    string fpath_data2x10a = buildPath(testDir, "data2x10a.tsv");
    writeUnittestTsvFile(fpath_data2x10a, data2x10a);

    string[][] data2x10aExpectedPermuteWt2Probs =
        [["random_value", "line", "weight"],
         ["0.96833865494543658", "8", "0.91836862"],
         ["0.91856842054413923", "4", "0.47379424"],
         ["0.25730832087795091", "7", "0.70529242"],
         ["0.2372531790701812", "9", "0.99103720"],
         ["0.16016096701872204", "3", "0.38627527"],
         ["0.090819662667243381", "10", "0.31401740"],
         ["0.0071764539244361172", "6", "0.05636231"],
         ["4.8318642951630057e-08", "1", "0.26788837"],
         ["3.7525692966535517e-10", "5", "0.02966641"],
         ["8.2123247880095796e-13", "2", "0.06601298"]];

    /* 2x10b - Uniform distribution [0,1000]. */
    string[][] data2x10b =
        [["line", "weight"],
         ["1", "761"],
         ["2", "432"],
         ["3", "103"],
         ["4", "448"],
         ["5", "750"],
         ["6", "711"],
         ["7", "867"],
         ["8", "841"],
         ["9", "963"],
         ["10", "784"]];

    string fpath_data2x10b = buildPath(testDir, "data2x10b.tsv");
    writeUnittestTsvFile(fpath_data2x10b, data2x10b);

    string[][] data2x10bExpectedPermuteWt2Probs =
        [["random_value", "line", "weight"],
         ["0.99996486739067969", "8", "841"],
         ["0.99991017467137211", "4", "448"],
         ["0.99960871524873662", "6", "711"],
         ["0.999141885371438", "5", "750"],
         ["0.99903963250274785", "10", "784"],
         ["0.99889631825931946", "7", "867"],
         ["0.99852058315191139", "9", "963"],
         ["0.99575669679158918", "2", "432"],
         ["0.99408758732050595", "1", "761"],
         ["0.99315467761212362", "3", "103"]];

    /* 2x10c - Logarithmic distribution in random order. */
    string[][] data2x10c =
        [["line", "weight"],
         ["1", "31.85"],
         ["2", "17403.31"],
         ["3", "653.84"],
         ["4", "8.23"],
         ["5", "2671.04"],
         ["6", "26226.08"],
         ["7", "1.79"],
         ["8", "354.56"],
         ["9", "35213.81"],
         ["10", "679.29"]];

    string fpath_data2x10c = buildPath(testDir, "data2x10c.tsv");
    writeUnittestTsvFile(fpath_data2x10c, data2x10c);

    string[][] data2x10cExpectedPermuteWt2Probs =
        [["random_value", "line", "weight"],
         ["0.99998939008709697", "6", "26226.08"],
         ["0.99995951291695517", "9", "35213.81"],
         ["0.99991666907613541", "8", "354.56"],
         ["0.9998944505218641", "2", "17403.31"],
         ["0.9997589760286163", "5", "2671.04"],
         ["0.99891852769877643", "3", "653.84"],
         ["0.99889167752782515", "10", "679.29"],
         ["0.99512207506850148", "4", "8.23"],
         ["0.86789371584259023", "1", "31.85"],
         ["0.5857443816291561", "7", "1.79"]];

    /* 2x10d. Logarithmic distribution in ascending order. */
    string[][] data2x10d =
        [["line", "weight"],
         ["1", "1.79"],
         ["2", "8.23"],
         ["3", "31.85"],
         ["4", "354.56"],
         ["5", "653.84"],
         ["6", "679.29"],
         ["7", "2671.04"],
         ["8", "17403.31"],
         ["9", "26226.08"],
         ["10", "35213.81"]];

    string fpath_data2x10d = buildPath(testDir, "data2x10d.tsv");
    writeUnittestTsvFile(fpath_data2x10d, data2x10d);

    string[][] data2x10dExpectedPermuteWt2Probs =
        [["random_value", "line", "weight"],
         ["0.99999830221846353", "8", "17403.31"],
         ["0.99997860834041397", "10", "35213.81"],
         ["0.99994563828986716", "9", "26226.08"],
         ["0.99988650363575737", "4", "354.56"],
         ["0.99964161939190088", "7", "2671.04"],
         ["0.99959045338948649", "6", "679.29"],
         ["0.99901574490639788", "5", "653.84"],
         ["0.97803163304747431", "3", "31.85"],
         ["0.79994791806910948", "2", "8.23"],
         ["0.080374261239949119", "1", "1.79"]];

    /* 2x10e. Logarithmic distribution in descending order. */
    string[][] data2x10e =
        [["line", "weight"],
         ["1", "35213.81"],
         ["2", "26226.08"],
         ["3", "17403.31"],
         ["4", "2671.04"],
         ["5", "679.29"],
         ["6", "653.84"],
         ["7", "354.56"],
         ["8", "31.85"],
         ["9", "8.23"],
         ["10", "1.79"]];
    string fpath_data2x10e = buildPath(testDir, "data2x10e.tsv");
    writeUnittestTsvFile(fpath_data2x10e, data2x10e);

    string[][] data2x10eExpectedPermuteWt2Probs =
        [["random_value", "line", "weight"],
         ["0.99998493348975237", "4", "2671.04"],
         ["0.99995934807202624", "3", "17403.31"],
         ["0.99992995739727453", "2", "26226.08"],
         ["0.99987185679245649", "1", "35213.81"],
         ["0.99957451563173938", "6", "653.84"],
         ["0.99907273650209583", "8", "31.85"],
         ["0.99905260312968946", "5", "679.29"],
         ["0.99730333650516401", "7", "354.56"],
         ["0.84093902435227808", "9", "8.23"],
         ["0.65650015926290028", "10", "1.79"]];

    /* Data sets for distinct sampling. */
    string[][] data5x25 =
        [["ID", "Shape", "Color", "Size", "Weight"],
         ["01", "circle", "red", "S", "10"],
         ["02", "circle", "black", "L", "20"],
         ["03", "square", "black", "L", "20"],
         ["04", "circle", "green", "L", "30"],
         ["05", "ellipse", "red", "S", "20"],
         ["06", "triangle", "red", "S", "10"],
         ["07", "triangle", "red", "L", "20"],
         ["08", "square", "black", "S", "10"],
         ["09", "circle", "black", "S", "20"],
         ["10", "square", "green", "L", "20"],
         ["11", "triangle", "red", "L", "20"],
         ["12", "circle", "green", "L", "30"],
         ["13", "ellipse", "red", "S", "20"],
         ["14", "circle", "green", "L", "30"],
         ["15", "ellipse", "red", "L", "30"],
         ["16", "square", "red", "S", "10"],
         ["17", "circle", "black", "L", "20"],
         ["18", "square", "red", "S", "20"],
         ["19", "square", "black", "L", "20"],
         ["20", "circle", "red", "S", "10"],
         ["21", "ellipse", "black", "L", "30"],
         ["22", "triangle", "red", "L", "30"],
         ["23", "circle", "green", "S", "20"],
         ["24", "square", "green", "L", "20"],
         ["25", "circle", "red", "S", "10"],
        ];

    string fpath_data5x25 = buildPath(testDir, "data5x25.tsv");
    string fpath_data5x25_noheader = buildPath(testDir, "data5x25_noheader.tsv");
    writeUnittestTsvFile(fpath_data5x25, data5x25);
    writeUnittestTsvFile(fpath_data5x25_noheader, data5x25[1..$]);

    string[][] data5x25ExpectedDistinctK2P40 =
        [["ID", "Shape", "Color", "Size", "Weight"],
         ["03", "square", "black", "L", "20"],
         ["05", "ellipse", "red", "S", "20"],
         ["08", "square", "black", "S", "10"],
         ["10", "square", "green", "L", "20"],
         ["13", "ellipse", "red", "S", "20"],
         ["15", "ellipse", "red", "L", "30"],
         ["16", "square", "red", "S", "10"],
         ["18", "square", "red", "S", "20"],
         ["19", "square", "black", "L", "20"],
         ["21", "ellipse", "black", "L", "30"],
         ["24", "square", "green", "L", "20"],
        ];

    string[][] data5x25ExpectedDistinctK2K4P20 =
        [["ID", "Shape", "Color", "Size", "Weight"],
         ["03", "square", "black", "L", "20"],
         ["07", "triangle", "red", "L", "20"],
         ["08", "square", "black", "S", "10"],
         ["10", "square", "green", "L", "20"],
         ["11", "triangle", "red", "L", "20"],
         ["16", "square", "red", "S", "10"],
         ["18", "square", "red", "S", "20"],
         ["19", "square", "black", "L", "20"],
         ["22", "triangle", "red", "L", "30"],
         ["24", "square", "green", "L", "20"],
        ];

    string[][] data5x25ExpectedDistinctK2K3K4P20 =
        [["ID", "Shape", "Color", "Size", "Weight"],
         ["04", "circle", "green", "L", "30"],
         ["07", "triangle", "red", "L", "20"],
         ["09", "circle", "black", "S", "20"],
         ["11", "triangle", "red", "L", "20"],
         ["12", "circle", "green", "L", "30"],
         ["14", "circle", "green", "L", "30"],
         ["16", "square", "red", "S", "10"],
         ["18", "square", "red", "S", "20"],
         ["22", "triangle", "red", "L", "30"],
        ];

    /*
     * Enough setup! Actually run some tests!
     */

    /* Permutations. Headers, static seed, compatibility mode. With weights and without. */
    testTsvSample(["test-a1", "--header", "--static-seed", "--compatibility-mode", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-a2", "--header", "--static-seed", "--compatibility-mode", fpath_data3x0], data3x0);
    testTsvSample(["test-a3", "-H", "-s", "--compatibility-mode", fpath_data3x1], data3x1);
    testTsvSample(["test-a4", "-H", "-s", "--compatibility-mode", fpath_data3x2], data3x2PermuteCompat);
    testTsvSample(["test-a5", "-H", "-s", "--compatibility-mode", fpath_data3x3], data3x3ExpectedPermuteCompat);
    testTsvSample(["test-a6", "-H", "-s", "--compatibility-mode", fpath_data3x6], data3x6ExpectedPermuteCompat);
    testTsvSample(["test-a7", "-H", "-s", "--print-random", fpath_data3x6], data3x6ExpectedPermuteCompatProbs);
    testTsvSample(["test-a8", "-H", "-s", "--weight-field", "3", fpath_data3x6], data3x6ExpectedPermuteWt3);
    testTsvSample(["test-a9", "-H", "-s", "--print-random", "-w", "3", fpath_data3x6], data3x6ExpectedPermuteWt3Probs);
    testTsvSample(["test-a10", "-H", "--seed-value", "41", "--print-random", fpath_data3x6], data3x6ExpectedPermuteCompatV41Probs);
    testTsvSample(["test-a11", "-H", "-s", "-v", "41", "--print-random", fpath_data3x6], data3x6ExpectedPermuteCompatV41Probs);
    testTsvSample(["test-a12", "-H", "-s", "-v", "0", "--print-random", fpath_data3x6], data3x6ExpectedPermuteCompatProbs);
    testTsvSample(["test-a13", "-H", "-v", "41", "-w", "3", "--print-random", fpath_data3x6], data3x6ExpectedPermuteWt3V41Probs);

    /* Permutations, without compatibility mode, or with both compatibility and printing. */
    testTsvSample(["test-aa1", "--header", "--static-seed", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-aa2", "--header", "--static-seed", fpath_data3x0], data3x0);
    testTsvSample(["test-aa3", "-H", "-s", fpath_data3x1], data3x1);
    testTsvSample(["test-aa4", "-H", "-s", fpath_data3x2], data3x2PermuteShuffle);
    testTsvSample(["test-aa5", "-H", "-s", fpath_data3x3], data3x3ExpectedPermuteSwap);
    testTsvSample(["test-aa6", "-H", "-s", fpath_data3x6], data3x6ExpectedPermuteSwap);
    testTsvSample(["test-aa7", "-H", "-s", "--weight-field", "3", fpath_data3x6], data3x6ExpectedPermuteWt3);
    testTsvSample(["test-aa8", "-H", "-s", "--print-random", "-w", "3", "--compatibility-mode", fpath_data3x6], data3x6ExpectedPermuteWt3Probs);
    testTsvSample(["test-aa9", "-H", "--seed-value", "41", "--print-random", "--compatibility-mode", fpath_data3x6], data3x6ExpectedPermuteCompatV41Probs);

    /* Reservoir sampling using Algorithm R.
     * (Note: reservoirSamplingViaHeap is tested later in the length-based iteration loops.)
     */
    testTsvSample(["test-aa10", "--prefer-algorithm-r", "--header", "--static-seed", "--num", "1", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-aa11", "--prefer-algorithm-r", "--header", "--static-seed", "--num", "2", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-aa12", "--prefer-algorithm-r", "-H", "-s", "--num", "1", fpath_data3x0], data3x0);
    testTsvSample(["test-aa13", "--prefer-algorithm-r", "-H", "-s", "--num", "2", fpath_data3x0], data3x0);
    testTsvSample(["test-aa14", "--prefer-algorithm-r", "-H", "-s", "--num", "1", fpath_data3x1], data3x1);
    testTsvSample(["test-aa15", "--prefer-algorithm-r", "-H", "-s", "--num", "2", fpath_data3x1], data3x1);
    testTsvSample(["test-aa16", "--prefer-algorithm-r", "-H", "-s", "--num", "7", fpath_data3x6], data3x6ExpectedPermuteAlgoRNum6);
    testTsvSample(["test-aa17", "--prefer-algorithm-r", "-H", "-s", "--num", "6", fpath_data3x6], data3x6ExpectedPermuteAlgoRNum6);
    testTsvSample(["test-aa18", "--prefer-algorithm-r", "-H", "-s", "--num", "5", fpath_data3x6], data3x6ExpectedPermuteAlgoRNum5);
    testTsvSample(["test-aa19", "--prefer-algorithm-r", "-H", "-s", "--num", "4", fpath_data3x6], data3x6ExpectedPermuteAlgoRNum4);
    testTsvSample(["test-aa20", "--prefer-algorithm-r", "-H", "-s", "--num", "3", fpath_data3x6], data3x6ExpectedPermuteAlgoRNum3);
    testTsvSample(["test-aa21", "--prefer-algorithm-r", "-H", "-s", "--num", "2", fpath_data3x6], data3x6ExpectedPermuteAlgoRNum2);
    testTsvSample(["test-aa22", "--prefer-algorithm-r", "-H", "-s", "--num", "1", fpath_data3x6], data3x6ExpectedPermuteAlgoRNum1);

    /* Bernoulli sampling cases. */
    testTsvSample(["test-a14", "--header", "--static-seed", "--prob", "0.001", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-a15", "--header", "--static-seed", "--prob", "0.001", fpath_data3x0], data3x0);
    testTsvSample(["test-a16", "-H", "-s", "-p", "1.0", fpath_data3x1], data3x1);
    testTsvSample(["test-a17", "-H", "-s", "-p", "1.0", fpath_data3x6], data3x6);
    testTsvSample(["test-a18", "-H", "-p", "1.0", fpath_data3x6], data3x6);
    testTsvSample(["test-a19", "-H", "-s", "--prob", "1.0", "--print-random", fpath_data3x6], data3x6ExpectedBernoulliProbsP100);
    testTsvSample(["test-a20", "-H", "-s", "--prob", "0.60", "--print-random", fpath_data3x6], data3x6ExpectedBernoulliCompatProbsP60);
    testTsvSample(["test-a21", "-H", "-s", "--prob", "0.60", fpath_data3x6], data3x6ExpectedBernoulliCompatP60);
    testTsvSample(["test-a22", "-H", "-v", "41", "--prob", "0.60", "--print-random", fpath_data3x6], data3x6ExpectedBernoulliCompatP60V41Probs);

    /* Bernoulli sampling with probabilities in skip sampling range or preferring skip sampling. */
    testTsvSample(["test-ab1", "-H", "--seed-value", "333", "--prob", "0.01", fpath_data1x200], data1x200ExpectedBernoulliSkipV333P01);
    testTsvSample(["test-ab2", "-H", "--seed-value", "333", "--prob", "0.02", fpath_data1x200], data1x200ExpectedBernoulliSkipV333P02);
    testTsvSample(["test-ab3", "-H", "--seed-value", "333", "--prob", "0.03", fpath_data1x200], data1x200ExpectedBernoulliSkipV333P03);
    testTsvSample(["test-ab4", "-H", "--seed-value", "333", "--prob", "0.01", "--compatibility-mode", fpath_data1x200], data1x200ExpectedBernoulliCompatV333P01);
    testTsvSample(["test-ab5", "-H", "--seed-value", "333", "--prob", "0.02", "--compatibility-mode", fpath_data1x200], data1x200ExpectedBernoulliCompatV333P02);
    testTsvSample(["test-ab6", "-H", "--seed-value", "333", "--prob", "0.03", "--compatibility-mode", fpath_data1x200], data1x200ExpectedBernoulliCompatV333P03);
    testTsvSample(["test-ab7", "-H", "-s", "-p", "0.40", "--prefer-skip-sampling", fpath_data3x6], data3x6ExpectedBernoulliSkipP40);

    /* Distinct sampling cases. */
    testTsvSample(["test-a23", "--header", "--static-seed", "--prob", "0.001", "--key-fields", "1", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-a24", "--header", "--static-seed", "--prob", "0.001", "--key-fields", "1", fpath_data3x0], data3x0);
    testTsvSample(["test-a25", "-H", "-s", "-p", "1.0", "-k", "2", fpath_data3x1], data3x1);
    testTsvSample(["test-a26", "-H", "-s", "-p", "1.0", "-k", "2", fpath_data3x6], data3x6);
    testTsvSample(["test-a27", "-H", "-s", "-p", "0.6", "-k", "1,3", fpath_data3x6], data3x6ExpectedDistinctK1K3P60);

    /* Generating random weights. Use Bernoulli sampling test set at prob 100% for uniform sampling.
     * For weighted sampling, use the weighted cases, but with expected using the original ordering.
     */
    testTsvSample(["test-a28", "-H", "-s", "--gen-random-inorder", fpath_data3x6], data3x6ExpectedBernoulliProbsP100);
    testTsvSample(["test-a29", "-H", "-s", "--gen-random-inorder", fpath_data3x6], data3x6ExpectedBernoulliProbsP100);
    testTsvSample(["test-a30", "-H", "-s", "--gen-random-inorder", "--weight-field", "3", fpath_data3x6],
                  data3x6ExpectedWt3ProbsInorder);
    testTsvSample(["test-a31", "-H", "-v", "41", "--gen-random-inorder", "--weight-field", "3", fpath_data3x6],
                  data3x6ExpectedWt3V41ProbsInorder);
    testTsvSample(["test-a32", "-H", "-s", "-p", "0.6", "-k", "1,3", "--print-random", fpath_data3x6],
                  data3x6ExpectedDistinctK1K3P60Probs);
    testTsvSample(["test-a33", "-H", "-s", "-p", "0.6", "-k", "1,3", "--print-random", "--random-value-header",
                   "custom_random_value_header", fpath_data3x6], data3x6ExpectedDistinctK1K3P60ProbsRVCustom);
    testTsvSample(["test-a34", "-H", "-s", "-p", "0.2", "-k", "2", "--gen-random-inorder", fpath_data3x6],
                  data3x6ExpectedDistinctK2P2ProbsInorder);

    /* Simple random sampling with replacement. */
    testTsvSample(["test-a35", "-H", "-s", "--replace", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-a36", "-H", "-s", "--replace", "--num", "3", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-a37", "-H", "-s", "--replace", fpath_data3x0], data3x0);
    testTsvSample(["test-a38", "-H", "-s", "--replace", "--num", "3", fpath_data3x0], data3x0);
    testTsvSample(["test-a39", "-H", "-s", "--replace", "--num", "3", fpath_data3x1], data3x1ExpectedReplaceNum3);
    testTsvSample(["test-a40", "-H", "-s", "--replace", "--num", "10", fpath_data3x6], data3x6ExpectedReplaceNum10);
    testTsvSample(["test-a41", "-H", "-s", "-v", "77", "--replace", "--num", "10", fpath_data3x6], data3x6ExpectedReplaceNum10V77);

    /* Permutations, compatibility mode, without headers. */
    testTsvSample(["test-b1", "-s", "--compatibility-mode", fpath_data3x1_noheader], data3x1[1..$]);
    testTsvSample(["test-b2", "-s", "--compatibility-mode", fpath_data3x2_noheader], data3x2PermuteCompat[1..$]);
    testTsvSample(["test-b3", "-s", "--compatibility-mode", fpath_data3x3_noheader], data3x3ExpectedPermuteCompat[1..$]);
    testTsvSample(["test-b4", "-s", "--compatibility-mode", fpath_data3x6_noheader], data3x6ExpectedPermuteCompat[1..$]);
    testTsvSample(["test-b5", "-s", "--print-random", fpath_data3x6_noheader], data3x6ExpectedPermuteCompatProbs[1..$]);
    testTsvSample(["test-b6", "-s", "--weight-field", "3", "--compatibility-mode", fpath_data3x6_noheader], data3x6ExpectedPermuteWt3[1..$]);
    testTsvSample(["test-b7", "-s", "--print-random", "-w", "3", fpath_data3x6_noheader], data3x6ExpectedPermuteWt3Probs[1..$]);
    testTsvSample(["test-b8", "-v", "41", "--print-random", fpath_data3x6_noheader], data3x6ExpectedPermuteCompatV41Probs[1..$]);
    testTsvSample(["test-b9", "-v", "41", "-w", "3", "--print-random", fpath_data3x6_noheader], data3x6ExpectedPermuteWt3V41Probs[1..$]);

    /* Permutations, no headers, without compatibility mode, or with printing and compatibility mode. */
    testTsvSample(["test-bb1", "-s", fpath_data3x1_noheader], data3x1[1..$]);
    testTsvSample(["test-bb2", "-s", fpath_data3x2_noheader], data3x2PermuteShuffle[1..$]);
    testTsvSample(["test-bb3", "-s", fpath_data3x3_noheader], data3x3ExpectedPermuteSwap[1..$]);
    testTsvSample(["test-bb4", "-s", fpath_data3x6_noheader], data3x6ExpectedPermuteSwap[1..$]);
    testTsvSample(["test-bb5", "-s", "--weight-field", "3", fpath_data3x6_noheader], data3x6ExpectedPermuteWt3[1..$]);
    testTsvSample(["test-bb6", "-s", "--print-random", "-w", "3", "--compatibility-mode", fpath_data3x6_noheader], data3x6ExpectedPermuteWt3Probs[1..$]);
    testTsvSample(["test-bb7", "-v", "41", "--print-random", "--compatibility-mode", fpath_data3x6_noheader], data3x6ExpectedPermuteCompatV41Probs[1..$]);

    /* Reservoir sampling using Algorithm R, no headers. */
    testTsvSample(["test-aa10", "--prefer-algorithm-r", "--static-seed", "--num", "1", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-aa11", "--prefer-algorithm-r", "--static-seed", "--num", "2", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-aa14", "--prefer-algorithm-r", "-s", "--num", "1", fpath_data3x1_noheader], data3x1[1..$]);
    testTsvSample(["test-aa15", "--prefer-algorithm-r", "-s", "--num", "2", fpath_data3x1_noheader], data3x1[1..$]);
    testTsvSample(["test-aa16", "--prefer-algorithm-r", "-s", "--num", "7", fpath_data3x6_noheader], data3x6ExpectedPermuteAlgoRNum6[1..$]);
    testTsvSample(["test-aa17", "--prefer-algorithm-r", "-s", "--num", "6", fpath_data3x6_noheader], data3x6ExpectedPermuteAlgoRNum6[1..$]);
    testTsvSample(["test-aa18", "--prefer-algorithm-r", "-s", "--num", "5", fpath_data3x6_noheader], data3x6ExpectedPermuteAlgoRNum5[1..$]);
    testTsvSample(["test-aa19", "--prefer-algorithm-r", "-s", "--num", "4", fpath_data3x6_noheader], data3x6ExpectedPermuteAlgoRNum4[1..$]);
    testTsvSample(["test-aa20", "--prefer-algorithm-r", "-s", "--num", "3", fpath_data3x6_noheader], data3x6ExpectedPermuteAlgoRNum3[1..$]);
    testTsvSample(["test-aa21", "--prefer-algorithm-r", "-s", "--num", "2", fpath_data3x6_noheader], data3x6ExpectedPermuteAlgoRNum2[1..$]);
    testTsvSample(["test-aa22", "--prefer-algorithm-r", "-s", "--num", "1", fpath_data3x6_noheader], data3x6ExpectedPermuteAlgoRNum1[1..$]);

    /* Bernoulli sampling cases. */
    testTsvSample(["test-b10", "-s", "-p", "1.0", fpath_data3x1_noheader], data3x1[1..$]);
    testTsvSample(["test-b11", "-s", "-p", "1.0", fpath_data3x6_noheader], data3x6[1..$]);
    testTsvSample(["test-b12", "-p", "1.0", fpath_data3x6_noheader], data3x6[1..$]);
    testTsvSample(["test-b13", "-s", "--prob", "1.0", "--print-random", fpath_data3x6_noheader], data3x6ExpectedBernoulliProbsP100[1..$]);
    testTsvSample(["test-b14", "-s", "--prob", "0.60", "--print-random", fpath_data3x6_noheader], data3x6ExpectedBernoulliCompatProbsP60[1..$]);
    testTsvSample(["test-b15", "-v", "41", "--prob", "0.60", "--print-random", fpath_data3x6_noheader], data3x6ExpectedBernoulliCompatP60V41Probs[1..$]);

    /* Bernoulli sampling with probabilities in skip sampling range. */
    testTsvSample(["test-bb1", "-v", "333", "-p", "0.01", fpath_data1x200_noheader], data1x200ExpectedBernoulliSkipV333P01[1..$]);
    testTsvSample(["test-bb2", "-v", "333", "-p", "0.02", fpath_data1x200_noheader], data1x200ExpectedBernoulliSkipV333P02[1..$]);
    testTsvSample(["test-bb3", "-v", "333", "-p", "0.03", fpath_data1x200_noheader], data1x200ExpectedBernoulliSkipV333P03[1..$]);
    testTsvSample(["test-bb4", "-v", "333", "-p", "0.01", "--compatibility-mode", fpath_data1x200_noheader], data1x200ExpectedBernoulliCompatV333P01[1..$]);
    testTsvSample(["test-bb5", "-v", "333", "-p", "0.02", "--compatibility-mode", fpath_data1x200_noheader], data1x200ExpectedBernoulliCompatV333P02[1..$]);
    testTsvSample(["test-bb6", "-v", "333", "-p", "0.03", "--compatibility-mode", fpath_data1x200_noheader], data1x200ExpectedBernoulliCompatV333P03[1..$]);
    testTsvSample(["test-bb7", "-s", "-p", "0.40", "--prefer-skip-sampling", fpath_data3x6_noheader], data3x6ExpectedBernoulliSkipP40[1..$]);

    /* Distinct sampling cases. */
    testTsvSample(["test-b16", "-s", "-p", "1.0", "-k", "2", fpath_data3x1_noheader], data3x1[1..$]);
    testTsvSample(["test-b17", "-s", "-p", "1.0", "-k", "2", fpath_data3x6_noheader], data3x6[1..$]);
    testTsvSample(["test-b18", "-p", "1.0", "-k", "2", fpath_data3x6_noheader], data3x6[1..$]);
    testTsvSample(["test-b19", "-v", "71563", "-p", "1.0", "-k", "2", fpath_data3x6_noheader], data3x6[1..$]);

    /* Generating random weights. Reuse Bernoulli sampling tests at prob 100%. */
    testTsvSample(["test-b20", "-s", "--gen-random-inorder", fpath_data3x6_noheader], data3x6ExpectedBernoulliProbsP100[1..$]);
    testTsvSample(["test-b23", "-v", "41", "--gen-random-inorder", "--weight-field", "3", fpath_data3x6_noheader], data3x6ExpectedWt3V41ProbsInorder[1..$]);
    testTsvSample(["test-b24", "-s", "-p", "0.6", "-k", "1,3", "--print-random", fpath_data3x6_noheader],
                  data3x6ExpectedDistinctK1K3P60Probs[1..$]);
    testTsvSample(["test-b24", "-s", "-p", "0.2", "-k", "2", "--gen-random-inorder", fpath_data3x6_noheader],
                  data3x6ExpectedDistinctK2P2ProbsInorder[1..$]);

    /* Simple random sampling with replacement. */
    testTsvSample(["test-b25", "-s", "--replace", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-b26", "-s", "-r", "--num", "3", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-b27", "-s", "-r", "-n", "3", fpath_data3x1_noheader], data3x1ExpectedReplaceNum3[1..$]);
    testTsvSample(["test-b28", "-s", "--replace", "-n", "10", fpath_data3x6_noheader], data3x6ExpectedReplaceNum10[1..$]);
    testTsvSample(["test-b29", "-s", "-v", "77", "--replace", "--num", "10", fpath_data3x6_noheader], data3x6ExpectedReplaceNum10V77[1..$]);

    /* Multi-file tests. */
    testTsvSample(["test-c1", "--header", "--static-seed", "--compatibility-mode",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedPermuteCompat);
    testTsvSample(["test-c2", "--header", "--static-seed", "--print-random",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedPermuteCompatProbs);
    testTsvSample(["test-c3", "--header", "--static-seed", "--print-random", "--weight-field", "3",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedPermuteWt3Probs);
    testTsvSample(["test-c4", "--header", "--static-seed", "--weight-field", "3", "--compatibility-mode",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedPermuteWt3);
    testTsvSample(["test-c5", "--header", "--static-seed", "--prefer-algorithm-r", "--num", "4",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedPermuteAlgoRNum4);

    /* Multi-file, no headers. */
    testTsvSample(["test-c6", "--static-seed", "--compatibility-mode",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedPermuteCompat[1..$]);
    testTsvSample(["test-c7", "--static-seed", "--print-random",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedPermuteCompatProbs[1..$]);
    testTsvSample(["test-c8", "--static-seed", "--print-random", "--weight-field", "3",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedPermuteWt3Probs[1..$]);
    testTsvSample(["test-c9", "--static-seed", "--weight-field", "3", "--compatibility-mode",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedPermuteWt3[1..$]);
    testTsvSample(["test-c10", "--static-seed", "--prefer-algorithm-r", "--num", "4",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedPermuteAlgoRNum4[1..$]);

    /* Bernoulli sampling cases. */
    testTsvSample(["test-c11", "--header", "--static-seed", "--print-random", "--prob", ".5",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedBernoulliCompatP50Probs);
    testTsvSample(["test-c12", "--header", "--static-seed", "--prob", ".4",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedBernoulliCompatP40);
    testTsvSample(["test-c13", "--static-seed", "--print-random", "--prob", ".5",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedBernoulliCompatP50Probs[1..$]);
    testTsvSample(["test-c14", "--static-seed", "--prob", ".4",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedBernoulliCompatP40[1..$]);

    /* Bernoulli sampling with probabilities in skip sampling range. */
    testTsvSample(["test-cc1", "-H", "-v", "333", "-p", "0.03",
                   fpath_data3x0, fpath_data3x1, fpath_data1x200, fpath_dataEmpty, fpath_data1x10],
                  combo2ExpectedBernoulliSkipV333P03);
    testTsvSample(["test-cc1", "-v", "333", "-p", "0.03",
                   fpath_data3x1_noheader, fpath_data1x200_noheader, fpath_dataEmpty, fpath_data1x10_noheader],
                  combo2ExpectedBernoulliSkipV333P03[1..$]);

    /* Distinct sampling cases. */
    testTsvSample(["test-c13", "--header", "--static-seed", "--key-fields", "1", "--prob", ".4",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedDistinctK1P40);
    testTsvSample(["test-c14", "--static-seed", "--key-fields", "1", "--prob", ".4",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedDistinctK1P40[1..$]);

    /* Generating random weights. */
    testTsvSample(["test-c15", "--header", "--static-seed", "--gen-random-inorder",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedProbsInorder);
    testTsvSample(["test-c16", "--static-seed", "--gen-random-inorder",
                   fpath_data3x3_noheader, fpath_data3x1_noheader,
                   fpath_dataEmpty, fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedProbsInorder[1..$]);

    /* Simple random sampling with replacement. */
    testTsvSample(["test-c17", "--header", "--static-seed", "--replace", "--num", "10",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedReplaceNum10);

    testTsvSample(["test-c18", "--static-seed", "--replace", "--num", "10",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedReplaceNum10[1..$]);

    /* Single column file. */
    testTsvSample(["test-d1", "-H", "-s", "--compatibility-mode", fpath_data1x10], data1x10ExpectedPermuteCompat);
    testTsvSample(["test-d2", "-H", "-s", "--compatibility-mode", fpath_data1x10], data1x10ExpectedPermuteCompat);

    /* Distributions. */
    testTsvSample(["test-e1", "-H", "-s", "-w", "2", "--print-random", fpath_data2x10a], data2x10aExpectedPermuteWt2Probs);
    testTsvSample(["test-e2", "-H", "-s", "-w", "2", "--print-random", fpath_data2x10b], data2x10bExpectedPermuteWt2Probs);
    testTsvSample(["test-e3", "-H", "-s", "-w", "2", "--print-random", fpath_data2x10c], data2x10cExpectedPermuteWt2Probs);
    testTsvSample(["test-e4", "-H", "-s", "-w", "2", "--print-random", fpath_data2x10d], data2x10dExpectedPermuteWt2Probs);
    testTsvSample(["test-e5", "-H", "-s", "-w", "2", "--print-random", fpath_data2x10e], data2x10eExpectedPermuteWt2Probs);

    /* Tests of subset sample (--n|num) field.
     *
     * Note: The way these tests are done ensures that subset length does not affect
     * output order.
     */
    import std.algorithm : min;
    for (size_t n = data3x6.length + 2; n >= 1; n--)
    {
        /* reservoirSamplingViaHeap.
         */
        size_t expectedLength = min(data3x6.length, n + 1);
        testTsvSample([format("test-f1_%d", n), "-s", "-n", n.to!string,
                       "-H", fpath_data3x6], data3x6ExpectedPermuteCompat[0..expectedLength]);

        testTsvSample([format("test-f2_%d", n), "-s", "-n", n.to!string,
                       "-H", "--compatibility-mode", fpath_data3x6], data3x6ExpectedPermuteCompat[0..expectedLength]);

        testTsvSample([format("test-f3_%d", n), "-s", "-n", n.to!string,
                       "-H", "--print-random", fpath_data3x6], data3x6ExpectedPermuteCompatProbs[0..expectedLength]);

        testTsvSample([format("test-f4_%d", n), "-s", "-n", n.to!string,
                       "-H", "-w", "3", fpath_data3x6], data3x6ExpectedPermuteWt3[0..expectedLength]);

        testTsvSample([format("test-f5_%d", n), "-s", "-n", n.to!string,
                       "-H", "--print-random", "-w", "3", fpath_data3x6], data3x6ExpectedPermuteWt3Probs[0..expectedLength]);

        testTsvSample([format("test-f6_%d", n), "-s", "-n", n.to!string,
                       fpath_data3x6_noheader], data3x6ExpectedPermuteCompat[1..expectedLength]);

        testTsvSample([format("test-f7_%d", n), "-s", "-n", n.to!string,
                       "--print-random", fpath_data3x6_noheader], data3x6ExpectedPermuteCompatProbs[1..expectedLength]);

        testTsvSample([format("test-f8_%d", n), "-s", "-n", n.to!string,
                       "-w", "3", fpath_data3x6_noheader], data3x6ExpectedPermuteWt3[1..expectedLength]);

        testTsvSample([format("test-f9_%d", n), "-s", "-n", n.to!string,
                       "--print-random", "-w", "3", fpath_data3x6_noheader], data3x6ExpectedPermuteWt3Probs[1..expectedLength]);

        /* Bernoulli sampling.
         */
        import std.algorithm : min;
        size_t sampleExpectedLength = min(expectedLength, data3x6ExpectedBernoulliCompatProbsP60.length);

        testTsvSample([format("test-f10_%d", n), "-s", "-p", "0.6", "-n", n.to!string,
                       "-H", "--print-random", fpath_data3x6], data3x6ExpectedBernoulliCompatProbsP60[0..sampleExpectedLength]);

        testTsvSample([format("test-f11_%d", n), "-s", "-p", "0.6", "-n", n.to!string,
                       "-H", fpath_data3x6], data3x6ExpectedBernoulliCompatP60[0..sampleExpectedLength]);

        testTsvSample([format("test-f12_%d", n), "-s", "-p", "0.6", "-n", n.to!string,
                       "--print-random", fpath_data3x6_noheader], data3x6ExpectedBernoulliCompatProbsP60[1..sampleExpectedLength]);

        testTsvSample([format("test-f13_%d", n), "-s", "-p", "0.6", "-n", n.to!string,
                       fpath_data3x6_noheader], data3x6ExpectedBernoulliCompatP60[1..sampleExpectedLength]);

        /* Distinct Sampling.
         */
        size_t distinctExpectedLength = min(expectedLength, data3x6ExpectedDistinctK1K3P60.length);

        testTsvSample([format("test-f14_%d", n), "-s", "-k", "1,3", "-p", "0.6", "-n", n.to!string,
                       "-H", fpath_data3x6], data3x6ExpectedDistinctK1K3P60[0..distinctExpectedLength]);

        testTsvSample([format("test-f15_%d", n), "-s", "-k", "1,3", "-p", "0.6", "-n", n.to!string,
                       fpath_data3x6_noheader], data3x6ExpectedDistinctK1K3P60[1..distinctExpectedLength]);

        testTsvSample([format("test-f16_%d", n), "-s", "--gen-random-inorder", "-n", n.to!string,
                       "-H", fpath_data3x6], data3x6ExpectedBernoulliProbsP100[0..expectedLength]);

        testTsvSample([format("test-f17_%d", n), "-s", "--gen-random-inorder", "-n", n.to!string,
                       fpath_data3x6_noheader], data3x6ExpectedBernoulliProbsP100[1..expectedLength]);
    }

    /* Similar tests with the 1x10 data set. */
    for (size_t n = data1x10.length + 2; n >= 1; n--)
    {
        size_t expectedLength = min(data1x10.length, n + 1);
        testTsvSample([format("test-g1_%d", n), "-s", "-n", n.to!string,
                       "-H", fpath_data1x10], data1x10ExpectedPermuteCompat[0..expectedLength]);

        testTsvSample([format("test-g2_%d", n), "-s", "-n", n.to!string,
                       "-H", "-w", "1", fpath_data1x10], data1x10ExpectedPermuteWt1[0..expectedLength]);

        testTsvSample([format("test-g3_%d", n), "-s", "-n", n.to!string,
                       fpath_data1x10_noheader], data1x10ExpectedPermuteCompat[1..expectedLength]);

        testTsvSample([format("test-g4_%d", n), "-s", "-n", n.to!string,
                       "-w", "1", fpath_data1x10_noheader], data1x10ExpectedPermuteWt1[1..expectedLength]);
    }

    /* Simple random sampling with replacement: ensure sample size doesn't change order. */
    for (size_t n = data3x6ExpectedReplaceNum10.length - 1; n >= 1; n--)
    {
        testTsvSample([format("test-h1_%d", n), "-s", "--replace", "-n", n.to!string, "-H", fpath_data3x6],
                      data3x6ExpectedReplaceNum10[0 .. n + 1]);

        testTsvSample([format("test-h2_%d", n), "-s", "--replace", "-n", n.to!string, fpath_data3x6_noheader],
                      data3x6ExpectedReplaceNum10[1 .. n + 1]);
    }

    /* Bernoulli skip sampling. Test with lengths both greater than and less than expected. */
    for (size_t n = data1x200ExpectedBernoulliSkipV333P03.length + 2; n >= 1; n--)
    {
        size_t expectedLength = min(data1x200ExpectedBernoulliSkipV333P03.length, n + 1);

        testTsvSample([format("test-i1_%d", n), "-v", "333", "-p", "0.03", "-n", n.to!string,
                       "-H", fpath_data1x200], data1x200ExpectedBernoulliSkipV333P03[0..expectedLength]);

        testTsvSample([format("test-i2_%d", n), "-v", "333", "-p", "0.03", "-n", n.to!string,
                       fpath_data1x200_noheader], data1x200ExpectedBernoulliSkipV333P03[1..expectedLength]);
}


    /* Distinct sampling tests. */
    testTsvSample(["test-j1", "--header", "--static-seed", "--prob", "0.40", "--key-fields", "2", fpath_data5x25],
                  data5x25ExpectedDistinctK2P40);

    testTsvSample(["test-j2", "-H", "-s", "-p", "0.20", "-k", "2,4", fpath_data5x25],
                  data5x25ExpectedDistinctK2K4P20);

    testTsvSample(["test-j3", "-H", "-s", "-p", "0.20", "-k", "2-4", fpath_data5x25],
                  data5x25ExpectedDistinctK2K3K4P20);

    testTsvSample(["test-j4", "--static-seed", "--prob", "0.40", "--key-fields", "2", fpath_data5x25_noheader],
                  data5x25ExpectedDistinctK2P40[1..$]);

    testTsvSample(["test-j5", "-s", "-p", "0.20", "-k", "2,4", fpath_data5x25_noheader],
                  data5x25ExpectedDistinctK2K4P20[1..$]);

    testTsvSample(["test-j6", "-s", "-p", "0.20", "-k", "2-4", fpath_data5x25_noheader],
                  data5x25ExpectedDistinctK2K3K4P20[1..$]);
}
