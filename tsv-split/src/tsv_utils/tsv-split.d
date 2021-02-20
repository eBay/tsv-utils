/**
Command line tool for splitting a files (or files) into multiple output files.
Several methods for splitting are available, including splitting by line count,
splitting by random assignment, and splitting by random assignment based on
key fields.

Copyright (c) 2020-2021, eBay Inc.
Initially written by Jon Degenhardt

License: Boost License 1.0 (http://boost.org/LICENSE_1_0.txt)
*/
module tsv_utils.tsv_split;

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
     * Invokes command line argument processing and calls tsvSplit to do the real
     * work. Errors occurring during processing are caught and reported to the user.
     */
    int main(string[] cmdArgs)
    {
        /* When running in DMD code coverage mode, turn on report merging. */
        version(D_Coverage) version(DigitalMars)
        {
            import core.runtime : dmd_coverSetMerge;
            dmd_coverSetMerge(true);
        }

        TsvSplitOptions cmdopt;
        const r = cmdopt.processArgs(cmdArgs);
        if (!r[0]) return r[1];
        version(LDC_Profile)
        {
            import ldc.profile : resetAll;
            resetAll();
        }
        try
        {
            tsvSplit(cmdopt);
        }
        catch (Exception exc)
        {
            stderr.writefln("Error [%s]: %s", cmdopt.programName, exc.msg);
            return 1;
        }
        return 0;
    }
}

immutable helpText = q"EOS
Synopsis: tsv-split [options] [file...]

Split input lines into multiple output files. There are three modes of
operation:

* Fixed number of lines per file (--l|lines-per-file NUM): Each input
  block of NUM lines is written to a new file. Similar to Unix 'split'.

* Random assignment (--n|num-files NUM): Each input line is written to a
  randomly selected output file. Random selection is from NUM files.

* Random assignment by key (--n|num-files NUM, --k|key-fields FIELDS):
  Input lines are written to output files using fields as a key. Each
  unique key is randomly assigned to one of NUM output files. All lines
  with the same key are written to the same file.

By default, files are written to the current directory and have names
of the form 'part_NNN<suffix>', with 'NNN' being a number and <suffix>
being the extension of the first input file. If the input file is
'file.txt', the names will take the form 'part_NNN.txt'. The output
directory and file names are customizable.

Fields are specified using field number or field name. Field names
require that the input file has a header line.

Use '--help-verbose' for more detailed information.

Options:
EOS";

immutable helpTextVerbose = q"EOS
Synopsis: tsv-split [options] [file...]

Split input lines into multiple output files. There are three modes of
operation:

* Fixed number of lines per file (--l|lines-per-file NUM): Each input
  block of NUM lines is written to a new file. Similar to Unix 'split'.

* Random assignment (--n|num-files NUM): Each input line is written to a
  randomly selected output file. Random selection is from NUM files.

* Random assignment by key (--n|num-files NUM, --k|key-fields FIELDS):
  Input lines are written to output files using fields as a key. Each
  unique key is randomly assigned to one of NUM output files. All lines
  with the same key are written to the same file.

Output files: By default, files are written to the current directory and
have names of the form 'part_NNN<suffix>', with 'NNN' being a number and
<suffix> being the extension of the first input file. If the input file is
'file.txt', the names will take the form 'part_NNN.txt'. The suffix is
empty when reading from standard input. The numeric part defaults to 3
digits for '--l|lines-per-files'. For '--n|num-files' enough digits are
used so all filenames are the same length. The output directory and file
names are customizable.

Header lines: There are two ways to handle input with headers: write a
header to all output files (--H|header), or exclude headers from all
output files ('--I|header-in-only'). The best choice depends on the
follow-up processing. All tsv-utils tools support header lines in multiple
input files, but many other tools do not. For example, GNU parallel works
best on files without header lines.

Random assignment (--n|num-files): Random distribution of records to a set
of files is a common task. When data fits in memory the preferred approach
is usually to shuffle the data and split it into fixed sized blocks. E.g.
'tsv-sample data.tsv | tsv-split -l NUM'. However, alternate approaches
are needed when data is too large for convenient shuffling. tsv-split's
random assignment feature is useful in this case. Each input line is
written to a randomly selected output file. Note that output files will
have similar but not identical numbers of records.

Random assignment by key (--n|num-files NUM, --k|key-fields FIELDS): This
splits a data set into multiple files sharded by key. All lines with the
same key are written to the same file. This partitioning enables parallel
computation based on the key. For example, statistical calculation
('tsv-summarize --group-by') or duplicate removal ('tsv-uniq --fields').
These operations can be parallelized using tools like GNU parallel, which
simplifies concurrent operations on multiple files. Fields are specified
using field number or field name. Field names require that the input file
has a header line. Use '--help-fields' for details about field names.

Random seed: By default, each tsv-split invocation using random assignment
or random assignment by key produces different assignments to the output
files. Using '--s|static-seed' changes this so multiple runs produce the
same assignments. This works by using the same random seed each run. The
seed can be specified using '--v|seed-value'.

Appending to existing files: By default, an error is triggered if an
output file already exists. '--a|append' changes this so that lines are
appended to existing files. (Header lines are not appended to files with
data.) This is useful when adding new data to files created by a previous
tsv-split run. Random assignment should use the same '--n|num-files' value
each run, but different random seeds (avoid '--s|static-seed'). Random
assignment by key should use the same '--n|num-files', '--k|key-fields',
and seed ('--s|static-seed' or '--v|seed-value') each run.

Max number of open files: Random assignment and random assignment by key
are dramatically faster when all output files are kept open. However,
keeping a large numbers of open files can bump into system limits or limit
resources available to other processes. By default, tsv-split uses up to
4096 open files or the system per-process limit, whichever is smaller.
This can be changed using '--max-open-files', though it cannot be set
larger than the system limit. The system limit varies considerably between
systems. On many systems it is unlimited. On MacOS it is often set to 256.
Use Unix 'ulimit' to display and modify the limits:
* 'ulimit -n' - Show the "soft limit". The per-process maximum.
* 'ulimit -Hn' - Show the "hard limit". The max allowed soft limit.
* 'ulimit -Sn NUM' - Change the "soft limit" to NUM.

Examples:

  # Split a 10 million line file into 1000 files, 10,000 lines each.
  # Output files are part_000.txt, part_001.txt, ... part_999.txt.
  tsv-split data.txt --lines-per-file 10000

  # Same as the previous example, but write files to a subdirectory.
  tsv-split data.txt --dir split_files --lines-per-file 10000

  # Split a file into 10,000 line files, writing a header line to each
  tsv-split data.txt -H --lines-per-file 10000

  # Same as the previous example, but dropping the header line.
  tsv-split data.txt -I --lines-per-file 10000

  # Randomly assign lines to 1000 files
  tsv-split data.txt --num-files 1000

  # Randomly assign lines to 1000 files while keeping unique entries
  # from the 'url' field together.
  tsv-split data.tsv -H -k url --num-files 1000

  # Randomly assign lines to 1000 files. Later, randomly assign lines
  # from a second data file to the same output files.
  tsv-split data1.tsv -n 1000
  tsv-split data2.tsv -n 1000 --append

  # Randomly assign lines to 1000 files using field 3 as a key.
  # Later, add a second file to the same output files.
  tsv-split data1.tsv -n 1000 -k 3 --static-seed
  tsv-split data2.tsv -n 1000 -k 3 --static-seed --append

  # Change the system per-process open file limit for one command.
  # The parens create a sub-shell. The current shell is not changed.
  ( ulimit -Sn 1000 && tsv-split --num-files 1000 data.txt )

Options:
EOS";

/** Container for command line options and derived data.
 *
 * TsvSplitOptions handles several aspects of command line options. On the input side,
 * it defines the command line options available, performs validation, and sets up any
 * derived state based on the options provided. These activities are handled by the
 * processArgs() member.
 *
 * Once argument processing is complete, TsvSplitOptions is used as a container
 * holding the specific processing options used by the splitting algorithms.
 */
struct TsvSplitOptions
{
    import tsv_utils.common.utils : inputSourceRange, InputSourceRange, ReadHeader;

    enum invalidFileSuffix = "///////";

    string programName;                        /// Program name
    InputSourceRange inputSources;             /// Input files
    bool headerInOut = false;                  /// --H|header
    bool headerIn = false;                     /// --I|header-in-only
    size_t linesPerFile = 0;                   /// --l|lines-per-file
    uint numFiles = 0;                         /// --n|num-files
    size_t[] keyFields;                        /// Derived: --k|key-fields
    string dir;                                /// --dir
    string prefix = "part_";                   /// --prefix
    string suffix = invalidFileSuffix;         /// --suffix
    uint digitWidth = 0;                       /// --w|digit-width
    bool appendToExistingFiles = false;        /// --a|append
    bool staticSeed = false;                   /// --s|static-seed
    uint seedValueOptionArg = 0;               /// --v|seed-value
    char delim = '\t';                         /// --d|delimiter
    uint maxOpenFilesArg = 0;                  /// --max-open-files
    bool hasHeader = false;                    /// Derived. True if either '--H|header' or '--I|header-in-only' is set.
    bool keyIsFullLine = false;                /// Derived. True if '--f|fields 0' is specfied.
    bool usingUnpredictableSeed = true;        /// Derived from --static-seed, --seed-value
    uint seed = 0;                             /// Derived from --static-seed, --seed-value
    uint maxOpenOutputFiles;                   /// Derived.

    /** Process tsv-split command line arguments.
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
        import std.algorithm : all, canFind, each, min;
        import std.conv : to;
        import std.file : exists, isDir;
        import std.getopt;
        import std.math : isNaN;
        import std.path : baseName, expandTilde, extension, stripExtension;
        import std.typecons : Yes, No;
        import tsv_utils.common.fieldlist;

        bool helpVerbose = false;                  // --help-verbose
        bool helpFields = false;                   // --help-fields
        bool versionWanted = false;                // --V|version
        string keyFieldsArg;                       // --k|key-fields

        string keyFieldsOptionString = "k|key-fields";

        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

        try
        {
            arraySep = ",";    // Use comma to separate values in command line options
            auto r = getopt(
                cmdArgs,
                "help-verbose",    "     Print more detailed help.", &helpVerbose,
                "help-fields",     "     Print help on specifying fields.", &helpFields,

                std.getopt.config.caseSensitive,
                "H|header",         "     Input files have a header line. Write the header to each output file.", &headerInOut,
                "I|header-in-only", "     Input files have a header line. Do not write the header to output files.", &headerIn,
                std.getopt.config.caseInsensitive,

                "l|lines-per-file", "NUM  Number of lines to write to each output file (excluding the header line).", &linesPerFile,
                "n|num-files",      "NUM  Number of output files to generate.", &numFiles,

                keyFieldsOptionString,
                "<field-list>  Fields to use as key. Lines with the same key are written to the same output file. Use '--k|key-fields 0' to use the entire line as the key.",
                &keyFieldsArg,

                "dir",              "STR  Directory to write to. Default: Current working directory.", &dir,
                "prefix",           "STR  Filename prefix. Default: 'part_'", &prefix,
                "suffix",           "STR  Filename suffix. Default: First input file extension. None for standard input.", &suffix,
                "w|digit-width",    "NUM  Number of digits in filename numeric portion. Default: '--l|lines-per-file': 3. '--n|num-files': Chosen so filenames have the same length. '--w|digit-width 0' uses the default.", &digitWidth,
                "a|append",         "     Append to existing files.", &appendToExistingFiles,

                "s|static-seed",    "     Use the same random seed every run.", &staticSeed,

                std.getopt.config.caseSensitive,
                "v|seed-value",     "NUM  Sets the random seed. Use a non-zero, 32 bit positive integer. Zero is a no-op.", &seedValueOptionArg,
                std.getopt.config.caseInsensitive,

                "d|delimiter",      "CHR  Field delimiter.", &delim,
                "max-open-files",   "NUM  Maximum open file handles to use. Min of 5 required.", &maxOpenFilesArg,

                std.getopt.config.caseSensitive,
                "V|version",        "     Print version information and exit.", &versionWanted,
                std.getopt.config.caseInsensitive,
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
                writeln(tsvutilsVersionNotice("tsv-split"));
                return tuple(false, 0);
            }

            /* Remaining command line args are files.
             */
            string[] filepaths = (cmdArgs.length > 1) ? cmdArgs[1 .. $] : ["-"];
            cmdArgs.length = 1;

            /* Validation and derivations - Do as much validation prior to header line
             * processing as possible (avoids waiting on stdin).
             *
             * Note: keyFields depends on header line processing, but keyFieldsArg
             * can be used to detect whether the command line argument was specified.
             */

            enforce(!(headerInOut && headerIn),
                    "Use only one of '--H|header' and '--I|header-in-only'.");

            hasHeader = headerInOut || headerIn;

            enforce(linesPerFile != 0 || numFiles != 0,
                    "Either '--l|lines-per-file' or '--n|num-files' is required.");

            enforce(linesPerFile == 0 || numFiles == 0,
                    "'--l|lines-per-file' and '--n|num-files' cannot be used together.");

            enforce(linesPerFile == 0 || keyFieldsArg.length == 0,
                    "'--l|lines-per-file' and '--k|key-fields' cannot be used together.");

            enforce(numFiles != 1, "'--n|num-files must be two or more.");

            if (!dir.empty)
            {
                dir = dir.expandTilde;
                enforce(dir.exists, format("Directory does not exist: --dir '%s'", dir));
                enforce(dir.isDir, format("Path is not a directory: --dir '%s'", dir));
            }

            /* Seed. */
            import std.random : unpredictableSeed;

            usingUnpredictableSeed = (!staticSeed && seedValueOptionArg == 0);

            if (usingUnpredictableSeed) seed = unpredictableSeed;
            else if (seedValueOptionArg != 0) seed = seedValueOptionArg;
            else if (staticSeed) seed = 2438424139;
            else assert(0, "Internal error, invalid seed option states.");

            /* Maximum number of open files. Mainly applies when --num-files is used.
             *
             * Derive maxOpenOutputFiles. Inputs:
             * - Internal default limit: 4096. This is a somewhat conservative setting.
             * - rlimit open files limit. Defined by '$ ulimit -n'.
             * - '--max-open-files' (maxOpenFilesArg). This adjusts the internal limit,
             *   but only up to the rlimit value.
             * - Four open files are reserved for stdin, stdout, stderr, and one input
             *   file.
             */

            immutable uint internalDefaultMaxOpenFiles = 4096;
            immutable uint numReservedOpenFiles = 4;
            immutable uint rlimitOpenFilesLimit = rlimitCurrOpenFilesLimit();

            enforce(maxOpenFilesArg == 0 || maxOpenFilesArg > numReservedOpenFiles,
                    format("'--max-open-files' must be at least %d.",
                           numReservedOpenFiles + 1));

            enforce(maxOpenFilesArg <= rlimitOpenFilesLimit,
                    format("'--max-open-files' value (%d) greater current system limit (%d)." ~
                           "\nRun 'ulimit -n' to see the soft limit." ~
                           "\nRun 'ulimit -Hn' to see the hard limit." ~
                           "\nRun 'ulimit -Sn NUM' to change the soft limit.",
                           maxOpenFilesArg, rlimitOpenFilesLimit));

            enforce(rlimitOpenFilesLimit > numReservedOpenFiles,
                    format("System open file limit too small. Current value: %d. Must be %d or more." ~
                           "\nRun 'ulimit -n' to see the soft limit." ~
                           "\nRun 'ulimit -Hn' to see the hard limit." ~
                           "\nRun 'ulimit -Sn NUM' to change the soft limit.",
                           rlimitOpenFilesLimit, numReservedOpenFiles + 1));

            immutable uint openFilesLimit =
                (maxOpenFilesArg != 0)
                ? maxOpenFilesArg
                : min(internalDefaultMaxOpenFiles, rlimitOpenFilesLimit);

            assert(openFilesLimit > numReservedOpenFiles);

            maxOpenOutputFiles = openFilesLimit - numReservedOpenFiles;

            /* Suffix - If not provided, use the extension of the first input file.
             * No suffix if reading from standard input.
             */
            if (suffix == invalidFileSuffix) suffix = filepaths[0].extension;

            /* Ensure forward slash is not included in the filename prefix and suffix.
             * Forward slash is an invalid Unix filename character. However, open file
             * calls could match a directory path, resulting in unintended file
             * creation.
             *
             * The other invalid filename character on Unix is the NULL character.
             * However, the NULL character cannot be entered via Unix command lines,
             * so there is no need to test for it explicitly.
             */
            enforce(!prefix.canFind('/'),
                    "'--prefix' cannot contain forward slash characters. Use '--dir' to specify an output directory.");

            enforce(!suffix.canFind('/'),
                    "'--suffix' cannot contain forward slash characters. Use '--dir' to specify an output directory.");

            /* Digit width - If not specified, or specified as zero, the width is
             * determined by the number of files for --num-files, or defaulted to 3
             * for --lines-per-file.
             */
            if (digitWidth == 0)
            {
                if (numFiles > 0)
                {
                    digitWidth = 1;
                    uint n = numFiles - 1;
                    while (n >= 10)
                    {
                        n /= 10;
                        ++digitWidth;
                    }
                }
                else
                {
                    digitWidth = 3;
                }
            }
            assert(digitWidth != 0);

            /*
             * Create the inputSourceRange and perform header line processing.
             */
            ReadHeader readHeader = hasHeader ? Yes.readHeader : No.readHeader;
            inputSources = inputSourceRange(filepaths, readHeader);

            string[] headerFields;

            if (hasHeader) headerFields = inputSources.front.header.split(delim).to!(string[]);

            if (!keyFieldsArg.empty)
            {
                keyFields =
                    keyFieldsArg
                    .parseFieldList!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero)
                    (hasHeader, headerFields, keyFieldsOptionString)
                    .array;
            }

            if (keyFields.length > 0)
            {
                if (keyFields.length == 1 && keyFields[0] == 0)
                {
                    keyIsFullLine = true;
                }
                else
                {
                    enforce(keyFields.all!(x => x != 0),
                            "Whole line as key (--k|key-fields 0) cannot be combined with multiple fields.");

                    keyFields.each!((ref x) => --x);  // Convert to zero-based indexing.
                }
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

/* TsvSplitOptions unit tests (command-line argument processing).
 *
 * Basic tests. Many cases are covered in executable tests, including all error cases,
 * as errors write to stderr.
 */
unittest
{
    import tsv_utils.common.unittest_utils;   // tsv unit test helpers, from common/src/.
    import std.conv : to;
    import std.file : mkdir, rmdirRecurse;
    import std.path : buildPath;

    /* A pair of dummy files are used so we don't have to worry about the cases where
     * command line processing might open a file. Don't want to use standard input for
     * this, at least in cases where it might try to read to get the header line.
     *
     * Note: For Windows we need to ensure there are no references held to the dummy
     * file (somefile.txt) by the time rmdirRecurse tries to remove it. So we take
     * a step not necessary in normal code and explicitly empty the inputSources in
     * TsvSplitOptions structs that are created during the tests. In normal code,
     * this happens when the input sources are iterated, but the sources are not
     * iterated in these tests.
     */
    auto testDir = makeUnittestTempDir("tsv_split_bylinecount");
    scope(exit) testDir.rmdirRecurse;

    string somefile_txt = buildPath(testDir, "somefile.txt");
    string anotherfile_pqr = buildPath(testDir, "anotherfile.pqr");

    {
        auto f1 = somefile_txt.File("wb");
        f1.writeln("Hello World!");
        f1.close;

        auto f2 = anotherfile_pqr.File("wb");
        f2.writeln("Good Morning World!");
        f2.close;
    }

    {
        auto args = ["unittest", "--lines-per-file", "10", somefile_txt];
        TsvSplitOptions cmdopt;
        const r = cmdopt.processArgs(args);

        assert(cmdopt.linesPerFile == 10);
        assert(cmdopt.keyFields.empty);
        assert(cmdopt.numFiles == 0);
        assert(cmdopt.hasHeader == false);

        while (!cmdopt.inputSources.empty) cmdopt.inputSources.popFront;
    }
    {
        auto args = ["unittest", "--num-files", "20", somefile_txt];
        TsvSplitOptions cmdopt;
        const r = cmdopt.processArgs(args);

        assert(cmdopt.linesPerFile == 0);
        assert(cmdopt.keyFields.empty);
        assert(cmdopt.numFiles == 20);
        assert(cmdopt.hasHeader == false);

        while (!cmdopt.inputSources.empty) cmdopt.inputSources.popFront;
    }
    {
        auto args = ["unittest", "-n", "5", "--key-fields", "1-3", somefile_txt];
        TsvSplitOptions cmdopt;
        const r = cmdopt.processArgs(args);

        assert(cmdopt.linesPerFile == 0);
        assert(cmdopt.keyFields == [0, 1, 2]);
        assert(cmdopt.numFiles == 5);
        assert(cmdopt.hasHeader == false);
        assert(cmdopt.keyIsFullLine == false);

        while (!cmdopt.inputSources.empty) cmdopt.inputSources.popFront;
    }
    {
        auto args = ["unittest", "-n", "5", "-k", "0", somefile_txt];
        TsvSplitOptions cmdopt;
        const r = cmdopt.processArgs(args);

        assert(cmdopt.linesPerFile == 0);
        assert(cmdopt.numFiles == 5);
        assert(cmdopt.hasHeader == false);
        assert(cmdopt.keyIsFullLine == true);

        while (!cmdopt.inputSources.empty) cmdopt.inputSources.popFront;
    }
    {
        auto args = ["unittest", "-n", "2", "--header", somefile_txt];
        TsvSplitOptions cmdopt;
        const r = cmdopt.processArgs(args);

        assert(cmdopt.headerInOut == true);
        assert(cmdopt.hasHeader == true);
        assert(cmdopt.headerIn == false);

        while (!cmdopt.inputSources.empty) cmdopt.inputSources.popFront;
    }
    {
        auto args = ["unittest", "-n", "2", "--header-in-only", somefile_txt];
        TsvSplitOptions cmdopt;
        const r = cmdopt.processArgs(args);

        assert(cmdopt.headerInOut == false);
        assert(cmdopt.hasHeader == true);
        assert(cmdopt.headerIn == true);

        while (!cmdopt.inputSources.empty) cmdopt.inputSources.popFront;
    }

    static void testSuffix(string[] args, string expectedSuffix)
    {
        TsvSplitOptions cmdopt;
        auto savedArgs = args.to!string;
        const r = cmdopt.processArgs(args);

        assert(r[0], format("[testSuffix] cmdopt.processArgs(%s) returned false.", savedArgs));
        assert(cmdopt.suffix == expectedSuffix,
               format("[testSuffix] Incorrect cmdopt.suffix. Expected: '%s', Actual: '%s'\n   cmdopt.processArgs(%s)",
                      expectedSuffix, cmdopt.suffix, savedArgs));

        while (!cmdopt.inputSources.empty) cmdopt.inputSources.popFront;
    }

    /* In these tests, don't use headers and when files are listed, use 'somefile_txt' first.
     * This makes sure there is no attempt to read standard input and that there won't be an
     * open failure trying to find a file.
     */
    testSuffix(["unittest", "-n", "2"], "");
    testSuffix(["unittest", "-n", "2", "--", "-"], "");
    testSuffix(["unittest", "-n", "2", "--suffix", "_123"], "_123");
    testSuffix(["unittest", "-n", "2", somefile_txt], ".txt");
    testSuffix(["unittest", "-n", "2", somefile_txt, anotherfile_pqr], ".txt");
    testSuffix(["unittest", "-n", "2", "--suffix", ".X", somefile_txt, anotherfile_pqr], ".X");
    testSuffix(["unittest", "-n", "2", "--suffix", "", somefile_txt], "");
    testSuffix(["unittest", "-n", "2", "--", "-", somefile_txt], "");
    testSuffix(["unittest", "-n", "2", "--", somefile_txt, "-"], ".txt");

    static void testDigitWidth(string[] args, uint expected)
    {
        TsvSplitOptions cmdopt;
        auto savedArgs = args.to!string;
        const r = cmdopt.processArgs(args);

        assert(r[0], format("[testDigitWidth] cmdopt.processArgs(%s) returned false.", savedArgs));
        assert(cmdopt.digitWidth == expected,
               format("[testDigitWidth] Incorrect cmdopt.digitWidth. Expected: %d, Actual: %d\n   cmdopt.processArgs(%s)",
                      expected, cmdopt.digitWidth, savedArgs));

        while (!cmdopt.inputSources.empty) cmdopt.inputSources.popFront;
    }

    testDigitWidth(["unittest", "-n", "2", somefile_txt], 1);
    testDigitWidth(["unittest", "-n", "2", "--digit-width" , "0", somefile_txt], 1);
    testDigitWidth(["unittest", "-n", "10", somefile_txt], 1);
    testDigitWidth(["unittest", "-n", "11", somefile_txt], 2);
    testDigitWidth(["unittest", "-n", "555", somefile_txt], 3);
    testDigitWidth(["unittest", "-n", "555", "--digit-width" , "2", somefile_txt], 2);
    testDigitWidth(["unittest", "-n", "555", "--digit-width" , "4", somefile_txt], 4);
    testDigitWidth(["unittest", "-l", "10", somefile_txt], 3);
    testDigitWidth(["unittest", "-l", "10000", somefile_txt], 3);
    testDigitWidth(["unittest", "-l", "10000", "--digit-width", "0", somefile_txt], 3);
    testDigitWidth(["unittest", "-l", "10000", "--digit-width", "1", somefile_txt], 1);
    testDigitWidth(["unittest", "-l", "10000", "--digit-width", "5", somefile_txt], 5);
}

/** Get the rlimit current number of open files the process is allowed.
 *
 * This routine returns the current soft limit on the number of open files the process
 * is allowed. This is the number returned by the command: '$ ulimit -n'.
 *
 * This routine translates this value to a 'uint', as tsv-split uses 'uint' for
 * tracking output files. The rlimit 'rlim_t' type is usually 'ulong' or 'long'.
 * RLIM_INFINITY and any value larger than 'uint.max' is translated to 'uint.max'.
 *
 * An exception is thrown if call to 'getrlimit' fails.
 *
 * Note about Windows: rlimit is a Posix construct, not available on Windows.
 * Currently, tsv-split is written for Posix. To allow it compile on Windows, this
 * routine returns 512 on Windows, which is the default for Windows stream I/O. This
 * is a stop-gap solution. A more generalized 'systemCurrOpenFilesLimit' would make
 * sense if Windows becomes primary platform. That would also require changing error
 * messages, help, etc., to be platform specfic. At present, testing is done only on
 * Posix platforms. For info on Windows stream I/O limits see:
 *   https://docs.microsoft.com/en-us/cpp/c-runtime-library/reference/setmaxstdio
 */
uint rlimitCurrOpenFilesLimit()
{
    version (Posix)
    {
        import core.sys.posix.sys.resource :
            rlim_t, rlimit, getrlimit, RLIMIT_NOFILE, RLIM_INFINITY, RLIM_SAVED_CUR;
        import std.conv : to;

        uint currOpenFileLimit = uint.max;

        rlimit rlimitMaxOpenFiles;

        enforce(getrlimit(RLIMIT_NOFILE, &rlimitMaxOpenFiles) == 0,
                "Internal error: getrlimit call failed");

        if (rlimitMaxOpenFiles.rlim_cur != RLIM_INFINITY &&
            rlimitMaxOpenFiles.rlim_cur != RLIM_SAVED_CUR &&
            rlimitMaxOpenFiles.rlim_cur >= 0 &&
            rlimitMaxOpenFiles.rlim_cur <= uint.max)
        {
            currOpenFileLimit = rlimitMaxOpenFiles.rlim_cur.to!uint;
        }

        return currOpenFileLimit;
    }
    else version (Windows)
    {
        return 512;
    }
    else
    {
        static assert(0, "Unsupported platform.");
    }
}

/** Invokes the proper split routine based on the command line arguments.
 *
 * This routine is the top-level control after command line argument processing is
 * done. It's primary job is to set up data structures and invoke the correct
 * processing routine based on the command line arguments.
 */
void tsvSplit(ref TsvSplitOptions cmdopt)
{
    /* Check that the input files were setup as expected. Should at least have one
     * input, stdin if nothing else. */
    assert(!cmdopt.inputSources.empty);

    if (cmdopt.linesPerFile != 0)
    {
        splitByLineCount(cmdopt);
    }
    else
    {
        /* Randomly distribute input lines to a specified number of files. */

        auto outputFiles =
            SplitOutputFiles(cmdopt.numFiles, cmdopt.dir, cmdopt.prefix, cmdopt.suffix,
                             cmdopt.digitWidth, cmdopt.headerInOut, cmdopt.maxOpenOutputFiles,
                             cmdopt.inputSources.front.header);

        if (!cmdopt.appendToExistingFiles)
        {
            string existingFile = outputFiles.checkIfFilesExist;
            enforce(existingFile.length == 0,
                    format("One or more output files already exist. Use '--a|append' to append to existing files. File: '%s'.",
                           existingFile));
        }

        if (cmdopt.keyFields.length == 0)
        {
            splitLinesRandomly(cmdopt, outputFiles);
        }
        else
        {
            splitLinesByKey(cmdopt, outputFiles);
        }
    }
}

/** A SplitOutputFiles struct holds a collection of output files.
 *
 * This struct manages a collection of output files used when writing to multiple
 * files at once. This includes constructing filenames, opening and closing files,
 * and writing data and header lines.
 *
 * Both random assignment (splitLinesRandomly) and random assignment by key
 * (splitLinesByKey) use a SplitOutputFiles struct to manage output files.
 *
 * The main properties of the output file set are specified in the constuctor. The
 * exception is the header line. This is not known until the first input file is
 * read, so it is specified in a separate 'setHeader' call.
 *
 * Individual output files are written to based on their zero-based index in the
 * output collection. The caller selects the output file number to write to and
 * calls 'writeDataLine' to write a line. The header is written if needed.
 */
struct SplitOutputFiles
{
    import std.conv : to;
    import std.file : exists;
    import std.path : buildPath;
    import std.stdio : File;

    static struct OutputFile
    {
        string filename;
        File ofile;
        bool hasData;
        bool isOpen;    // Track separately due to https://github.com/dlang/phobos/pull/7397
    }

    private uint _numFiles;
    private bool _writeHeaders;
    private uint _maxOpenFiles;

    private OutputFile[] _outputFiles;
    private uint _numOpenFiles = 0;
    private string _header;

    this(uint numFiles, string dir, string filePrefix, string fileSuffix,
         uint fileDigitWidth, bool writeHeaders, uint maxOpenFiles, string header)
    {
        assert(numFiles >= 2);
        assert(maxOpenFiles >= 1);

        _numFiles = numFiles;
        _writeHeaders = writeHeaders;
        _maxOpenFiles = maxOpenFiles;
        _header = header;

        _outputFiles.length = numFiles;

        /* Filename assignment. */
        foreach (i, ref f; _outputFiles)
        {
            f.filename =
                buildPath(dir, format("%s%.*d%s", filePrefix, fileDigitWidth, i, fileSuffix));
        }
    }

    /* Destructor ensures all files are closed.
     *
     * Note: A dual check on whether the file is open is made. This is to avoid a
     * Phobos bug where std.File doesn't properly maintain the state of open files
     * if the File.open call fails. See: https://github.com/dlang/phobos/pull/7397.
     */
    ~this()
    {
        foreach (ref f; _outputFiles)
        {
            if (f.isOpen && f.ofile.isOpen)
            {
                assert(_numOpenFiles >= 1);

                f.ofile.close;
                f.isOpen = false;
                _numOpenFiles--;
            }
        }
    }

    /* Check if any of the files already exist.
     *
     * Returns the empty string if none of the files exist. Otherwise returns the
     * filename of the first existing file found. This is to facilitate error
     * message generation.
     */
    string checkIfFilesExist()
    {
        foreach (f; _outputFiles) if (f.filename.exists) return f.filename;
        return "";
    }

    /* Picks a random file to close. Used when the open file handle limit has been
     * reached.
     */
    private void closeSomeFile()
    {
        import std.random : uniform;
        assert(_numOpenFiles > 0);

        immutable uint start = uniform(0, _numFiles);

        foreach (i; cycle(iota(_numFiles), start).take(_numFiles))
        {
            if (_outputFiles[i].isOpen)
            {
                _outputFiles[i].ofile.close;
                _outputFiles[i].isOpen = false;
                _numOpenFiles--;

                return;
            }
        }

        assert(false, "[SplitOutputFiles.closeSomeFile]: Could not find file to close.");
    }

    /* Write a line to the specified file number.
     *
     * A header is written to the file if headers are being written and this is the
     * first data written to the file.
     */
    void writeDataLine(uint fileNum, const char[] data)
    {
        assert(fileNum < _numFiles);
        assert(fileNum < _outputFiles.length);
        assert(_numOpenFiles <= _maxOpenFiles);

        OutputFile* outputFile = &_outputFiles[fileNum];

        if (!outputFile.isOpen)
        {
            if (_numOpenFiles == _maxOpenFiles) closeSomeFile();
            assert(_numOpenFiles < _maxOpenFiles);

            outputFile.ofile = outputFile.filename.File("ab");
            outputFile.isOpen = true;
            _numOpenFiles++;

            if (!outputFile.hasData)
            {
                ulong filesize = outputFile.ofile.size;
                outputFile.hasData = (filesize > 0 && filesize != ulong.max);
            }
        }

        if (_writeHeaders && !outputFile.hasData) outputFile.ofile.writeln(_header);

        outputFile.ofile.writeln(data);
        outputFile.hasData = true;
    }
}

/** Write input lines to multiple files, randomly selecting an output file for each line.
 */
void splitLinesRandomly(ref TsvSplitOptions cmdopt, ref SplitOutputFiles outputFiles)
{
    import std.random : Random = Mt19937, uniform;
    import tsv_utils.common.utils : bufferedByLine, InputSourceRange;

    /* inputSources must be an InputSourceRange and include at least stdin. */
    assert(!cmdopt.inputSources.empty);
    static assert(is(typeof(cmdopt.inputSources) == InputSourceRange));

    auto randomGenerator = Random(cmdopt.seed);

    /* Process each line. */
    foreach (inputStream; cmdopt.inputSources)
    {
        foreach (line; inputStream.file.bufferedByLine)
        {
            immutable uint outputFileNum = uniform(0, cmdopt.numFiles, randomGenerator);
            outputFiles.writeDataLine(outputFileNum, line);
        }
    }
}

/** Write input lines to multiple output files using fields as a random selection key.
 *
 * Each input line is written to an output file. The output file is chosen using
 * fields as a key. Each unique key is assigned to a file. All lines having the
 * same key are written to the same file.
 */
void splitLinesByKey(ref TsvSplitOptions cmdopt, ref SplitOutputFiles outputFiles)
{
    import std.algorithm : splitter;
    import std.conv : to;
    import std.digest.murmurhash;
    import tsv_utils.common.utils : bufferedByLine, InputFieldReordering,
        InputSourceRange, throwIfWindowsNewline;

    assert(cmdopt.keyFields.length > 0);

    /* inputSources must be an InputSourceRange and include at least stdin. */
    assert(!cmdopt.inputSources.empty);
    static assert(is(typeof(cmdopt.inputSources) == InputSourceRange));

    immutable ubyte[1] delimArray = [cmdopt.delim]; // For assembling multi-field hash keys.

    /* Create a mapping for the key fields. */
    auto keyFieldsReordering = cmdopt.keyIsFullLine ? null : new InputFieldReordering!char(cmdopt.keyFields);

    /* Process each line. */
    immutable size_t fileBodyStartLine = cmdopt.hasHeader ? 2 : 1;
    foreach (inputStream; cmdopt.inputSources)
    {
        if (cmdopt.hasHeader) throwIfWindowsNewline(inputStream.header, inputStream.name, 1);

        foreach (fileLineNum, line; inputStream.file.bufferedByLine.enumerate(fileBodyStartLine))
        {
            if (fileLineNum == 1) throwIfWindowsNewline(line, inputStream.name, fileLineNum);

            /* Murmurhash works by successively adding individual keys, then finalizing.
             * Adding individual keys is simpler if the full-line-as-key and individual
             * fields as keys cases are separated.
             */
            auto hasher = MurmurHash3!32(cmdopt.seed);

            if (cmdopt.keyIsFullLine)
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
            immutable uint outputFileNum = hasher.get % cmdopt.numFiles;
            outputFiles.writeDataLine(outputFileNum, line);
        }
    }
}

/** Write input lines to multiple files, splitting based on line count.
 *
 * Note: readBufferSize is an argument primarily for unit test purposes. Normal uses
 * should use the default value.
 */
void splitByLineCount(ref TsvSplitOptions cmdopt, const size_t readBufferSize = 1024L * 128L)
{
    import std.file : exists;
    import std.path : buildPath;
    import std.stdio : File;
    import tsv_utils.common.utils : InputSourceRange;

    assert (readBufferSize > 0);
    ubyte[] readBuffer = new ubyte[readBufferSize];

    /* inputSources must be an InputSourceRange and include at least stdin. */
    assert(!cmdopt.inputSources.empty);
    static assert(is(typeof(cmdopt.inputSources) == InputSourceRange));

    string header = !cmdopt.headerInOut ? "" :
        cmdopt.inputSources.front.header(Yes.keepTerminator);
    size_t nextOutputFileNum = 0;
    File outputFile;
    string outputFileName;
    bool isOutputFileOpen = false;           // Open file status tracked separately due to phobos bugs
    size_t outputFileRemainingLines;

    /* nextNewlineIndex finds the index of the next newline character. It is an
     * alternative to std.algorithm.countUntil. Invoking 'find' directly results
     * 'memchr' being used (faster). The current 'countUntil' implementation does
     * forward to find, but the way it is done avoids the memchr call optimization.
     */
    static long nextNewlineIndex(const ubyte[] buffer)
    {
        import std.algorithm : find;
        immutable ubyte newlineChar = '\n';
        immutable size_t buflen = buffer.length;
        immutable size_t findlen = buffer.find(newlineChar).length;

        return findlen > 0 ? buflen - findlen : -1;
    }

    foreach (inputStream; cmdopt.inputSources)
    {
        foreach (ref ubyte[] inputChunk; inputStream.file.byChunk(readBuffer))
        {
            size_t nextOutputChunkStart = 0;
            auto remainingInputChunk = inputChunk[nextOutputChunkStart .. $];

            while (!remainingInputChunk.empty)
            {
                /* See if the next output file needs to be opened. */
                if (!isOutputFileOpen)
                {
                    outputFileName =
                        buildPath(cmdopt.dir,
                                  format("%s%.*d%s", cmdopt.prefix,
                                         cmdopt.digitWidth, nextOutputFileNum, cmdopt.suffix));

                    enforce(cmdopt.appendToExistingFiles || !outputFileName.exists,
                            format("Output file already exists. Use '--a|append' to append to existing files. File: '%s'.",
                                   outputFileName));

                    outputFile = outputFileName.File("ab");
                    outputFile.setvbuf(1024L * 64L, _IOFBF);
                    isOutputFileOpen = true;
                    ++nextOutputFileNum;
                    outputFileRemainingLines = cmdopt.linesPerFile;

                    if (cmdopt.headerInOut)
                    {
                        ulong filesize = outputFile.size;
                        if (filesize == 0 || filesize == ulong.max) outputFile.rawWrite(header);
                    }
                }

                /* Find more newlines for the current output file. */

                assert(outputFileRemainingLines > 0);

                size_t nextOutputChunkEnd = nextOutputChunkStart;

                while (outputFileRemainingLines != 0 && !remainingInputChunk.empty)
                {
                    /* Note: newLineIndex is relative to 'remainingInputChunk', not
                     * 'inputChunk'. Updates to variables referring to 'inputChunk'
                     * need to reflect this. In particular, 'nextOutputChunkEnd'.
                     */
                    immutable newlineIndex = nextNewlineIndex(remainingInputChunk);

                    if (newlineIndex == -1)
                    {
                        nextOutputChunkEnd = inputChunk.length;
                    }
                    else
                    {
                        --outputFileRemainingLines;
                        nextOutputChunkEnd += (newlineIndex + 1);
                    }

                    remainingInputChunk = inputChunk[nextOutputChunkEnd .. $];
                }

                assert(nextOutputChunkStart < nextOutputChunkEnd);
                assert(nextOutputChunkEnd <= inputChunk.length);

                outputFile.rawWrite(inputChunk[nextOutputChunkStart .. nextOutputChunkEnd]);

                if (outputFileRemainingLines == 0)
                {
                    outputFile.close;
                    isOutputFileOpen = false;
                }

                nextOutputChunkStart = nextOutputChunkEnd;

                assert(remainingInputChunk.length == inputChunk.length - nextOutputChunkStart);
            }
        }
    }
}

/* splitByLineCount unit tests.
 *
 * These tests are primarily for buffer management. There are edge cases involving the
 * interaction buffer size, input file size, lines-per-file, and newline placement
 * that are difficult to test against the executable.
 */
unittest
{
    import tsv_utils.common.unittest_utils;   // tsv unit test helpers, from common/src/.
    import std.algorithm : min;
    import std.array : appender;
    import std.conv : to;
    import std.file : exists, mkdir, rmdirRecurse;
    import std.path : buildPath;
    import std.process : escapeShellCommand, executeShell;

    /* Test setup
     *
     * A set of twenty file input files is created, with names: input_NxM.txt, where
     * N is the number of characters in each row and M is the number of rows (lines).
     * The resulting files are put in the "lc_input" directory ('inputDir' variable)
     * and have names:
     *    input_0x2.txt, input_0x3.txt, ... input_5x5.txt.
     *
     * A standalone block of code produces the expected result files for splitting an
     * input file into a set of output files. This duplicates the splitByLineCount
     * output. This is done for lines-per-file counts 1 to 5. Each result set is place
     * ina subdirectory under "lc_expected" ('expectedDir' variable). Subdirectories
     * have names like: "0x2_by_1", "0x3_by_1", ..., "5x5_by_4".
     *
     * splitByLine is called for all the same input files and lines-per-file settings used
     * to produce the expected output. This is done via testSplitByLineCount, which calls
     * command line argument processing and splitByLine, similar to how the main program
     * works. The results are written to a subdirectory. The subdirectory is compared to
     * the expected output directory using the system 'diff' command.
     *
     * splitByLine is multiple times for each expected output case. The different calls
     * iterate over a series of small ReadBufferSizes. This is how tests for edge cases
     * in the readBufferSize vs line lengths, newline placement, etc., is accomplished.
     *
     * Note: One way to understand what is going on is to comment out the line:
     *
     *    scope(exit) testDir.rmdirRecurse;
     *
     * Then run the test (e.g. 'make test') and look at the directory structure left
     * behind. Print out the 'testDir' directory to see where it is located.
     */

    /* testSplitByLineCount acts as a surrogate for main() and tsvSplit(). It makes the
     * call to splitByLineCount and calls 'diff' to compare the output directory to the
     * expected directory. An assert is thrown if the directories do not match.
     */
    static void testSplitByLineCount(string[] cmdArgs, string expectedDir,
                                 size_t readBufferSize = 1024L * 512L)
    {
        import std.array : appender;

        assert(cmdArgs.length > 0, "[testSplitByLineCount] cmdArgs must not be empty.");

        auto formatAssertMessage(T...)(string msg, T formatArgs)
        {
            auto formatString = "[testSplitByLineCount] %s: " ~ msg;
            return format(formatString, cmdArgs[0], formatArgs);
        }

        TsvSplitOptions cmdopt;
        auto savedCmdArgs = cmdArgs.to!string;
        auto r = cmdopt.processArgs(cmdArgs);
        assert(r[0], formatAssertMessage("Invalid command lines arg: '%s'.", savedCmdArgs));
        assert(cmdopt.linesPerFile != 0, "[testSplitByLineCount] --lines-per-file is required.");
        assert(!cmdopt.dir.empty, "[testSplitByLineCount] --dir is required.");

        splitByLineCount(cmdopt, readBufferSize);

        /* Diff command setup. */
        auto diffCmdArgs = ["diff", expectedDir, cmdopt.dir];
        auto diffResult = executeShell(escapeShellCommand(diffCmdArgs));
        assert(diffResult.status == 0,
               format("[testSplitByLineCount]\n  cmd: %s\n  readBufferSize: %d\n  expectedDir: %s\n------ Diff ------%s\n-------",
                      savedCmdArgs, readBufferSize, expectedDir, diffResult.output));
    }

    auto testDir = makeUnittestTempDir("tsv_split_bylinecount");
    scope(exit) testDir.rmdirRecurse;

    auto inputDir = buildPath(testDir, "lc_input");
    auto outputDir = buildPath(testDir, "lc_output");
    auto expectedDir = buildPath(testDir, "lc_expected");

    mkdir(inputDir);
    mkdir(outputDir);
    mkdir(expectedDir);

    static string buildInputFilePath(string dir, long inputLineLength, long inputFileNumLines)
    {
        return buildPath(dir, format("input_%dx%d.txt", inputLineLength, inputFileNumLines));
    }

    string[5] outputRowData =
        [
            "abcde",
            "fghij",
            "klmno",
            "pqrst",
            "uvwxy"
        ];

    /* The main test loop. Iterates over input line lengths, numbers of rows,
     * lines-per-file, and finally readBufferSize lengths. All combos are tested.
     */
    foreach (inputLineLength; 0 .. 6)
    {
        foreach (inputFileNumLines; 2 .. 6)
        {
            auto inputFile = buildInputFilePath(inputDir, inputLineLength, inputFileNumLines);

            {
                auto ofile = inputFile.File("wb");
                auto output = appender!(char[])();
                foreach (m; 0 .. inputFileNumLines)
                {
                    put(output, outputRowData[m][0 .. inputLineLength]);
                    put(output, '\n');
                }
                ofile.write(output.data);
                ofile.close;
            }

            /* Iterate over the different lines-per-file lengths.
             * - Create an expected output directory and files for each.
             * - Test with different readBufferSize values.
             */
            foreach (outputFileNumLines; 1 .. min(5, inputFileNumLines))
            {
                auto expectedSubDir =
                    buildPath(expectedDir, format("%dx%d_by_%d", inputLineLength,
                                                  inputFileNumLines, outputFileNumLines));
                mkdir(expectedSubDir);

                size_t filenum = 0;
                size_t linesWritten = 0;
                while (linesWritten < inputFileNumLines)
                {
                    auto expectedFile = buildPath(expectedSubDir, format("part_%d.txt", filenum));
                    auto f = expectedFile.File("wb");
                    auto linesToWrite = min(outputFileNumLines, inputFileNumLines - linesWritten);
                    foreach (line; outputRowData[linesWritten .. linesWritten + linesToWrite])
                    {
                        f.writeln(line[0 .. inputLineLength]);
                    }
                    linesWritten += linesToWrite;
                    ++filenum;
                    f.close;
                }

                /* Test the different readBufferSizes.
                 * - An output directory is created for the run and deleted afterward.
                 * - First test the default size.
                 * - Then iterate overs small readBufferSize values.
                 */
                auto outputSubDir =
                    buildPath(outputDir, format("%dx%d_by_%d", inputLineLength,
                                                inputFileNumLines, outputFileNumLines));
                mkdir(outputSubDir);

                testSplitByLineCount(
                    ["test", "--lines-per-file", outputFileNumLines.to!string, "--dir", outputSubDir,
                     "--digit-width", "1", inputFile],
                    expectedSubDir);

                outputSubDir.rmdirRecurse;

                foreach (readBufSize; 1 .. 8)
                {
                     mkdir(outputSubDir);

                     testSplitByLineCount(
                         ["test", "--lines-per-file", outputFileNumLines.to!string, "--dir", outputSubDir,
                          "--digit-width", "1", inputFile],
                         expectedSubDir, readBufSize);

                     outputSubDir.rmdirRecurse;
                }
            }
        }
    }

    {
        /* Tests for the special case where readBufferSize is smaller than the header
         * line. We'll reuse the input_5x4.txt input file and write 1 line-per-file.
         */
        immutable inputLineLength = 5;
        immutable inputFileNumLines = 4;
        immutable outputFileNumLines = 1;

        auto inputFile = buildInputFilePath(inputDir, inputLineLength, inputFileNumLines);
        assert(inputFile.exists);

        auto expectedSubDirHeader =
            buildPath(expectedDir, format("%dx%d_by_%d_header", inputLineLength,
                                          inputFileNumLines, outputFileNumLines));

        auto expectedSubDirHeaderInOnly =
            buildPath(expectedDir, format("%dx%d_by_%d_header_in_only", inputLineLength,
                                          inputFileNumLines, outputFileNumLines));

        mkdir(expectedSubDirHeader);
        mkdir(expectedSubDirHeaderInOnly);

        /* Generate the expected results. Cheat by starting with linesWritten = 1. This
         * automatically excludes the header line, but keeps the loop code consistent
         * with the main test loop.
         */
        size_t filenum = 0;
        size_t linesWritten = 1;
        while (linesWritten < inputFileNumLines)
        {
            auto expectedFileHeader = buildPath(expectedSubDirHeader, format("part_%d.txt", filenum));
            auto expectedFileHeaderInOnly = buildPath(expectedSubDirHeaderInOnly,
                                                      format("part_%d.txt", filenum));
            auto fHeader = expectedFileHeader.File("wb");
            auto fHeaderInOnly = expectedFileHeaderInOnly.File("wb");
            auto linesToWrite = min(outputFileNumLines, inputFileNumLines - linesWritten);

            fHeader.writeln(outputRowData[0][0 .. inputLineLength]);
            foreach (line; outputRowData[linesWritten .. linesWritten + linesToWrite])
            {
                fHeader.writeln(line[0 .. inputLineLength]);
                fHeaderInOnly.writeln(line[0 .. inputLineLength]);
            }
            linesWritten += linesToWrite;
            ++filenum;
            fHeader.close;
            fHeaderInOnly.close;
        }

        /* Now run the tests. */
        auto outputSubDirHeader =
            buildPath(outputDir, format("%dx%d_by_%d_header", inputLineLength,
                                        inputFileNumLines, outputFileNumLines));
        auto outputSubDirHeaderInOnly =
            buildPath(outputDir, format("%dx%d_by_%d_header_in_only", inputLineLength,
                                        inputFileNumLines, outputFileNumLines));

        foreach (readBufSize; 1 .. 6)
        {
            mkdir(outputSubDirHeader);
            mkdir(outputSubDirHeaderInOnly);

            testSplitByLineCount(
                ["test", "--header", "--lines-per-file", outputFileNumLines.to!string,
                 "--dir", outputSubDirHeader, "--digit-width", "1", inputFile],
                expectedSubDirHeader, readBufSize);

            testSplitByLineCount(
                ["test", "--header-in-only", "--lines-per-file", outputFileNumLines.to!string,
                 "--dir", outputSubDirHeaderInOnly, "--digit-width", "1", inputFile],
                expectedSubDirHeaderInOnly, readBufSize);

            outputSubDirHeader.rmdirRecurse;
            outputSubDirHeaderInOnly.rmdirRecurse;
        }
    }
}
