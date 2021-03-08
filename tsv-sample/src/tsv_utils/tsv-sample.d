/**
Command line tool for shuffling or sampling lines from input streams. Several methods
are available, including weighted and unweighted shuffling, simple and weighted random
sampling, sampling with replacement, Bernoulli sampling, and distinct sampling.

Copyright (c) 2017-2021, eBay Inc.
Initially written by Jon Degenhardt

License: Boost License 1.0 (http://boost.org/LICENSE_1_0.txt)
*/
module tsv_utils.tsv_sample;

import std.array : appender, Appender, RefAppender;
import std.exception : enforce;
import std.format : format;
import std.range;
import std.stdio;
import std.typecons : tuple, Flag;

static if (__VERSION__ >= 2085) extern(C) __gshared string[] rt_options = [ "gcopt=cleanup:none" ];

version(unittest)
{
    // When running unit tests, use main from -main compiler switch.
}
else
{
    /** Main program.
     *
     * Invokes command line argument processing and calls tsvSample to do the real
     * work. Errors occurring during processing are caught and reported to the user.
     */
    int main(string[] cmdArgs)
    {
        import tsv_utils.common.utils : BufferedOutputRange, LineBuffered;

        /* When running in DMD code coverage mode, turn on report merging. */
        version(D_Coverage) version(DigitalMars)
        {
            import core.runtime : dmd_coverSetMerge;
            dmd_coverSetMerge(true);
        }

        TsvSampleOptions cmdopt;
        const r = cmdopt.processArgs(cmdArgs);
        if (!r[0]) return r[1];
        version(LDC_Profile)
        {
            import ldc.profile : resetAll;
            resetAll();
        }

        immutable LineBuffered linebuffered = cmdopt.lineBuffered ? Yes.lineBuffered : No.lineBuffered;

        try tsvSample(cmdopt, BufferedOutputRange!(typeof(stdout))(stdout, linebuffered));
        catch (Exception exc)
        {
            stderr.writefln("Error [%s]: %s", cmdopt.programName, exc.msg);
            return 1;
        }
        return 0;
    }
}

immutable helpText = q"EOS
Synopsis: tsv-sample [options] [file...]

Sample input lines or randomize their order. Several modes of operation
are available:
* Shuffling (the default): All input lines are output in random order. All
  orderings are equally likely.
* Random sampling (--n|num N): A random sample of N lines are selected and
  written to standard output. By default, selected lines are written in
  random order. All sample sets and orderings are equally likely. Use
  --i|inorder to write the selected lines in the original input order.
* Weighted random sampling (--n|num N, --w|weight-field F): A weighted
  sample of N lines is produced. Weights are taken from field F. Lines are
  output in weighted selection order. Use --i|inorder to write in original
  input order. Omit --n|num to shuffle all lines (weighted shuffling).
* Sampling with replacement (--r|replace, --n|num N): All input lines are
  read in, then lines are repeatedly selected at random and written out.
  This continues until N lines are output. Individual lines can be written
  multiple times. Output continues forever if N is zero or not provided.
* Bernoulli sampling (--p|prob P): A random subset of lines is selected
  based on probability P, a 0.0-1.0 value. This is a streaming operation.
  A decision is made on each line as it is read. Line order is not changed.
* Distinct sampling (--k|key-fields F, --p|prob P): Input lines are sampled
  based on the values in the key fields. A subset of keys are chosen based
  on the inclusion probability (a 'distinct' set of keys). All lines with
  one of the selected keys are output. Line order is not changed.

Fields are specified using field number or field name. Field names require
that the input file has a header line.

Use '--help-verbose' for detailed information.

Options:
EOS";

immutable helpTextVerbose = q"EOS
Synopsis: tsv-sample [options] [file...]

Sample input lines or randomize their order. Several modes of operation
are available:
* Shuffling (the default): All input lines are output in random order. All
  orderings are equally likely.
* Random sampling (--n|num N): A random sample of N lines are selected and
  written to standard output. By default, selected lines are written in
  random order. All sample sets and orderings are equally likely. Use
  --i|inorder to write the selected lines in the original input order.
* Weighted random sampling (--n|num N, --w|weight-field F): A weighted
  sample of N lines is produced. Weights are taken from field F. Lines are
  output in weighted selection order. Use --i|inorder to write in original
  input order. Omit --n|num to shuffle all lines (weighted shuffling).
* Sampling with replacement (--r|replace, --n|num N): All input lines are
  read in, then lines are repeatedly selected at random and written out.
  This continues until N lines are output. Individual lines can be written
  multiple times. Output continues forever if N is zero or not provided.
* Bernoulli sampling (--p|prob P): A random subset of lines is selected
  based on probability P, a 0.0-1.0 value. This is a streaming operation.
  A decision is made on each line as it is read. Line order is not changed.
* Distinct sampling (--k|key-fields F, --p|prob P): Input lines are sampled
  based on the values in the key fields. A subset of keys are chosen based
  on the inclusion probability (a 'distinct' set of keys). All lines with
  one of the selected keys are output. Line order is not changed.

Fields: Fields are specified by field number or name. Field names require
the input file to have a header line. Use '--help-fields' for details.

Sample size: The '--n|num' option controls the sample size for all
sampling methods. In the case of simple and weighted random sampling it
also limits the amount of memory required.

Controlling the random seed: By default, each run produces a different
randomization or sampling. Using '--s|static-seed' changes this so
multiple runs produce the same results. This works by using the same
random seed each run. The random seed can be specified using
'--v|seed-value'. This takes a non-zero, 32-bit positive integer. (A zero
value is a no-op and ignored.)

Memory use: Bernoulli sampling and distinct sampling make decisions on
each line as it is read, there is no memory accumulation. These algorithms
can run on arbitrary size inputs. Sampling with replacement reads all
lines into memory and is limited by available memory. Shuffling also reads
all lines into memory and is similarly limited. Random sampling uses
reservoir sampling, and only needs to hold the sample size (--n|num) in
memory. The input data can be of any length.

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
'--gen-random-inorder' option takes this one step further, generating
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

/** Container for command line options and derived data.
 *
 * TsvSampleOptions handles several aspects of command line options. On the input side,
 * it defines the command line options available, performs validation, and sets up any
 * derived state based on the options provided. These activities are handled by the
 * processArgs() member.
 *
 * Once argument processing is complete, TsvSampleOptions is used as a container
 * holding the specific processing options used by the different sampling routines.
 */
struct TsvSampleOptions
{
    import tsv_utils.common.utils : InputSourceRange;

    string programName;                        /// Program name
    InputSourceRange inputSources;             /// Input files
    bool hasHeader = false;                    /// --H|header
    ulong sampleSize = 0;                      /// --n|num - Size of the desired sample
    double inclusionProbability = double.nan;  /// --p|prob - Inclusion probability
    size_t[] keyFields;                        /// Derived: --k|key-fields - Used with inclusion probability
    size_t weightField = 0;                    /// Derived: --w|weight-field - Field holding the weight
    bool srsWithReplacement = false;           /// --r|replace
    bool preserveInputOrder = false;           /// --i|inorder
    bool staticSeed = false;                   /// --s|static-seed
    uint seedValueOptionArg = 0;               /// --v|seed-value
    bool printRandom = false;                  /// --print-random
    bool genRandomInorder = false;             /// --gen-random-inorder
    string randomValueHeader = "random_value"; /// --random-value-header
    bool compatibilityMode = false;            /// --compatibility-mode
    char delim = '\t';                         /// --d|delimiter
    bool lineBuffered = false;                 /// --line-buffered
    bool preferSkipSampling = false;           /// --prefer-skip-sampling
    bool preferAlgorithmR = false;             /// --prefer-algorithm-r
    bool hasWeightField = false;               /// Derived.
    bool useBernoulliSampling = false;         /// Derived.
    bool useDistinctSampling = false;          /// Derived.
    bool distinctKeyIsFullLine = false;        /// Derived. True if '--k|key-fields 0' is specfied.
    bool usingUnpredictableSeed = true;        /// Derived from --static-seed, --seed-value
    uint seed = 0;                             /// Derived from --static-seed, --seed-value

    /** Process tsv-sample command line arguments.
     *
     * Defines the command line options, performs validation, and derives additional
     * state. std.getopt.getopt is called to do the main option processing followed
     * additional validation and derivation.
     *
     * Help text is printed to standard output if help was requested. Error text is
     * written to stderr if invalid input is encountered.
     *
     * A tuple is returned. First value is true if command line arguments were
     * successfully processed and execution should continue, or false if an error
     * occurred or the user asked for help. If false, the second value is the
     * appropriate exit code (0 or 1).
     *
     * Returning true (execution continues) means args have been validated and derived
     * values calculated. Field indices will have been converted to zero-based.
     */
    auto processArgs(ref string[] cmdArgs)
    {
        import std.algorithm : all, canFind, each;
        import std.conv : to;
        import std.getopt;
        import std.math : isNaN;
        import std.path : baseName, stripExtension;
        import std.typecons : Yes, No;
        import tsv_utils.common.utils : inputSourceRange, ReadHeader, throwIfWindowsNewline;
        import tsv_utils.common.fieldlist;

        bool helpVerbose = false;                  // --help-verbose
        bool helpFields = false;                   // --help-fields
        bool versionWanted = false;                // --V|version
        string keyFieldsArg;                       // --k|key-fields
        string weightFieldArg;                     // --w|weight-field

        string keyFieldsOptionString = "k|key-fields";
        string weightFieldOptionString = "w|weight-field";

        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

        try
        {
            arraySep = ",";    // Use comma to separate values in command line options
            auto r = getopt(
                cmdArgs,
                "help-verbose",    "     Print more detailed help.", &helpVerbose,
                "help-fields",     "     Print help on specifying fields.", &helpFields,

                std.getopt.config.caseSensitive,
                "H|header",        "     Treat the first line of each file as a header.", &hasHeader,
                std.getopt.config.caseInsensitive,

                "n|num",           "NUM  Maximum number of lines to output. All selected lines are output if not provided or zero.", &sampleSize,
                "p|prob",          "NUM  Inclusion probability (0.0 < NUM <= 1.0). For Bernoulli sampling, the probability each line is selected output. For distinct sampling, the probability each unique key is selected for output.", &inclusionProbability,

                keyFieldsOptionString,
                "<field-list>  Fields to use as key for distinct sampling. Use with '--p|prob'. Specify '--k|key-fields 0' to use the entire line as the key.",
                &keyFieldsArg,

                weightFieldOptionString,
                "NUM  Field containing weights. All lines get equal weight if not provided.",
                &weightFieldArg,

                "r|replace",       "     Simple random sampling with replacement. Use --n|num to specify the sample size.", &srsWithReplacement,
                "i|inorder",       "     Output random samples in original input order. Requires use of --n|num.", &preserveInputOrder,
                "s|static-seed",   "     Use the same random seed every run.", &staticSeed,

                std.getopt.config.caseSensitive,
                "v|seed-value",    "NUM  Sets the random seed. Use a non-zero, 32 bit positive integer. Zero is a no-op.", &seedValueOptionArg,
                std.getopt.config.caseInsensitive,

                "print-random",       "     Include the assigned random value (prepended) when writing output lines.", &printRandom,
                "gen-random-inorder", "     Output all lines with assigned random values prepended, no changes to the order of input.", &genRandomInorder,
                "random-value-header",  "     Header to use with --print-random and --gen-random-inorder. Default: 'random_value'.", &randomValueHeader,
                "compatibility-mode", "     Turns on 'compatibility-mode'. Use --help-verbose for information.", &compatibilityMode,

                "d|delimiter",     "CHR  Field delimiter.", &delim,
                "line-buffered",   "     Immediately output every sampled line. Applies to Bernoulli and distinct sampling. Ignored in modes where all input data must be read before generating output.", &lineBuffered,

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
            else if (helpFields)
            {
                writeln(fieldListHelpText);
                return tuple(false, 0);
            }
            else if (versionWanted)
            {
                import tsv_utils.common.tsvutils_version;
                writeln(tsvutilsVersionNotice("tsv-sample"));
                return tuple(false, 0);
            }

            /* Input files. Remaining command line args are files. */
            string[] filepaths = (cmdArgs.length > 1) ? cmdArgs[1 .. $] : ["-"];
            cmdArgs.length = 1;

            /* Validation and derivations - Do as much validation prior to header line
             * processing as possible (avoids waiting on stdin).
             *
             * Note: keyFields and weightField depend on header line processing, but
             * keyFieldsArg and weightFieldArg can be used to detect whether the
             * command line argument was specified.
             */

            /* Set hasWeightField here so it can be used in other validation checks.
             * Field validity checked after reading file header.
             */
            hasWeightField = !weightFieldArg.empty;

            /* Sampling with replacement checks (--r|replace). */
            if (srsWithReplacement)
            {
                enforce(!hasWeightField,
                        "Sampling with replacement (--r|replace) does not support weights (--w|weight-field).");

                enforce(inclusionProbability.isNaN,
                        "Sampling with replacement (--r|replace) cannot be used with probabilities (--p|prob).");

                enforce(keyFieldsArg.empty,
                        "Sampling with replacement (--r|replace) cannot be used with distinct sampling (--k|key-fields).");

                enforce(!printRandom && !genRandomInorder,
                        "Sampling with replacement (--r|replace) does not support random value printing (--print-random, --gen-random-inorder).");

                enforce(!preserveInputOrder,
                        "Sampling with replacement (--r|replace) does not support input order preservation (--i|inorder option).");
            }

            /* Distinct sampling checks (--k|key-fields --p|prob). */
            enforce(keyFieldsArg.empty | !inclusionProbability.isNaN,
                    "--p|prob is required when using --k|key-fields.");

            /* Inclusion probability (--p|prob) is used for both Bernoulli sampling
             * and distinct sampling.
             */
            if (!inclusionProbability.isNaN)
            {
                enforce(inclusionProbability > 0.0 && inclusionProbability <= 1.0,
                        format("Invalid --p|prob option: %g. Must satisfy 0.0 < prob <= 1.0.", inclusionProbability));

                if (!keyFieldsArg.empty) useDistinctSampling = true;
                else useBernoulliSampling = true;

                enforce(!hasWeightField, "--w|weight-field and --p|prob cannot be used together.");

                enforce(!genRandomInorder || useDistinctSampling,
                        "--gen-random-inorder and --p|prob can only be used together if --k|key-fields is also used." ~
                        "\nUse --gen-random-inorder alone to print probabilities for all lines." ~
                        "\nUse --p|prob and --print-random to print probabilities for lines satisfying the probability threshold.");
            }
            else if (genRandomInorder && !hasWeightField)
            {
                useBernoulliSampling = true;
            }

            /* randomValueHeader (--random-value-header) validity. Note that
               randomValueHeader is initialized to a valid, non-empty string.
            */
            enforce(!randomValueHeader.empty && !randomValueHeader.canFind('\n') &&
                    !randomValueHeader.canFind(delim),
                    "--randomValueHeader must be at least one character and not contain field delimiters or newlines.");

            /* Check for incompatible use of (--i|inorder) and shuffling of the full
             * data set. Sampling with replacement is also incompatible, this is
             * detected earlier. Shuffling is the default operation, so it identified
             * by eliminating the other modes of operation.
             */
            enforce(!preserveInputOrder ||
                    sampleSize != 0 ||
                    useBernoulliSampling ||
                    useDistinctSampling,
                    "Preserving input order (--i|inorder) is not compatible with full data set shuffling. Switch to random sampling with a sample size (--n|num) to use --i|inorder.");

            /* Compatibility mode checks:
             * - Random value printing implies compatibility-mode, otherwise user's
             *   selection is used.
             * - Distinct sampling doesn't support compatibility-mode. The routines
             *   don't care, but users might expect larger probabilities to be a
             *   superset of smaller probabilities. This would be confusing, so
             *   flag it as an error.
             */
            enforce(!(compatibilityMode && useDistinctSampling),
                    "Distinct sampling (--k|key-fields --p|prob) does not support --compatibility-mode.");

            if (printRandom || genRandomInorder) compatibilityMode = true;

            /* Ignore --line-buffered if not using Bernoulli or distinct sampling. */
            if (!useBernoulliSampling && !useDistinctSampling) lineBuffered = false;

            /* Seed. */
            import std.random : unpredictableSeed;

            usingUnpredictableSeed = (!staticSeed && seedValueOptionArg == 0);

            if (usingUnpredictableSeed) seed = unpredictableSeed;
            else if (seedValueOptionArg != 0) seed = seedValueOptionArg;
            else if (staticSeed) seed = 2438424139;
            else assert(0, "Internal error, invalid seed option states.");

            string[] headerFields;

            /* fieldListArgProcessing encapsulates the field list processing. It is
             * called prior to reading the header line if headers are not being used,
             * and after if headers are being used.
             */
            void fieldListArgProcessing()
            {
                if (!weightFieldArg.empty)
                {
                    auto fieldIndices =
                        weightFieldArg
                        .parseFieldList!(size_t, Yes.convertToZeroBasedIndex, No.allowFieldNumZero)
                        (hasHeader, headerFields, weightFieldOptionString)
                        .array;

                    enforce(fieldIndices.length == 1,
                            format("'--%s' must be a single field.", weightFieldOptionString));

                    weightField = fieldIndices[0];
                }

                if (!keyFieldsArg.empty)
                {
                    keyFields =
                        keyFieldsArg
                        .parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero)
                        (hasHeader, headerFields, keyFieldsOptionString)
                        .array;

                    assert(keyFields.length > 0);

                    if (keyFields.length > 0)
                    {
                        if (keyFields.length == 1 && keyFields[0] == 0)
                        {
                            distinctKeyIsFullLine = true;
                        }
                        else
                        {
                            enforce(keyFields.length <= 1 || keyFields.all!(x => x != 0),
                                    "Whole line as key (--k|key-fields 0) cannot be combined with multiple fields.");

                            keyFields.each!((ref x) => --x);  // Convert to zero-based indexing.
                        }
                    }
                }
            }

            if (!hasHeader) fieldListArgProcessing();

            /*
             * Create the inputSourceRange and perform header line processing.
             */
            ReadHeader readHeader = hasHeader ? Yes.readHeader : No.readHeader;
            inputSources = inputSourceRange(filepaths, readHeader);

            if (hasHeader)
            {
                throwIfWindowsNewline(inputSources.front.header, inputSources.front.name, 1);
                headerFields = inputSources.front.header.split(delim).to!(string[]);
                fieldListArgProcessing();
            }

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
 *
 * tsvSample is the top-level routine handling the different tsv-sample use cases.
 * Its primary role is to invoke the correct routine for type of sampling requested.
 */
void tsvSample(OutputRange)(ref TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
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
        /* Note that the preceding cases handle gen-random-inorder themselves (Bernoulli,
         * Distinct), or don't handle it (SRS w/ Replacement).
         */
        assert(cmdopt.hasWeightField);
        generateWeightedRandomValuesInorder(cmdopt, outputStream);
    }
    else if (cmdopt.sampleSize != 0)
    {
        randomSamplingCommand(cmdopt, outputStream);
    }
    else
    {
        shuffleCommand(cmdopt, outputStream);
    }
}

/** Bernoulli sampling command handler. Invokes the appropriate Bernoulli sampling
 * routine based on the command line arguments.
 *
 * This routine selects the appropriate Bernoulli sampling function and template
 * instantiation to use based on the command line arguments.
 *
 * One of the basic choices is whether to use the vanilla algorithm or skip sampling.
 * Skip sampling is a little bit faster when the inclusion probability is small but
 * doesn't support compatibility mode. See the bernoulliSkipSampling documentation
 * for a discussion of the skipSamplingProbabilityThreshold used here.
 */
void bernoulliSamplingCommand(OutputRange)(ref TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
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

/** Bernoulli sampling of lines from the input stream.
 *
 * Each input line is a assigned a random value and output if less than
 * cmdopt.inclusionProbability. The order of the lines is not changed.
 *
 * This routine supports random value printing and gen-random-inorder value printing.
 */
void bernoulliSampling(Flag!"generateRandomAll" generateRandomAll, OutputRange)
    (ref TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.random : Random = Mt19937, uniform01;
    import tsv_utils.common.utils : bufferedByLine, isFlushableOutputRange,
        InputSourceRange, LineBuffered, throwIfWindowsNewline;

    static if (generateRandomAll) assert(cmdopt.genRandomInorder);
    else assert(!cmdopt.genRandomInorder);

    assert(!cmdopt.inputSources.empty);
    static assert(is(typeof(cmdopt.inputSources) == InputSourceRange));

    auto randomGenerator = Random(cmdopt.seed);

    /* First header is read during command line argument processing. */
    if (cmdopt.hasHeader && !cmdopt.inputSources.front.isHeaderEmpty)
    {
        auto inputStream = cmdopt.inputSources.front;

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

        outputStream.put(inputStream.header);
        outputStream.put("\n");

        /* Immediately flush the header so subsequent processes in a unix command
         * pipeline see it early. This helps provide timely error messages.
         */
        static if (isFlushableOutputRange!OutputRange) outputStream.flush;
    }

    /* Process each line. */
    immutable LineBuffered isLineBuffered = cmdopt.lineBuffered ? Yes.lineBuffered : No.lineBuffered;
    immutable size_t fileBodyStartLine = cmdopt.hasHeader ? 2 : 1;
    ulong numLinesWritten = 0;

    foreach (inputStream; cmdopt.inputSources)
    {
        if (cmdopt.hasHeader) throwIfWindowsNewline(inputStream.header, inputStream.name, 1);

        foreach (ulong fileLineNum, line;
                 inputStream
                 .file
                 .bufferedByLine!(KeepTerminator.no)(isLineBuffered)
                 .enumerate(fileBodyStartLine))
        {
            if (fileLineNum == 1) throwIfWindowsNewline(line, inputStream.name, fileLineNum);

            immutable double lineScore = uniform01(randomGenerator);

            static if (generateRandomAll)
            {
                outputStream.formatRandomValue(lineScore);
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
                    outputStream.formatRandomValue(lineScore);
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

/** bernoulliSkipSampling is an implementation of Bernoulli sampling using skips.
 *
 * Skip sampling works by skipping a random number of lines between selections. This
 * can be faster than assigning a random value to each line when the inclusion
 * probability is low, as it reduces the number of calls to the random number
 * generator. Both the random number generator and the log() function are called when
 * calculating the next skip size. These additional log() calls add up as the
 * inclusion probability increases.
 *
 * Performance tests indicate the break-even point is about 4-5% (--prob 0.04) for
 * file-oriented line sampling. This is obviously environment specific. In the
 * environments this implementation has been tested in the performance improvements
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
 * $(LIST
 *     * Jeffrey Scott Vitter, "An Efficient Algorithm for Sequential Random Sampling",
 *       ACM Trans on Mathematical Software, 1987. On-line:
 *       http://www.ittc.ku.edu/~jsv/Papers/Vit87.RandomSampling.pdf
 *     * P.J. Haas, "Data-Stream Sampling: Basic Techniques and Results", from the book
 *       "Data Stream Management", Springer-Verlag, 2016. On-line:
 *       https://www.springer.com/cda/content/document/cda_downloaddocument/9783540286073-c2.pdf
 *     * Erik Erlandson, "Faster Random Samples With Gap Sampling", 2014. On-line:
 *       http://erikerlandson.github.io/blog/2014/09/11/faster-random-samples-with-gap-sampling/
 * )
 */
void bernoulliSkipSampling(OutputRange)(ref TsvSampleOptions cmdopt, OutputRange outputStream)
    if (isOutputRange!(OutputRange, char))
{
    import std.conv : to;
    import std.math : log, trunc;
    import std.random : Random = Mt19937, uniform01;
    import tsv_utils.common.utils : bufferedByLine, isFlushableOutputRange,
        InputSourceRange, LineBuffered, throwIfWindowsNewline;

    assert(cmdopt.inclusionProbability > 0.0 && cmdopt.inclusionProbability < 1.0);
    assert(!cmdopt.printRandom);
    assert(!cmdopt.compatibilityMode);

    assert(!cmdopt.inputSources.empty);
    static assert(is(typeof(cmdopt.inputSources) == InputSourceRange));

    auto randomGenerator = Random(cmdopt.seed);

    immutable double discardRate = 1.0 - cmdopt.inclusionProbability;
    immutable double logDiscardRate = log(discardRate);

    /* Note: The '1.0 - uniform01(randomGenerator)' expression flips the half closed
     * interval to (0.0, 1.0], excluding 0.0.
     */
    size_t remainingSkips = (log(1.0 - uniform01(randomGenerator)) / logDiscardRate).trunc.to!size_t;

    /* First header is read during command line argument processing. */
    if (cmdopt.hasHeader && !cmdopt.inputSources.front.isHeaderEmpty)
    {
        auto inputStream = cmdopt.inputSources.front;

        outputStream.put(inputStream.header);
        outputStream.put("\n");

        /* Immediately flush the header so subsequent processes in a unix command
         * pipeline see it early. This helps provide timely error messages.
         */
        static if (isFlushableOutputRange!OutputRange) outputStream.flush;
    }

    /* Process each line. */
    immutable LineBuffered isLineBuffered = cmdopt.lineBuffered ? Yes.lineBuffered : No.lineBuffered;
    immutable size_t fileBodyStartLine = cmdopt.hasHeader ? 2 : 1;
    ulong numLinesWritten = 0;
    foreach (inputStream; cmdopt.inputSources)
    {
        if (cmdopt.hasHeader) throwIfWindowsNewline(inputStream.header, inputStream.name, 1);

        foreach (ulong fileLineNum, line;
                 inputStream
                 .file
                 .bufferedByLine!(KeepTerminator.no)(isLineBuffered)
                 .enumerate(fileBodyStartLine))
        {
            if (fileLineNum == 1) throwIfWindowsNewline(line, inputStream.name, fileLineNum);

            if (remainingSkips > 0)
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

/** Sample lines by choosing a random set of distinct keys formed from one or more
 * fields on each line.
 *
 * Distinct sampling is a streaming form of sampling, similar to Bernoulli sampling.
 * However, instead of each line being subject to an independent trial, lines are
 * selected based on a key from each line. A portion of keys are randomly selected for
 * output, and every line containing a selected key is included in the output.
 *
 * An example use-case is a query log having <user, query, clicked-url> triples. It is
 * often useful to sample records for portion of the users, but including all records
 * for the users selected. Distinct sampling supports this by selecting a subset of
 * users to include in the output.
 *
 * Distinct sampling is done by hashing the key and mapping the hash value into
 * buckets sized to hold the inclusion probability. Records having a key mapping to
 * bucket zero are output. Buckets are equal size and therefore may be larger than the
 * inclusion probability. (The other approach would be to have the caller specify the
 * the number of buckets. More correct, but less convenient.)
 */
void distinctSampling(Flag!"generateRandomAll" generateRandomAll, OutputRange)
    (ref TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.algorithm : splitter;
    import std.conv : to;
    import std.digest.murmurhash;
    import std.math : lrint;
    import tsv_utils.common.utils : bufferedByLine, isFlushableOutputRange,
        InputFieldReordering, InputSourceRange, LineBuffered, throwIfWindowsNewline;

    static if (generateRandomAll) assert(cmdopt.genRandomInorder);
    else assert(!cmdopt.genRandomInorder);

    assert(cmdopt.keyFields.length > 0);
    assert(0.0 < cmdopt.inclusionProbability && cmdopt.inclusionProbability <= 1.0);

    assert(!cmdopt.inputSources.empty);
    static assert(is(typeof(cmdopt.inputSources) == InputSourceRange));

    static if (generateRandomAll)
    {
        import std.format : formatValue, singleSpec;
        immutable randomValueFormatSpec = singleSpec("%d");
    }

    immutable ubyte[1] delimArray = [cmdopt.delim]; // For assembling multi-field hash keys.

    uint numBuckets = (1.0 / cmdopt.inclusionProbability).lrint.to!uint;

    /* Create a mapping for the key fields. */
    auto keyFieldsReordering = cmdopt.distinctKeyIsFullLine ? null : new InputFieldReordering!char(cmdopt.keyFields);

    /* First header is read during command line argument processing. */
    if (cmdopt.hasHeader && !cmdopt.inputSources.front.isHeaderEmpty)
    {
        auto inputStream = cmdopt.inputSources.front;

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

        outputStream.put(inputStream.header);
        outputStream.put("\n");

        /* Immediately flush the header so subsequent processes in a unix command
         * pipeline see it early. This helps provide timely error messages.
         */
        static if (isFlushableOutputRange!OutputRange) outputStream.flush;
    }

    /* Process each line. */
    immutable LineBuffered isLineBuffered = cmdopt.lineBuffered ? Yes.lineBuffered : No.lineBuffered;
    immutable size_t fileBodyStartLine = cmdopt.hasHeader ? 2 : 1;
    ulong numLinesWritten = 0;

    foreach (inputStream; cmdopt.inputSources)
    {
        if (cmdopt.hasHeader) throwIfWindowsNewline(inputStream.header, inputStream.name, 1);

        foreach (ulong fileLineNum, line;
                 inputStream
                 .file
                 .bufferedByLine!(KeepTerminator.no)(isLineBuffered)
                 .enumerate(fileBodyStartLine))
        {
            if (fileLineNum == 1) throwIfWindowsNewline(line, inputStream.name, fileLineNum);

            /* Murmurhash works by successively adding individual keys, then finalizing.
             * Adding individual keys is simpler if the full-line-as-key and individual
             * fields as keys cases are separated.
             */
            auto hasher = MurmurHash3!32(cmdopt.seed);

            if (cmdopt.distinctKeyIsFullLine)
            {
                hasher.put(cast(ubyte[]) line);
            }
            else
            {
                assert(keyFieldsReordering !is null);

                /* Gather the key field values and assemble the key. */
                keyFieldsReordering.initNewLine;
                foreach (fieldIndex, fieldValue; line.splitter(cmdopt.delim).enumerate)
                {
                    keyFieldsReordering.processNextField(fieldIndex, fieldValue);
                    if (keyFieldsReordering.allFieldsFilled) break;
                }

                enforce(keyFieldsReordering.allFieldsFilled,
                        format("Not enough fields in line. File: %s, Line: %s",
                               inputStream.name, fileLineNum));

                foreach (count, key; keyFieldsReordering.outputFields.enumerate)
                {
                    if (count > 0) hasher.put(delimArray);
                    hasher.put(cast(ubyte[]) key);
                }
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

/** Random sampling command handler. Invokes the appropriate sampling routine based on
 * the command line arguments.
 *
 * Random sampling selects a fixed size random sample from the input stream. Both
 * simple random sampling (equal likelihood) and weighted random sampling are
 * supported. Selected lines are output either in random order or original input order.
 * For weighted sampling the random order is the weighted selection order.
 *
 * Two algorithms are used, reservoir sampling via a heap and reservoir sampling via
 * Algorithm R. This routine selects the appropriate reservoir sampling function and
 * template instantiation to based on the command line arguments.
 *
 * Weighted sampling always uses the heap approach. Compatibility mode does as well,
 * as it is the method that uses per-line random value assignments. The implication
 * of compatibility mode is that a larger sample size includes all the results from
 * a smaller sample, assuming the same random seed is used.
 *
 * For unweighted sampling there is a performance tradeoff between implementations.
 * Heap-based sampling is faster for small sample sizes. Algorithm R is faster for
 * large sample sizes. The threshold used was chosen based on performance tests. See
 * the reservoirSamplingAlgorithmR documentation for more information.
 */

void randomSamplingCommand(OutputRange)(ref TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    assert(cmdopt.sampleSize != 0);

    immutable size_t algorithmRSampleSizeThreshold = 128 * 1024;

    if (cmdopt.hasWeightField)
    {
        if (cmdopt.preserveInputOrder)
        {
            reservoirSamplingViaHeap!(Yes.isWeighted, Yes.preserveInputOrder)(cmdopt, outputStream);
        }
        else
        {
            reservoirSamplingViaHeap!(Yes.isWeighted, No.preserveInputOrder)(cmdopt, outputStream);
        }
    }
    else if (cmdopt.compatibilityMode ||
             (cmdopt.sampleSize < algorithmRSampleSizeThreshold && !cmdopt.preferAlgorithmR))
    {
        if (cmdopt.preserveInputOrder)
        {
            reservoirSamplingViaHeap!(No.isWeighted, Yes.preserveInputOrder)(cmdopt, outputStream);
        }
        else
        {
            reservoirSamplingViaHeap!(No.isWeighted, No.preserveInputOrder)(cmdopt, outputStream);
        }
    }
    else if (cmdopt.preserveInputOrder)
    {
        reservoirSamplingAlgorithmR!(Yes.preserveInputOrder)(cmdopt, outputStream);
    }
    else
    {
        reservoirSamplingAlgorithmR!(No.preserveInputOrder)(cmdopt, outputStream);
    }
}

/** Reservoir sampling using a heap. Both weighted and unweighted random sampling are
 * supported.
 *
 * The algorithm used here is based on the one-pass algorithm described by Pavlos
 * Efraimidis and Paul Spirakis ("Weighted Random Sampling over Data Streams", Pavlos S.
 * Efraimidis, https://arxiv.org/abs/1012.0256). In the unweighted case weights are
 * simply set to one.
 *
 * The implementation uses a heap (priority queue) large enough to hold the desired
 * number of lines. Input is read line-by-line, assigned a random value, and added to
 * the heap. The role of the heap is to identify the lines with the highest assigned
 * random values. Once the heap is full, adding a new line means dropping the line with
 * the lowest score. A "min" heap used for this reason.
 *
 * When done reading all lines, the "min" heap is in reverse of weighted selection
 * order. Weighted selection order is obtained by removing each element one at at time
 * from the heap. The underlying data store will have the elements in weighted selection
 * order (largest weights first).
 *
 * Generating output in weighted order is useful for several reasons:
 *  - For weighted sampling, it preserves the property that smaller valid subsets can be
 *    created by taking the first N lines.
 *  - For unweighted sampling, it ensures that all output permutations are possible, and
 *    are not influenced by input order or the heap data structure used.
 *  - Order consistency is maintained when making repeated use of the same random seed,
 *    but with different sample sizes.
 *
 * The other choice is preserving input order. This is supporting by recording line
 * numbers and sorting the selected sample.
 *
 * There are use cases where only the selection set matters. For these some performance
 * could be gained by skipping the reordering and simply printing the backing store
 * array in-order. Performance tests indicate only a minor benefit, so this is not
 * supported.
 *
 * Notes:
 * $(LIST
 *    * In tsv-sample versions 1.2.1 and earlier this routine also supported
 *      randomization of all input lines. This was dropped in version 1.2.2 in favor
 *      of the approach used in randomizeLines. The latter has significant advantages
 *      given that all data must be read into memory.
 *    * For large reservoir sizes better performance can be achieved using Algorithm R.
 *      See the reservoirSamplingAlgorithmR documentation for details.
 * )
 */
void reservoirSamplingViaHeap(Flag!"isWeighted" isWeighted, Flag!"preserveInputOrder" preserveInputOrder, OutputRange)
    (ref TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.algorithm : sort;
    import std.container.array;
    import std.container.binaryheap;
    import std.meta : AliasSeq;
    import std.random : Random = Mt19937, uniform01;
    import tsv_utils.common.utils : bufferedByLine, isFlushableOutputRange,
        InputSourceRange, throwIfWindowsNewline;

    static if (isWeighted) assert(cmdopt.hasWeightField);
    else assert(!cmdopt.hasWeightField);

    assert(cmdopt.sampleSize > 0);

    assert(!cmdopt.inputSources.empty);
    static assert(is(typeof(cmdopt.inputSources) == InputSourceRange));

    auto randomGenerator = Random(cmdopt.seed);

    static struct Entry(Flag!"preserveInputOrder" preserveInputOrder)
    {
        double score;
        const(char)[] line;
        static if (preserveInputOrder) ulong lineNumber;
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

    Array!(Entry!preserveInputOrder) dataStore;
    dataStore.reserve(cmdopt.sampleSize);
    auto reservoir = dataStore.heapify!("a.score > b.score")(0);  // Min binaryheap

    /* First header is read during command line argument processing. */
    if (cmdopt.hasHeader && !cmdopt.inputSources.front.isHeaderEmpty)
    {
        auto inputStream = cmdopt.inputSources.front;

        if (cmdopt.printRandom)
        {
            outputStream.put(cmdopt.randomValueHeader);
            outputStream.put(cmdopt.delim);
        }
        outputStream.put(inputStream.header);
        outputStream.put("\n");

        /* Immediately flush the header so subsequent processes in a unix command
         * pipeline see it early. This helps provide timely error messages.
         */
        static if (isFlushableOutputRange!OutputRange) outputStream.flush;
    }

    /* Process each line. */
    immutable size_t fileBodyStartLine = cmdopt.hasHeader ? 2 : 1;
    static if (preserveInputOrder) ulong totalLineNum = 0;

    foreach (inputStream; cmdopt.inputSources)
    {
        if (cmdopt.hasHeader) throwIfWindowsNewline(inputStream.header, inputStream.name, 1);

        foreach (ulong fileLineNum, line;
                 inputStream.file.bufferedByLine!(KeepTerminator.no).enumerate(fileBodyStartLine))
        {
            if (fileLineNum == 1) throwIfWindowsNewline(line, inputStream.name, fileLineNum);

            static if (!isWeighted)
            {
                immutable double lineScore = uniform01(randomGenerator);
            }
            else
            {
                immutable double lineWeight =
                    getFieldValue!double(line, cmdopt.weightField, cmdopt.delim, inputStream.name, fileLineNum);
                immutable double lineScore =
                    (lineWeight > 0.0)
                    ? uniform01(randomGenerator) ^^ (1.0 / lineWeight)
                    : 0.0;
            }

            static if (preserveInputOrder) alias entryCTArgs = AliasSeq!(totalLineNum);
            else alias entryCTArgs = AliasSeq!();

            if (reservoir.length < cmdopt.sampleSize)
            {
                reservoir.insert(Entry!preserveInputOrder(lineScore, line.dup, entryCTArgs));
            }
            else if (reservoir.front.score < lineScore)
            {
                reservoir.replaceFront(Entry!preserveInputOrder(lineScore, line.dup, entryCTArgs));
            }

            static if (preserveInputOrder) ++totalLineNum;
        }
    }

    /* Done with input, all entries are in the reservoir. */

    /* The asserts here avoid issues with the current binaryheap implementation. They
     * detect use of backing stores having a length not synchronized to the reservoir.
     */
    immutable ulong numLines = reservoir.length;
    assert(numLines == dataStore.length);

    /* Update the backing store so it is in the desired output order.
     */
    static if (preserveInputOrder)
    {
        dataStore[].sort!((a, b) => a.lineNumber < b.lineNumber);
    }
    else
    {
        /* Output in weighted selection order. The heap is in reverse order of assigned
         * weights. Reversing order is done by removing all elements from the heap. This
         * leaves the backing store in the correct order.
         */
        while (!reservoir.empty) reservoir.removeFront;
    }

    assert(numLines == dataStore.length);

    foreach (entry; dataStore)
    {
        if (cmdopt.printRandom)
        {
            outputStream.formatRandomValue(entry.score);
            outputStream.put(cmdopt.delim);
        }
        outputStream.put(entry.line);
        outputStream.put("\n");
    }
 }

/** Generate weighted random values for all input lines, preserving input order.
 *
 * This complements weighted reservoir sampling, but instead of using a reservoir it
 * simply iterates over the input lines generating the values. The weighted random
 * values are generated with the same formula used by reservoirSampling.
 */
void generateWeightedRandomValuesInorder(OutputRange)
    (ref TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.random : Random = Mt19937, uniform01;
    import tsv_utils.common.utils : bufferedByLine, isFlushableOutputRange,
        InputSourceRange, throwIfWindowsNewline;

    assert(cmdopt.hasWeightField);

    assert(!cmdopt.inputSources.empty);
    static assert(is(typeof(cmdopt.inputSources) == InputSourceRange));

    auto randomGenerator = Random(cmdopt.seed);

    /* First header is read during command line argument processing. */
    if (cmdopt.hasHeader && !cmdopt.inputSources.front.isHeaderEmpty)
    {
        auto inputStream = cmdopt.inputSources.front;

        outputStream.put(cmdopt.randomValueHeader);
        outputStream.put(cmdopt.delim);
        outputStream.put(inputStream.header);
        outputStream.put("\n");

        /* Immediately flush the header so subsequent processes in a unix command
         * pipeline see it early. This helps provide timely error messages.
         */
        static if (isFlushableOutputRange!OutputRange) outputStream.flush;
    }

    /* Process each line. */
    immutable size_t fileBodyStartLine = cmdopt.hasHeader ? 2 : 1;
    ulong numLinesWritten = 0;

    foreach (inputStream; cmdopt.inputSources)
    {
        if (cmdopt.hasHeader) throwIfWindowsNewline(inputStream.header, inputStream.name, 1);

        foreach (ulong fileLineNum, line;
                 inputStream.file.bufferedByLine!(KeepTerminator.no).enumerate(fileBodyStartLine))
        {
            if (fileLineNum == 1) throwIfWindowsNewline(line, inputStream.name, fileLineNum);

            immutable double lineWeight =
                getFieldValue!double(line, cmdopt.weightField, cmdopt.delim, inputStream.name, fileLineNum);

            immutable double lineScore =
                (lineWeight > 0.0)
                ? uniform01(randomGenerator) ^^ (1.0 / lineWeight)
                : 0.0;

            outputStream.formatRandomValue(lineScore);
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

/** Reservoir sampling via Algorithm R
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
 * lines. This is consistent with shuffling (line order randomization), a primary
 * tsv-sample use-case.
 *
 * This algorithm is faster than reservoirSamplingViaHeap when the sample size
 * (reservoir size) is large. Heap insertion is O(log k), where k is the sample size.
 * Insertion in this algorithm is O(1). Similarly, generating the random order in the
 * heap is O(k * log k), while in this algorithm the final randomization step is O(k).
 *
 * This speed advantage may be offset a certain amount by using a more expensive random
 * value generator. reservoirSamplingViaHeap generates values between zero and one,
 * whereas reservoirSamplingAlgorithmR generates random integers over and ever growing
 * interval. The latter is expected to be more expensive. This is consistent with
 * performance tests indicating that reservoirSamplingViaHeap is faster when using
 * small-to-medium size reservoirs and large input streams.
 */
void reservoirSamplingAlgorithmR(Flag!"preserveInputOrder" preserveInputOrder, OutputRange)
    (ref TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.meta : AliasSeq;
    import std.random : Random = Mt19937, randomShuffle, uniform;
    import std.algorithm : sort;
    import tsv_utils.common.utils : bufferedByLine, isFlushableOutputRange,
        InputSourceRange, throwIfWindowsNewline;

    assert(cmdopt.sampleSize > 0);
    assert(!cmdopt.hasWeightField);
    assert(!cmdopt.compatibilityMode);
    assert(!cmdopt.printRandom);
    assert(!cmdopt.genRandomInorder);

    assert(!cmdopt.inputSources.empty);
    static assert(is(typeof(cmdopt.inputSources) == InputSourceRange));

    static struct Entry(Flag!"preserveInputOrder" preserveInputOrder)
    {
        const(char)[] line;
        static if (preserveInputOrder) ulong lineNumber;
    }

    Entry!preserveInputOrder[] reservoir;
    auto reservoirAppender = appender(&reservoir);
    reservoirAppender.reserve(cmdopt.sampleSize);

    auto randomGenerator = Random(cmdopt.seed);

    /* First header is read during command line argument processing. */
    if (cmdopt.hasHeader && !cmdopt.inputSources.front.isHeaderEmpty)
    {
        auto inputStream = cmdopt.inputSources.front;

        outputStream.put(inputStream.header);
        outputStream.put("\n");

        /* Immediately flush the header so subsequent processes in a unix command
         * pipeline see it early. This helps provide timely error messages.
         */
        static if (isFlushableOutputRange!OutputRange) outputStream.flush;
    }

    /* Process each line. */
    immutable size_t fileBodyStartLine = cmdopt.hasHeader ? 2 : 1;
    ulong totalLineNum = 0;

    foreach (inputStream; cmdopt.inputSources)
    {
        if (cmdopt.hasHeader) throwIfWindowsNewline(inputStream.header, inputStream.name, 1);

        foreach (ulong fileLineNum, line;
                 inputStream.file.bufferedByLine!(KeepTerminator.no).enumerate(fileBodyStartLine))
        {
            if (fileLineNum == 1) throwIfWindowsNewline(line, inputStream.name, fileLineNum);

            /* Add lines to the reservoir until the reservoir is filled.
             * After that lines are added with decreasing likelihood, based on
             * the total number of lines seen. If added to the reservoir, the
             * line replaces a randomly chosen existing line.
             */
            static if (preserveInputOrder) alias entryCTArgs = AliasSeq!(totalLineNum);
            else alias entryCTArgs = AliasSeq!();

            if (totalLineNum < cmdopt.sampleSize)
            {
                reservoirAppender ~= Entry!preserveInputOrder(line.idup, entryCTArgs);
            }
            else
            {
                immutable size_t i = uniform(0, totalLineNum, randomGenerator);
                if (i < reservoir.length)
                {
                    reservoir[i] = Entry!preserveInputOrder(line.idup, entryCTArgs);
                }
            }

            ++totalLineNum;
        }
    }

    /* Done with input. The sample is in the reservoir. Update the order and print. */

    static if (preserveInputOrder)
    {
        reservoir.sort!((a, b) => a.lineNumber < b.lineNumber);
    }
    else
    {
        reservoir.randomShuffle(randomGenerator);
    }

    foreach (ref entry; reservoir)
    {
        outputStream.put(entry.line);
        outputStream.put("\n");
    }
}

/** Shuffling command handler. Invokes the appropriate shuffle (line order
 * randomization) routine based on the command line arguments.
 *
 * Shuffling has similarities to random sampling, but the algorithms used are
 * different. Random sampling selects a subset, only the current subset selection
 * needs to be kept in memory. This is supported by reservoir sampling. By contrast,
 * shuffling needs to hold all input in memory, so it works better to read all lines
 * into memory at once and then shuffle.
 *
 * Two different algorithms are used. Array shuffling is used for unweighted shuffling.
 * Sorting plus random weight assignments is used for weighted shuffling and when
 * compatibility mode is being used.
 *
 * The algorithms used here are all limited by available memory.
 */
void shuffleCommand(OutputRange)(ref TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
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

/** Shuffle all input lines by assigning random weights and sorting.
 *
 * randomizeLinesViaSort reads in all input lines and writes them out in random order.
 * The algorithm works by assigning a random value to each line and sorting. Both
 * weighted and unweighted shuffling are supported.
 *
 * Notes:
 * $(LIST
 *   * For unweighted shuffling randomizeLinesViaShuffle is faster and should be used
 *     unless compatibility mode is needed.
 *   * This routine is significantly faster than heap-based reservoir sampling in the
 *     case where the entire file is being read.
 *   * Input data must be read entirely in memory. Disk oriented techniques are needed
 *     when data sizes get too large for available memory. One option is to generate
 *     random values for each line, e.g. --gen-random-inorder, and sort with a disk-
 *     backed sort program like GNU sort.
 * )
 */
void randomizeLinesViaSort(Flag!"isWeighted" isWeighted, OutputRange)
    (ref TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.algorithm : map, sort;

    static if (isWeighted) assert(cmdopt.hasWeightField);
    else assert(!cmdopt.hasWeightField);

    assert(cmdopt.sampleSize == 0);

    /*
     * Read all file data into memory. Then split the data into lines and assign a
     * random value to each line. readFileData also writes the first header line.
     */
    const fileData = readFileData!(Yes.hasRandomValue)(cmdopt, outputStream);
    auto inputLines = fileData.identifyInputLines!(Yes.hasRandomValue, isWeighted)(cmdopt);

    /*
     * Sort by the weight and output the lines.
     */
    inputLines.sort!((a, b) => a.randomValue > b.randomValue);

    foreach (lineEntry; inputLines)
    {
        if (cmdopt.printRandom)
        {
            outputStream.formatRandomValue(lineEntry.randomValue);
            outputStream.put(cmdopt.delim);
        }
        outputStream.put(lineEntry.data);
        outputStream.put("\n");
    }
}

/** Shuffle (randomize) all input lines using a shuffling algorithm.
 *
 * All lines in files and/or standard input are read in and written out in random
 * order. This routine uses array shuffling, which is faster than sorting. It is a
 * good alternative to randomizeLinesViaSort when doing unweighted shuffling (the
 * most common case).
 *
 * Input data size is limited by available memory. Disk oriented techniques are needed
 * when data sizes are larger. For example, generating random values line-by-line (ala
 * --gen-random-inorder) and sorting with a disk-backed sort program like GNU sort.
 *
 * This routine does not support random value printing or compatibility-mode.
 */
void randomizeLinesViaShuffle(OutputRange)(ref TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
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
    const fileData = readFileData!(No.hasRandomValue)(cmdopt, outputStream);
    auto inputLines = fileData.identifyInputLines!(No.hasRandomValue, No.isWeighted)(cmdopt);

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
void simpleRandomSamplingWithReplacement(OutputRange)
    (ref TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.algorithm : map;
    import std.random : Random = Mt19937, uniform;

    /*
     * Read all file data into memory and split the data into lines.
     */
    const fileData = readFileData!(No.hasRandomValue)(cmdopt, outputStream);
    const inputLines = fileData.identifyInputLines!(No.hasRandomValue, No.isWeighted)(cmdopt);

    if (inputLines.length > 0)
    {
        auto randomGenerator = Random(cmdopt.seed);

        /* Repeat forever is sampleSize is zero, otherwise print sampleSize lines. */
        size_t numLeft = (cmdopt.sampleSize == 0) ? 1 : cmdopt.sampleSize;
        while (numLeft != 0)
        {
            immutable size_t index = uniform(0, inputLines.length, randomGenerator);
            outputStream.put(inputLines[index].data);
            outputStream.put("\n");
            if (cmdopt.sampleSize != 0) numLeft--;
        }
    }
}

/** A container holding data read from a file or standard input.
 *
 * The InputBlock struct is used to represent a block of data read from a file or
 * standard input. An array of InputBlocks is returned by readFileData. Typically one
 * block per file. Multiple blocks are used for standard input and when the file size
 * cannot be determined. Individual lines are not allowed to span blocks. The blocks
 * allocated to an individual file are numbered starting with zero.
 *
 * See readFileData() for more information.
 */
static struct InputBlock
{
    string filename;          /// Original filename or path. "-" denotes standard input.
    size_t fileBlockNumber;   /// Zero-based block number for the file.
    char[] data;              /// The actual data. Newline terminated or last block for the file.
}

/** Read data from one or more files. This routine is used by algorithms needing to
 * read all data into memory.
 *
 * readFileData reads in all data from a set of files. Data is returned as an array
 * of InputBlock structs. Normally one InputBlock per file, sized to match the size
 * of the file. Standard input is read in one or more blocks, as are files whose size
 * cannot be determined. Multiple blocks are used in these last two cases to avoid
 * expensive memory reallocations. This is not necessary when file size is known as
 * the necessary memory can be preallocated.
 *
 * Individual lines never span multiple blocks, and newlines are preserved. This
 * means that each block starts at the beginning of a line and ends with a newline
 * unless the end of a file has been reached.
 *
 * Each file gets its own block. Prior to using InputSourceRange this was so header
 * processing can be done. With InputSourceRange the header is read separately, so
 * this could be changed.
 */
InputBlock[] readFileData(HasRandomValue hasRandomValue, OutputRange)
(ref TsvSampleOptions cmdopt, auto ref OutputRange outputStream)
if (isOutputRange!(OutputRange, char))
{
    import std.algorithm : find, min;
    import std.range : retro;
    import tsv_utils.common.utils : InputSourceRange, isFlushableOutputRange,
        throwIfWindowsNewline;

    static if(!hasRandomValue) assert(!cmdopt.printRandom);

    assert(!cmdopt.inputSources.empty);
    static assert(is(typeof(cmdopt.inputSources) == InputSourceRange));

    /* First header is read during command line argument processing. */
    if (cmdopt.hasHeader && !cmdopt.inputSources.front.isHeaderEmpty)
    {
        auto inputStream = cmdopt.inputSources.front;

        if (cmdopt.printRandom)
        {
            outputStream.put(cmdopt.randomValueHeader);
            outputStream.put(cmdopt.delim);
        }
        outputStream.put(inputStream.header);
        outputStream.put("\n");

        /* Immediately flush the header so subsequent processes in a unix command
         * pipeline see it early. This helps provide timely error messages.
         */
        static if (isFlushableOutputRange!OutputRange) outputStream.flush;
    }

    enum BlockSize = 1024L * 1024L * 1024L;  // 1 GB. ('L' notation avoids overflow w/ 2GB+ sizes.)
    enum ReadSize = 1024L * 128L;
    enum NewlineSearchSize = 1024L * 16L;

    InputBlock[] blocks;
    auto blocksAppender = appender(&blocks);
    blocksAppender.reserve(cmdopt.inputSources.length);  // At least one block per file.

    ubyte[] rawReadBuffer = new ubyte[ReadSize];

    foreach (inputStream; cmdopt.inputSources)
    {
        if (cmdopt.hasHeader) throwIfWindowsNewline(inputStream.header, inputStream.name, 1);

        /* If the file size can be determined then read it as a single block.
         * Otherwise read as multiple blocks. File.size() returns ulong.max
         * if file size cannot be determined, so we'll combine that check
         * with the standard input case.
         */

        immutable ulong filesize = inputStream.isStdin ? ulong.max : inputStream.file.size;
        auto ifile = inputStream.file;

        if (filesize != ulong.max)
        {
            readFileDataAsOneBlock(inputStream.name, ifile, filesize,
                                   blocksAppender, rawReadBuffer);
        }
        else
        {
            readFileDataAsMultipleBlocks(
                inputStream.name, ifile, blocksAppender, rawReadBuffer,
                BlockSize, NewlineSearchSize);
        }
    }
    return blocks;
}

/* readFileData() helper function. Read data from a File handle as a single block. The
 * new block is appended to an existing InputBlock[] array.
 *
 * readFileDataAsOneBlocks is part of the readFileData logic. It handles the case
 * where a file is being read as a single block. Normally initialBlockSize is passed
 * as the size of the file.
 *
 * This routine has been separated out to enable unit testing. At present it is not
 * intended as a general API. See readFileData for more info.
 */
private void readFileDataAsOneBlock(
    string filename,
    ref File ifile,
    const ulong initialBlockSize,
    ref RefAppender!(InputBlock[]) blocksAppender,
    ref ubyte[] rawReadBuffer)
{
    blocksAppender.put(InputBlock(filename, 0));
    auto dataAppender = appender(&(blocksAppender.data[$-1].data));
    dataAppender.reserve(initialBlockSize);

    foreach (ref ubyte[] buffer; ifile.byChunk(rawReadBuffer))
    {
        dataAppender.put(cast(char[]) buffer);
    }
}

/* readFileData() helper function. Read data from a File handle as one or more blocks.
 * Blocks are appended to an existing InputBlock[] array.
 *
 * readFileDataAsMultipleBlocks is part of the readFileData logic. It handles the case
 * where a file or standard input is being read as a series of blocks. This is the
 * standard approach for standard input, but also applies when the file size cannot be
 * determined.
 *
 * This routine has been separated out to enable unit testing. At present it is not
 * intended as a general API. See readFileData for more info.
 */
private void readFileDataAsMultipleBlocks(
    string filename,
    ref File ifile,
    ref RefAppender!(InputBlock[]) blocksAppender,
    ref ubyte[] rawReadBuffer,
    const size_t blockSize,
    const size_t newlineSearchSize)
{
    import std.algorithm : find, min;
    import std.range : retro;

    assert(ifile.isOpen);

    /* Create a new block for the file and an Appender for writing data.
     */
    blocksAppender.put(InputBlock(filename, 0));
    auto dataAppender = appender(&(blocksAppender.data[$-1].data));
    dataAppender.reserve(blockSize);
    size_t blockNumber = 0;

    /* Read all the data and copy it to an InputBlock. */
    foreach (ref ubyte[] buffer; ifile.byChunk(rawReadBuffer))
    {
        assert(blockNumber == blocksAppender.data[$-1].fileBlockNumber);

        immutable size_t remainingCapacity = dataAppender.capacity - dataAppender.data.length;

        if (buffer.length <= remainingCapacity)
        {
            dataAppender.put(cast(char[]) buffer);
        }
        else
        {
            /* Look for the last newline in the input buffer that fits in remaining
             * capacity of the block.
             */
            auto searchRegion = buffer[0 .. remainingCapacity];
            auto appendRegion = searchRegion.retro.find('\n').source;

            if (appendRegion.length > 0)
            {
                /* Copy the first part of the read buffer to the block. */
                dataAppender.put(cast(char[]) appendRegion);

                /* Create a new InputBlock and copy the remaining data to it. */
                blockNumber++;
                blocksAppender.put(InputBlock(filename, blockNumber));
                dataAppender = appender(&(blocksAppender.data[$-1].data));
                dataAppender.reserve(blockSize);
                dataAppender.put(cast(char[]) buffer[appendRegion.length .. $]);

                assert(blocksAppender.data.length >= 2);
                assert(blocksAppender.data[$-2].data[$-1] == '\n');
            }
            else
            {
                /* Search backward in the current block for a newline. If found, it
                 * becomes the last newline in the current block. Anything following
                 * it is moved to the block. If a newline is not found, simply append
                 * to the current block and let it grow. We'll only search backward
                 * so far.
                 */
                immutable size_t currBlockLength = blocksAppender.data[$-1].data.length;
                immutable size_t searchLength = min(currBlockLength, newlineSearchSize);
                immutable size_t searchStart = currBlockLength - searchLength;
                auto blockSearchRegion = blocksAppender.data[$-1].data[searchStart .. $];
                auto lastNewlineOffset = blockSearchRegion.retro.find('\n').source.length;

                if (lastNewlineOffset != 0)
                {
                    /* Create a new InputBlock. The previous InputBlock is then found
                     * at blocksAppender.data[$-2]. It may be a physically different
                     * struct (a copy) if the blocks array gets reallocated.
                     */
                    blockNumber++;
                    blocksAppender.put(InputBlock(filename, blockNumber));
                    dataAppender = appender(&(blocksAppender.data[$-1].data));
                    dataAppender.reserve(blockSize);

                    /* Copy data following the newline from the last block to the new
                     * block. Then append the current read buffer.
                     */
                    immutable size_t moveRegionStart = searchStart + lastNewlineOffset;
                    dataAppender.put(blocksAppender.data[$-2].data[moveRegionStart .. $]);
                    dataAppender.put(cast(char[]) buffer);

                    /* Now delete the moved region from the last block. */
                    blocksAppender.data[$-2].data.length = moveRegionStart;

                    assert(blocksAppender.data.length >= 2);
                    assert(blocksAppender.data[$-2].data[$-1] == '\n');
                }
                else
                {
                    /* Give up. Allow the current block to grow. */
                    dataAppender.put(cast(char[]) buffer);
                }
            }
        }
    }
}

/** HasRandomValue is a boolean flag used at compile time by identifyInputLines to
 * distinguish use cases needing random value assignments from those that don't.
 */
alias HasRandomValue = Flag!"hasRandomValue";

/** An InputLine array is returned by identifyInputLines to represent each non-header line
 * line found in a FileData array. The 'data' element contains the line. A 'randomValue'
 * line is included if random values are being generated.
 */
static struct InputLine(HasRandomValue hasRandomValue)
{
    const(char)[] data;
    static if (hasRandomValue) double randomValue;
}

/** identifyInputLines is used by algorithms that read all files into memory prior to
 * processing. It does the initial processing of the file data.
 *
 * Two main tasks are performed. One is splitting all input data into lines. The second
 * is assigning a random value to the line, if random values are being generated.
 *
 * The key input is an InputBlock array. Normally one block for each file, but standard
 * input may have multiple blocks.
 *
 * The return value is an array of InputLine structs. The struct will have a 'randomValue'
 * member if random values are being assigned.
 */
InputLine!hasRandomValue[] identifyInputLines(HasRandomValue hasRandomValue, Flag!"isWeighted" isWeighted)
(const ref InputBlock[] inputBlocks, ref TsvSampleOptions cmdopt)
{
    import std.algorithm : splitter;
    import std.array : appender;
    import std.random : Random = Mt19937, uniform01;
    import tsv_utils.common.utils : throwIfWindowsNewline;

    static assert(hasRandomValue || !isWeighted);
    static if(!hasRandomValue) assert(!cmdopt.printRandom);

    InputLine!hasRandomValue[] inputLines;

    auto linesAppender = appender(&inputLines);
    static if (hasRandomValue) auto randomGenerator = Random(cmdopt.seed);

    /* Note: fileLineNum is zero-based here. One-based in most other code in this file. */
    immutable size_t fileBodyStartLine = cmdopt.hasHeader ? 1 : 0;
    size_t fileLineNum = fileBodyStartLine;

    foreach (block; inputBlocks)
    {
        /* Drop the last newline to avoid adding an extra empty line. */
        const data = (block.data.length > 0 && block.data[$-1] == '\n') ?
            block.data[0 .. $-1] : block.data;

        if (block.fileBlockNumber == 0) fileLineNum = fileBodyStartLine;

        foreach (ref line; data.splitter('\n'))
        {
            fileLineNum++;

            if (fileLineNum == 1) throwIfWindowsNewline(line, block.filename, fileLineNum);

            static if (!hasRandomValue)
            {
                linesAppender.put(InputLine!hasRandomValue(line));
            }
            else
            {
                static if (!isWeighted)
                {
                    immutable double randomValue = uniform01(randomGenerator);
                }
                else
                {
                    immutable double lineWeight =
                        getFieldValue!double(line, cmdopt.weightField, cmdopt.delim,
                                             block.filename, fileLineNum);
                    immutable double randomValue =
                        (lineWeight > 0.0)
                        ? uniform01(randomGenerator) ^^ (1.0 / lineWeight)
                        : 0.0;
                }

                linesAppender.put(InputLine!hasRandomValue(line, randomValue));
            }
        }
    }

    return inputLines;
}


/* Unit tests for ReadFileData. These tests focus on multiple InputBlock scenarios.
 * Other use paths are well tested by the tests at the end cases.
 */
unittest
{
    import tsv_utils.common.unittest_utils;
    import std.algorithm : equal, find, joiner, splitter;
    import std.array : appender;
    import std.file : rmdirRecurse;
    import std.path : buildPath;
    import std.range : repeat;

    auto rfdTestDir = makeUnittestTempDir("tsv_sample_readFileData");
    scope(exit) rfdTestDir.rmdirRecurse;

    char[] file1Data;
    char[] file2Data;
    char[] file3Data;

    auto app1 = appender(&file1Data);
    auto app2 = appender(&file2Data);
    auto app3 = appender(&file3Data);

    /* File 1: 1000 short lines. */
    app1.put("\n".repeat(100).joiner);
    app1.put("x\n".repeat(100).joiner);
    app1.put("yz\n".repeat(100).joiner);
    app1.put("pqr\n".repeat(100).joiner);
    app1.put("a\nbc\ndef\n".repeat(100).joiner);
    app1.put('\n'.repeat(100));
    app1.put("z\n".repeat(100).joiner);
    app1.put("xy\n".repeat(100).joiner);

    /* File 2: 500 longer lines. */
    app2.put(
        "0123456789-abcdefghijklmnopqrstuvwxyz-0123456789abcdefghijklmnopqrstuvwxyz-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-\n"
        .repeat(100)
        .joiner);
    app2.put(
        "|abcdefghijklmnopqrstuv|\n|0123456789|\n|0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ|\n|abcdefghijklmnopqrstuvwxyz|\n"
        .repeat(100)
        .joiner);
    app2.put(
         "0123456789-abcdefghijklmnopqrstuvwxyz-0123456789abcdefghijklmnopqrstuvwxyz-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-\n"
        .repeat(100)
        .joiner);

    /* File 3: 1000 mixed length lines. */
    app3.put("\n\n|abcde|\n1\n12\n123\n|abcdefghijklmnop|\n|xyz|\n0123456789\nX\n".repeat(100).joiner);

    string file1Path = buildPath(rfdTestDir, "file1.txt");
    string file2Path = buildPath(rfdTestDir, "file2.txt");
    string file3Path = buildPath(rfdTestDir, "file3.txt");

    try
    {
        auto ofile1 = File(file1Path, "wb");
        ofile1.write(file1Data);
        ofile1.close;
    }
    catch (Exception e) assert(false, format("Failed to write file: %s.\n  Error: %s", file1Path, e.msg));

    try
    {
        auto ofile2 = File(file2Path, "wb");
        ofile2.write(file2Data);
        ofile2.close;
    }
    catch (Exception e) assert(false, format("Failed to write file: %s.\n  Error: %s", file2Path, e.msg));

    try
    {
        auto ofile3 = File(file3Path, "wb");
        ofile3.write(file3Data);
        ofile3.close;
    }
    catch  (Exception e) assert(false, format("Failed to write file: %s.\n  Error: %s", file3Path, e.msg));

    auto allData = file1Data ~ file2Data ~ file3Data;
    auto expectedLines = allData.splitter('\n').array[0 .. $-1];

    auto file2DataNoHeader = (file2Data.find('\n'))[1 .. $];
    auto file3DataNoHeader = (file3Data.find('\n'))[1 .. $];
    auto allDataUsingHeader = file1Data ~ file2DataNoHeader ~ file3DataNoHeader;
    auto expectedLinesUsingHeader = allDataUsingHeader.splitter('\n').array[0 .. $-1];

    assert(expectedLines.length == expectedLinesUsingHeader.length + 2);

    /* We need real files for creating command line arg structs.
     */
    string file1Copy1Path = buildPath(rfdTestDir, "file1_copy1.txt");
    string file1Copy2Path = buildPath(rfdTestDir, "file1_copy2.txt");

    try
    {
        auto ofile = File(file1Copy1Path, "wb");
        ofile.write(file1Data);
        ofile.close;
    }
    catch (Exception e) assert(false, format("Failed to write file: %s.\n  Error: %s", file1Copy1Path, e.msg));

    try
    {
        auto ofile = File(file1Copy2Path, "wb");
        ofile.write(file1Data);
        ofile.close;
    }
    catch (Exception e) assert(false, format("Failed to write file: %s.\n  Error: %s", file1Copy2Path, e.msg));

    TsvSampleOptions cmdoptNoHeader;
    auto noHeaderCmdArgs = ["unittest", file1Copy1Path];
    auto r1 = cmdoptNoHeader.processArgs(noHeaderCmdArgs);
    assert(r1[0], format("Invalid command lines arg: '%s'.", noHeaderCmdArgs));

    TsvSampleOptions cmdoptYesHeader;
    auto yesHeaderCmdArgs = ["unittest", "--header", file1Copy2Path];
    auto r2 = cmdoptYesHeader.processArgs(yesHeaderCmdArgs);
    assert(r2[0], format("Invalid command lines arg: '%s'.", yesHeaderCmdArgs));

    scope (exit)
    {
        /* Close the files being used by the cmdopt[yes|no]Header structs. */
        while (!cmdoptNoHeader.inputSources.empty) cmdoptNoHeader.inputSources.popFront;
        while (!cmdoptYesHeader.inputSources.empty) cmdoptYesHeader.inputSources.popFront;
    }

    auto outputStream = appender!(char[])();

    {
        /* Reading as single blocks. */
        ubyte[] rawReadBuffer = new ubyte[256];
        InputBlock[] blocks;
        auto blocksAppender = appender(&blocks);
        blocksAppender.reserve(3);
        foreach (f; [ file1Path, file2Path, file3Path ])
        {
            auto ifile = f.File("rb");
            ulong filesize = ifile.size;
            if (filesize == ulong.max) filesize = 1000;
            readFileDataAsOneBlock(f, ifile, filesize, blocksAppender, rawReadBuffer);
            ifile.close;
        }
        auto inputLines =
            identifyInputLines!(No.hasRandomValue, No.isWeighted)(
                blocks, cmdoptNoHeader);

        assert(equal!((a, b) => a.data == b)(inputLines, expectedLines));
    }

    {
        /* Reading as multiple blocks. */
        foreach (size_t searchSize; [ 0, 1, 2, 64 ])
        {
            foreach (size_t blockSize; [ 1, 2, 16, 64, 256 ])
            {
                foreach (size_t readSize; [ 1, 2, 8, 32 ])
                {
                    ubyte[] rawReadBuffer = new ubyte[readSize];
                    InputBlock[] blocks;
                    auto blocksAppender = appender(&blocks);
                    blocksAppender.reserve(3);
                    foreach (f; [ file1Path, file2Path, file3Path ])
                    {
                        auto ifile = f.File("rb");
                        readFileDataAsMultipleBlocks(f, ifile, blocksAppender,
                                                     rawReadBuffer, blockSize, searchSize);
                        ifile.close;
                    }
                    auto inputLines =
                        identifyInputLines!(No.hasRandomValue, No.isWeighted)(
                            blocks, cmdoptNoHeader);

                    assert(equal!((a, b) => a.data == b)(inputLines, expectedLines));
                }
            }
        }
    }
    version(none) {
    {
        /* Reading as multiple blocks, with header processing. */
        const size_t readSize = 32;
        const size_t blockSize = 48;
        const size_t searchSize = 16;

        ubyte[] rawReadBuffer = new ubyte[readSize];
        InputBlock[] blocks;
        auto blocksAppender = appender(&blocks);
        blocksAppender.reserve(3);
        foreach (f; [ file1Path, file2Path, file3Path ])
        {
            auto ifile = f.File("rb");
            readFileDataAsMultipleBlocks(f, ifile, blocksAppender,
                                         rawReadBuffer, blockSize, searchSize);
            ifile.close;
        }
        auto inputLines =
            identifyInputLines!(No.hasRandomValue, No.isWeighted)(
                blocks, cmdoptYesHeader);

        assert(outputStream.data == expectedLinesUsingHeader[0] ~ '\n');
        assert(equal!((a, b) => a.data == b)(inputLines, expectedLinesUsingHeader[1 .. $]));
    }
    }
}

/** Write a floating point random value to an output stream.
 *
 * This routine is used for floating point random value printing. This routine writes
 * 17 significant digits, the range available in doubles. This routine prefers decimal
 * format, without exponents. It will generate somewhat large precision numbers,
 * currently up to 28 digits, before switching to exponents.
 *
 * The primary reason for this approach is to enable faster sorting on random values
 * by GNU sort and similar external sorting programs. GNU sort is dramatically faster
 * on decimal format numeric sorts ('n' switch) than general numeric sorts ('g' switch).
 * The 'general numeric' handles exponential notation. The difference is 5-10x.
 *
 * Random values generated by Bernoulli sampling are nearly always greater than 1e-12.
 * No examples less than 1e-09 were seen in hundred of millions of trials. Similar
 * results were seen with weighted sampling with integer weights. The same is not true
 * with floating point weights. These produce quite large exponents. However, even
 * for floating point weights this can be useful. For random weights [0,1] less than 5%
 * will be less than 1e-12 and use exponential notation.
 */
void formatRandomValue(OutputRange)(auto ref OutputRange outputStream, double value)
if (isOutputRange!(OutputRange, char))
{
    import std.format : formatValue, singleSpec;

    immutable spec17f = singleSpec("%.17f");
    immutable spec18f = singleSpec("%.18f");
    immutable spec19f = singleSpec("%.19f");
    immutable spec20f = singleSpec("%.20f");
    immutable spec21f = singleSpec("%.21f");
    immutable spec22f = singleSpec("%.22f");
    immutable spec23f = singleSpec("%.23f");
    immutable spec24f = singleSpec("%.24f");
    immutable spec25f = singleSpec("%.25f");
    immutable spec26f = singleSpec("%.26f");
    immutable spec27f = singleSpec("%.27f");
    immutable spec28f = singleSpec("%.28f");

    immutable spec17g = singleSpec("%.17g");

    immutable formatSpec =
        (value >= 1e-01) ? spec17f :
        (value >= 1e-02) ? spec18f :
        (value >= 1e-03) ? spec19f :
        (value >= 1e-04) ? spec20f :
        (value >= 1e-05) ? spec21f :
        (value >= 1e-06) ? spec22f :
        (value >= 1e-07) ? spec23f :
        (value >= 1e-08) ? spec24f :
        (value >= 1e-09) ? spec25f :
        (value >= 1e-10) ? spec26f :
        (value >= 1e-11) ? spec27f :
        (value >= 1e-12) ? spec28f : spec17g;

    outputStream.formatValue(value, formatSpec);
}

@safe unittest
{
    void testFormatValue(double value, string expected)
    {
        import std.array : appender;

        auto s = appender!string();
        s.formatRandomValue(value);
        assert(s.data == expected,
               format("[testFormatValue] value: %g; expected: %s; actual: %s", value, expected, s.data));
    }

    testFormatValue(1.0,   "1.00000000000000000");
    testFormatValue(0.1,   "0.10000000000000001");
    testFormatValue(0.01,  "0.010000000000000000");
    testFormatValue(1e-03, "0.0010000000000000000");
    testFormatValue(1e-04, "0.00010000000000000000");
    testFormatValue(1e-05, "0.000010000000000000001");
    testFormatValue(1e-06, "0.0000010000000000000000");
    testFormatValue(1e-07, "0.00000010000000000000000");
    testFormatValue(1e-08, "0.000000010000000000000000");
    testFormatValue(1e-09, "0.0000000010000000000000001");
    testFormatValue(1e-10, "0.00000000010000000000000000");
    testFormatValue(1e-11, "0.000000000009999999999999999");
    testFormatValue(1e-12, "0.0000000000010000000000000000");
    testFormatValue(1e-13, "1e-13");
    testFormatValue(1e-14, "1e-14");
    testFormatValue(12345678901234567e-15, "12.34567890123456735");
    testFormatValue(12345678901234567e-16, "1.23456789012345669");
    testFormatValue(12345678901234567e-17, "0.12345678901234566");
    testFormatValue(12345678901234567e-18, "0.012345678901234567");
    testFormatValue(12345678901234567e-19, "0.0012345678901234567");
    testFormatValue(12345678901234567e-20, "0.00012345678901234567");
    testFormatValue(12345678901234567e-21, "0.000012345678901234568");
    testFormatValue(12345678901234567e-22, "0.0000012345678901234567");
    testFormatValue(12345678901234567e-23, "0.00000012345678901234566");
    testFormatValue(12345678901234567e-24, "0.000000012345678901234567");
    testFormatValue(12345678901234567e-25, "0.0000000012345678901234566");
    testFormatValue(12345678901234567e-26, "0.00000000012345678901234568");
    testFormatValue(12345678901234567e-27, "0.000000000012345678901234567");
    testFormatValue(12345678901234567e-28, "0.0000000000012345678901234567");
    testFormatValue(12345678901234567e-29, "1.2345678901234566e-13");
}

/** Convenience function for extracting a single field from a line. See
 * [tsv_utils.common.utils.getTsvFieldValue] for details. This wrapper creates error
 * text tailored for this program.
 */
import std.traits : isSomeChar;
T getFieldValue(T, C)(const C[] line, size_t fieldIndex, C delim, string filename, ulong lineNum) pure @safe
if (isSomeChar!C)
{
    import std.conv : ConvException, to;
    import tsv_utils.common.utils : getTsvFieldValue;

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

@safe unittest
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
 * on several different platform, compiler, and library versions. However, it is certainly
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
     *  - Sampling Type (required): Permute (Shuffle), Sample, Replace, Bernoulli, Distinct
     *  - Compatibility: Compat, AlgoR, Skip, Swap, Inorder
     *  - Weight Field: Wt<num>, e.g. Wt3
     *  - Sample Size: Num<num>, eg. Num3
     *  - Seed Value: V<num>, eg. V77
     *  - Key Field: K<num>, e.g. K2
     *  - Probability: P<num>, e.g P05 (5%)
     *  - Printing Probabilities: Probs
     *  - Printing Probs in order: ProbsInorder
     *  - Printing Probs with custom header: RVCustom
     */

    /* Empty file. */
    string[][] dataEmpty = [];
    string fpath_dataEmpty = buildPath(testDir, "dataEmpty.tsv");
    writeUnittestTsvFile(fpath_dataEmpty, dataEmpty);

    /* 3x0, header only. */
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
    writeUnittestTsvFile(fpath_data3x1_noheader, data3x1[1 .. $]);

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
    writeUnittestTsvFile(fpath_data3x2_noheader, data3x2[1 .. $]);

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
    writeUnittestTsvFile(fpath_data3x3_noheader, data3x3[1 .. $]);

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
    writeUnittestTsvFile(fpath_data3x6_noheader, data3x6[1 .. $]);

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
         ["0.75710153928957880", "black", "黒", "0.983"],
         ["0.52525980887003243", "blue", "青", "12"],
         ["0.49287854949943721", "white", "白", "1.65"],
         ["0.15929344086907804", "green", "緑", "0.0072"],
         ["0.010968807619065046", "red", "赤", "23.8"]];

    /* Note: data3x6ExpectedSampleAlgoRNum6 is identical to data3x6ExpectedPermuteSwap because
     * both are effectively the same algorithm given that --num is data length. Both read
     * in the full data in order then call randomShuffle.
     */
    string[][] data3x6ExpectedSampleAlgoRNum6 =
        [["field_a", "field_b", "field_c"],
         ["black", "黒", "0.983"],
         ["green", "緑", "0.0072"],
         ["red", "赤", "23.8"],
         ["yellow", "黄", "12"],
         ["white", "白", "1.65"],
         ["blue", "青", "12"]];

    string[][] data3x6ExpectedSampleAlgoRNum5 =
        [["field_a", "field_b", "field_c"],
         ["red", "赤", "23.8"],
         ["black", "黒", "0.983"],
         ["white", "白", "1.65"],
         ["green", "緑", "0.0072"],
         ["yellow", "黄", "12"]];

    string[][] data3x6ExpectedSampleAlgoRNum4 =
        [["field_a", "field_b", "field_c"],
         ["blue", "青", "12"],
         ["green", "緑", "0.0072"],
         ["black", "黒", "0.983"],
         ["white", "白", "1.65"]];

    string[][] data3x6ExpectedSampleAlgoRNum3 =
        [["field_a", "field_b", "field_c"],
         ["red", "赤", "23.8"],
         ["black", "黒", "0.983"],
         ["green", "緑", "0.0072"]];

    string[][] data3x6ExpectedSampleAlgoRNum2 =
        [["field_a", "field_b", "field_c"],
         ["black", "黒", "0.983"],
         ["red", "赤", "23.8"]];

    string[][] data3x6ExpectedSampleAlgoRNum1 =
        [["field_a", "field_b", "field_c"],
         ["green", "緑", "0.0072"]];

    /* Inorder versions. */
    string[][] data3x6ExpectedSampleAlgoRNum6Inorder =
        [["field_a", "field_b", "field_c"],
         ["red", "赤", "23.8"],
         ["green", "緑", "0.0072"],
         ["white", "白", "1.65"],
         ["yellow", "黄", "12"],
         ["blue", "青", "12"],
         ["black", "黒", "0.983"]];

    string[][] data3x6ExpectedSampleAlgoRNum5Inorder =
        [["field_a", "field_b", "field_c"],
         ["red", "赤", "23.8"],
         ["green", "緑", "0.0072"],
         ["white", "白", "1.65"],
         ["yellow", "黄", "12"],
         ["black", "黒", "0.983"]];

    string[][] data3x6ExpectedSampleAlgoRNum4Inorder =
        [["field_a", "field_b", "field_c"],
         ["green", "緑", "0.0072"],
         ["white", "白", "1.65"],
         ["blue", "青", "12"],
         ["black", "黒", "0.983"]];

    string[][] data3x6ExpectedSampleAlgoRNum3Inorder =
        [["field_a", "field_b", "field_c"],
         ["red", "赤", "23.8"],
         ["green", "緑", "0.0072"],
         ["black", "黒", "0.983"]];

    string[][] data3x6ExpectedSampleAlgoRNum2Inorder =
        [["field_a", "field_b", "field_c"],
         ["red", "赤", "23.8"],
         ["black", "黒", "0.983"]];

    string[][] data3x6ExpectedSampleAlgoRNum1Inorder =
        [["field_a", "field_b", "field_c"],
         ["green", "緑", "0.0072"]];

    /* Reservoir inorder */
    string[][] data3x6ExpectedSampleCompatNum6Inorder =
        [["field_a", "field_b", "field_c"],
         ["red", "赤", "23.8"],
         ["green", "緑", "0.0072"],
         ["white", "白", "1.65"],
         ["yellow", "黄", "12"],
         ["blue", "青", "12"],
         ["black", "黒", "0.983"]];

    string[][] data3x6ExpectedSampleCompatNum5Inorder =
        [["field_a", "field_b", "field_c"],
         ["green", "緑", "0.0072"],
         ["white", "白", "1.65"],
         ["yellow", "黄", "12"],
         ["blue", "青", "12"],
         ["black", "黒", "0.983"]];

    string[][] data3x6ExpectedSampleCompatNum4Inorder =
        [["field_a", "field_b", "field_c"],
         ["white", "白", "1.65"],
         ["yellow", "黄", "12"],
         ["blue", "青", "12"],
         ["black", "黒", "0.983"]];

    string[][] data3x6ExpectedSampleCompatNum3Inorder =
        [["field_a", "field_b", "field_c"],
         ["yellow", "黄", "12"],
         ["blue", "青", "12"],
         ["black", "黒", "0.983"]];

    string[][] data3x6ExpectedSampleCompatNum2Inorder =
        [["field_a", "field_b", "field_c"],
         ["yellow", "黄", "12"],
         ["black", "黒", "0.983"]];

    string[][] data3x6ExpectedSampleCompatNum1Inorder =
        [["field_a", "field_b", "field_c"],
         ["yellow", "黄", "12"]];


    /* Reservoir inorder with probabilities. */
    string[][] data3x6ExpectedSampleCompatNum6ProbsInorder =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.010968807619065046", "red", "赤", "23.8"],
         ["0.15929344086907804", "green", "緑", "0.0072"],
         ["0.49287854949943721", "white", "白", "1.65"],
         ["0.96055546286515892", "yellow", "黄", "12"],
         ["0.52525980887003243", "blue", "青", "12"],
         ["0.75710153928957880", "black", "黒", "0.983"]];

    string[][] data3x6ExpectedSampleCompatNum5ProbsInorder =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.15929344086907804", "green", "緑", "0.0072"],
         ["0.49287854949943721", "white", "白", "1.65"],
         ["0.96055546286515892", "yellow", "黄", "12"],
         ["0.52525980887003243", "blue", "青", "12"],
         ["0.75710153928957880", "black", "黒", "0.983"]];

    string[][] data3x6ExpectedSampleCompatNum4ProbsInorder =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.49287854949943721", "white", "白", "1.65"],
         ["0.96055546286515892", "yellow", "黄", "12"],
         ["0.52525980887003243", "blue", "青", "12"],
         ["0.75710153928957880", "black", "黒", "0.983"]];

    string[][] data3x6ExpectedSampleCompatNum3ProbsInorder =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.96055546286515892", "yellow", "黄", "12"],
         ["0.52525980887003243", "blue", "青", "12"],
         ["0.75710153928957880", "black", "黒", "0.983"]];

    string[][] data3x6ExpectedSampleCompatNum2ProbsInorder =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.96055546286515892", "yellow", "黄", "12"],
         ["0.75710153928957880", "black", "黒", "0.983"]];

    string[][] data3x6ExpectedSampleCompatNum1ProbsInorder =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.96055546286515892", "yellow", "黄", "12"]];

    string[][] data3x6ExpectedWt3Num6Inorder =
        [["field_a", "field_b", "field_c"],
         ["red", "赤", "23.8"],
         ["green", "緑", "0.0072"],
         ["white", "白", "1.65"],
         ["yellow", "黄", "12"],
         ["blue", "青", "12"],
         ["black", "黒", "0.983"]];

    string[][] data3x6ExpectedWt3Num5Inorder =
        [["field_a", "field_b", "field_c"],
         ["green", "緑", "0.0072"],
         ["white", "白", "1.65"],
         ["yellow", "黄", "12"],
         ["blue", "青", "12"],
         ["black", "黒", "0.983"]];

    string[][] data3x6ExpectedWt3Num4Inorder =
        [["field_a", "field_b", "field_c"],
         ["white", "白", "1.65"],
         ["yellow", "黄", "12"],
         ["blue", "青", "12"],
         ["black", "黒", "0.983"]];

    string[][] data3x6ExpectedWt3Num3Inorder =
        [["field_a", "field_b", "field_c"],
         ["yellow", "黄", "12"],
         ["blue", "青", "12"],
         ["black", "黒", "0.983"]];

    string[][] data3x6ExpectedWt3Num2Inorder =
        [["field_a", "field_b", "field_c"],
         ["yellow", "黄", "12"],
         ["black", "黒", "0.983"]];

    string[][] data3x6ExpectedWt3Num1Inorder =
        [["field_a", "field_b", "field_c"],
         ["yellow", "黄", "12"]];


    string[][] data3x6ExpectedBernoulliProbsP100 =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.010968807619065046", "red", "赤", "23.8"],
         ["0.15929344086907804", "green", "緑", "0.0072"],
         ["0.49287854949943721", "white", "白", "1.65"],
         ["0.96055546286515892", "yellow", "黄", "12"],
         ["0.52525980887003243", "blue", "青", "12"],
         ["0.75710153928957880", "black", "黒", "0.983"]];

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
         ["0.99665198757645390", "yellow", "黄", "12"],
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
         ["0.99665198757645390", "yellow", "黄", "12"],
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
         ["0.046095821075141430", "white", "白", "1.65"]];

    string[][] data3x6ExpectedBernoulliCompatP60V41Probs =
        [["random_value", "field_a", "field_b", "field_c"],
         ["0.25092361867427826", "red", "赤", "23.8"],
         ["0.046095821075141430", "white", "白", "1.65"],
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
         ["0.75710153928957880", "green", "緑", "0.0072"],
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
         ["0.75710153928957880", "green", "緑", "0.0072"],
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
         ["0.97330961938083660", "red", "赤", "23.8"],
         ["0.88797551521739648", "blue", "青", "12"],
         ["0.81999230489041786", "gray", "グレー", "6.2"],
         ["0.55975569204250941", "white", "白", "1.65"],
         ["0.46472135609205739", "black", "黒", "0.983"],
         ["0.18824582704191337", "pink", "ピンク", "1.1"],
         ["0.16446131853299920", "orange", "オレンジ", "2.5"],
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

        string[][] combo1ExpectedSampleAlgoRNum4 =
        [["field_a", "field_b", "field_c"],
         ["blue", "青", "12"],
         ["gray", "グレー", "6.2"],
         ["brown", "褐色", "29.2"],
         ["white", "白", "1.65"]];

        string[][] combo1ExpectedSampleAlgoRNum4Inorder =
        [["field_a", "field_b", "field_c"],
         ["white", "白", "1.65"],
         ["blue", "青", "12"],
         ["brown", "褐色", "29.2"],
         ["gray", "グレー", "6.2"]];

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
    writeUnittestTsvFile(fpath_data1x200_noheader, data1x200[1 .. $]);

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
    writeUnittestTsvFile(fpath_data1x10_noheader, data1x10[1 .. $]);

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
         ["0.23725317907018120", "9", "0.99103720"],
         ["0.16016096701872204", "3", "0.38627527"],
         ["0.090819662667243381", "10", "0.31401740"],
         ["0.0071764539244361172", "6", "0.05636231"],
         ["0.000000048318642951630057", "1", "0.26788837"],
         ["0.00000000037525692966535517", "5", "0.02966641"],
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
         ["0.99914188537143800", "5", "750"],
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
         ["0.99989445052186410", "2", "17403.31"],
         ["0.99975897602861630", "5", "2671.04"],
         ["0.99891852769877643", "3", "653.84"],
         ["0.99889167752782515", "10", "679.29"],
         ["0.99512207506850148", "4", "8.23"],
         ["0.86789371584259023", "1", "31.85"],
         ["0.58574438162915610", "7", "1.79"]];

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
    writeUnittestTsvFile(fpath_data5x25_noheader, data5x25[1 .. $]);

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

    /* Fields 2 and 4 from data5x25. Distinct rows should be the same for equiv keys. */
    string[][] data2x25 =
        [["Shape", "Size"],
         ["circle", "S"],
         ["circle", "L"],
         ["square", "L"],
         ["circle", "L"],
         ["ellipse", "S"],
         ["triangle", "S"],
         ["triangle", "L"],
         ["square", "S"],
         ["circle", "S"],
         ["square", "L"],
         ["triangle", "L"],
         ["circle", "L"],
         ["ellipse", "S"],
         ["circle", "L"],
         ["ellipse", "L"],
         ["square", "S"],
         ["circle", "L"],
         ["square", "S"],
         ["square", "L"],
         ["circle", "S"],
         ["ellipse", "L"],
         ["triangle", "L"],
         ["circle", "S"],
         ["square", "L"],
         ["circle", "S"],
        ];

    string fpath_data2x25 = buildPath(testDir, "data2x25.tsv");
    string fpath_data2x25_noheader = buildPath(testDir, "data2x25_noheader.tsv");
    writeUnittestTsvFile(fpath_data2x25, data2x25);
    writeUnittestTsvFile(fpath_data2x25_noheader, data2x25[1 .. $]);

    string[][] data2x25ExpectedDistinctK1K2P20 =
        [["Shape", "Size"],
         ["square", "L"],
         ["triangle", "L"],
         ["square", "S"],
         ["square", "L"],
         ["triangle", "L"],
         ["square", "S"],
         ["square", "S"],
         ["square", "L"],
         ["triangle", "L"],
         ["square", "L"],
        ];

    string[][] data1x25 =
        [["Shape-Size"],
         ["circle-S"],
         ["circle-L"],
         ["square-L"],
         ["circle-L"],
         ["ellipse-S"],
         ["triangle-S"],
         ["triangle-L"],
         ["square-S"],
         ["circle-S"],
         ["square-L"],
         ["triangle-L"],
         ["circle-L"],
         ["ellipse-S"],
         ["circle-L"],
         ["ellipse-L"],
         ["square-S"],
         ["circle-L"],
         ["square-S"],
         ["square-L"],
         ["circle-S"],
         ["ellipse-L"],
         ["triangle-L"],
         ["circle-S"],
         ["square-L"],
         ["circle-S"],
        ];

    string fpath_data1x25 = buildPath(testDir, "data1x25.tsv");
    string fpath_data1x25_noheader = buildPath(testDir, "data1x25_noheader.tsv");
    writeUnittestTsvFile(fpath_data1x25, data1x25);
    writeUnittestTsvFile(fpath_data1x25_noheader, data1x25[1 .. $]);

    string[][] data1x25ExpectedDistinctK1P20 =
        [["Shape-Size"],
         ["triangle-L"],
         ["square-S"],
         ["triangle-L"],
         ["ellipse-L"],
         ["square-S"],
         ["square-S"],
         ["ellipse-L"],
         ["triangle-L"],
        ];

    string[][] data1x25ExpectedDistinctK1P20Probs =
        [["random_value", "Shape-Size"],
         ["0", "triangle-L"],
         ["0", "square-S"],
         ["0", "triangle-L"],
         ["0", "ellipse-L"],
         ["0", "square-S"],
         ["0", "square-S"],
         ["0", "ellipse-L"],
         ["0", "triangle-L"],
        ];

    string[][] data1x25ExpectedDistinctK1P20ProbsInorder =
        [["random_value", "Shape-Size"],
         ["1", "circle-S"],
         ["4", "circle-L"],
         ["2", "square-L"],
         ["4", "circle-L"],
         ["2", "ellipse-S"],
         ["1", "triangle-S"],
         ["0", "triangle-L"],
         ["0", "square-S"],
         ["1", "circle-S"],
         ["2", "square-L"],
         ["0", "triangle-L"],
         ["4", "circle-L"],
         ["2", "ellipse-S"],
         ["4", "circle-L"],
         ["0", "ellipse-L"],
         ["0", "square-S"],
         ["4", "circle-L"],
         ["0", "square-S"],
         ["2", "square-L"],
         ["1", "circle-S"],
         ["0", "ellipse-L"],
         ["0", "triangle-L"],
         ["1", "circle-S"],
         ["2", "square-L"],
         ["1", "circle-S"],
        ];

    /*
     * Enough setup! Actually run some tests!
     */

    /* Shuffling tests. Headers, static seed, compatibility mode. With weights and without. */
    testTsvSample(["test-a1", "--header", "--static-seed", "--compatibility-mode", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-a2", "--header", "--static-seed", "--compatibility-mode", fpath_data3x0], data3x0);
    testTsvSample(["test-a3", "-H", "-s", "--compatibility-mode", fpath_data3x1], data3x1);
    testTsvSample(["test-a4", "-H", "-s", "--compatibility-mode", fpath_data3x2], data3x2PermuteCompat);
    testTsvSample(["test-a5", "-H", "-s", "--compatibility-mode", fpath_data3x3], data3x3ExpectedPermuteCompat);
    testTsvSample(["test-a6", "-H", "-s", "--compatibility-mode", fpath_data3x6], data3x6ExpectedPermuteCompat);
    testTsvSample(["test-a7", "-H", "-s", "--print-random", fpath_data3x6], data3x6ExpectedPermuteCompatProbs);
    testTsvSample(["test-a8", "-H", "-s", "--weight-field", "3", fpath_data3x6], data3x6ExpectedPermuteWt3);
    testTsvSample(["test-a8b", "-H", "-s", "--weight-field", "field_c", fpath_data3x6], data3x6ExpectedPermuteWt3);
    testTsvSample(["test-a9", "-H", "-s", "--print-random", "-w", "3", fpath_data3x6], data3x6ExpectedPermuteWt3Probs);
    testTsvSample(["test-a9b", "-H", "-s", "--print-random", "-w", "field_c", fpath_data3x6], data3x6ExpectedPermuteWt3Probs);
    testTsvSample(["test-a9c", "-H", "-s", "--print-random", "-w", "f*c", fpath_data3x6], data3x6ExpectedPermuteWt3Probs);
    testTsvSample(["test-a10", "-H", "--seed-value", "41", "--print-random", fpath_data3x6], data3x6ExpectedPermuteCompatV41Probs);
    testTsvSample(["test-a11", "-H", "-s", "-v", "41", "--print-random", fpath_data3x6], data3x6ExpectedPermuteCompatV41Probs);
    testTsvSample(["test-a12", "-H", "-s", "-v", "0", "--print-random", fpath_data3x6], data3x6ExpectedPermuteCompatProbs);
    testTsvSample(["test-a13", "-H", "-v", "41", "-w", "3", "--print-random", fpath_data3x6], data3x6ExpectedPermuteWt3V41Probs);
    testTsvSample(["test-a13b", "-H", "-v", "41", "-w", "field_c", "--print-random", fpath_data3x6], data3x6ExpectedPermuteWt3V41Probs);
    testTsvSample(["test-a13c", "--line-buffered", "-H", "-v", "41", "-w", "field_c", "--print-random", fpath_data3x6], data3x6ExpectedPermuteWt3V41Probs);

    /* Shuffling, without compatibility mode, or with both compatibility and printing. */
    testTsvSample(["test-aa1", "--header", "--static-seed", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-aa2", "--header", "--static-seed", fpath_data3x0], data3x0);
    testTsvSample(["test-aa3", "-H", "-s", fpath_data3x1], data3x1);
    testTsvSample(["test-aa4", "-H", "-s", fpath_data3x2], data3x2PermuteShuffle);
    testTsvSample(["test-aa5", "-H", "-s", fpath_data3x3], data3x3ExpectedPermuteSwap);
    testTsvSample(["test-aa6", "-H", "-s", fpath_data3x6], data3x6ExpectedPermuteSwap);
    testTsvSample(["test-aa7", "-H", "-s", "--weight-field", "3", fpath_data3x6], data3x6ExpectedPermuteWt3);
    testTsvSample(["test-aa8", "-H", "-s", "--print-random", "-w", "3", "--compatibility-mode", fpath_data3x6], data3x6ExpectedPermuteWt3Probs);
    testTsvSample(["test-aa8b", "-H", "-s", "--print-random", "-w", "field_c", "--compatibility-mode", fpath_data3x6], data3x6ExpectedPermuteWt3Probs);
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
    testTsvSample(["test-aa16", "--prefer-algorithm-r", "-H", "-s", "--num", "7", fpath_data3x6], data3x6ExpectedSampleAlgoRNum6);
    testTsvSample(["test-aa17", "--prefer-algorithm-r", "-H", "-s", "--num", "6", fpath_data3x6], data3x6ExpectedSampleAlgoRNum6);
    testTsvSample(["test-aa18", "--prefer-algorithm-r", "-H", "-s", "--num", "5", fpath_data3x6], data3x6ExpectedSampleAlgoRNum5);
    testTsvSample(["test-aa19", "--prefer-algorithm-r", "-H", "-s", "--num", "4", fpath_data3x6], data3x6ExpectedSampleAlgoRNum4);
    testTsvSample(["test-aa20", "--prefer-algorithm-r", "-H", "-s", "--num", "3", fpath_data3x6], data3x6ExpectedSampleAlgoRNum3);
    testTsvSample(["test-aa21", "--prefer-algorithm-r", "-H", "-s", "--num", "2", fpath_data3x6], data3x6ExpectedSampleAlgoRNum2);
    testTsvSample(["test-aa22", "--prefer-algorithm-r", "-H", "-s", "--num", "1", fpath_data3x6], data3x6ExpectedSampleAlgoRNum1);
    testTsvSample(["test-aa22b", "--line-buffered", "--prefer-algorithm-r", "-H", "-s", "--num", "1", fpath_data3x6], data3x6ExpectedSampleAlgoRNum1);

    /* Inorder versions of Algorithm R tests. */
    testTsvSample(["test-ai10", "--prefer-algorithm-r", "--header", "--static-seed", "--num", "1", "--inorder", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-ai11", "--prefer-algorithm-r", "--header", "--static-seed", "--num", "2", "--inorder", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-ai12", "--prefer-algorithm-r", "-H", "-s", "--num", "1", "--inorder", fpath_data3x0], data3x0);
    testTsvSample(["test-ai13", "--prefer-algorithm-r", "-H", "-s", "--num", "2", "--inorder", fpath_data3x0], data3x0);
    testTsvSample(["test-ai14", "--prefer-algorithm-r", "-H", "-s", "--num", "1", "--inorder", fpath_data3x1], data3x1);
    testTsvSample(["test-ai15", "--prefer-algorithm-r", "-H", "-s", "--num", "2", "-i", fpath_data3x1], data3x1);
    testTsvSample(["test-ai16", "--prefer-algorithm-r", "-H", "-s", "--num", "7", "-i", fpath_data3x6], data3x6ExpectedSampleAlgoRNum6Inorder);
    testTsvSample(["test-ai17", "--prefer-algorithm-r", "-H", "-s", "--num", "6", "-i", fpath_data3x6], data3x6ExpectedSampleAlgoRNum6Inorder);
    testTsvSample(["test-ai18", "--prefer-algorithm-r", "-H", "-s", "--num", "5", "-i", fpath_data3x6], data3x6ExpectedSampleAlgoRNum5Inorder);
    testTsvSample(["test-ai19", "--prefer-algorithm-r", "-H", "-s", "--num", "4", "-i", fpath_data3x6], data3x6ExpectedSampleAlgoRNum4Inorder);
    testTsvSample(["test-ai20", "--prefer-algorithm-r", "-H", "-s", "--num", "3", "-i", fpath_data3x6], data3x6ExpectedSampleAlgoRNum3Inorder);
    testTsvSample(["test-ai21", "--prefer-algorithm-r", "-H", "-s", "--num", "2", "-i", fpath_data3x6], data3x6ExpectedSampleAlgoRNum2Inorder);
    testTsvSample(["test-ai22", "--prefer-algorithm-r", "-H", "-s", "--num", "1", "-i", fpath_data3x6], data3x6ExpectedSampleAlgoRNum1Inorder);

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
    testTsvSample(["test-a22b", "--line-buffered", "-H", "-v", "41", "--prob", "0.60", "--print-random", fpath_data3x6], data3x6ExpectedBernoulliCompatP60V41Probs);

    /* Bernoulli sampling with probabilities in skip sampling range or preferring skip sampling. */
    testTsvSample(["test-ab1", "-H", "--seed-value", "333", "--prob", "0.01", fpath_data1x200], data1x200ExpectedBernoulliSkipV333P01);
    testTsvSample(["test-ab2", "-H", "--seed-value", "333", "--prob", "0.02", fpath_data1x200], data1x200ExpectedBernoulliSkipV333P02);
    testTsvSample(["test-ab3", "-H", "--seed-value", "333", "--prob", "0.03", fpath_data1x200], data1x200ExpectedBernoulliSkipV333P03);
    testTsvSample(["test-ab4", "-H", "--seed-value", "333", "--prob", "0.01", "--compatibility-mode", fpath_data1x200], data1x200ExpectedBernoulliCompatV333P01);
    testTsvSample(["test-ab5", "-H", "--seed-value", "333", "--prob", "0.02", "--compatibility-mode", fpath_data1x200], data1x200ExpectedBernoulliCompatV333P02);
    testTsvSample(["test-ab6", "-H", "--seed-value", "333", "--prob", "0.03", "--compatibility-mode", fpath_data1x200], data1x200ExpectedBernoulliCompatV333P03);
    testTsvSample(["test-ab7", "-H", "-s", "-p", "0.40", "--prefer-skip-sampling", fpath_data3x6], data3x6ExpectedBernoulliSkipP40);
    testTsvSample(["test-ab7b", "--line-buffered", "-H", "-s", "-p", "0.40", "--prefer-skip-sampling", fpath_data3x6], data3x6ExpectedBernoulliSkipP40);

    /* Distinct sampling cases. */
    testTsvSample(["test-a23", "--header", "--static-seed", "--prob", "0.001", "--key-fields", "1", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-a24", "--header", "--static-seed", "--prob", "0.001", "--key-fields", "1", fpath_data3x0], data3x0);
    testTsvSample(["test-a24b", "--header", "--static-seed", "--prob", "0.001", "--key-fields", "field_a", fpath_data3x0], data3x0);
    testTsvSample(["test-a25", "-H", "-s", "-p", "1.0", "-k", "2", fpath_data3x1], data3x1);
    testTsvSample(["test-a25b", "-H", "-s", "-p", "1.0", "-k", "field_b", fpath_data3x1], data3x1);
    testTsvSample(["test-a26", "-H", "-s", "-p", "1.0", "-k", "2", fpath_data3x6], data3x6);
    testTsvSample(["test-a26b", "-H", "-s", "-p", "1.0", "-k", "field_b", fpath_data3x6], data3x6);
    testTsvSample(["test-a27", "-H", "-s", "-p", "0.6", "-k", "1,3", fpath_data3x6], data3x6ExpectedDistinctK1K3P60);
    testTsvSample(["test-a27b", "-H", "-s", "-p", "0.6", "-k", "field_a,field_c", fpath_data3x6], data3x6ExpectedDistinctK1K3P60);
    testTsvSample(["test-a27c", "--line-buffered", "-H", "-s", "-p", "0.6", "-k", "field_a,field_c", fpath_data3x6], data3x6ExpectedDistinctK1K3P60);

    /* Generating random weights. Use Bernoulli sampling test set at prob 100% for uniform sampling.
     * For weighted sampling, use the weighted cases, but with expected using the original ordering.
     */
    testTsvSample(["test-a28", "-H", "-s", "--gen-random-inorder", fpath_data3x6], data3x6ExpectedBernoulliProbsP100);
    testTsvSample(["test-a29", "-H", "-s", "--gen-random-inorder", fpath_data3x6], data3x6ExpectedBernoulliProbsP100);
    testTsvSample(["test-a30", "-H", "-s", "--gen-random-inorder", "--weight-field", "3", fpath_data3x6],
                  data3x6ExpectedWt3ProbsInorder);
    testTsvSample(["test-a30b", "-H", "-s", "--gen-random-inorder", "--weight-field", "field_c", fpath_data3x6],
                  data3x6ExpectedWt3ProbsInorder);
    testTsvSample(["test-a31", "-H", "-v", "41", "--gen-random-inorder", "--weight-field", "3", fpath_data3x6],
                  data3x6ExpectedWt3V41ProbsInorder);
    testTsvSample(["test-a32", "-H", "-s", "-p", "0.6", "-k", "1,3", "--print-random", fpath_data3x6],
                  data3x6ExpectedDistinctK1K3P60Probs);
    testTsvSample(["test-a32b", "-H", "-s", "-p", "0.6", "-k", "field_a,field_c", "--print-random", fpath_data3x6],
                  data3x6ExpectedDistinctK1K3P60Probs);
    testTsvSample(["test-a33", "-H", "-s", "-p", "0.6", "-k", "1,3", "--print-random", "--random-value-header",
                   "custom_random_value_header", fpath_data3x6], data3x6ExpectedDistinctK1K3P60ProbsRVCustom);
    testTsvSample(["test-a34", "-H", "-s", "-p", "0.2", "-k", "2", "--gen-random-inorder", fpath_data3x6],
                  data3x6ExpectedDistinctK2P2ProbsInorder);
    testTsvSample(["test-a34b", "--line-buffered", "-H", "-s", "-p", "0.2", "-k", "2", "--gen-random-inorder", fpath_data3x6],
                  data3x6ExpectedDistinctK2P2ProbsInorder);

    /* Simple random sampling with replacement. */
    testTsvSample(["test-a35", "-H", "-s", "--replace", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-a36", "-H", "-s", "--replace", "--num", "3", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-a37", "-H", "-s", "--replace", fpath_data3x0], data3x0);
    testTsvSample(["test-a38", "-H", "-s", "--replace", "--num", "3", fpath_data3x0], data3x0);
    testTsvSample(["test-a39", "-H", "-s", "--replace", "--num", "3", fpath_data3x1], data3x1ExpectedReplaceNum3);
    testTsvSample(["test-a40", "-H", "-s", "--replace", "--num", "10", fpath_data3x6], data3x6ExpectedReplaceNum10);
    testTsvSample(["test-a41", "-H", "-s", "-v", "77", "--replace", "--num", "10", fpath_data3x6], data3x6ExpectedReplaceNum10V77);
    testTsvSample(["test-a41b", "--line-buffered", "-H", "-s", "-v", "77", "--replace", "--num", "10", fpath_data3x6], data3x6ExpectedReplaceNum10V77);

    /* Shuffling, compatibility mode, without headers. */
    testTsvSample(["test-b1", "-s", "--compatibility-mode", fpath_data3x1_noheader], data3x1[1 .. $]);
    testTsvSample(["test-b2", "-s", "--compatibility-mode", fpath_data3x2_noheader], data3x2PermuteCompat[1 .. $]);
    testTsvSample(["test-b3", "-s", "--compatibility-mode", fpath_data3x3_noheader], data3x3ExpectedPermuteCompat[1 .. $]);
    testTsvSample(["test-b4", "-s", "--compatibility-mode", fpath_data3x6_noheader], data3x6ExpectedPermuteCompat[1 .. $]);
    testTsvSample(["test-b5", "-s", "--print-random", fpath_data3x6_noheader], data3x6ExpectedPermuteCompatProbs[1 .. $]);
    testTsvSample(["test-b6", "-s", "--weight-field", "3", "--compatibility-mode", fpath_data3x6_noheader], data3x6ExpectedPermuteWt3[1 .. $]);
    testTsvSample(["test-b7", "-s", "--print-random", "-w", "3", fpath_data3x6_noheader], data3x6ExpectedPermuteWt3Probs[1 .. $]);
    testTsvSample(["test-b8", "-v", "41", "--print-random", fpath_data3x6_noheader], data3x6ExpectedPermuteCompatV41Probs[1 .. $]);
    testTsvSample(["test-b9", "-v", "41", "-w", "3", "--print-random", fpath_data3x6_noheader], data3x6ExpectedPermuteWt3V41Probs[1 .. $]);
    testTsvSample(["test-b9b", "--line-buffered", "-v", "41", "-w", "3", "--print-random", fpath_data3x6_noheader], data3x6ExpectedPermuteWt3V41Probs[1 .. $]);

    /* Shuffling, no headers, without compatibility mode, or with printing and compatibility mode. */
    testTsvSample(["test-bb1", "-s", fpath_data3x1_noheader], data3x1[1 .. $]);
    testTsvSample(["test-bb2", "-s", fpath_data3x2_noheader], data3x2PermuteShuffle[1 .. $]);
    testTsvSample(["test-bb3", "-s", fpath_data3x3_noheader], data3x3ExpectedPermuteSwap[1 .. $]);
    testTsvSample(["test-bb4", "-s", fpath_data3x6_noheader], data3x6ExpectedPermuteSwap[1 .. $]);
    testTsvSample(["test-bb5", "-s", "--weight-field", "3", fpath_data3x6_noheader], data3x6ExpectedPermuteWt3[1 .. $]);
    testTsvSample(["test-bb6", "-s", "--print-random", "-w", "3", "--compatibility-mode", fpath_data3x6_noheader], data3x6ExpectedPermuteWt3Probs[1 .. $]);
    testTsvSample(["test-bb7", "-v", "41", "--print-random", "--compatibility-mode", fpath_data3x6_noheader], data3x6ExpectedPermuteCompatV41Probs[1 .. $]);
    testTsvSample(["test-bb7b", "--line-buffered", "-v", "41", "--print-random", "--compatibility-mode", fpath_data3x6_noheader], data3x6ExpectedPermuteCompatV41Probs[1 .. $]);

    /* Reservoir sampling using Algorithm R, no headers. */
    testTsvSample(["test-ac10", "--prefer-algorithm-r", "--static-seed", "--num", "1", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-ac11", "--prefer-algorithm-r", "--static-seed", "--num", "2", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-ac14", "--prefer-algorithm-r", "-s", "--num", "1", fpath_data3x1_noheader], data3x1[1 .. $]);
    testTsvSample(["test-ac15", "--prefer-algorithm-r", "-s", "--num", "2", fpath_data3x1_noheader], data3x1[1 .. $]);
    testTsvSample(["test-ac16", "--prefer-algorithm-r", "-s", "--num", "7", fpath_data3x6_noheader], data3x6ExpectedSampleAlgoRNum6[1 .. $]);
    testTsvSample(["test-ac17", "--prefer-algorithm-r", "-s", "--num", "6", fpath_data3x6_noheader], data3x6ExpectedSampleAlgoRNum6[1 .. $]);
    testTsvSample(["test-ac18", "--prefer-algorithm-r", "-s", "--num", "5", fpath_data3x6_noheader], data3x6ExpectedSampleAlgoRNum5[1 .. $]);
    testTsvSample(["test-ac19", "--prefer-algorithm-r", "-s", "--num", "4", fpath_data3x6_noheader], data3x6ExpectedSampleAlgoRNum4[1 .. $]);
    testTsvSample(["test-ac20", "--prefer-algorithm-r", "-s", "--num", "3", fpath_data3x6_noheader], data3x6ExpectedSampleAlgoRNum3[1 .. $]);
    testTsvSample(["test-ac21", "--prefer-algorithm-r", "-s", "--num", "2", fpath_data3x6_noheader], data3x6ExpectedSampleAlgoRNum2[1 .. $]);
    testTsvSample(["test-ac22", "--prefer-algorithm-r", "-s", "--num", "1", fpath_data3x6_noheader], data3x6ExpectedSampleAlgoRNum1[1 .. $]);
    testTsvSample(["test-ac22b", "--line-buffered", "--prefer-algorithm-r", "-s", "--num", "1", fpath_data3x6_noheader], data3x6ExpectedSampleAlgoRNum1[1 .. $]);

    /* Reservoir sampling using Algorithm R, no headers, inorder output. */
    testTsvSample(["test-aj10", "--prefer-algorithm-r", "--static-seed", "--num", "1", "-i", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-aj11", "--prefer-algorithm-r", "--static-seed", "--num", "2", "-i", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-aj14", "--prefer-algorithm-r", "-s", "--num", "1", "-i", fpath_data3x1_noheader], data3x1[1 .. $]);
    testTsvSample(["test-aj15", "--prefer-algorithm-r", "-s", "--num", "2", "-i", fpath_data3x1_noheader], data3x1[1 .. $]);
    testTsvSample(["test-aj16", "--prefer-algorithm-r", "-s", "--num", "7", "-i", fpath_data3x6_noheader], data3x6ExpectedSampleAlgoRNum6Inorder[1 .. $]);
    testTsvSample(["test-aj17", "--prefer-algorithm-r", "-s", "--num", "6", "-i", fpath_data3x6_noheader], data3x6ExpectedSampleAlgoRNum6Inorder[1 .. $]);
    testTsvSample(["test-aj18", "--prefer-algorithm-r", "-s", "--num", "5", "-i", fpath_data3x6_noheader], data3x6ExpectedSampleAlgoRNum5Inorder[1 .. $]);
    testTsvSample(["test-aj19", "--prefer-algorithm-r", "-s", "--num", "4", "-i", fpath_data3x6_noheader], data3x6ExpectedSampleAlgoRNum4Inorder[1 .. $]);
    testTsvSample(["test-aj20", "--prefer-algorithm-r", "-s", "--num", "3", "-i", fpath_data3x6_noheader], data3x6ExpectedSampleAlgoRNum3Inorder[1 .. $]);
    testTsvSample(["test-aj21", "--prefer-algorithm-r", "-s", "--num", "2", "-i", fpath_data3x6_noheader], data3x6ExpectedSampleAlgoRNum2Inorder[1 .. $]);
    testTsvSample(["test-aj22", "--prefer-algorithm-r", "-s", "--num", "1", "-i", fpath_data3x6_noheader], data3x6ExpectedSampleAlgoRNum1Inorder[1 .. $]);
    testTsvSample(["test-aj22b", "--line-buffered", "--prefer-algorithm-r", "-s", "--num", "1", "-i", fpath_data3x6_noheader], data3x6ExpectedSampleAlgoRNum1Inorder[1 .. $]);

    /* Bernoulli sampling cases. */
    testTsvSample(["test-b10", "-s", "-p", "1.0", fpath_data3x1_noheader], data3x1[1 .. $]);
    testTsvSample(["test-b11", "-s", "-p", "1.0", fpath_data3x6_noheader], data3x6[1 .. $]);
    testTsvSample(["test-b12", "-p", "1.0", fpath_data3x6_noheader], data3x6[1 .. $]);
    testTsvSample(["test-b13", "-s", "--prob", "1.0", "--print-random", fpath_data3x6_noheader], data3x6ExpectedBernoulliProbsP100[1 .. $]);
    testTsvSample(["test-b14", "-s", "--prob", "0.60", "--print-random", fpath_data3x6_noheader], data3x6ExpectedBernoulliCompatProbsP60[1 .. $]);
    testTsvSample(["test-b15", "-v", "41", "--prob", "0.60", "--print-random", fpath_data3x6_noheader], data3x6ExpectedBernoulliCompatP60V41Probs[1 .. $]);
    testTsvSample(["test-b15b", "--line-buffered", "-v", "41", "--prob", "0.60", "--print-random", fpath_data3x6_noheader], data3x6ExpectedBernoulliCompatP60V41Probs[1 .. $]);

    /* Bernoulli sampling with probabilities in skip sampling range. */
    testTsvSample(["test-bb1", "-v", "333", "-p", "0.01", fpath_data1x200_noheader], data1x200ExpectedBernoulliSkipV333P01[1 .. $]);
    testTsvSample(["test-bb2", "-v", "333", "-p", "0.02", fpath_data1x200_noheader], data1x200ExpectedBernoulliSkipV333P02[1 .. $]);
    testTsvSample(["test-bb3", "-v", "333", "-p", "0.03", fpath_data1x200_noheader], data1x200ExpectedBernoulliSkipV333P03[1 .. $]);
    testTsvSample(["test-bb4", "-v", "333", "-p", "0.01", "--compatibility-mode", fpath_data1x200_noheader], data1x200ExpectedBernoulliCompatV333P01[1 .. $]);
    testTsvSample(["test-bb5", "-v", "333", "-p", "0.02", "--compatibility-mode", fpath_data1x200_noheader], data1x200ExpectedBernoulliCompatV333P02[1 .. $]);
    testTsvSample(["test-bb6", "-v", "333", "-p", "0.03", "--compatibility-mode", fpath_data1x200_noheader], data1x200ExpectedBernoulliCompatV333P03[1 .. $]);
    testTsvSample(["test-bb7", "-s", "-p", "0.40", "--prefer-skip-sampling", fpath_data3x6_noheader], data3x6ExpectedBernoulliSkipP40[1 .. $]);
    testTsvSample(["test-bb7b", "--line-buffered", "-s", "-p", "0.40", "--prefer-skip-sampling", fpath_data3x6_noheader], data3x6ExpectedBernoulliSkipP40[1 .. $]);

    /* Distinct sampling cases. */
    testTsvSample(["test-b16", "-s", "-p", "1.0", "-k", "2", fpath_data3x1_noheader], data3x1[1 .. $]);
    testTsvSample(["test-b17", "-s", "-p", "1.0", "-k", "2", fpath_data3x6_noheader], data3x6[1 .. $]);
    testTsvSample(["test-b18", "-p", "1.0", "-k", "2", fpath_data3x6_noheader], data3x6[1 .. $]);
    testTsvSample(["test-b19", "-v", "71563", "-p", "1.0", "-k", "2", fpath_data3x6_noheader], data3x6[1 .. $]);
    testTsvSample(["test-b19b", "--line-buffered", "-v", "71563", "-p", "1.0", "-k", "2", fpath_data3x6_noheader], data3x6[1 .. $]);

    /* Generating random weights. Reuse Bernoulli sampling tests at prob 100%. */
    testTsvSample(["test-b20", "-s", "--gen-random-inorder", fpath_data3x6_noheader], data3x6ExpectedBernoulliProbsP100[1 .. $]);
    testTsvSample(["test-b23", "-v", "41", "--gen-random-inorder", "--weight-field", "3", fpath_data3x6_noheader], data3x6ExpectedWt3V41ProbsInorder[1 .. $]);
    testTsvSample(["test-b24", "-s", "-p", "0.6", "-k", "1,3", "--print-random", fpath_data3x6_noheader],
                  data3x6ExpectedDistinctK1K3P60Probs[1 .. $]);
    testTsvSample(["test-b24", "-s", "-p", "0.2", "-k", "2", "--gen-random-inorder", fpath_data3x6_noheader],
                  data3x6ExpectedDistinctK2P2ProbsInorder[1 .. $]);
    testTsvSample(["test-b24b", "--line-buffered", "-s", "-p", "0.2", "-k", "2", "--gen-random-inorder", fpath_data3x6_noheader],
                  data3x6ExpectedDistinctK2P2ProbsInorder[1 .. $]);

    /* Simple random sampling with replacement. */
    testTsvSample(["test-b25", "-s", "--replace", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-b26", "-s", "-r", "--num", "3", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-b27", "-s", "-r", "-n", "3", fpath_data3x1_noheader], data3x1ExpectedReplaceNum3[1 .. $]);
    testTsvSample(["test-b28", "-s", "--replace", "-n", "10", fpath_data3x6_noheader], data3x6ExpectedReplaceNum10[1 .. $]);
    testTsvSample(["test-b29", "-s", "-v", "77", "--replace", "--num", "10", fpath_data3x6_noheader], data3x6ExpectedReplaceNum10V77[1 .. $]);
    testTsvSample(["test-b29b", "--line-buffered", "-s", "-v", "77", "--replace", "--num", "10", fpath_data3x6_noheader], data3x6ExpectedReplaceNum10V77[1 .. $]);

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
    testTsvSample(["test-c3b", "--header", "--static-seed", "--print-random", "--weight-field", "field_c",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedPermuteWt3Probs);
    testTsvSample(["test-c4", "--header", "--static-seed", "--weight-field", "3", "--compatibility-mode",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedPermuteWt3);
    testTsvSample(["test-c5", "--header", "--static-seed", "--prefer-algorithm-r", "--num", "4",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedSampleAlgoRNum4);
    testTsvSample(["test-c5b", "--header", "--static-seed", "--prefer-algorithm-r", "--num", "4", "--inorder",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedSampleAlgoRNum4Inorder);

    /* Multi-file, no headers. */
    testTsvSample(["test-c6", "--static-seed", "--compatibility-mode",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedPermuteCompat[1 .. $]);
    testTsvSample(["test-c7", "--static-seed", "--print-random",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedPermuteCompatProbs[1 .. $]);
    testTsvSample(["test-c8", "--static-seed", "--print-random", "--weight-field", "3",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedPermuteWt3Probs[1 .. $]);
    testTsvSample(["test-c9", "--static-seed", "--weight-field", "3", "--compatibility-mode",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedPermuteWt3[1 .. $]);
    testTsvSample(["test-c10", "--static-seed", "--prefer-algorithm-r", "--num", "4",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedSampleAlgoRNum4[1 .. $]);
    testTsvSample(["test-c10b", "--static-seed", "--prefer-algorithm-r", "--num", "4", "--inorder",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedSampleAlgoRNum4Inorder[1 .. $]);

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
                  combo1ExpectedBernoulliCompatP50Probs[1 .. $]);
    testTsvSample(["test-c14", "--static-seed", "--prob", ".4",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedBernoulliCompatP40[1 .. $]);
    testTsvSample(["test-c14b", "--line-buffered", "--static-seed", "--prob", ".4",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedBernoulliCompatP40[1 .. $]);

    /* Bernoulli sampling with probabilities in skip sampling range. */
    testTsvSample(["test-cc1", "-H", "-v", "333", "-p", "0.03",
                   fpath_data3x0, fpath_data3x1, fpath_data1x200, fpath_dataEmpty, fpath_data1x10],
                  combo2ExpectedBernoulliSkipV333P03);
    testTsvSample(["test-cc2", "-v", "333", "-p", "0.03",
                   fpath_data3x1_noheader, fpath_data1x200_noheader, fpath_dataEmpty, fpath_data1x10_noheader],
                  combo2ExpectedBernoulliSkipV333P03[1 .. $]);
    testTsvSample(["test-cc3", "--line-buffered", "-v", "333", "-p", "0.03",
                   fpath_data3x1_noheader, fpath_data1x200_noheader, fpath_dataEmpty, fpath_data1x10_noheader],
                  combo2ExpectedBernoulliSkipV333P03[1 .. $]);

    /* Distinct sampling cases. */
    testTsvSample(["test-c15", "--header", "--static-seed", "--key-fields", "1", "--prob", ".4",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedDistinctK1P40);
    testTsvSample(["test-c15b", "--header", "--static-seed", "--key-fields", "field_a", "--prob", ".4",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedDistinctK1P40);
    testTsvSample(["test-c15c", "--line-buffered", "--header", "--static-seed", "--key-fields", "field_a", "--prob", ".4",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedDistinctK1P40);
    testTsvSample(["test-c16", "--static-seed", "--key-fields", "1", "--prob", ".4",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedDistinctK1P40[1 .. $]);
    testTsvSample(["test-c16b", "--line-buffered", "--static-seed", "--key-fields", "1", "--prob", ".4",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedDistinctK1P40[1 .. $]);

    /* Generating random weights. */
    testTsvSample(["test-c17", "--header", "--static-seed", "--gen-random-inorder",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedProbsInorder);
    testTsvSample(["test-c18", "--static-seed", "--gen-random-inorder",
                   fpath_data3x3_noheader, fpath_data3x1_noheader,
                   fpath_dataEmpty, fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedProbsInorder[1 .. $]);

    /* Simple random sampling with replacement. */
    testTsvSample(["test-c19", "--header", "--static-seed", "--replace", "--num", "10",
                   fpath_data3x0, fpath_data3x3, fpath_data3x1, fpath_dataEmpty, fpath_data3x6, fpath_data3x2],
                  combo1ExpectedReplaceNum10);

    testTsvSample(["test-c20", "--static-seed", "--replace", "--num", "10",
                   fpath_data3x3_noheader, fpath_data3x1_noheader, fpath_dataEmpty,
                   fpath_data3x6_noheader, fpath_data3x2_noheader],
                  combo1ExpectedReplaceNum10[1 .. $]);

    /* Single column file. */
    testTsvSample(["test-d1", "-H", "-s", "--compatibility-mode", fpath_data1x10], data1x10ExpectedPermuteCompat);
    testTsvSample(["test-d2", "-H", "-s", "--compatibility-mode", fpath_data1x10], data1x10ExpectedPermuteCompat);

    /* Distributions. */
    testTsvSample(["test-e1", "-H", "-s", "-w", "2", "--print-random", fpath_data2x10a], data2x10aExpectedPermuteWt2Probs);
    testTsvSample(["test-e1b", "-H", "-s", "-w", "weight", "--print-random", fpath_data2x10a], data2x10aExpectedPermuteWt2Probs);
    testTsvSample(["test-e2", "-H", "-s", "-w", "2", "--print-random", fpath_data2x10b], data2x10bExpectedPermuteWt2Probs);
    testTsvSample(["test-e3", "-H", "-s", "-w", "2", "--print-random", fpath_data2x10c], data2x10cExpectedPermuteWt2Probs);
    testTsvSample(["test-e4", "-H", "-s", "-w", "2", "--print-random", fpath_data2x10d], data2x10dExpectedPermuteWt2Probs);
    testTsvSample(["test-e5", "-H", "-s", "-w", "2", "--print-random", fpath_data2x10e], data2x10eExpectedPermuteWt2Probs);

    /* Tests of subset sample (--n|num) field. Random sampling, Bernoulli sampling, distinct sampling.
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

    /* Inorder sampling tests using reservoir sampling via heap (compatibility mode). */
    testTsvSample(["test-ar10", "--compatibility-mode", "--header", "--static-seed", "--num", "1", "--inorder", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-ar11", "--compatibility-mode", "--header", "--static-seed", "--num", "2", "--inorder", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-ar12", "--compatibility-mode", "-H", "-s", "--num", "1", "--inorder", fpath_data3x0], data3x0);
    testTsvSample(["test-ar13", "--compatibility-mode", "-H", "-s", "--num", "2", "--inorder", fpath_data3x0], data3x0);
    testTsvSample(["test-ar14", "--compatibility-mode", "-H", "-s", "--num", "1", "--inorder", fpath_data3x1], data3x1);
    testTsvSample(["test-ar15", "--compatibility-mode", "-H", "-s", "--num", "2", "-i", fpath_data3x1], data3x1);
    testTsvSample(["test-ar16", "--compatibility-mode", "-H", "-s", "--num", "7", "-i", fpath_data3x6], data3x6ExpectedSampleCompatNum6Inorder);
    testTsvSample(["test-ar17", "--compatibility-mode", "-H", "-s", "--num", "6", "-i", fpath_data3x6], data3x6ExpectedSampleCompatNum6Inorder);
    testTsvSample(["test-ar18", "--compatibility-mode", "-H", "-s", "--num", "5", "-i", fpath_data3x6], data3x6ExpectedSampleCompatNum5Inorder);
    testTsvSample(["test-ar19", "--compatibility-mode", "-H", "-s", "--num", "4", "-i", fpath_data3x6],         data3x6ExpectedSampleCompatNum4Inorder);
    testTsvSample(["test-ar20", "--compatibility-mode", "-H", "-s", "--num", "3", "-i", fpath_data3x6], data3x6ExpectedSampleCompatNum3Inorder);
    testTsvSample(["test-ar21", "--compatibility-mode", "-H", "-s", "--num", "2", "-i", fpath_data3x6], data3x6ExpectedSampleCompatNum2Inorder);
    testTsvSample(["test-ar22", "--compatibility-mode", "-H", "-s", "--num", "1", "-i", fpath_data3x6], data3x6ExpectedSampleCompatNum1Inorder);

    testTsvSample(["test-as10", "--compatibility-mode", "--static-seed", "--num", "1", "-i", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-as11", "--compatibility-mode", "--static-seed", "--num", "2", "-i", fpath_dataEmpty], dataEmpty);
    testTsvSample(["test-as14", "--compatibility-mode", "-s", "--num", "1", "-i", fpath_data3x1_noheader], data3x1[1 .. $]);
    testTsvSample(["test-as15", "--compatibility-mode", "-s", "--num", "2", "-i", fpath_data3x1_noheader], data3x1[1 .. $]);
    testTsvSample(["test-as16", "--compatibility-mode", "-s", "--num", "7", "-i", fpath_data3x6_noheader], data3x6ExpectedSampleCompatNum6Inorder[1 .. $]);
    testTsvSample(["test-as17", "--compatibility-mode", "-s", "--num", "6", "-i", fpath_data3x6_noheader], data3x6ExpectedSampleCompatNum6Inorder[1 .. $]);
    testTsvSample(["test-as18", "--compatibility-mode", "-s", "--num", "5", "-i", fpath_data3x6_noheader], data3x6ExpectedSampleCompatNum5Inorder[1 .. $]);
    testTsvSample(["test-as19", "--compatibility-mode", "-s", "--num", "4", "-i", fpath_data3x6_noheader], data3x6ExpectedSampleCompatNum4Inorder[1 .. $]);
    testTsvSample(["test-as20", "--compatibility-mode", "-s", "--num", "3", "-i", fpath_data3x6_noheader], data3x6ExpectedSampleCompatNum3Inorder[1 .. $]);
    testTsvSample(["test-as21", "--compatibility-mode", "-s", "--num", "2", "-i", fpath_data3x6_noheader], data3x6ExpectedSampleCompatNum2Inorder[1 .. $]);
    testTsvSample(["test-as22", "--compatibility-mode", "-s", "--num", "1", "-i", fpath_data3x6_noheader], data3x6ExpectedSampleCompatNum1Inorder[1 .. $]);

    /* Inorder sampling tests with random number printing. --compatibility-mode not needed. */
    testTsvSample(["test-at16", "--compatibility-mode", "-H", "-s", "--num", "7", "-i", "--print-random", fpath_data3x6], data3x6ExpectedSampleCompatNum6ProbsInorder);
    testTsvSample(["test-at17", "--compatibility-mode", "-H", "-s", "--num", "6", "-i", "--print-random", fpath_data3x6], data3x6ExpectedSampleCompatNum6ProbsInorder);
    testTsvSample(["test-at18", "--compatibility-mode", "-H", "-s", "--num", "5", "-i", "--print-random", fpath_data3x6], data3x6ExpectedSampleCompatNum5ProbsInorder);
    testTsvSample(["test-at19", "--compatibility-mode", "-H", "-s", "--num", "4", "-i", "--print-random", fpath_data3x6], data3x6ExpectedSampleCompatNum4ProbsInorder);
    testTsvSample(["test-at19",                         "-H", "-s", "--num", "4", "-i", "--print-random", fpath_data3x6], data3x6ExpectedSampleCompatNum4ProbsInorder);
    testTsvSample(["test-at20", "--compatibility-mode", "-H", "-s", "--num", "3", "-i", "--print-random", fpath_data3x6], data3x6ExpectedSampleCompatNum3ProbsInorder);
    testTsvSample(["test-at20",                         "-H", "-s", "--num", "3", "-i", "--print-random", fpath_data3x6], data3x6ExpectedSampleCompatNum3ProbsInorder);
    testTsvSample(["test-at21", "--compatibility-mode", "-H", "-s", "--num", "2", "-i", "--print-random", fpath_data3x6], data3x6ExpectedSampleCompatNum2ProbsInorder);
    testTsvSample(["test-at22", "--compatibility-mode", "-H", "-s", "--num", "1", "-i", "--print-random", fpath_data3x6], data3x6ExpectedSampleCompatNum1ProbsInorder);

    testTsvSample(["test-au16", "--compatibility-mode", "-s", "--num", "7", "-i", "--print-random", fpath_data3x6_noheader], data3x6ExpectedSampleCompatNum6ProbsInorder[1 .. $]);
    testTsvSample(["test-au17", "--compatibility-mode", "-s", "--num", "6", "-i", "--print-random", fpath_data3x6_noheader], data3x6ExpectedSampleCompatNum6ProbsInorder[1 .. $]);
    testTsvSample(["test-au18", "--compatibility-mode", "-s", "--num", "5", "-i", "--print-random", fpath_data3x6_noheader], data3x6ExpectedSampleCompatNum5ProbsInorder[1 .. $]);
    testTsvSample(["test-au19", "--compatibility-mode", "-s", "--num", "4", "-i", "--print-random", fpath_data3x6_noheader], data3x6ExpectedSampleCompatNum4ProbsInorder[1 .. $]);
    testTsvSample(["test-au19",                         "-s", "--num", "4", "-i", "--print-random", fpath_data3x6_noheader], data3x6ExpectedSampleCompatNum4ProbsInorder[1 .. $]);
    testTsvSample(["test-au20", "--compatibility-mode", "-s", "--num", "3", "-i", "--print-random", fpath_data3x6_noheader], data3x6ExpectedSampleCompatNum3ProbsInorder[1 .. $]);
    testTsvSample(["test-au21", "--compatibility-mode", "-s", "--num", "2", "-i", "--print-random", fpath_data3x6_noheader], data3x6ExpectedSampleCompatNum2ProbsInorder[1 .. $]);
    testTsvSample(["test-au22", "--compatibility-mode", "-s", "--num", "1", "-i", "--print-random", fpath_data3x6_noheader], data3x6ExpectedSampleCompatNum1ProbsInorder[1 .. $]);

    /* Inorder weighted sampling tests. */
    testTsvSample(["test-ax16", "-H", "-s", "-n", "7", "-i", fpath_data3x6], data3x6ExpectedWt3Num6Inorder);
    testTsvSample(["test-ax17", "-H", "-s", "-n", "6", "-i", fpath_data3x6], data3x6ExpectedWt3Num6Inorder);
    testTsvSample(["test-ax18", "-H", "-s", "-n", "5", "-i", fpath_data3x6], data3x6ExpectedWt3Num5Inorder);
    testTsvSample(["test-ax19", "-H", "-s", "-n", "4", "-i", fpath_data3x6], data3x6ExpectedWt3Num4Inorder);
    testTsvSample(["test-ax20", "-H", "-s", "-n", "3", "-i", fpath_data3x6], data3x6ExpectedWt3Num3Inorder);
    testTsvSample(["test-ax21", "-H", "-s", "-n", "2", "-i", fpath_data3x6], data3x6ExpectedWt3Num2Inorder);
    testTsvSample(["test-ax22", "-H", "-s", "-n", "1", "-i", fpath_data3x6], data3x6ExpectedWt3Num1Inorder);

    testTsvSample(["test-ay16", "-s", "-n", "7", "-i", fpath_data3x6_noheader], data3x6ExpectedWt3Num6Inorder[1 .. $]);
    testTsvSample(["test-ay17", "-s", "-n", "6", "-i", fpath_data3x6_noheader], data3x6ExpectedWt3Num6Inorder[1 .. $]);
    testTsvSample(["test-ay18", "-s", "-n", "5", "-i", fpath_data3x6_noheader], data3x6ExpectedWt3Num5Inorder[1 .. $]);
    testTsvSample(["test-ay19", "-s", "-n", "4", "-i", fpath_data3x6_noheader], data3x6ExpectedWt3Num4Inorder[1 .. $]);
    testTsvSample(["test-ay20", "-s", "-n", "3", "-i", fpath_data3x6_noheader], data3x6ExpectedWt3Num3Inorder[1 .. $]);
    testTsvSample(["test-ay21", "-s", "-n", "2", "-i", fpath_data3x6_noheader], data3x6ExpectedWt3Num2Inorder[1 .. $]);
    testTsvSample(["test-ay22", "-s", "-n", "1", "-i", fpath_data3x6_noheader], data3x6ExpectedWt3Num1Inorder[1 .. $]);

    /*
     * Distinct sampling tests.
     */
    testTsvSample(["test-j1", "--header", "--static-seed", "--prob", "0.40", "--key-fields", "2", fpath_data5x25],
                  data5x25ExpectedDistinctK2P40);

    testTsvSample(["test-j1b", "--header", "--static-seed", "--prob", "0.40", "--key-fields", "Shape", fpath_data5x25],
                  data5x25ExpectedDistinctK2P40);

    testTsvSample(["test-j2", "-H", "-s", "-p", "0.20", "-k", "2,4", fpath_data5x25],
                  data5x25ExpectedDistinctK2K4P20);

    testTsvSample(["test-j2b", "-H", "-s", "-p", "0.20", "-k", "Shape,Size", fpath_data5x25],
                  data5x25ExpectedDistinctK2K4P20);

    testTsvSample(["test-j3", "-H", "-s", "-p", "0.20", "-k", "2-4", fpath_data5x25],
                  data5x25ExpectedDistinctK2K3K4P20);

    testTsvSample(["test-j3b", "-H", "-s", "-p", "0.20", "-k", "Shape-Size", fpath_data5x25],
                  data5x25ExpectedDistinctK2K3K4P20);

    testTsvSample(["test-j4", "--static-seed", "--prob", "0.40", "--key-fields", "2", fpath_data5x25_noheader],
                  data5x25ExpectedDistinctK2P40[1 .. $]);

    testTsvSample(["test-j5", "-s", "-p", "0.20", "-k", "2,4", fpath_data5x25_noheader],
                  data5x25ExpectedDistinctK2K4P20[1 .. $]);

    testTsvSample(["test-j6", "-s", "-p", "0.20", "-k", "2-4", fpath_data5x25_noheader],
                  data5x25ExpectedDistinctK2K3K4P20[1 .. $]);


    /* These distinct tests check that the whole line as '-k 0' and specifying all fields
     * in order have the same result. Also that field numbers don't matter, as '-k 1,2'
     * in data2x25 are the same keys as '-k 2,4' in data5x25.
     */
    testTsvSample(["test-j7", "-H", "-s", "-p", "0.20", "-k", "1,2", fpath_data2x25],
                  data2x25ExpectedDistinctK1K2P20);

    testTsvSample(["test-j8", "-H", "-s", "-p", "0.20", "-k", "0", fpath_data2x25],
                  data2x25ExpectedDistinctK1K2P20);

    testTsvSample(["test-j8b", "-H", "-s", "-p", "0.20", "-k", "*", fpath_data2x25],
                  data2x25ExpectedDistinctK1K2P20);

    testTsvSample(["test-j9", "-s", "-p", "0.20", "-k", "1,2", fpath_data2x25_noheader],
                  data2x25ExpectedDistinctK1K2P20[1 .. $]);

    testTsvSample(["test-j10", "-s", "-p", "0.20", "-k", "0", fpath_data2x25_noheader],
                  data2x25ExpectedDistinctK1K2P20[1 .. $]);

    /* Similar to the last set, but for a 1-column file. Also with random value printing. */
    testTsvSample(["test-j11", "-H", "-s", "-p", "0.20", "-k", "1", fpath_data1x25],
                  data1x25ExpectedDistinctK1P20);

    testTsvSample(["test-j12", "-H", "-s", "-p", "0.20", "-k", "0", fpath_data1x25],
                  data1x25ExpectedDistinctK1P20);

    testTsvSample(["test-j12b", "-H", "-s", "-p", "0.20", "-k", "*", fpath_data1x25],
                  data1x25ExpectedDistinctK1P20);

    testTsvSample(["test-j13", "-s", "-p", "0.20", "-k", "1", fpath_data1x25_noheader],
                  data1x25ExpectedDistinctK1P20[1 .. $]);

    testTsvSample(["test-j14", "-s", "-p", "0.20", "-k", "0", fpath_data1x25_noheader],
                  data1x25ExpectedDistinctK1P20[1 .. $]);

    testTsvSample(["test-j15", "-H", "-s", "-p", "0.20", "-k", "1", "--print-random", fpath_data1x25],
                  data1x25ExpectedDistinctK1P20Probs);

    testTsvSample(["test-j15b", "-H", "-s", "-p", "0.20", "-k", `Shape\-Size`, "--print-random", fpath_data1x25],
                  data1x25ExpectedDistinctK1P20Probs);

    testTsvSample(["test-j16", "-H", "-s", "-p", "0.20", "-k", "0", "--print-random", fpath_data1x25],
                  data1x25ExpectedDistinctK1P20Probs);

    testTsvSample(["test-j16b", "-H", "-s", "-p", "0.20", "-k", "*", "--print-random", fpath_data1x25],
                  data1x25ExpectedDistinctK1P20Probs);

    testTsvSample(["test-j17", "-s", "-p", "0.20", "-k", "1", "--print-random", fpath_data1x25_noheader],
                  data1x25ExpectedDistinctK1P20Probs[1 .. $]);

    testTsvSample(["test-j18", "-s", "-p", "0.20", "-k", "0", "--print-random", fpath_data1x25_noheader],
                  data1x25ExpectedDistinctK1P20Probs[1 .. $]);

    testTsvSample(["test-j19", "-H", "-s", "-p", "0.20", "-k", "1", "--gen-random-inorder", fpath_data1x25],
                  data1x25ExpectedDistinctK1P20ProbsInorder);

    testTsvSample(["test-j19b", "-H", "-s", "-p", "0.20", "-k", `Shape\-Size`, "--gen-random-inorder", fpath_data1x25],
                  data1x25ExpectedDistinctK1P20ProbsInorder);

    testTsvSample(["test-j20", "-H", "-s", "-p", "0.20", "-k", "0", "--gen-random-inorder", fpath_data1x25],
                  data1x25ExpectedDistinctK1P20ProbsInorder);

    testTsvSample(["test-j20b", "-H", "-s", "-p", "0.20", "-k", "*", "--gen-random-inorder", fpath_data1x25],
                  data1x25ExpectedDistinctK1P20ProbsInorder);

    testTsvSample(["test-j21", "-s", "-p", "0.20", "-k", "1", "--gen-random-inorder", fpath_data1x25_noheader],
                  data1x25ExpectedDistinctK1P20ProbsInorder[1 .. $]);

    testTsvSample(["test-j22", "-s", "-p", "0.20", "-k", "0", "--gen-random-inorder", fpath_data1x25_noheader],
                  data1x25ExpectedDistinctK1P20ProbsInorder[1 .. $]);

}
