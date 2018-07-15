/**
This is a simple dub build launcher for tsv-utils to use with Dub installs.

The tsv-utils package contains multiple executable programs in sub-directories.
Vanilla Dub does not support building multiple executables, a separate invocations is
required for each app. However, experienced Dub users may try to install with a
standard Dub sequence, for example:

    dub fetch tsv-utils
    dub run tsv-utils

Another use-case:

    dub fetch --local <package>
    cd <package>
    dub run

This executable is intended to handle these cases. It also has one additional function:
inform the user where the binaries are stored so they can be added to the path.

This build launcher does not provide general build services. For example, it does not
support 'test'. This can still be done via dub, but on the individual sub-packages, not
the full package.

Copyright (c) 2015-2018, eBay Software Foundation
Initially written by Jon Degenhardt

License: Boost Licence 1.0 (http://boost.org/LICENSE_1_0.txt)
*/

auto helpText = q"EOS
Build the apps in the tsv-utils package. Options:
EOS";

int main(string[] args) {
    import std.array : join;
    import std.format;
    import std.getopt;
    import std.path;
    import std.process : escapeShellCommand, executeShell;
    import std.stdio;

    bool debugBuild = 0;
    string compiler = "";

    auto r = getopt(
        args,
        "debug", "Debug build. Release builds are the default.", &debugBuild,
        "compiler", "COMPILER  Compiler to use. Typically dmd, ldc2, gdc. Can be a path.", &compiler
        );

    if (r.helpWanted) {
        defaultGetoptPrinter(helpText, r.options);
        return 0;
    }

    // Note: At present 'common' is a source library and does not need a standalone compilation step.
    auto packageName = "tsv-utils";
    auto subPackages = ["csv2tsv", "keep-header", "number-lines", "tsv-append", "tsv-filter", "tsv-join", "tsv-pretty", "tsv-sample", "tsv-select", "tsv-summarize", "tsv-uniq"];
    auto buildCmdArgs = ["dub", "build", "<package>", "--force", "-b"];
    buildCmdArgs ~= debugBuild ? "debug" : "release";
    if (compiler.length > 0) {
        buildCmdArgs ~= format("--compiler=%s", compiler);
    }

    assert(args.length > 0);
    auto exePath = args[0].absolutePath;
    auto exeDir = exePath.dirName;
    auto binDir = buildNormalizedPath(exeDir, "bin");
    writeln();
    writeln("=== Building tsv-utils executables ===");
    writeln();
    foreach (subPkg; subPackages) {
        auto subPkgBuildName = packageName ~ ":" ~ subPkg;
        buildCmdArgs[2] = subPkgBuildName;
        writeln("Building ", subPkg);
        writeln();
        writeln(buildCmdArgs.join(' '));
        auto buildResult = executeShell(escapeShellCommand(buildCmdArgs));
        writeln(buildResult.output);
        if (buildResult.status != 0) {
            stderr.writeln("\n===> Build failure.\n");
            return buildResult.status;
        }
    }

    writeln("========================================================");
    writeln("Executables are in: ", binDir);
    writeln("Add this directory or the excecutables to the PATH.");
    writeln();
    writeln("To build with a different compiler:");
    writefln("    dub run %s -- --compiler=<compiler>", packageName);
    writeln("========================================================");

    return 0;
}
