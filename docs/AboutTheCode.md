_Visit the [main page](../README.md)_

# About the code

Some further details about the code used in the TSV Utilities.

Contents:
* [Code structure](#code-structure)
* [Coding philosophy](#coding-philosophy)
* [Building and makefile](#building-and-makefile)
* [Unit tests and code coverage reports](#unit-tests-and-code-coverage-reports)

## Code structure

There is directory for each tool, plus one directory for shared code (`common`). The tools all have a similar structure. Code is typically in one file, e.g. `tsv-uniq.d`. Functionality is broken into three pieces:

* A class managing command line options. e.g. `TsvUniqOptions`.
* A function reading reading input and processing each line. e.g. `tsvUniq`.
* A `main` routine putting it all together.

Documentation for each tool is found near the top of the main file, both in the help text and the option documentation.

The simplest tool is `number-lines`. It is useful as an illustration of the code outline followed by the other tools. `tsv-select` and `tsv-uniq` also have straightforward functionality, but employ a few more D programming concepts. `tsv-select` uses templates and compile-time programming in a somewhat less common way, it may be clearer after gaining some familiarity with D templates. A non-templatized version of the source code is included for comparison.

`tsv-append` has a simple code structure. It's one of the newer tools. It's only additional complexity is that writes to an 'output range' rather than directly to standard output. This enables better encapsulation for unit testing. `tsv-sample`, another new tool, is written in a similar fashion. The code is only a bit more complicated, but the algorithm is much more interesting.

`tsv-join` and `tsv-filter` also have relatively straightforward functionality, but support more use cases resulting in more code. `tsv-filter` in particular has more elaborate setup steps that take a bit more time to understand. `tsv-filter` uses several features like delegates (closures) and regular expressions not used in the other tools.

`tsv-summarize` is one or the more recent tools. It uses a more object oriented style than the other tools, this makes it relatively easy to add new operations. It also makes quite extensive use of built-in unit tests.

The `common` directory has code shared by the tools. At present this very limited, one helper class written as template. In addition to being an example of a simple template, it also makes use of a D ranges, a very useful sequence abstraction, and built-in unit tests.

New tools can be added by creating a new directory and a source tree following the same pattern as one of existing tools.

## Coding philosophy

The tools were written in part to explore D for use in a data science environment. Data mining environments have custom data and application needs. This leads to custom tools, which in turn raises the productivity vs execution speed question. This trade-off is exemplified by interpreted languages like Python on the one hand and system languages like C/C++ on the other. The D programming language occupies an interesting point on this spectrum. D's programmer experience is somewhere in the middle ground between interpreted languages and C/C++, but run-time performance is closer to C/C++. Execution speed is a very practical consideration in data mining environments: it increases dataset sizes that can handled on a single machine, perhaps the researcher's own machine, without needing to switch to a distributed compute environment. There is additional value in having data science practitioners program these tools quickly, themselves, without needing to invest time in low-level programming.

These tools were implemented with these trade-offs in mind. The code was deliberately kept at a reasonably high level. The obvious built-in facilities were used, notably the standard library. A certain amount of performance optimization was done to explore this dimension of D programming, but low-level optimizations were generally avoided. Indeed, there are options likely to improve performance, notably:

* Custom I/O buffer management, including reading entire files into memory.
* Custom hash tables rather than built-in associative arrays.
* Avoiding garbage collection.

A useful aspect of D is that is additional optimization can be made as the need arises. Coding of these tools did utilize a several optimizations that might not have been done in an initial effort. These include:

* The `InputFieldReordering` class in the `common` directory. This is an optimization for processing only the first N fields needed for the individual command invocation. This is used by several tools.
* The template expansion done in `tsv-select`. This reduces the number of if-tests in the inner loop.
* Reusing arrays every input line, without re-allocating. Some programmers would do this naturally on the first attempt, for others it would be a second pass optimization.
* The output buffering done in `csv2tsv`. The algorithm used naturally generates a single byte at a time, but writing a byte-at-a-time incurs a costly system call. Buffering the writes sped the program up signficantly.

## Building and makefile

### Make setup

The makefile setup is very simplistic. It works reasonably in this case because the tools are small and have a very simple code structure, but it is not a setup that will scale to more complex programs. `make` can be run from the top level directory or from the individual tool directories. Available commands include:

* `make release` (default) - This builds the tools in release mode. Executables go in the bin directory.
* `make debug` - Makes debug versions of the tools (with a `.dbg` extension).
* `make clean` - Deletes executables and intermediate files.
* `make test` - Run unit tests and command line tests against debug and release executables.
* `make test-nobuild` - Runs tests against the current app builds. This is useful when using DUB to build.
* `make test-codecov` - Runs unit tests and debug app tests with code coverage reports turned on.
* `make help` - Shows all the make commands.

Builds can be customized by changing the settings in `makedefs.mk`. The most basic customization is the compiler choice, this controlled by the `DCOMPILER` variable.

### DUB package setup

A parallel build setup was created using DUB packages. This was done to better align with the D ecosystem. However, at present DUB does not have first class support for multiple executables, and this setup pushes the boundaries of what works smoothly. That said, the setup appears to work well. One specific functionality not supported are the test capabilities. However, after building with DUB tests can be run using the makefile setup. Here's an example:
```
$ cd tsv-utils
$ dub run
$ dub test tsv-utils:common
$ make test-nobuild
```

## Unit tests and code coverage reports

D has an excellent facility for adding unit tests right with the code. The `common` utility functions and the more recent tools take advantage of built-in unit tests. However, the earlier tools do not, and instead use more traditional invocation of the command line executables and diffs the output against a "gold" result set. The more recent tools use both built-in unit tests ad tests against the executable. This includes `csv2tsv`, `tsv-summarize`, `tsv-append`, and `tsv-sample`. The built-in unit tests are much nicer, and also the advantage of being naturally cross-platform. The command line executable tests assume a Unix shell.

Tests for the command line executables are in the `tests` directory of each tool. Overall the tests cover a fair number of cases and are quite useful checks when modifying the code. They may also be helpful as an examples of command line tool invocations. See the `tests.sh` file in each `test` directory, and the `test` makefile target in `makeapp.mk`.

The unit test built into the common code (`common/src/tsvutil.d`) illustrates a useful interaction with templates: it is quite easy and natural to unit test template instantiations that might not occur naturally in the application being written along with the template.

D also has code coverage reports supported by the compiler. The `-cov` compiler flag creates an executable recording code coverage. Most common is to run coverage as part of unit tests, but reports can also be generated when running an application normally. This project generates code coverage reports using both methods and aggregates the reports (use `make test-codecov`). See the D language [Code Coverage Analysis](https://dlang.org/code_coverage.html) page for more info.
