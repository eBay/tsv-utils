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

Split input files into multiple output files. Modes of operation:

* Fixed number of lines per file (--l|lines-per-file NUM): Each input
  block of NUM lines is written to a new file.

* Random assignment (--n|num-files NUM): Each input line is written to a
  randomly selected output file. NUM output files are written.

* Random assignment by key (--n|num-files NUM, --k|key-fields FIELDS):
  Input lines are written to output files using fields as a key. Each
  unique key is randomly assigned to an output file. All lines with the
  same key are written to the same file. NUM output files are written.

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
    size_t linesPerFile = 0;                   /// --l|lines-per-file
    uint numFiles = 0;                         /// --n|num-files
    size_t[] keyFields;                        /// --k|key-fields
    string dir;                                /// --dir
    string prefix = "part_";                   /// --prefix
    string suffix = ".tsv";                    /// --suffix
    bool appendToExistingFiles = false;        /// --a|append
    bool staticSeed = false;                   /// --s|static-seed
    uint seedValueOptionArg = 0;               /// --v|seed-value
    char delim = '\t';                         /// --d|delimiter
    uint maxOpenFilesArg = 0;                  /// --max-open-files
    bool versionWanted = false;                /// --V|version
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
        import std.algorithm : any, canFind, each, min;
        import std.file : exists, isDir;
        import std.format : format;
        import std.getopt;
        import std.math : isNaN;
        import std.path : baseName, expandTilde, stripExtension;
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

                "l|lines-per-file", "NUM  Number of lines to write to each file.", &linesPerFile,
                "n|num-files",      "NUM  Number of files to write.", &numFiles,
                "k|key-fields",     "<field-list>  Fields to use as key. Lines with the same key are written to the same output file. Use '--k|key-fields 0' to use the entire line as the key.",
                keyFields.makeFieldListOptionHandler!(size_t, No.convertToZeroBasedIndex, Yes.allowFieldNumZero),

                "dir",              "STR  Directory to write to. Default: Current working directory.", &dir,
                "prefix",           "STR  Filename prefix. Default: 'part_'", &prefix,
                "suffix",           "STR  Filename suffix. Default: '.tsv'", &suffix,
                "a|append",         "     Append to existing files.", &appendToExistingFiles,

                "s|static-seed",    "     Use the same random seed every run.", &staticSeed,

                std.getopt.config.caseSensitive,
                "v|seed-value",     "NUM  Sets the random seed. Use a non-zero, 32 bit positive integer. Zero is a no-op.", &seedValueOptionArg,
                std.getopt.config.caseInsensitive,

                "d|delimiter",      "CHR  Field delimiter.", &delim,
                "max-open-files",   "NUM  Maximum open file handles. Min of 5 required.", &maxOpenFilesArg,

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

            /*
             * Validation and derivations.
             */

            if (linesPerFile == 0 && numFiles == 0)
            {
                throw new Exception ("Either '--l|lines-per-file' or '--n|num-files' is required.");
            }

            if (linesPerFile != 0 && numFiles != 0)
            {
                throw new Exception ("'--l|lines-per-file' and '--n|num-files' cannot be used together.");
            }

            if (linesPerFile != 0 && keyFields.length != 0)
            {
                throw new Exception ("'--l|lines-per-file' and '--k|key-fields' cannot be used together.");
            }

            if (numFiles == 1)
            {
                throw new Exception("'--n|num-files must be two or more.");
            }

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

            if (!dir.empty)
            {
                dir = dir.expandTilde;
                if (!dir.exists) throw new Exception(format("Directory does not exist: --dir '%s'", dir));
                else if (!dir.isDir) throw new Exception(format("Path is not a directory: --dir '%s'", dir));
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

            if (maxOpenFilesArg != 0 && maxOpenFilesArg <= numReservedOpenFiles)
            {
                throw new Exception(
                    format("'--max-open-files' must be at least %d.",
                           numReservedOpenFiles + 1));
            }

            if (maxOpenFilesArg > rlimitOpenFilesLimit)
            {
                throw new Exception(
                    format("'--max-open-files' value (%d) greater current system limit (%d)." ~
                           "\nRun 'ulimit -n' to see the soft limit." ~
                           "\nRun 'ulimit -Hn' to see the hard limit." ~
                           "\nRun 'ulimit -Sn NUM' to change the soft limit.",
                           maxOpenFilesArg, rlimitOpenFilesLimit));
            }

            if (rlimitOpenFilesLimit <= numReservedOpenFiles)
            {
                throw new Exception(
                    format("System open file limit too small. Current value: %d. Must be %d or more." ~
                           "\nRun 'ulimit -n' to see the soft limit." ~
                           "\nRun 'ulimit -Hn' to see the hard limit." ~
                           "\nRun 'ulimit -Sn NUM' to change the soft limit.",
                           rlimitOpenFilesLimit, numReservedOpenFiles + 1));
            }

            immutable uint openFilesLimit =
                (maxOpenFilesArg != 0)
                ? maxOpenFilesArg
                : min(internalDefaultMaxOpenFiles, rlimitOpenFilesLimit);

            assert(openFilesLimit > numReservedOpenFiles);

            maxOpenOutputFiles = openFilesLimit - numReservedOpenFiles;

            /* Remaining command line args.
             *
             * Assume remaining args are files. Use standard input if files were not
             * provided.
             */

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

/** A SplitOutputFiles struct holds the collection of output files.
 *
 * This struct manages the collection of output files. This includes filenames,
 * opening and closing files, and writing data and header lines.
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
    import std.format : format;
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

    this(uint numFiles, string dir, string filePrefix, string fileSuffix, bool writeHeaders, uint maxOpenFiles)
    {
        assert(numFiles >= 2);
        assert(maxOpenFiles >= 1);

        _numFiles = numFiles;
        _writeHeaders = writeHeaders;
        _maxOpenFiles = maxOpenFiles;

        _outputFiles.length = numFiles;

        /* Filename assignment. */
        uint numPrintDigits = 1;
        uint x = _numFiles - 1;
        while (x >= 10)
        {
            x /= 10;
            ++numPrintDigits;
        }

        foreach (i, ref f; _outputFiles)
        {
            f.filename =
                buildPath(dir, format("%s%.*d%s", filePrefix, numPrintDigits, i, fileSuffix));
        }
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
     * Should be called prior to writeDataLine when headers are being written. This
     * is operation is separate from the constructor because the header is not known
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
                _outputFiles[i].ofile.flush;
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

            outputFile.ofile = outputFile.filename.File("a");
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

/* Get the rlimit current number of open files the process is allowed.
 *
 * This routine returns the current soft limit on the number of open files the process
 * is allowed. This is the number returned by the command: '$ ulimit -n'.
 *
 * This routine translates this value to a 'uint', as tsv-split uses 'uint' for
 * tracking output files. The rlimit 'rlim_t' type is usually 'ulong' or 'long'.
 * RLIM_INFINITY and any value larger than 'uint.max' is translated to 'uint.max'.
 *
 * An exception is thrown if call to 'getrlimit' fails.
 */
uint rlimitCurrOpenFilesLimit()
{
    import core.sys.posix.sys.resource :
        rlim_t, rlimit, getrlimit, RLIMIT_NOFILE, RLIM_INFINITY, RLIM_SAVED_CUR;
    import std.conv : to;

    uint currOpenFileLimit = uint.max;

    rlimit rlimitMaxOpenFiles;

    if (getrlimit(RLIMIT_NOFILE, &rlimitMaxOpenFiles) != 0)
    {
        throw new Exception("Internal error: getrlimit call failed");
    }

    if (rlimitMaxOpenFiles.rlim_cur != RLIM_INFINITY &&
        rlimitMaxOpenFiles.rlim_cur != RLIM_SAVED_CUR &&
        rlimitMaxOpenFiles.rlim_cur >= 0 &&
        rlimitMaxOpenFiles.rlim_cur <= uint.max)
    {
        currOpenFileLimit = rlimitMaxOpenFiles.rlim_cur.to!uint;
    }

    return currOpenFileLimit;
}

/** Invokes the proper split routine based on the command line arguments.
 */
void tsvSplit(TsvSplitOptions cmdopt)
{
    import std.format : format;

    if (cmdopt.linesPerFile != 0)
    {
        splitByLineCount(cmdopt);
    }
    else
    {
        /* Split into a specified number of files. */

        auto outputFiles =
            SplitOutputFiles(cmdopt.numFiles, cmdopt.dir, cmdopt.prefix,
                             cmdopt.suffix, cmdopt.headerInOut, cmdopt.maxOpenOutputFiles);

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

void splitLinesRandomly(TsvSplitOptions cmdopt, ref SplitOutputFiles outputFiles)
{
    import std.random : Random = Mt19937, uniform;
    import tsv_utils.common.utils : bufferedByLine, throwIfWindowsNewlineOnUnix;

    auto randomGenerator = Random(cmdopt.seed);

    /* Process each line. */
    foreach (inputFileNum, filename; cmdopt.files)
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (ulong fileLineNum, line; inputStream.bufferedByLine!(KeepTerminator.no).enumerate(1))
        {
            if (fileLineNum == 1) throwIfWindowsNewlineOnUnix(line, filename, fileLineNum);
            if (fileLineNum == 1 && cmdopt.hasHeader)
            {
                if (inputFileNum == 0) outputFiles.setHeader(line);
            }
            else
            {
                immutable uint outputFileNum = uniform(0, cmdopt.numFiles, randomGenerator);
                outputFiles.writeDataLine(outputFileNum, line);
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
    foreach (inputFileNum, filename; cmdopt.files)
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (ulong fileLineNum, line; inputStream.bufferedByLine!(KeepTerminator.no).enumerate(1))
        {
            if (fileLineNum == 1) throwIfWindowsNewlineOnUnix(line, filename, fileLineNum);
            if (fileLineNum == 1 && cmdopt.hasHeader)
            {
                if (inputFileNum == 0) outputFiles.setHeader(line);
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
                immutable uint outputFileNum = hasher.get % cmdopt.numFiles;
                outputFiles.writeDataLine(outputFileNum, line);
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

struct OutputFileSequence
{
    import std.conv : to;
    import std.file : exists;
    import std.format : format;
    import std.path : buildPath;
    import std.stdio : File;

    private size_t _linesPerFile;
    private string _dir;
    private string _filePrefix;
    private string _fileSuffix;
    private bool _writeHeaders;
    private bool _appendToExistingFiles;

    private string _header;

    private size_t _nextFileNum;
    private string _currFileName;
    private File _currOFile;
    private size_t _currLinesWritten;
    private bool _currFileOpen;

    this(size_t linesPerFile, string dir, string filePrefix, string fileSuffix,
         bool writeHeaders, bool appendToExisting)
    {
            _linesPerFile = linesPerFile;
            _dir = dir;
            _filePrefix = filePrefix;
            _fileSuffix = fileSuffix;
            _writeHeaders = writeHeaders;
            _appendToExistingFiles = appendToExisting;
    }

    ~this()
    {
        if (_currFileOpen)
        {
            _currOFile.flush;
            _currOFile.close;
            _currFileOpen = false;
        }
    }

     /* Sets the header line.
     *
     * Should be called prior to writeDataLine when headers are being written. This
     * is operation is separate from the constructor because the header is not known
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

    void writeDataLine(const char[] data)
    {
        /* See if a new file needs to be opened. */
        if (_currLinesWritten == 0)
        {
            _currFileName =
                buildPath(_dir, format("%s%d%s", _filePrefix, _nextFileNum, _fileSuffix));

            if (!_appendToExistingFiles && _currFileName.exists)
            {
                throw new Exception(
                format("Output file already exists. Use '--a|append' to append to existing files. File: '%s'.",
                       _currFileName));
            }

            _currOFile = _currFileName.File("a");
            _currFileOpen = true;
            ++_nextFileNum;

            if (_writeHeaders)
            {
                ulong filesize = _currOFile.size;
                if (filesize == 0 || filesize == ulong.max)
                {
                    _currOFile.writeln(_header);
                }
            }
        }

        _currOFile.writeln(data);
        ++_currLinesWritten;

        if (_currLinesWritten == _linesPerFile)
        {
            _currOFile.flush;
            _currOFile.close;
            _currFileOpen = false;
            _currLinesWritten = 0;
        }
    }
}

void splitByLineCount(TsvSplitOptions cmdopt)
{
    import tsv_utils.common.utils : bufferedByLine, throwIfWindowsNewlineOnUnix;

    auto outputFiles =
        OutputFileSequence(cmdopt.linesPerFile, cmdopt.dir, cmdopt.prefix, cmdopt.suffix,
                           cmdopt.headerInOut, cmdopt.appendToExistingFiles);

    foreach (inputFileNum, filename; cmdopt.files)
    {
        auto inputStream = (filename == "-") ? stdin : filename.File();
        foreach (ulong fileLineNum, line; inputStream.bufferedByLine!(KeepTerminator.no).enumerate(1))
        {
            if (fileLineNum == 1) throwIfWindowsNewlineOnUnix(line, filename, fileLineNum);
            if (fileLineNum == 1 && cmdopt.hasHeader)
            {
                if (inputFileNum == 0) outputFiles.setHeader(line);
            }
            else
            {
                outputFiles.writeDataLine(line);
            }
        }
    }
}

unittest
{
    /* TsvSplitOptions unit tests.
     * 
     * Very basic here. Mostly covered in executable tests, especially error cases, as
     * errors write to stderr.
     */
    {
        auto args = ["unittest", "--lines-per-file", "10"];
        TsvSplitOptions cmdopt;
        const r = cmdopt.processArgs(args);

        assert(cmdopt.files == ["-"]);
        assert(cmdopt.linesPerFile == 10);
        assert(cmdopt.keyFields.empty);
        assert(cmdopt.numFiles == 0);
        assert(cmdopt.hasHeader == false);
    }
    {
        auto args = ["unittest", "--num-files", "20"];
        TsvSplitOptions cmdopt;
        const r = cmdopt.processArgs(args);

        assert(cmdopt.files == ["-"]);
        assert(cmdopt.linesPerFile == 0);
        assert(cmdopt.keyFields.empty);
        assert(cmdopt.numFiles == 20);
        assert(cmdopt.hasHeader == false);
    }
    {
        auto args = ["unittest", "-n", "5", "--key-fields", "1-3"];
        TsvSplitOptions cmdopt;
        const r = cmdopt.processArgs(args);

        assert(cmdopt.linesPerFile == 0);
        assert(cmdopt.keyFields == [0, 1, 2]);
        assert(cmdopt.numFiles == 5);
        assert(cmdopt.hasHeader == false);
        assert(cmdopt.keyIsFullLine == false);
    }
    {
        auto args = ["unittest", "-n", "5", "-k", "0"];
        TsvSplitOptions cmdopt;
        const r = cmdopt.processArgs(args);

        assert(cmdopt.linesPerFile == 0);
        assert(cmdopt.numFiles == 5);
        assert(cmdopt.hasHeader == false);
        assert(cmdopt.keyIsFullLine == true);
    }
    {
        auto args = ["unittest", "-n", "2", "--header"];
        TsvSplitOptions cmdopt;
        const r = cmdopt.processArgs(args);

        assert(cmdopt.headerInOut == true);
        assert(cmdopt.hasHeader == true);
        assert(cmdopt.headerIn == false);
    }
    {
        auto args = ["unittest", "-n", "2", "--header-in-only"];
        TsvSplitOptions cmdopt;
        const r = cmdopt.processArgs(args);

        assert(cmdopt.headerInOut == false);
        assert(cmdopt.hasHeader == true);
        assert(cmdopt.headerIn == true);
    }
}
