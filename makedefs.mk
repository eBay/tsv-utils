# This makefile (makedefs.mk) is included by the subdirectory makefiles. eg. Included by
# the tsv-arrange/makefile. It establishes the basic definitions used across the project.
# An executable typically includes this file, adds any shared files used to the
# 'common_srcs' variable, and includes the makeapp.mk include. See the app makefiles for
# examples. The 'common' subdirectory makefile also includes this, but has it's own
# makefile targets.
#
# This makefile can be customized by setting the DCOMPILER, DFLAGS, LDC_LTO, and
# LDC_RUNTIME_LTO variables. These can also be set on the make command line.
#
# - DCOMPILER - path to the D compiler to use. Should include one of 'dmd', 'ldc', or
#   'gdc' in the compiler name.
# - DFLAGS are passed to the compiler on the command line.
# - LDC_LTO should be either 'thin' or 'full'. It is only used if DCOMPILER specifies an
#   ldc compiler. It overrides the default LTO setting.
# - LDC_BUILD_RUNTIME - Used to enable building the druntime and phobos runtime libraries
#   using LTO. If set to '1', builds the runtimes using the 'ldc-build-runtime' tool.
#   Otherwise is expected to be a path to the tool. Available starting with ldc 1.5.


DCOMPILER =
DFLAGS =
LDC_LTO =
LDC_BUILD_RUNTIME =

project_dir ?= $(realpath ..)
common_srcdir = $(project_dir)/common/src
project_bindir = $(project_dir)/bin
buildtools_dir = $(project_dir)/buildtools
ldc_runtime_thin_dir = $(project_dir)/ldc-build-runtime.thin
ldc_runtime_full_dir = $(project_dir)/ldc-build-runtime.full
# Thin vs Full build dir set later in file
ldc_build_runtime_dir =
objdir = obj
bindir = bin
testsdir = tests

OS_NAME := $(shell uname -s)

# Identify the compiler

dmd_compiler =
ldc_compiler =
gdc_compiler =

ifndef DCOMPILER
	DCOMPILER = dmd
	dmd_compiler = 1
else
	compiler_name = $(notdir $(basename $(DCOMPILER)))

	ifeq ($(compiler_name),dmd)
		dmd_compiler = 1
	else ifeq ($(compiler_name),ldc)
		ldc_compiler = 1
	else ifeq ($(compiler_name),ldc2)
		ldc_compiler = 1
	else ifeq ($(compiler_name),gdc)
		gdc_compiler = 1
	else ifeq ($(compiler_name),ldc)
		ldc_compiler = 1
	else ifeq ($(findstring dmd,$(compiler_name)),dmd)
		dmd_compiler = 1
	else ifeq ($(findstring ldc,$(compiler_name)),ldc)
		ldc_compiler = 1
	else ifeq ($(findstring gdc,$(compiler_name)),gdc)
		gcd_compiler = 1
	else
		dmd_compiler = 1
	endif
endif

ldc_build_runtime_tool_name = ldc-build-runtime
ldc_build_runtime_tool = $(ldc_build_runtime_tool_name)
ifdef LDC_BUILD_RUNTIME
	ifneq ($(LDC_BUILD_RUNTIME),1)
		ldc_build_runtime_tool=$(LDC_BUILD_RUNTIME)
	endif
	ifndef LDC_LTO
		ifeq ($(OS_NAME),Darwin)
			LDC_LTO = thin
		else
			LDC_LTO = full
		endif
	endif
endif

ifdef LDC_LTO
	ifeq ($(LDC_LTO),thin)
		ldc_build_runtime_dir = $(ldc_runtime_thin_dir)
	else ifeq ($(LDC_LTO),full)
		ldc_build_runtime_dir = $(ldc_runtime_full_dir)
	else
		$(error "Invalid LDC_LTO value: $(LDC_LTO). Must be either 'thin' or 'full'")
	endif
endif

ldc_build_runtime_dflags =
lto_option =
lto_release_option =

ifdef ldc_compiler
	ifdef LDC_LTO
		lto_option = -flto=$(LDC_LTO)
		lto_release_option = -flto=$(LDC_LTO)
	else ifeq ($(OS_NAME),Darwin)
		LDC_LTO = thin
		lto_release_option = -flto=$(LDC_LTO)
	endif

	ifeq ($(OS_NAME),Darwin)
		ldc_build_runtime_dflags = -flto=$(LDC_LTO);-ar=
	else
		ldc_build_runtime_dflags = -flto=$(LDC_LTO)
	endif
endif

debug_flags_base =
release_flags_base = -release -O
link_flags_base =

ifdef dmd_compiler
	release_flags_base = -release -O -boundscheck=off -inline
else ifdef ldc_compiler
	debug_flags_base = $(lto_option)
	release_flags_base = -release -O3 -boundscheck=off -singleobj $(lto_release_option)
	ifdef LDC_BUILD_RUNTIME
		ifeq ($(OS_NAME),Darwin)
			link_flags_base = -L-L$(ldc_build_runtime_dir)/lib
		else
			link_flags_base = -L-L$(ldc_build_runtime_dir)/lib -Xcc=-fuse-ld=gold
		endif
	endif
endif

debug_flags = $(debug_flags_base) -od$(objdir) $(link_flags_base) $(DFLAGS)
release_flags = $(release_flags_base) -od$(objdir) $(link_flags_base) $(DFLAGS)
unittest_flags = $(DFLAGS) -unittest -main -run
codecov_flags = -od$(objdir) $(DFLAGS) -cov
unittest_codecov_flags = -od$(objdir) $(DFLAGS) -cov -unittest -main -run
