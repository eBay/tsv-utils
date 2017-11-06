_Visit the [main page](../README.md)_

# Building with Link Time Optimization

## About Link Time Optimization (LTO)

Link Time Optimization is an approach to whole program optimization that defers many optimizations to link-time. LDC, the LLVM-based D compiler, supports Link Time Optimization via LLVM's LTO support.

When LTO is used, the compiler generates an intermediate representation rather than machine code. In LLVM's case, LLVM bitcode. This bitcode is saved in `.o` files in place of machine code. At link time the linker calls back into LLVM plugin modules that optimize code generation across the entire program. This enables optimization that crosses function and module boundaries.

This is a powerful technique, but involves more complex cooperation between compiler and linker than the traditional compile-link cycle. Due to this complexity, it is only recently that LTO has started to become widely available.

LDC has supported LTO for several releases, however, only macOS was fully supported out-of-the-box. With the LDC 1.5.0 release, LTO is now available out-of-the-box on both Linux and macOS. Windows LTO support is in progress.

An important enhancement introduced in LDC 1.5.0 is support for compiling the D run-time library and standard library (Phobos) with LTO. This enables interprocedural optimizations spanning both D libraries and the application. For the TSV utilities this produces materially faster executables.

Compiling the D libraries with LTO is done with `ldc-build-runtime` tool, included with the LDC 1.5.0 release. This tool downloads the source code the D libraries and compiles it with LTO enabled. These LTO compiled libraries are included on the `ldc2` compile/link command when building the application. Applications can also be built compiling just the application code with LTO, linking with the static D libraries (native compilation) shipped with LDC.

There are two different forms of LTO available: Full and Thin. To build the TSV utilities with LTO is suffice to know that they exist and are incompatible with each other. For information on the differences see the LLVM blog post [ThinLTO: Scalable and Incremental LTO](http://blog.llvm.org/2016/06/thinlto-scalable-and-incremental-lto.html).

## Building the TSV utilities with LTO

The TSV utilities [pre-built binaries](https://github.com/eBay/tsv-utils-dlang/releases) are compiled with LTO. However, the default makefile configuration does not turn on LTO for Linux builds, and macOS builds use LTO for the application code, but not the D libraries. The reason is simple: LTO is still an early stage technology. Testing on a wider variety of platforms is needed before making it the default.

However, the TSV utilities can be built with LTO enabled by setting makefile parameters. Testing with the built-in test suite should provide confidence in the resulting applications. The TSV utilities makefile takes care of invoking both `ldc-build-runtime` and `ldc2` with the necessary parameters.

**Prerequisites:**
  * LDC 1.5.0 or later
  * TSV utilities 1.15.0-beta3 or later
  * Linux or macOS. macOS requires Xcode 9.0.1 or later.

Linux builds have been tested on Ubuntu 14.04 and 16.04.

**Retrieve the TSV utilities source code:**

Via git clone:

```
$ git clone https://github.com/eBay/tsv-utils-dlang.git
$ cd tsv-utils-dlang
```

Via DUB (replace `1.1.15` with the version retrieved):

```
$ dub fetch tsv-utils-dlang --cache=local
$ cd tsv-utils-dlang-1.1.15/tsv-utils-dlang
```

**Build with LTO enabled:**

Using LTO for D libraries and the TSV utilities application:

```
$ make DCOMPILER=ldc2 LDC_BUILD_RUNTIME=1
$ make test-nobuild
```

Alternative: Use LTO for TSV utilities code only:

```
$ make DCOMPILER=ldc2 LDC_LTO=default
$ make test-nobuild
```

The build should be good if the tests succeed.

## Additional options

The above instructions should be sufficient to create valid LTO builds. This section describes a few additional choices.

### Statically linking the C runtime library on Linux builds

The prebuilt linux binaries statically link the C runtime library. This increases portability, at the expense of increased binary sizes. The above instructions dynamically link the static library. To use static linking, add `DFLAGS=-static` to the build lines, as follows:

```
$ # LTO for D libraries and application
$ make DCOMPILER=ldc2 LDC_BUILD_RUNTIME=1 DFLAGS=-static
$ # LTO for application code only
$ make DCOMPILER=ldc2 LDC_LTO=default DFLAGS=-static
```

This is only applicable to Linux builds, and has only been tested on Ubuntu. On Ubuntu, use release 16.04. Issues have been observed with Ubuntu 14.04.

### Choosing between thin and full LTO builds

The makefile default settings choose between "thin" and "full" LTO builds based on the platform. At present, "thin" is used on macOS, "full" is used on Linux uses "full". This is based on the author's configuration testing. At the time this was written (LDC 1.5.0, TSV Utilities 1.1.15), bugs have surfaced in other configurations. These issues tend to be complex, involving a combination of LDC, LLVM, and the system linkers. These are likely to be fixed in future releases, but for now the default configurations are recommended. These bugs surface primarily when building both D libraries and application code using LTO (`LDC_BUILD_RUNTIME=1`). Building the application code alone works fine in most configurations. For this, use `LDC_LTO=thin` or `LDC_LTO=full`, without specifying the `LDC_BUILD_RUNTIME` parameter.

The `LDC_LTO=thin|full` parameter can also be combined with `LDC_BUILD_RUNTIME=1` to set the thin/full type when building the D libraries with LTO.

It is also possible to turn off LTO on macOS builds. For this use `LDC_LTO=off`.
