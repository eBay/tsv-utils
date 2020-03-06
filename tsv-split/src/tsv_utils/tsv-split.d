/**
Command line tool for splitting files.

Copyright (c) 2020, eBay Inc.
Initially written by Jon Degenhardt

License: Boost License 1.0 (http://boost.org/LICENSE_1_0.txt)
*/
module tsv_utils.tsv_split;

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
    string programName;                        /// Program name
    string[] files;                            /// Input files
    bool headerInOut = false;                  /// --H|header
    bool headerIn = false;                     /// --I|header-in-only
    uint numFiles = 0;                         /// --n|num-files (Required)
    size_t[] keyFields;                        /// --k|key-fields
    string prefix = "part_";                   /// --prefix
    string suffix = ".tsv";                    /// --suffix
    bool appendToExistingFiles = false;        /// --a|append
    bool staticSeed = false;                   /// --s|static-seed
    uint seedValueOptionArg = 0;               /// --v|seed-value
    char delim = '\t';                         /// --d|delimiter
    bool versionWanted = false;                /// --V|version
    bool hasHeader = false;                    /// Derived. True if either '--H|header' or '--I|header-in-only' is set.
    bool keyIsFullLine = false;                /// Derived. True if '--f|fields 0' is specfied.
    bool usingUnpredictableSeed = true;        /// Derived from --static-seed, --seed-value
    uint seed = 0;                             /// Derived from --static-seed, --seed-value

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
        import std.algorithm : any, canFind, each;
        import std.getopt;
        import std.math : isNaN;
        import std.path : baseName, stripExtension;
        import std.typecons : Yes, No;
        import tsv_utils.common.utils : makeFieldListOptionHandler;

        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

        try
        {
            arraySep = ",";    // Use comma to separate values in command line options
            auto r = getopt(
                cmdArgs,

                std.getopt.config.caseSensitive,
                "H|header",         "     Input files have a header line. Write the header to output files.", &headerInOut,
                "I|header-in-only", "     Input files have a header line. Do not write the header to output files.", &headerIn,
                std.getopt.config.caseInsensitive,

                "n|num-files",      "NUM  (Required) Number of files to write.", &numFiles,
                "k|key-fields",     "<field-list>  Fields to use as key. Use '--k|key-fields 0' to use the entire line as the key.",
                keyFields.makeFieldListOptionHandler!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero),

                "prefix",           "STR  Filename prefix. Default: 'part_'", &prefix,
                "suffix",           "STR  Filename suffix. Default: '.tsv'", &suffix,
                "a|append",         "     Append to existing files.", &appendToExistingFiles,

                "s|static-seed",    "     Use the same random seed every run.", &staticSeed,

                std.getopt.config.caseSensitive,
                "v|seed-value",     "NUM  Sets the random seed. Use a non-zero, 32 bit positive integer. Zero is a no-op.", &seedValueOptionArg,
                std.getopt.config.caseInsensitive,

                "d|delimiter",      "CHR  Field delimiter.", &delim,

                std.getopt.config.caseSensitive,
                "V|version",        "     Print version information and exit.", &versionWanted,
                std.getopt.config.caseInsensitive,
                );

            if (r.helpWanted)
            {
                defaultGetoptPrinter(helpText, r.options);
                return tuple(false, 0);
            }
            else if (versionWanted)
            {
                import tsv_utils.common.tsvutils_version;
                writeln(tsvutilsVersionNotice("tsv-split"));
                return tuple(false, 0);
            }

            if (numFiles < 2) throw new Exception("'--n|num-files is required and must be two or more.");

            if (keyFields.length > 0)
            {
                if (keyFields.length == 1 && keyFields[0] == 0)
                {
                    keyIsFullLine = true;
                }
                else
                {
                    if (keyFields.length > 1 && keyFields.any!(x => x == 0))
                    {
                        throw new Exception(
                            "Whole line as key (--k|key-fields 0) cannot be combined with multiple fields.");
                    }

                    keyFields.each!((ref x) => --x);  // Convert to zero-based indexing.
                }
            }

            if (headerInOut && headerIn)
            {
                throw new Exception("Use only one of '--H|header' and '--I|header-in-only'.");
            }

            hasHeader = headerInOut || headerIn;

            /* Seed. */
            import std.random : unpredictableSeed;

            usingUnpredictableSeed = (!staticSeed && seedValueOptionArg == 0);

            if (usingUnpredictableSeed) seed = unpredictableSeed;
            else if (seedValueOptionArg != 0) seed = seedValueOptionArg;
            else if (staticSeed) seed = 2438424139;
            else assert(0, "Internal error, invalid seed option states.");

            /* Assume remaining args are files. Use standard input if files were not provided. */
            files ~= (cmdArgs.length > 1) ? cmdArgs[1 .. $] : ["-"];
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

struct SplitOutputFiles
{
    import std.conv : to;
    import std.file : exists;
    import std.stdio : File;

    static struct OutputFile
    {
        string filename;
        File ofile;
        bool hasData;
        bool isOpen;    // Track separately due to https://github.com/dlang/phobos/pull/7397
    }

    private uint _numFiles;
    private string _filePrefix;
    private string _fileSuffix;
    private bool _writeHeaders;
    private uint _maxOpenFiles;

    private OutputFile[] _outputFiles;
    private uint _numOpenFiles = 0;
    private string _header;

    this(uint numFiles, string filePrefix, string fileSuffix, bool writeHeaders, uint maxOpenFiles)
    {
        assert(numFiles >= 2);
        assert(maxOpenFiles >= 1);

        _numFiles = numFiles;
        _filePrefix = filePrefix;
        _fileSuffix = fileSuffix;
        _writeHeaders = writeHeaders;
        _maxOpenFiles = maxOpenFiles;

        _outputFiles.length = numFiles;

        foreach (i, ref f; _outputFiles) f.filename = _filePrefix ~ i.to!string ~ _fileSuffix;

        import std.stdio;
    }

    /* Destructor ensures all files are flushed and closed.
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

                f.ofile.flush;
                f.ofile.close;
                f.isOpen = false;
                _numOpenFiles--;
            }
        }
    }

    /* Checks if any of the files already exist.
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

    /* Sets the header line.
     *
     * Should be called prior to writeln when headers are being written. This is
     * operation is separate from the constructor because the header is not known
     * until the first line of a file is read.
     *
     * Headers are only written if 'writeHeaders' is specified as true in the
     * constructor. As a convenience, this routine can be called even if headers are
     * not being written.
     */
    void setHeader(const char[] header)
    {
        _header = header.to!string;
    }

    /* Picks a random file to close. */
    void closeSomeFile()
    {
        import std.random : uniform;
        assert(_numOpenFiles > 0);

        immutable uint start = uniform(0, _numFiles);

        foreach (i; cycle(iota(_numFiles), start).take(_numFiles))
        {
            if (_outputFiles[i].isOpen)
            {
                _outputFiles[i].ofile.flush;
                _outputFiles[i].ofile.close;
                _outputFiles[i].isOpen = false;
                _numOpenFiles--;

                return;
            }
        }

        assert(false, "[SplitOutputFiles.closeOutputFile]: Could not find file to close.");
    }

    void writeDataLine(uint key, const char[] data)
    {
        assert(key < _numFiles);
        assert(key < _outputFiles.length);
        assert(_numOpenFiles <= _maxOpenFiles);

        if (!_outputFiles[key].isOpen)
        {
            if (_numOpenFiles == _maxOpenFiles) closeSomeFile();
            assert(_numOpenFiles < _maxOpenFiles);

            _outputFiles[key].ofile = _outputFiles[key].filename.File("a");
            _outputFiles[key].isOpen = true;
            _numOpenFiles++;

            if (!_outputFiles[key].hasData)
            {
                ulong filesize = _outputFiles[key].ofile.size;
                _outputFiles[key].hasData = (filesize > 0 && filesize != ulong.max);
            }
        }

        if (_writeHeaders && !_outputFiles[key].hasData) _outputFiles[key].ofile.writeln(_header);

        _outputFiles[key].ofile.writeln(data);
        _outputFiles[key].hasData = true;
    }
}


/** Invokes the proper split routine based on the command line arguments.
 */
void tsvSplit(TsvSplitOptions cmdopt)
{
    import core.sys.posix.sys.resource : rlim_t, rlimit, getrlimit, RLIMIT_NOFILE;
    import std.conv : to;
    import std.format : format;

    /* Get the maximum number of open files.
     *
     * Internally limit to 4096 for the process (conversative) and the number
     * specified by '$ ulimit -n'. Four open files are reserved for standard input
     * standard output, standard error, and the input file.
     */
    immutable uint tsvSplitMaxOpenFiles = 4096;
    immutable uint numReservedOpenFiles = 4;

    rlimit rlimitMaxOpenFiles;

    if (getrlimit(RLIMIT_NOFILE, &rlimitMaxOpenFiles) != 0)
    {
        throw new Exception("Internal error: getrlimit call failed");
    }

    if (rlimitMaxOpenFiles.rlim_cur <= numReservedOpenFiles)
    {
        throw new Exception(
            format("Open file limit too small. Current value: %d. Must be %d or more." ~
                   "\nRun 'ulimit -n' to see the soft limit." ~
                   "\nRun 'ulimit -Hn' to see the hard limit." ~
                   "\nRun 'ulimit -Sn NUM' to change the soft limit.",
                   rlimitMaxOpenFiles.rlim_cur, numReservedOpenFiles + 1));
    }

    immutable uint maxOpenFiles =
        (tsvSplitMaxOpenFiles.to!rlim_t <= rlimitMaxOpenFiles.rlim_cur)
        ? tsvSplitMaxOpenFiles - numReservedOpenFiles
        : rlimitMaxOpenFiles.rlim_cur.to!uint - numReservedOpenFiles;


    auto outputFiles = SplitOutputFiles(cmdopt.numFiles, cmdopt.prefix, cmdopt.suffix,
                                        cmdopt.headerInOut, maxOpenFiles);

    if (!cmdopt.appendToExistingFiles)
    {
        string existingFile = outputFiles.checkIfFilesExist;

        if (existingFile.length != 0)
        {
            throw new Exception(
                format("One or more output files already exist. Use '--a|append' to append to existing files. File: '%s'.",
                       existingFile));
        }
    }

    if (cmdopt.keyFields.length == 0) splitLinesRandomly(cmdopt, outputFiles);
    else splitLinesByKey(cmdopt, outputFiles);
}

void splitLinesRandomly(TsvSplitOptions cmdopt, ref SplitOutputFiles outputFiles)
{
    import std.random : Random = Mt19937, uniform;
    import tsv_utils.common.utils : bufferedByLine, throwIfWindowsNewlineOnUnix;

    auto randomGenerator = Random(cmdopt.seed);

    /* Process each line. */
    bool headerSet = false;
    foreach (filename; cmdopt.files)
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (ulong fileLineNum, line; inputStream.bufferedByLine!(KeepTerminator.no).enumerate(1))
        {
            if (fileLineNum == 1) throwIfWindowsNewlineOnUnix(line, filename, fileLineNum);
            if (fileLineNum == 1 && cmdopt.hasHeader)
            {
                if (!headerSet)
                {
                    outputFiles.setHeader(line);
                    headerSet = true;
                }
            }
            else
            {
                immutable uint n = uniform(0, cmdopt.numFiles, randomGenerator);
                outputFiles.writeDataLine(n, line);
            }
        }

        /* Close input files immediately after use to preserve open file handles.
         * File close occurs when variable goes out scope, but not immediately in the
         * case of loop termination. Avoids open file errors when the number of
         * output files exceeds the open file limit.
         */
        if (filename != "-") inputStream.close;
    }
}

void splitLinesByKey(TsvSplitOptions cmdopt, ref SplitOutputFiles outputFiles)
{
    import std.algorithm : splitter;
    import std.conv : to;
    import std.digest.murmurhash;
    import tsv_utils.common.utils : bufferedByLine, InputFieldReordering, throwIfWindowsNewlineOnUnix;

    assert(cmdopt.keyFields.length > 0);

    immutable ubyte[1] delimArray = [cmdopt.delim]; // For assembling multi-field hash keys.

    /* Create a mapping for the key fields. */
    auto keyFieldsReordering = cmdopt.keyIsFullLine ? null : new InputFieldReordering!char(cmdopt.keyFields);

    /* Process each line. */
    bool headerSet = false;
    foreach (filename; cmdopt.files)
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (ulong fileLineNum, line; inputStream.bufferedByLine!(KeepTerminator.no).enumerate(1))
        {
            if (fileLineNum == 1) throwIfWindowsNewlineOnUnix(line, filename, fileLineNum);
            if (fileLineNum == 1 && cmdopt.hasHeader)
            {
                if (!headerSet)
                {
                    outputFiles.setHeader(line);
                    headerSet = true;
                }
            }
            else
            {
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

                    if (!keyFieldsReordering.allFieldsFilled)
                    {
                        import std.format : format;
                        throw new Exception(
                            format("Not enough fields in line. File: %s, Line: %s",
                                   (filename == "-") ? "Standard Input" : filename, fileLineNum));
                    }

                    foreach (count, key; keyFieldsReordering.outputFields.enumerate)
                    {
                        if (count > 0) hasher.put(delimArray);
                        hasher.put(cast(ubyte[]) key);
                    }
                }

                hasher.finish;
                immutable uint n = hasher.get % cmdopt.numFiles;
                outputFiles.writeDataLine(n, line);
            }
        }

        /* Close input files immediately after use to preserve open file handles.
         * File close occurs when variable goes out scope, but not immediately in the
         * case of loop termination. Avoids open file errors when the number of
         * output files exceeds the open file limit.
         */
        if (filename != "-") inputStream.close;
    }
}
