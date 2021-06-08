/**
A cover for D standard library 'getopt' routine (std.getopt.getopt) function that preserves
command line argument processing order.

This is a work-around to a limitation in getopt, in that getopt does not process arguments
in command line order. Instead, getopt processes options in the order specified in the call
to getopt. That is, the order in the text of the code. This prevents using command line
options in ways where order specified by the user is taken into account.

More details here: https://issues.dlang.org/show_bug.cgi?id=16539

This should only be used when retaining order is important. Though minimized, there are
cases that don't work as expected, the most important involving option arguments starting
with a dash. See the getoptInorder function comments for specifics.

Copyright (c) 2016-2021, eBay Inc.
Initially written by Jon Degenhardt

License: Boost License 1.0 (http://boost.org/LICENSE_1_0.txt)

Acknowledgments:

- Unit tests in this file have been adopted from unit tests for the D programming language
  std.getopt standard library modules (https://dlang.org/phobos/std_getopt.html).

  License: Boost License 1.0 (http://boost.org/LICENSE_1_0.txt)
  Copyright: 2008-2015 Andrei Alexandrescu
*/

module tsv_utils.common.getopt_inorder;

import std.getopt;

/** checkForUnsupportedConfigOptions walks the option list looking for unsupported config
 * options.
 *
 * Currently everything except std.getopt.config.required is supported. An exception is
 * thrown if an unsupported config parameter is found.
 *
 * Note: A compile-time check would be ideal. That does not appear doable, as values of
 * parameters cannot be read at compile-type, only the data type (template parameter part).
 * The generated code creates a test against each 'config' parameter in the options list.
 * (An option list contains both config and non-config parameters.)
 */
private void checkForUnsupportedConfigOptions(T...)(T opts)
{
    static if (opts.length > 0)
    {
        /* opts contains a mixture of types (varadic template parameter). Can
         * only place tests on config option tests.
         */
        static if (is(typeof(opts[0]) : std.getopt.config))
        {
            if (opts[0] == std.getopt.config.required)
            {
                throw new Exception(
                    "getoptInorder does not support std.getopt.config.required");
            }
        }

        checkForUnsupportedConfigOptions(opts[1..$]);
    }
}

/** hasStopOnFirstNotOption walks the config list returns true if one of the
 * options in is std.getopt.config.stopOnFirstNonOption.
 */
private bool hasStopOnFirstNonOption(T...)(T opts)
{
    static if (opts.length > 0)
    {
        static if (is(typeof(opts[0]) : std.getopt.config))
        {
            if (opts[0] == std.getopt.config.stopOnFirstNonOption) return true;
        }

        return hasStopOnFirstNonOption(opts[1..$]);
    }
    else
    {
        return false;
    }
}

unittest
{
    int[] vals;

    assert(!hasStopOnFirstNonOption(
               "a|aa", "aaa VAL", &vals,
               "b|bb", "bbb VAL", &vals,
               "c|cc", "ccc VAL", &vals,
               ));

    assert(hasStopOnFirstNonOption(
               std.getopt.config.stopOnFirstNonOption,
               "a|aa", "aaa VAL", &vals,
               "b|bb", "bbb VAL", &vals,
               "c|cc", "ccc VAL", &vals,
               ));

    assert(hasStopOnFirstNonOption(
               "a|aa", "aaa VAL", &vals,
               std.getopt.config.stopOnFirstNonOption,
               "b|bb", "bbb VAL", &vals,
               "c|cc", "ccc VAL", &vals,
               ));

    assert(hasStopOnFirstNonOption(
               "a|aa", "aaa VAL", &vals,
               "b|bb", "bbb VAL", &vals,
               std.getopt.config.stopOnFirstNonOption,
               "c|cc", "ccc VAL", &vals,
               ));

    assert(hasStopOnFirstNonOption(
               "a|aa", "aaa VAL", &vals,
               "b|bb", "bbb VAL", &vals,
               "c|cc", "ccc VAL", &vals,
               std.getopt.config.stopOnFirstNonOption,
               ));
}

/** getoptInorder is a cover to std.getopt that processes command line options in the
 * order on the command.
 *
 * This is intended for command line argument processing where the order of arguments
 * on the command line is important. The standard library std.getopt routine processes
 * options in the order listed in call to getopt. Behavioral changes involve order of
 * callback processing and array filling.
 *
 * Other changes from std.getopt:
 * $(LIST
 *     * The std.getopt.config.required option is not supported.
 *     * Single digits cannot be used as short options. e.g. '-1' cannot be an option.
 *     * Non-numeric option arguments starting with a dash are not interpreted correctly,
 *       unless it looks like a negative number or is a single dash. Some examples,
 *       assuming ("--val") takes one argument:
 *       $(LIST
 *           * `["--val", "-9"]` - Okay, "-9" is arg
 *           * `["--val", "-"]`  - Okay, "-" is arg
 *           * `["--val", "-a"]` - Not okay, "-a" is treated as separate option.
 *        )
 *  )
 */
GetoptResult getoptInorder(T...)(ref string[] args, T opts)
{
    import std.algorithm : min, remove;
    import std.typecons : tuple;

    debug import std.stdio;
    debug writeln("\n=========================\n");
    debug writeln("[getoptInorder] args: ", args, " opts: ", opts);

    checkForUnsupportedConfigOptions(opts);
    bool configHasStopOnFirstNonOption = hasStopOnFirstNonOption(opts);

    bool isOption(string arg)
    {
        import std.string : isNumeric;
        import std.ascii : isDigit;

        return
            (arg == std.getopt.endOfOptions) ||
            (arg.length >= 2 &&
             arg[0] == std.getopt.optionChar &&
             !(arg[1].isDigit && arg.isNumeric));
    }

    /* Walk input args, passing one command option at a time to getopt.
     * Example - Assume the args array is:
     *
     *    ["program_name", "--foo", "--bar", "1", "--baz", "2", "3", "--goo"]
     *
     * The above array is passed to getopt in the following calls:
     *
     *   ["program_name", "--foo"]
     *   ["program_name", "--bar", "1"]
     *   ["program_name", "--baz", "2", "3"]
     *   ["program_name", "--goo"]
     *
     * The same output variable references are passed each time, with the result that they
     * are filled in command option order. The result of the last call to getopt is
     * returned. This works because getopt is returning two pieces of info: the help
     * options and whether help was wanted. The first is the same on all calls, so the
     * last call is fine. The 'help wanted' status needs to be tracked, as it could issued
     * any point in the command line.
     *
     * getopt will remove all arguments accounted for by option processing, but others will
     * be passed through. These are kept as part of the command args as they are encountered.
     */
    GetoptResult result;
    bool helpWanted = false;   // Need to track if help is ever requested.
    size_t argStart = 1;       // Start at 1, index zero is program name.
    bool isLastCall = false;

    while (!isLastCall)
    {
        /* This is the last call to getopt if:
         * - There are zero or one args left
         * - The next arg is '--' (endOfOptions), which terminates the arg string.
         */
        isLastCall = (args.length <= argStart + 1) || (args[argStart] == std.getopt.endOfOptions);

        size_t argEnd = args.length;
        if (!isLastCall)
        {
            /* Find the next option. */
            for (size_t i = argStart + 1; i < args.length; i++)
            {
                if (isOption(args[i]))
                {
                    argEnd = i;
                    break;
                }
            }
        }

        auto currArg = args[0..argEnd].dup;
        size_t currArgLength = currArg.length;
        debug writeln("[getoptInorder] Calling getopt. args: ", currArg, " opts: ", opts);

        result = getopt(currArg, opts);
        helpWanted |= result.helpWanted;

        debug writeln("[getoptInorder] After getopt call");

        size_t numRemoved = currArgLength - currArg.length;

        if (numRemoved > 0)
        {
            debug import std.conv;
            /* Current arg array was modified. Repeat the modification against the full
             * array. Assumption in this code is that the removal occurs at the start.
             * e.g. Assume the args passed to getopt are [program --foo abc def ghi]. If
             * two args are consumed, assumption is the two consumed are [--foo abc] and
             * [def ghi] are left as pass-through. This code could go be enhanced to
             * validate the specific args removed, at present does not do this.
             */
            debug writefln("[getoptInorder] Arg modified. argStart: %d, argEnd: %d, currArgLength: %d, currArg.length: %d, numRemoved: %d, currArg: %s",
                     argStart, argEnd, currArgLength, currArg.length, numRemoved, currArg.to!string);
            args = args.remove(tuple(argStart, argStart + numRemoved));
            debug writeln("[getoptInorder] Updated args: ", args);
        }

        size_t numPassThrough = currArgLength - (argStart + numRemoved);

        if (numPassThrough > 0)
        {
            argStart += numPassThrough;
            isLastCall |= configHasStopOnFirstNonOption;
            debug writeln("[getoptInorder] argStart moved forward: ", numPassThrough, " postions.");
        }
    }

    result.helpWanted = helpWanted;

    return result;
}

version(unittest)
{
    import std.exception;
}

unittest // Issue 16539
{

    // Callback order
    auto args = ["program",
                 "-a", "1", "-b", "2", "-c", "3",
                 "--cc", "4", "--bb", "5", "--aa", "6",
                 "-a", "7", "-b", "8", "-c", "9"];

    string optionHandlerResult;

    void optionHandler(string option, string optionVal)
    {
        if (optionHandlerResult.length > 0) optionHandlerResult ~= "; ";
        optionHandlerResult ~= option ~ "=" ~ optionVal;
    }

    getoptInorder(
        args,
        "a|aa", "aaa VAL", &optionHandler,
        "b|bb", "bbb VAL", &optionHandler,
        "c|cc", "ccc VAL", &optionHandler,
        );

    assert(optionHandlerResult == "a|aa=1; b|bb=2; c|cc=3; c|cc=4; b|bb=5; a|aa=6; a|aa=7; b|bb=8; c|cc=9");

    // Array population order
    string[] cmdvals;

    args = ["program",
            "-a", "1", "-b", "2", "-c", "3",
            "--cc", "4", "--bb", "5", "--aa", "6",
            "-a", "7", "-b", "8", "-c", "9"];

    getoptInorder(
        args,
        "a|aa", "aaa VAL", &cmdvals,
        "b|bb", "bbb VAL", &cmdvals,
        "c|cc", "ccc VAL", &cmdvals,
        );

    assert(cmdvals == ["1", "2", "3", "4", "5", "6", "7", "8", "9"]);
}

unittest // Dashes
{
    auto args = ["program", "-m", "-5", "-n", "-50", "-c", "-"];

    int m;
    int n;
    char c;

    getoptInorder(
        args,
        "m|mm", "integer", &m,
        "n|nn", "integer", &n,
        "c|cc", "character", &c,
        );

    assert(m == -5);
    assert(n == -50);
    assert(c == '-');
}


/* NOTE: The following unit tests have been adapted from unit tests in std.getopt.d
 * See https://github.com/dlang/phobos/blob/master/std/getopt.d and
 * https://dlang.org/phobos/std_getopt.html.
 */

@system unittest
{
    auto args = ["prog", "--foo", "-b"];

    bool foo;
    bool bar;
    auto rslt = getoptInorder(args, "foo|f", "Some information about foo.", &foo, "bar|b",
        "Some help message about bar.", &bar);

    if (rslt.helpWanted)
    {
        defaultGetoptPrinter("Some information about the program.",
            rslt.options);
    }
}

@system unittest // bugzilla 15914
{
    bool opt;
    string[] args = ["program", "-a"];
    getoptInorder(args, config.passThrough, 'a', &opt);
    assert(opt);
    opt = false;
    args = ["program", "-a"];
    getoptInorder(args, 'a', &opt);
    assert(opt);
    opt = false;
    args = ["program", "-a"];
    getoptInorder(args, 'a', "help string", &opt);
    assert(opt);
    opt = false;
    args = ["program", "-a"];
    getoptInorder(args, config.caseSensitive, 'a', "help string", &opt);
    assert(opt);

    version(none)
    {
        /* About version(none) - This case crashes, whether calling getoptInorder or simply
         * getopt. Not clear why. Even converting the whole test case to getopt still results
         * in failure at this line. (Implies getoptInorder is not itself the cause, but could
         * involve context in which the test is run.)
         */
        assertThrown(getoptInorder(args, "", "forgot to put a string", &opt));
    }
}

// 5316 - arrays with arraySep
@system unittest
{
    import std.conv;

    arraySep = ",";
    scope (exit) arraySep = "";

    string[] names;
    auto args = ["program.name", "-nfoo,bar,baz"];
    getoptInorder(args, "name|n", &names);
    assert(names == ["foo", "bar", "baz"], to!string(names));

    names = names.init;
    args = ["program.name", "-n", "foo,bar,baz"];
    getoptInorder(args, "name|n", &names);
    assert(names == ["foo", "bar", "baz"], to!string(names));

    names = names.init;
    args = ["program.name", "--name=foo,bar,baz"];
    getoptInorder(args, "name|n", &names);
    assert(names == ["foo", "bar", "baz"], to!string(names));

    names = names.init;
    args = ["program.name", "--name", "foo,bar,baz"];
    getoptInorder(args, "name|n", &names);
    assert(names == ["foo", "bar", "baz"], to!string(names));
}

// 5316 - associative arrays with arraySep
@system unittest
{
    import std.conv;

    arraySep = ",";
    scope (exit) arraySep = "";

    int[string] values;
    values = values.init;
    auto args = ["program.name", "-vfoo=0,bar=1,baz=2"];
    getoptInorder(args, "values|v", &values);
    assert(values == ["foo":0, "bar":1, "baz":2], to!string(values));

    values = values.init;
    args = ["program.name", "-v", "foo=0,bar=1,baz=2"];
    getoptInorder(args, "values|v", &values);
    assert(values == ["foo":0, "bar":1, "baz":2], to!string(values));

    values = values.init;
    args = ["program.name", "--values=foo=0,bar=1,baz=2"];
    getoptInorder(args, "values|t", &values);
    assert(values == ["foo":0, "bar":1, "baz":2], to!string(values));

    values = values.init;
    args = ["program.name", "--values", "foo=0,bar=1,baz=2"];
    getoptInorder(args, "values|v", &values);
    assert(values == ["foo":0, "bar":1, "baz":2], to!string(values));
}

@system unittest
{
    import std.conv;
    import std.math;

    bool closeEnough(T)(T x, T y)
    {
        static if (__VERSION__ >= 2096) return isClose(x, y);
        else return approxEqual(x, y);
    }

    uint paranoid = 2;
    string[] args = ["program.name", "--paranoid", "--paranoid", "--paranoid"];
    getoptInorder(args, "paranoid+", &paranoid);
    assert(paranoid == 5, to!(string)(paranoid));

    enum Color { no, yes }
    Color color;
    args = ["program.name", "--color=yes",];
    getoptInorder(args, "color", &color);
    assert(color, to!(string)(color));

    color = Color.no;
    args = ["program.name", "--color", "yes",];
    getoptInorder(args, "color", &color);
    assert(color, to!(string)(color));

    string data = "file.dat";
    int length = 24;
    bool verbose = false;
    args = ["program.name", "--length=5", "--file", "dat.file", "--verbose"];
    getoptInorder(
        args,
        "length",  &length,
        "file",    &data,
        "verbose", &verbose);
    assert(args.length == 1);
    assert(data == "dat.file");
    assert(length == 5);
    assert(verbose);

    //
    string[] outputFiles;
    args = ["program.name", "--output=myfile.txt", "--output", "yourfile.txt"];
    getoptInorder(args, "output", &outputFiles);
    assert(outputFiles.length == 2
           && outputFiles[0] == "myfile.txt" && outputFiles[1] == "yourfile.txt");

    outputFiles = [];
    arraySep = ",";
    args = ["program.name", "--output", "myfile.txt,yourfile.txt"];
    getoptInorder(args, "output", &outputFiles);
    assert(outputFiles.length == 2
           && outputFiles[0] == "myfile.txt" && outputFiles[1] == "yourfile.txt");
    arraySep = "";

    foreach (testArgs;
        [["program.name", "--tune=alpha=0.5", "--tune", "beta=0.6"],
         ["program.name", "--tune=alpha=0.5,beta=0.6"],
         ["program.name", "--tune", "alpha=0.5,beta=0.6"]])
    {
        arraySep = ",";
        double[string] tuningParms;
        getoptInorder(testArgs, "tune", &tuningParms);
        assert(testArgs.length == 1);
        assert(tuningParms.length == 2);
        assert(closeEnough(tuningParms["alpha"], 0.5));
        assert(closeEnough(tuningParms["beta"], 0.6));
        arraySep = "";
    }

    uint verbosityLevel = 1;
    void myHandler(string option)
    {
        if (option == "quiet")
        {
            verbosityLevel = 0;
        }
        else
        {
            assert(option == "verbose");
            verbosityLevel = 2;
        }
    }
    args = ["program.name", "--quiet"];
    getoptInorder(args, "verbose", &myHandler, "quiet", &myHandler);
    assert(verbosityLevel == 0);
    args = ["program.name", "--verbose"];
    getoptInorder(args, "verbose", &myHandler, "quiet", &myHandler);
    assert(verbosityLevel == 2);

    verbosityLevel = 1;
    void myHandler2(string option, string value)
    {
        assert(option == "verbose");
        verbosityLevel = 2;
    }
    args = ["program.name", "--verbose", "2"];
    getoptInorder(args, "verbose", &myHandler2);
    assert(verbosityLevel == 2);

    verbosityLevel = 1;
    void myHandler3()
    {
        verbosityLevel = 2;
    }
    args = ["program.name", "--verbose"];
    getoptInorder(args, "verbose", &myHandler3);
    assert(verbosityLevel == 2);

    bool foo, bar;
    args = ["program.name", "--foo", "--bAr"];
    getoptInorder(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.passThrough,
        "foo", &foo,
        "bar", &bar);
    assert(args[1] == "--bAr");

    // test stopOnFirstNonOption

    args = ["program.name", "--foo", "nonoption", "--bar"];
    foo = bar = false;
    getoptInorder(args,
                  std.getopt.config.stopOnFirstNonOption,
                  "foo", &foo,
                  "bar", &bar);
    assert(foo && !bar && args[1] == "nonoption" && args[2] == "--bar");

    args = ["program.name", "--foo", "nonoption", "--zab"];
    foo = bar = false;
    getoptInorder(args,
                  std.getopt.config.stopOnFirstNonOption,
                  "foo", &foo,
                  "bar", &bar);
    assert(foo && !bar && args[1] == "nonoption" && args[2] == "--zab");

    args = ["program.name", "--fb1", "--fb2=true", "--tb1=false"];
    bool fb1, fb2;
    bool tb1 = true;
    getoptInorder(args, "fb1", &fb1, "fb2", &fb2, "tb1", &tb1);
    assert(fb1 && fb2 && !tb1);

    // test keepEndOfOptions

    args = ["program.name", "--foo", "nonoption", "--bar", "--", "--baz"];
    getoptInorder(args,
        std.getopt.config.keepEndOfOptions,
        "foo", &foo,
        "bar", &bar);
    assert(args == ["program.name", "nonoption", "--", "--baz"]);

    // Ensure old behavior without the keepEndOfOptions

    args = ["program.name", "--foo", "nonoption", "--bar", "--", "--baz"];
    getoptInorder(args,
        "foo", &foo,
        "bar", &bar);
    assert(args == ["program.name", "nonoption", "--baz"]);

    // test function callbacks

    static class MyEx : Exception
    {
        this() { super(""); }
        this(string option) { this(); this.option = option; }
        this(string option, string value) { this(option); this.value = value; }

        string option;
        string value;
    }

    static void myStaticHandler1() { throw new MyEx(); }
    args = ["program.name", "--verbose"];
    try { getoptInorder(args, "verbose", &myStaticHandler1); assert(0); }
    catch (MyEx ex) { assert(ex.option is null && ex.value is null); }

    static void myStaticHandler2(string option) { throw new MyEx(option); }
    args = ["program.name", "--verbose"];
    try { getoptInorder(args, "verbose", &myStaticHandler2); assert(0); }
    catch (MyEx ex) { assert(ex.option == "verbose" && ex.value is null); }

    static void myStaticHandler3(string option, string value) { throw new MyEx(option, value); }
    args = ["program.name", "--verbose", "2"];
    try { getoptInorder(args, "verbose", &myStaticHandler3); assert(0); }
    catch (MyEx ex) { assert(ex.option == "verbose" && ex.value == "2"); }
}

@system unittest
{
    // From bugzilla 2142
    bool f_linenum, f_filename;
    string[] args = [ "", "-nl" ];
    getoptInorder
        (
            args,
            std.getopt.config.bundling,
            //std.getopt.config.caseSensitive,
            "linenum|l", &f_linenum,
            "filename|n", &f_filename
        );
    assert(f_linenum);
    assert(f_filename);
}

@system unittest
{
    // From bugzilla 6887
    string[] p;
    string[] args = ["", "-pa"];
    getoptInorder(args, "p", &p);
    assert(p.length == 1);
    assert(p[0] == "a");
}

@system unittest
{
    // From bugzilla 6888
    int[string] foo;
    auto args = ["", "-t", "a=1"];
    getoptInorder(args, "t", &foo);
    assert(foo == ["a":1]);
}

@system unittest
{
    // From bugzilla 9583
    int opt;
    auto args = ["prog", "--opt=123", "--", "--a", "--b", "--c"];
    getoptInorder(args, "opt", &opt);
    assert(args == ["prog", "--a", "--b", "--c"]);
}

@system unittest
{
    string foo, bar;
    auto args = ["prog", "-thello", "-dbar=baz"];
    getoptInorder(args, "t", &foo, "d", &bar);
    assert(foo == "hello");
    assert(bar == "bar=baz");

    // From bugzilla 5762
    string a;
    args = ["prog", "-a-0x12"];
    getoptInorder(args, config.bundling, "a|addr", &a);
    assert(a == "-0x12", a);
    args = ["prog", "--addr=-0x12"];
    getoptInorder(args, config.bundling, "a|addr", &a);
    assert(a == "-0x12");

    // From https://d.puremagic.com/issues/show_bug.cgi?id=11764
    args = ["main", "-test"];
    bool opt;
    args.getoptInorder(config.passThrough, "opt", &opt);
    assert(args == ["main", "-test"]);

    // From https://issues.dlang.org/show_bug.cgi?id=15220
    args = ["main", "-o=str"];
    string o;
    args.getoptInorder("o", &o);
    assert(o == "str");

    args = ["main", "-o=str"];
    o = null;
    args.getoptInorder(config.bundling, "o", &o);
    assert(o == "str");
}

@system unittest // 5228
{
    import std.exception;
    import std.conv;

    auto args = ["prog", "--foo=bar"];
    int abc;
    assertThrown!GetOptException(getoptInorder(args, "abc", &abc));

    args = ["prog", "--abc=string"];
    assertThrown!ConvException(getoptInorder(args, "abc", &abc));
}

@system unittest // From bugzilla 7693
{
    import std.exception;

    enum Foo {
        bar,
        baz
    }

    auto args = ["prog", "--foo=barZZZ"];
    Foo foo;
    assertThrown(getoptInorder(args, "foo", &foo));
    args = ["prog", "--foo=bar"];
    assertNotThrown(getoptInorder(args, "foo", &foo));
    args = ["prog", "--foo", "barZZZ"];
    assertThrown(getoptInorder(args, "foo", &foo));
    args = ["prog", "--foo", "baz"];
    assertNotThrown(getoptInorder(args, "foo", &foo));
}

@system unittest // same bug as 7693 only for bool
{
    import std.exception;

    auto args = ["prog", "--foo=truefoobar"];
    bool foo;
    assertThrown(getoptInorder(args, "foo", &foo));
    args = ["prog", "--foo"];
    getoptInorder(args, "foo", &foo);
    assert(foo);
}

@system unittest
{
    bool foo;
    auto args = ["prog", "--foo"];
    getoptInorder(args, "foo", &foo);
    assert(foo);
}

@system unittest
{
    bool foo;
    bool bar;
    auto args = ["prog", "--foo", "-b"];
    getoptInorder(args, config.caseInsensitive,"foo|f", "Some foo", &foo,
        config.caseSensitive, "bar|b", "Some bar", &bar);
    assert(foo);
    assert(bar);
}

@system unittest
{
    bool foo;
    bool bar;
    auto args = ["prog", "-b", "--foo", "-z"];
    assertThrown(
        getoptInorder(args, config.caseInsensitive, config.required, "foo|f", "Some foo",
                      &foo, config.caseSensitive, "bar|b", "Some bar", &bar,
                      config.passThrough));
    version(none) // These tests only appy if config.required is supported.
    {
        assert(foo);
        assert(bar);
    }
}

@system unittest
{
    import std.exception;

    bool foo;
    bool bar;
    auto args = ["prog", "-b", "-z"];
    assertThrown(getoptInorder(args, config.caseInsensitive, config.required, "foo|f",
                               "Some foo", &foo, config.caseSensitive, "bar|b", "Some bar", &bar,
                               config.passThrough));
}

@system unittest
{
    version(none)  // No point running this test without config.required support.
    {
        import std.exception;

        bool foo;
        bool bar;
        auto args = ["prog", "--foo", "-z"];
        assertNotThrown(getoptInorder(args, config.caseInsensitive, config.required,
                                      "foo|f", "Some foo", &foo, config.caseSensitive, "bar|b", "Some bar",
                                      &bar, config.passThrough));
        assert(foo);
        assert(!bar);
    }
}

@system unittest
{
    bool foo;
    auto args = ["prog", "-f"];
    auto r = getoptInorder(args, config.caseInsensitive, "help|f", "Some foo", &foo);
    assert(foo);
    assert(!r.helpWanted);
}

@safe unittest // implicit help option without config.passThrough
{
    string[] args = ["program", "--help"];
    auto r = getoptInorder(args);
    assert(r.helpWanted);
}

// Issue 13316 - std.getopt: implicit help option breaks the next argument
@system unittest
{
    string[] args = ["program", "--help", "--", "something"];
    getoptInorder(args);
    assert(args == ["program", "something"]);

    args = ["program", "--help", "--"];
    getoptInorder(args);
    assert(args == ["program"]);

    bool b;
    args = ["program", "--help", "nonoption", "--option"];
    getoptInorder(args, config.stopOnFirstNonOption, "option", &b);
    assert(args == ["program", "nonoption", "--option"]);
}

// Issue 13317 - std.getopt: endOfOptions broken when it doesn't look like an option
@system unittest
{
    auto endOfOptionsBackup = endOfOptions;
    scope(exit) endOfOptions = endOfOptionsBackup;
    endOfOptions = "endofoptions";
    string[] args = ["program", "endofoptions", "--option"];
    bool b = false;
    getoptInorder(args, "option", &b);
    assert(!b);
    assert(args == ["program", "--option"]);
}

@system unittest
{
    import std.conv;

    import std.array;
    import std.string;
    bool a;
    auto args = ["prog", "--foo"];
    auto t = getoptInorder(args, "foo|f", "Help", &a);
    string s;
    auto app = appender!string();
    defaultGetoptFormatter(app, "Some Text", t.options);

    string helpMsg = app.data;
    //writeln(helpMsg);
    assert(helpMsg.length);
    assert(helpMsg.count("\n") == 3, to!string(helpMsg.count("\n")) ~ " "
        ~ helpMsg);
    assert(helpMsg.indexOf("--foo") != -1);
    assert(helpMsg.indexOf("-f") != -1);
    assert(helpMsg.indexOf("-h") != -1);
    assert(helpMsg.indexOf("--help") != -1);
    assert(helpMsg.indexOf("Help") != -1);

    string wanted = "Some Text\n-f  --foo Help\n-h --help This help "
        ~ "information.\n";
    assert(wanted == helpMsg);
}

@system unittest
{
    version(none)  // No point in running this unit test without config.required support
    {
        import std.conv;
        import std.string;
        import std.array ;
        bool a;
        auto args = ["prog", "--foo"];
        auto t = getoptInorder(args, config.required, "foo|f", "Help", &a);
        string s;
        auto app = appender!string();
        defaultGetoptFormatter(app, "Some Text", t.options);

        string helpMsg = app.data;
        //writeln(helpMsg);
        assert(helpMsg.length);
        assert(helpMsg.count("\n") == 3, to!string(helpMsg.count("\n")) ~ " "
               ~ helpMsg);
        assert(helpMsg.indexOf("Required:") != -1);
        assert(helpMsg.indexOf("--foo") != -1);
        assert(helpMsg.indexOf("-f") != -1);
        assert(helpMsg.indexOf("-h") != -1);
        assert(helpMsg.indexOf("--help") != -1);
        assert(helpMsg.indexOf("Help") != -1);

        string wanted = "Some Text\n-f  --foo Required: Help\n-h --help "
            ~ "          This help information.\n";
        assert(wanted == helpMsg, helpMsg ~ wanted);
    }
}

@system unittest // Issue 14724
{
    version(none)  // No point running this unit test without config.required support
    {
        bool a;
        auto args = ["prog", "--help"];
        GetoptResult rslt;
        try
        {
            rslt = getoptInorder(args, config.required, "foo|f", "bool a", &a);
        }
        catch (Exception e)
        {
            enum errorMsg = "If the request for help was passed required options" ~
                "must not be set.";
            assert(false, errorMsg);
        }

        assert(rslt.helpWanted);
    }
}
