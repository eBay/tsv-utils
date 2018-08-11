/**
Convert CSV formatted data to TSV format.

This program converts comma-separated value data to tab-separated format.

Copyright (c) 2016-2018, eBay Software Foundation
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)
*/

module csv2tsv;

import std.stdio;
import std.format : format;
import std.range;
import std.traits : Unqual;
import std.typecons : Nullable, tuple;

auto helpText = q"EOS
Synopsis: csv2tsv [options] [file...]

csv2tsv converts comma-separated text (CSV) to tab-separated format (TSV). Records
are read from files or standard input, converted records written to standard output.
Use '--help-verbose' for details the CSV formats accepted.

Options:
EOS";

auto helpTextVerbose = q"EOS
Synopsis: csv2tsv [options] [file...]

csv2tsv converts CSV (comma-separated) text to TSV (tab-separated) format. Records
are read from files or standard input, converted records written to standard output.

Both formats represent tabular data, each record on its own line, fields separated
by a delimiter character. The key difference is that CSV uses escape sequences to
represent newlines and field separators in the data, whereas TSV disallows these
characters in the data. The most common field delimiters are comma for CSV and tab
for TSV, but any character can be used.

Conversion to TSV is done by removing CSV escape syntax, changing field delimiters,
and replacing newlines and field delimiters in the data. By default, newlines and
field delimiters in the data are replaced by spaces. Most details are customizable.

There is no single spec for CSV, any number of variants can be found. The escape
syntax is common enough: fields containing newlines or field delimiters are placed
in double quotes. Inside a quoted field, a double quote is represented by a pair of
double quotes. As with field separators, the quoting character is customizable.

Behaviors of this program that often vary between CSV implementations:
  * Newlines are supported in quoted fields.
  * Double quotes are permitted in a non-quoted field. However, a field starting
    with a quote must follow quoting rules.
  * Each record can have a different numbers of fields.
  * The three common forms of newlines are supported: CR, CRLF, LF.
  * A newline will be added if the file does not end with one.
  * No whitespace trimming is done.

This program does not validate CSV correctness, but will terminate with an error
upon reaching an inconsistent state. Improperly terminated quoted fields are the
primary cause.

UTF-8 input is assumed. Convert other encodings prior to invoking this tool.

Options:
EOS";

/** Container for command line options.
 */
struct Csv2tsvOptions
{
    string programName;
    bool helpVerbose = false;          // --help-verbose
    bool hasHeader = false;            // --H|header
    char csvQuoteChar = '"';           // --q|quote
    char csvDelimChar = ',';           // --c|csv-delim
    char tsvDelimChar = '\t';          // --t|tsv-delim
    string tsvDelimReplacement = " ";  // --r|replacement
    bool versionWanted = false;        // --V|version

    auto processArgs (ref string[] cmdArgs)
    {
        import std.algorithm : canFind;
        import std.getopt;
        import std.path : baseName, stripExtension;

        programName = (cmdArgs.length > 0) ? cmdArgs[0].stripExtension.baseName : "Unknown_program_name";

        try
        {
            auto r = getopt(
                cmdArgs,
                "help-verbose",  "     Print full help.", &helpVerbose,
                std.getopt.config.caseSensitive,
                "H|header",      "     Treat the first line of each file as a header. Only the header of the first file is output.", &hasHeader,
                std.getopt.config.caseSensitive,
                "q|quote",       "CHR  Quoting character in CSV data. Default: double-quote (\")", &csvQuoteChar,
                "c|csv-delim",   "CHR  Field delimiter in CSV data. Default: comma (,).", &csvDelimChar,
                "t|tsv-delim",   "CHR  Field delimiter in TSV data. Default: TAB", &tsvDelimChar,
                "r|replacement", "STR  Replacement for newline and TSV field delimiters found in CSV input. Default: Space.", &tsvDelimReplacement,
                std.getopt.config.caseSensitive,
                "V|version",     "     Print version information and exit.", &versionWanted,
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
            else if (versionWanted)
            {
                import tsvutils_version;
                writeln(tsvutilsVersionNotice("csv2tsv"));
                return tuple(false, 0);
            }

            /* Consistency checks. */
            if (csvQuoteChar == '\n' || csvQuoteChar == '\r')
            {
                throw new Exception ("CSV quote character cannot be newline (--q|quote).");
            }

            if (csvQuoteChar == csvDelimChar)
            {
                throw new Exception("CSV quote and CSV field delimiter characters must be different (--q|quote, --c|csv-delim).");
            }

            if (csvQuoteChar == tsvDelimChar)
            {
                throw new Exception("CSV quote and TSV field delimiter characters must be different (--q|quote, --t|tsv-delim).");
            }

            if (csvDelimChar == '\n' || csvDelimChar == '\r')
            {
                throw new Exception ("CSV field delimiter cannot be newline (--c|csv-delim).");
            }

            if (tsvDelimChar == '\n' || tsvDelimChar == '\r')
            {
                throw new Exception ("TSV field delimiter cannot be newline (--t|tsv-delimiter).");
            }

            if (canFind!(c => (c == '\n' || c == '\r' || c == tsvDelimChar))(tsvDelimReplacement))
            {
                throw new Exception ("Replacement character cannot contain newlines or TSV field delimiters (--r|replacement).");
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

version(unittest)
{
    // No main in unittest
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

        Csv2tsvOptions cmdopt;
        auto r = cmdopt.processArgs(cmdArgs);
        if (!r[0]) return r[1];
        version(LDC_Profile)
        {
            import ldc.profile : resetAll;
            resetAll();
        }
        try csv2tsvFiles(cmdopt, cmdArgs[1..$]);
        catch (Exception exc)
        {
            writeln();
            stdin.flush();
            stderr.writefln("Error [%s]: %s", cmdopt.programName, exc.msg);
            return 1;
        }

        return 0;
    }
}

/* This uses a D feature where a type can reserve a single value to represent null. */
alias NullableSizeT = Nullable!(size_t, size_t.max);


/** csv2tsvFiles reads multiple files and standard input and writes the results to
 * standard output. 
 */
void csv2tsvFiles(in Csv2tsvOptions cmdopt, in string[] inputFiles)
{
    import std.algorithm : joiner;
    import tsvutil : BufferedOutputRange;

    ubyte[1024 * 1024] fileRawBuf;
    ubyte[] stdinRawBuf = fileRawBuf[0..1024];
    auto stdoutWriter = BufferedOutputRange!(typeof(stdout))(stdout);
    bool firstFile = true;

    foreach (filename; (inputFiles.length > 0) ? inputFiles : ["-"])
    {
        auto ubyteChunkedStream = (filename == "-") ?
            stdin.byChunk(stdinRawBuf) : filename.File.byChunk(fileRawBuf);
        auto ubyteStream = ubyteChunkedStream.joiner;

        if (firstFile || !cmdopt.hasHeader)
        {
            csv2tsv(ubyteStream, stdoutWriter, filename, 0,
                    cmdopt.csvQuoteChar, cmdopt.csvDelimChar,
                    cmdopt.tsvDelimChar, cmdopt.tsvDelimReplacement);
        }
        else
        {
            /* Don't write the header on subsequent files. Write the first
             * record to a null sink instead.
             */
            auto nullWriter = NullSink();
            csv2tsv(ubyteStream, nullWriter, filename, 0,
                    cmdopt.csvQuoteChar, cmdopt.csvDelimChar,
                    cmdopt.tsvDelimChar, cmdopt.tsvDelimReplacement,
                    NullableSizeT(1));
            csv2tsv(ubyteStream, stdoutWriter, filename, 1,
                    cmdopt.csvQuoteChar, cmdopt.csvDelimChar,
                    cmdopt.tsvDelimChar, cmdopt.tsvDelimReplacement);
        }
        firstFile = false;
    }
}

/** Read CSV from an input source, covert to TSV and write to an output source.
 *
 * Params:
 *   InputRange          =  A ubyte input range to read CSV text from. A ubyte range
 *                          matched byChunck. It also avoids convesion to dchar by front().
 *   OutputRange         =  An output range to write TSV text to.
 *   filename            =  Name of file to use when reporting errors. A descriptive name
 *                       =  can be used in lieu of a file name.
 *   currFileLineNumber  =  First line being processed. Used when reporting errors. Needed
 *                          only when part of the input has already been processed.
 *   csvQuote            =  The quoting character used in the input CSV file.
 *   csvDelim            =  The field delimiter character used in the input CSV file.
 *   tsvDelim            =  The field delimiter character to use in the generated TSV file.
 *   tsvDelimReplacement =  A string to use when replacing newlines and TSV field delimiters
 *                          occurring in CSV fields.
 *   maxRecords          =  The maximum number of records to process (output lines). This is
 *                          intended to support processing the header line separately.
 *
 * Throws: Exception on finding inconsistent CSV. Exception text includes the filename and
 *         line number where the error was identified.
 */
void csv2tsv(InputRange, OutputRange)
    (ref InputRange inputStream, ref OutputRange outputStream,
     string filename = "(none)", size_t currFileLineNumber = 0,
     const char csvQuote = '"', const char csvDelim = ',', const char tsvDelim = '\t',
     string tsvDelimReplacement = " ",
     NullableSizeT maxRecords=NullableSizeT.init,
        )
    if (isInputRange!InputRange && isOutputRange!(OutputRange, char) &&
        is(Unqual!(ElementType!InputRange) == ubyte))
{
    enum State { FieldEnd, NonQuotedField, QuotedField, QuoteInQuotedField }

    State currState = State.FieldEnd;
    size_t recordNum = 1;      // Record number. Output line number.
    size_t fieldNum = 0;       // Field on current line.

InputLoop: while (!inputStream.empty)
    {
        char nextChar = inputStream.front;
        inputStream.popFront;

        if (nextChar == '\r')
        {
            /* Collapse newline cases to '\n'. */
            if (!inputStream.empty && inputStream.front == '\n')
            {
                inputStream.popFront;
            }
            nextChar = '\n';
        }

    OuterSwitch: final switch (currState)
        {
        case State.FieldEnd:
            /* Start of input or after consuming a field terminator. */
            ++fieldNum;

            /* Note: Can't use a switch here do the 'goto case' to the OuterSwitch.  */
            if (nextChar == csvQuote)
            {
                currState = State.QuotedField;
                break OuterSwitch;
            }
            else
            {
                /* Processing state change only. Don't consume the character. */
                currState = State.NonQuotedField;
                goto case State.NonQuotedField;
            }

        case State.NonQuotedField:
            switch (nextChar)
            {
            default:
                put(outputStream, nextChar);
                break OuterSwitch;
            case csvDelim:
                put(outputStream, tsvDelim);
                currState = State.FieldEnd;
                break OuterSwitch;
            case tsvDelim:
                put(outputStream, tsvDelimReplacement);
                break OuterSwitch;
            case '\n':
                put(outputStream, '\n');
                ++recordNum;
                fieldNum = 0;
                currState = State.FieldEnd;
                if (!maxRecords.isNull && recordNum > maxRecords) break InputLoop;
                else break OuterSwitch;
            }

        case State.QuotedField:
            switch (nextChar)
            {
            default:
                put(outputStream, nextChar);
                break OuterSwitch;
            case csvQuote:
                /* Quote in a quoted field. Need to look at the next character.*/
                if (!inputStream.empty)
                {
                    currState = State.QuoteInQuotedField;
                }
                else
                {
                    /* End of input. A rare case: Quoted field on last line with no
                     * following trailing newline. Reset the state to avoid triggering
                     * an invalid quoted field exception, plus adding additional newline.
                     */
                    currState = State.FieldEnd;
                }
                break OuterSwitch;
            case '\n':
                /* Newline in a quoted field. */
                put(outputStream, tsvDelimReplacement);
                break OuterSwitch;
            case tsvDelim:
                put(outputStream, tsvDelimReplacement);
                break OuterSwitch;
            }

        case State.QuoteInQuotedField:
            /* Just processed a quote in a quoted field. */
            switch (nextChar)
            {
            case csvQuote:
                put(outputStream, csvQuote);
                currState = State.QuotedField;
                break OuterSwitch;
            case csvDelim:
                put(outputStream, tsvDelim);
                currState = State.FieldEnd;
                break OuterSwitch;
            case '\n':
                put(outputStream, '\n');
                ++recordNum;
                fieldNum = 0;
                currState = State.FieldEnd;

                if (!maxRecords.isNull && recordNum > maxRecords) break InputLoop;
                else break OuterSwitch;
            default:
                throw new Exception(
                    format("Invalid CSV. Improperly terminated quoted field. File: %s, Line: %d",
                           (filename == "-") ? "Standard Input" : filename,
                           currFileLineNumber + recordNum));
            }
        }
    }

    if (currState == State.QuotedField)
    {
        throw new Exception(
            format("Invalid CSV. Improperly terminated quoted field. File: %s, Line: %d",
                   (filename == "-") ? "Standard Input" : filename,
                   currFileLineNumber + recordNum));
    }

    if (fieldNum > 0) put(outputStream, '\n');    // Last line w/o terminating newline.
}

unittest
{
    /* Unit tests for the csv2tsv function.
     *
     * These unit tests exercise different CSV combinations and escaping cases. The CSV
     * data content is the same for each corresponding test string, except the delimiters
     * have been changed. e.g csv6a and csv6b have the same data content.
     *
     * A property used in these tests is that changing the CSV delimiters doesn't change
     * the resulting TSV. However, changing the TSV delimiters will change the TSV result,
     * as TSV doesn't support having it's delimiters in the data. This allows having a
     * single TSV expected set that is generated by CSVs with different delimter sets.
     *
     * This test set does not test main, file handling, or error messages. These are
     * handled by tests run against the executable.
     */

    /* Default CSV. */
    auto csv1a = "a,b,c";
    auto csv2a = "a,bc,,,def";
    auto csv3a = ",a, b , cd ,";
    auto csv4a = "ß,ßÀß,あめりか物語,书名: 五色石";
    auto csv5a = "\"\n\",\"\n\n\",\"\n\n\n\"";
    auto csv6a = "\"\t\",\"\t\t\",\"\t\t\t\"";
    auto csv7a = "\",\",\",,\",\",,,\"";
    auto csv8a = "\"\",\"\"\"\",\"\"\"\"\"\"";
    auto csv9a = "\"ab, de\tfg\"\"\nhij\"";
    auto csv10a = "";
    auto csv11a = ",";
    auto csv12a = ",,";
    auto csv13a = "\"\r\",\"\r\r\",\"\r\r\r\"";
    auto csv14a = "\"\r\n\",\"\r\n\r\n\",\"\r\n\r\n\r\n\"";
    auto csv15a = "\"ab, de\tfg\"\"\rhij\"";
    auto csv16a = "\"ab, de\tfg\"\"\r\nhij\"";
    auto csv17a = "ab\",ab\"cd";
    auto csv18a = "\n\n\n";
    auto csv19a = "\t";
    auto csv20a = "\t\t";
    auto csv21a = "a\n";
    auto csv22a = "a,\n";
    auto csv23a = "a,b\n";
    auto csv24a = ",\n";
    auto csv25a = "#";
    auto csv26a = "^";
    auto csv27a = "#^#";
    auto csv28a = "^#^";
    auto csv29a = "$";
    auto csv30a = "$,$\n\"$\",\"$$\",$$\n^#$,$#^,#$^,^$#\n";
    auto csv31a = "1-1\n2-1,2-2\n3-1,3-2,3-3\n\n,5-2\n,,6-3\n";
    auto csv32a = ",1-2,\"1-3\"\n\"2-1\",\"2-2\",\n\"3-1\",,\"3-3\"";

    /* Set B has the same data and TSV results as set A, but uses # for quote and ^ for comma. */
    auto csv1b = "a^b^c";
    auto csv2b = "a^bc^^^def";
    auto csv3b = "^a^ b ^ cd ^";
    auto csv4b = "ß^ßÀß^あめりか物語^书名: 五色石";
    auto csv5b = "#\n#^#\n\n#^#\n\n\n#";
    auto csv6b = "#\t#^#\t\t#^#\t\t\t#";
    auto csv7b = "#,#^#,,#^#,,,#";
    auto csv8b = "##^#\"#^#\"\"#";
    auto csv9b = "#ab, de\tfg\"\nhij#";
    auto csv10b = "";
    auto csv11b = "^";
    auto csv12b = "^^";
    auto csv13b = "#\r#^#\r\r#^#\r\r\r#";
    auto csv14b = "#\r\n#^#\r\n\r\n#^#\r\n\r\n\r\n#";
    auto csv15b = "#ab, de\tfg\"\rhij#";
    auto csv16b = "#ab, de\tfg\"\r\nhij#";
    auto csv17b = "ab\"^ab\"cd";
    auto csv18b = "\n\n\n";
    auto csv19b = "\t";
    auto csv20b = "\t\t";
    auto csv21b = "a\n";
    auto csv22b = "a^\n";
    auto csv23b = "a^b\n";
    auto csv24b = "^\n";
    auto csv25b = "####";
    auto csv26b = "#^#";
    auto csv27b = "###^###";
    auto csv28b = "#^##^#";
    auto csv29b = "$";
    auto csv30b = "$^$\n#$#^#$$#^$$\n#^##$#^#$##^#^###$^#^#^$###\n";
    auto csv31b = "1-1\n2-1^2-2\n3-1^3-2^3-3\n\n^5-2\n^^6-3\n";
    auto csv32b = "^1-2^#1-3#\n#2-1#^#2-2#^\n#3-1#^^#3-3#";

    /* The expected results for csv sets A and B. This is for the default TSV delimiters.*/
    auto tsv1 = "a\tb\tc\n";
    auto tsv2 = "a\tbc\t\t\tdef\n";
    auto tsv3 = "\ta\t b \t cd \t\n";
    auto tsv4 = "ß\tßÀß\tあめりか物語\t书名: 五色石\n";
    auto tsv5 = " \t  \t   \n";
    auto tsv6 = " \t  \t   \n";
    auto tsv7 = ",\t,,\t,,,\n";
    auto tsv8 = "\t\"\t\"\"\n";
    auto tsv9 = "ab, de fg\" hij\n";
    auto tsv10 = "";
    auto tsv11 = "\t\n";
    auto tsv12 = "\t\t\n";
    auto tsv13 = " \t  \t   \n";
    auto tsv14 = " \t  \t   \n";
    auto tsv15 = "ab, de fg\" hij\n";
    auto tsv16 = "ab, de fg\" hij\n";
    auto tsv17 = "ab\"\tab\"cd\n";
    auto tsv18 = "\n\n\n";
    auto tsv19 = " \n";
    auto tsv20 = "  \n";
    auto tsv21 = "a\n";
    auto tsv22 = "a\t\n";
    auto tsv23 = "a\tb\n";
    auto tsv24 = "\t\n";
    auto tsv25 = "#\n";
    auto tsv26 = "^\n";
    auto tsv27 = "#^#\n";
    auto tsv28 = "^#^\n";
    auto tsv29 = "$\n";
    auto tsv30 = "$\t$\n$\t$$\t$$\n^#$\t$#^\t#$^\t^$#\n";
    auto tsv31 = "1-1\n2-1\t2-2\n3-1\t3-2\t3-3\n\n\t5-2\n\t\t6-3\n";
    auto tsv32 = "\t1-2\t1-3\n2-1\t2-2\t\n3-1\t\t3-3\n";

    /* The TSV results for CSV sets 1a and 1b, but with $ as the delimiter rather than tab.
     * This will also result in different replacements when TAB and $ appear in the CSV.
     */
    auto tsv1_x = "a$b$c\n";
    auto tsv2_x = "a$bc$$$def\n";
    auto tsv3_x = "$a$ b $ cd $\n";
    auto tsv4_x = "ß$ßÀß$あめりか物語$书名: 五色石\n";
    auto tsv5_x = " $  $   \n";
    auto tsv6_x = "\t$\t\t$\t\t\t\n";
    auto tsv7_x = ",$,,$,,,\n";
    auto tsv8_x = "$\"$\"\"\n";
    auto tsv9_x = "ab, de\tfg\" hij\n";
    auto tsv10_x = "";
    auto tsv11_x = "$\n";
    auto tsv12_x = "$$\n";
    auto tsv13_x = " $  $   \n";
    auto tsv14_x = " $  $   \n";
    auto tsv15_x = "ab, de\tfg\" hij\n";
    auto tsv16_x = "ab, de\tfg\" hij\n";
    auto tsv17_x = "ab\"$ab\"cd\n";
    auto tsv18_x = "\n\n\n";
    auto tsv19_x = "\t\n";
    auto tsv20_x = "\t\t\n";
    auto tsv21_x = "a\n";
    auto tsv22_x = "a$\n";
    auto tsv23_x = "a$b\n";
    auto tsv24_x = "$\n";
    auto tsv25_x = "#\n";
    auto tsv26_x = "^\n";
    auto tsv27_x = "#^#\n";
    auto tsv28_x = "^#^\n";
    auto tsv29_x = " \n";
    auto tsv30_x = " $ \n $  $  \n^# $ #^$# ^$^ #\n";
    auto tsv31_x = "1-1\n2-1$2-2\n3-1$3-2$3-3\n\n$5-2\n$$6-3\n";
    auto tsv32_x = "$1-2$1-3\n2-1$2-2$\n3-1$$3-3\n";

    /* The TSV results for CSV sets 1a and 1b, but with $ as the delimiter rather than tab,
     * and with the delimiter/newline replacement string being |--|. Basically, newlines
     * and '$' in the original data are replaced by |--|.
     */
    auto tsv1_y = "a$b$c\n";
    auto tsv2_y = "a$bc$$$def\n";
    auto tsv3_y = "$a$ b $ cd $\n";
    auto tsv4_y = "ß$ßÀß$あめりか物語$书名: 五色石\n";
    auto tsv5_y = "|--|$|--||--|$|--||--||--|\n";
    auto tsv6_y = "\t$\t\t$\t\t\t\n";
    auto tsv7_y = ",$,,$,,,\n";
    auto tsv8_y = "$\"$\"\"\n";
    auto tsv9_y = "ab, de\tfg\"|--|hij\n";
    auto tsv10_y = "";
    auto tsv11_y = "$\n";
    auto tsv12_y = "$$\n";
    auto tsv13_y = "|--|$|--||--|$|--||--||--|\n";
    auto tsv14_y = "|--|$|--||--|$|--||--||--|\n";
    auto tsv15_y = "ab, de\tfg\"|--|hij\n";
    auto tsv16_y = "ab, de\tfg\"|--|hij\n";
    auto tsv17_y = "ab\"$ab\"cd\n";
    auto tsv18_y = "\n\n\n";
    auto tsv19_y = "\t\n";
    auto tsv20_y = "\t\t\n";
    auto tsv21_y = "a\n";
    auto tsv22_y = "a$\n";
    auto tsv23_y = "a$b\n";
    auto tsv24_y = "$\n";
    auto tsv25_y = "#\n";
    auto tsv26_y = "^\n";
    auto tsv27_y = "#^#\n";
    auto tsv28_y = "^#^\n";
    auto tsv29_y = "|--|\n";
    auto tsv30_y = "|--|$|--|\n|--|$|--||--|$|--||--|\n^#|--|$|--|#^$#|--|^$^|--|#\n";
    auto tsv31_y = "1-1\n2-1$2-2\n3-1$3-2$3-3\n\n$5-2\n$$6-3\n";
    auto tsv32_y = "$1-2$1-3\n2-1$2-2$\n3-1$$3-3\n";

    auto csvSet1a = [csv1a, csv2a, csv3a, csv4a, csv5a, csv6a, csv7a, csv8a, csv9a, csv10a,
                     csv11a, csv12a, csv13a, csv14a, csv15a, csv16a, csv17a, csv18a, csv19a, csv20a,
                     csv21a, csv22a, csv23a, csv24a, csv25a, csv26a, csv27a, csv28a, csv29a, csv30a,
                     csv31a, csv32a];

    auto csvSet1b = [csv1b, csv2b, csv3b, csv4b, csv5b, csv6b, csv7b, csv8b, csv9b, csv10b,
                     csv11b, csv12b, csv13b, csv14b, csv15b, csv16b, csv17b, csv18b, csv19b, csv20b,
                     csv21b, csv22b, csv23b, csv24b, csv25b, csv26b, csv27b, csv28b, csv29b, csv30b,
                     csv31b, csv32b];

    auto tsvSet1  = [tsv1, tsv2, tsv3, tsv4, tsv5, tsv6, tsv7, tsv8, tsv9, tsv10,
                     tsv11, tsv12, tsv13, tsv14, tsv15, tsv16, tsv17, tsv18, tsv19, tsv20,
                     tsv21, tsv22, tsv23, tsv24, tsv25, tsv26, tsv27, tsv28, tsv29, tsv30,
                     tsv31, tsv32];

    auto tsvSet1_x  = [tsv1_x, tsv2_x, tsv3_x, tsv4_x, tsv5_x, tsv6_x, tsv7_x, tsv8_x, tsv9_x, tsv10_x,
                       tsv11_x, tsv12_x, tsv13_x, tsv14_x, tsv15_x, tsv16_x, tsv17_x, tsv18_x, tsv19_x, tsv20_x,
                       tsv21_x, tsv22_x, tsv23_x, tsv24_x, tsv25_x, tsv26_x, tsv27_x, tsv28_x, tsv29_x, tsv30_x,
                       tsv31_x, tsv32_x];

    auto tsvSet1_y  = [tsv1_y, tsv2_y, tsv3_y, tsv4_y, tsv5_y, tsv6_y, tsv7_y, tsv8_y, tsv9_y, tsv10_y,
                       tsv11_y, tsv12_y, tsv13_y, tsv14_y, tsv15_y, tsv16_y, tsv17_y, tsv18_y, tsv19_y, tsv20_y,
                       tsv21_y, tsv22_y, tsv23_y, tsv24_y, tsv25_y, tsv26_y, tsv27_y, tsv28_y, tsv29_y, tsv30_y,
                       tsv31_y, tsv32_y];

    foreach (i, csva, csvb, tsv, tsv_x, tsv_y; lockstep(csvSet1a, csvSet1b, tsvSet1, tsvSet1_x, tsvSet1_y))
    {
        import std.conv : to;

        /* Byte streams for csv2tsv. Consumed by csv2tsv, so need to be reset when re-used. */
        ubyte[] csvInputA = cast(ubyte[])csva;
        ubyte[] csvInputB = cast(ubyte[])csvb;

        /* CSV Set A vs TSV expected. */
        auto tsvResultA = appender!(char[])();
        csv2tsv(csvInputA, tsvResultA, "csvInputA_defaultTSV", i);
        assert(tsv == tsvResultA.data,
               format("Unittest failure. tsv != tsvResultA.data. Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csva, tsv, tsvResultA.data));

        /* CSV Set B vs TSV expected. Different CSV delimiters, same TSV results as CSV Set A.*/
        auto tsvResultB = appender!(char[])();
        csv2tsv(csvInputB, tsvResultB, "csvInputB_defaultTSV", i, '#', '^');
        assert(tsv == tsvResultB.data,
               format("Unittest failure. tsv != tsvResultB.data.  Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csvb, tsv, tsvResultB.data));

        /* CSV Set A and TSV with $ separator.*/
        csvInputA = cast(ubyte[])csva;
        auto tsvResult_XA = appender!(char[])();
        csv2tsv(csvInputA, tsvResult_XA, "csvInputA_TSV_WithDollarDelimiter", i, '"', ',', '$');
        assert(tsv_x == tsvResult_XA.data,
               format("Unittest failure. tsv_x != tsvResult_XA.data. Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csva, tsv_x, tsvResult_XA.data));

        /* CSV Set B and TSV with $ separator. Same TSV results as CSV Set A.*/
        csvInputB = cast(ubyte[])csvb;
        auto tsvResult_XB = appender!(char[])();
        csv2tsv(csvInputB, tsvResult_XB, "csvInputB__TSV_WithDollarDelimiter", i, '#', '^', '$');
        assert(tsv_x == tsvResult_XB.data,
               format("Unittest failure. tsv_x != tsvResult_XB.data.  Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csvb, tsv_x, tsvResult_XB.data));

        /* CSV Set A and TSV with $ separator and tsv delimiter/newline replacement. */
        csvInputA = cast(ubyte[])csva;
        auto tsvResult_YA = appender!(char[])();
        csv2tsv(csvInputA, tsvResult_YA, "csvInputA_TSV_WithDollarAndDelimReplacement", i, '"', ',', '$', "|--|");
        assert(tsv_y == tsvResult_YA.data,
               format("Unittest failure. tsv_y != tsvResult_YA.data. Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csva, tsv_y, tsvResult_YA.data));

        /* CSV Set A and TSV with $ separator and tsv delimiter/newline replacement. Same TSV as CSV Set A.*/
        csvInputB = cast(ubyte[])csvb;
        auto tsvResult_YB = appender!(char[])();
        csv2tsv(csvInputB, tsvResult_YB, "csvInputB__TSV_WithDollarAndDelimReplacement", i, '#', '^', '$', "|--|");
        assert(tsv_y == tsvResult_YB.data,
               format("Unittest failure. tsv_y != tsvResult_YB.data.  Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csvb, tsv_y, tsvResult_YB.data));

    }
}

unittest
{
    /* Unit tests for 'maxRecords' feature of the csv2tsv function.
     */

    /* Input CSV. */
    auto csv1 = "";
    auto csv2 = ",";
    auto csv3 = "a";
    auto csv4 = "a\n";
    auto csv5 = "a\nb";
    auto csv6 = "a\nb\n";
    auto csv7 = "a\nb\nc";
    auto csv8 = "a\nb\nc\n";
    auto csv9 = "a,aa";
    auto csv10 = "a,aa\n";
    auto csv11 = "a,aa\nb,bb";
    auto csv12 = "a,aa\nb,bb\n";
    auto csv13 = "a,aa\nb,bb\nc,cc";
    auto csv14 = "a,aa\nb,bb\nc,cc\n";

    auto csv15 = "\"a\",\"aa\"";
    auto csv16 = "\"a\",\"aa\"\n";
    auto csv17 = "\"a\",\"aa\"\n\"b\",\"bb\"";
    auto csv18 = "\"a\",\"aa\"\n\"b\",\"bb\"\n";
    auto csv19 = "\"a\",\"aa\"\n\"b\",\"bb\"\n\"c\",\"cc\"";
    auto csv20 = "\"a\",\"aa\"\n\"b\",\"bb\"\n\"c\",\"cc\"\n";

    /* TSV with max 1 record. */
    auto tsv1_max1 = "";
    auto tsv2_max1 = "\t\n";
    auto tsv3_max1 = "a\n";
    auto tsv4_max1 = "a\n";
    auto tsv5_max1 = "a\n";
    auto tsv6_max1 = "a\n";
    auto tsv7_max1 = "a\n";
    auto tsv8_max1 = "a\n";
    auto tsv9_max1 = "a\taa\n";
    auto tsv10_max1 = "a\taa\n";
    auto tsv11_max1 = "a\taa\n";
    auto tsv12_max1 = "a\taa\n";
    auto tsv13_max1 = "a\taa\n";
    auto tsv14_max1 = "a\taa\n";

    auto tsv15_max1 = "a\taa\n";
    auto tsv16_max1 = "a\taa\n";
    auto tsv17_max1 = "a\taa\n";
    auto tsv18_max1 = "a\taa\n";
    auto tsv19_max1 = "a\taa\n";
    auto tsv20_max1 = "a\taa\n";

    /* Remaining TSV converted after first call. */
    auto tsv1_max1_rest = "";
    auto tsv2_max1_rest = "";
    auto tsv3_max1_rest = "";
    auto tsv4_max1_rest = "";
    auto tsv5_max1_rest = "b\n";
    auto tsv6_max1_rest = "b\n";
    auto tsv7_max1_rest = "b\nc\n";
    auto tsv8_max1_rest = "b\nc\n";
    auto tsv9_max1_rest = "";
    auto tsv10_max1_rest = "";
    auto tsv11_max1_rest = "b\tbb\n";
    auto tsv12_max1_rest = "b\tbb\n";
    auto tsv13_max1_rest = "b\tbb\nc\tcc\n";
    auto tsv14_max1_rest = "b\tbb\nc\tcc\n";

    auto tsv15_max1_rest = "";
    auto tsv16_max1_rest = "";
    auto tsv17_max1_rest = "b\tbb\n";
    auto tsv18_max1_rest = "b\tbb\n";
    auto tsv19_max1_rest = "b\tbb\nc\tcc\n";
    auto tsv20_max1_rest = "b\tbb\nc\tcc\n";

    /* TSV with max 2 records. */
    auto tsv1_max2 = "";
    auto tsv2_max2 = "\t\n";
    auto tsv3_max2 = "a\n";
    auto tsv4_max2 = "a\n";
    auto tsv5_max2 = "a\nb\n";
    auto tsv6_max2 = "a\nb\n";
    auto tsv7_max2 = "a\nb\n";
    auto tsv8_max2 = "a\nb\n";
    auto tsv9_max2 = "a\taa\n";
    auto tsv10_max2 = "a\taa\n";
    auto tsv11_max2 = "a\taa\nb\tbb\n";
    auto tsv12_max2 = "a\taa\nb\tbb\n";
    auto tsv13_max2 = "a\taa\nb\tbb\n";
    auto tsv14_max2 = "a\taa\nb\tbb\n";

    auto tsv15_max2 = "a\taa\n";
    auto tsv16_max2 = "a\taa\n";
    auto tsv17_max2 = "a\taa\nb\tbb\n";
    auto tsv18_max2 = "a\taa\nb\tbb\n";
    auto tsv19_max2 = "a\taa\nb\tbb\n";
    auto tsv20_max2 = "a\taa\nb\tbb\n";

    /* Remaining TSV converted after first call. */
    auto tsv1_max2_rest = "";
    auto tsv2_max2_rest = "";
    auto tsv3_max2_rest = "";
    auto tsv4_max2_rest = "";
    auto tsv5_max2_rest = "";
    auto tsv6_max2_rest = "";
    auto tsv7_max2_rest = "c\n";
    auto tsv8_max2_rest = "c\n";
    auto tsv9_max2_rest = "";
    auto tsv10_max2_rest = "";
    auto tsv11_max2_rest = "";
    auto tsv12_max2_rest = "";
    auto tsv13_max2_rest = "c\tcc\n";
    auto tsv14_max2_rest = "c\tcc\n";

    auto tsv15_max2_rest = "";
    auto tsv16_max2_rest = "";
    auto tsv17_max2_rest = "";
    auto tsv18_max2_rest = "";
    auto tsv19_max2_rest = "c\tcc\n";
    auto tsv20_max2_rest = "c\tcc\n";

    auto csvSet1 =
        [csv1, csv2, csv3, csv4, csv5, csv6, csv7,
         csv8, csv9, csv10, csv11, csv12, csv13, csv14,
         csv15, csv16, csv17, csv18, csv19, csv20 ];

    auto tsvMax1Set1 =
        [tsv1_max1, tsv2_max1, tsv3_max1, tsv4_max1, tsv5_max1, tsv6_max1, tsv7_max1,
         tsv8_max1, tsv9_max1, tsv10_max1, tsv11_max1, tsv12_max1, tsv13_max1, tsv14_max1,
         tsv15_max1, tsv16_max1, tsv17_max1, tsv18_max1, tsv19_max1, tsv20_max1];

    auto tsvMax1RestSet1 =
        [tsv1_max1_rest, tsv2_max1_rest, tsv3_max1_rest, tsv4_max1_rest, tsv5_max1_rest, tsv6_max1_rest, tsv7_max1_rest,
         tsv8_max1_rest, tsv9_max1_rest, tsv10_max1_rest, tsv11_max1_rest, tsv12_max1_rest, tsv13_max1_rest, tsv14_max1_rest,
         tsv15_max1_rest, tsv16_max1_rest, tsv17_max1_rest, tsv18_max1_rest, tsv19_max1_rest, tsv20_max1_rest];

    auto tsvMax2Set1 =
        [tsv1_max2, tsv2_max2, tsv3_max2, tsv4_max2, tsv5_max2, tsv6_max2, tsv7_max2,
         tsv8_max2, tsv9_max2, tsv10_max2, tsv11_max2, tsv12_max2, tsv13_max2, tsv14_max2,
         tsv15_max2, tsv16_max2, tsv17_max2, tsv18_max2, tsv19_max2, tsv20_max2];

    auto tsvMax2RestSet1 =
        [tsv1_max2_rest, tsv2_max2_rest, tsv3_max2_rest, tsv4_max2_rest, tsv5_max2_rest, tsv6_max2_rest, tsv7_max2_rest,
         tsv8_max2_rest, tsv9_max2_rest, tsv10_max2_rest, tsv11_max2_rest, tsv12_max2_rest, tsv13_max2_rest, tsv14_max2_rest,
         tsv15_max2_rest, tsv16_max2_rest, tsv17_max2_rest, tsv18_max2_rest, tsv19_max2_rest, tsv20_max2_rest];

    foreach (i, csv, tsv_max1, tsv_max1_rest, tsv_max2, tsv_max2_rest;
             lockstep(csvSet1, tsvMax1Set1, tsvMax1RestSet1, tsvMax2Set1, tsvMax2RestSet1))
    {
        /* Byte stream for csv2tsv. Consumed by csv2tsv, so need to be reset when re-used. */
        ubyte[] csvInput = cast(ubyte[])csv;

        /* Call with maxRecords == 1. */
        auto tsvMax1Result = appender!(char[])();
        csv2tsv(csvInput, tsvMax1Result, "maxRecords-one", i, '"', ',', '\t', " ", NullableSizeT(1));
        assert(tsv_max1 == tsvMax1Result.data,
               format("Unittest failure. tsv_max1 != tsvMax1Result.data. Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csv, tsv_max1, tsvMax1Result.data));

        /* Follow-up call getting all records remaining after the maxRecords==1 call. */
        auto tsvMax1RestResult = appender!(char[])();
        csv2tsv(csvInput, tsvMax1RestResult, "maxRecords-one-followup", i);
        assert(tsv_max1_rest == tsvMax1RestResult.data,
               format("Unittest failure. tsv_max1_rest != tsvMax1RestResult.data. Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csv, tsv_max1_rest, tsvMax1RestResult.data));

        /* Reset the input stream for maxRecords == 2. */
        csvInput = cast(ubyte[])csv;

        /* Call with maxRecords == 2. */
        auto tsvMax2Result = appender!(char[])();
        csv2tsv(csvInput, tsvMax2Result, "maxRecords-two", i, '"', ',', '\t', " ", NullableSizeT(2));
        assert(tsv_max2 == tsvMax2Result.data,
               format("Unittest failure. tsv_max2 != tsvMax2Result.data. Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csv, tsv_max2, tsvMax2Result.data));

        /* Follow-up call getting all records remaining after the maxRecords==2 call. */
        auto tsvMax2RestResult = appender!(char[])();
        csv2tsv(csvInput, tsvMax2RestResult, "maxRecords-two-followup", i);
        assert(tsv_max2_rest == tsvMax2RestResult.data,
               format("Unittest failure. tsv_max2_rest != tsvMax2RestResult.data. Test: %d\ncsv: |%s|\ntsv: |%s|\nres: |%s|\n",
                      i + 1, csv, tsv_max2_rest, tsvMax2RestResult.data));
    }
}
