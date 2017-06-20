# This makefile (makedefs.mk) is included by the subdirectory makefiles. eg. Included by
# the tsv-arrange/makefile. It establishes the basic definitions used across the project.
# An executable typically includes this file, adds any shared files used to the
# 'common_srcs' variable, and includes the makeapp.mk include. See the app makefiles for
# examples. The 'common' subdirectory makefile also includes this, but has it's own
# makefile targets.
#
# This makefile can be customized by setting the DCOMPILER and DFLAGS variable. These
# can also be set on the make command line.

DCOMPILER = dmd
DFLAGS =

project_dir ?= $(realpath ..)
common_srcdir = $(project_dir)/common/src
project_bindir = $(project_dir)/bin
buildtools_dir = $(project_dir)/buildtools
objdir = obj
bindir = bin
testsdir = tests

OS_NAME := $(shell uname -s)

FLTO_OPTION =
ifeq ($(OS_NAME),Darwin)
	FLTO_OPTION = -flto=full
endif

release_flags_base = -release -O3 -boundscheck=off -singleobj $(FLTO_OPTION)
ifeq ($(notdir $(basename $(DCOMPILER))),dmd)
	release_flags_base = -release -O -boundscheck=off -inline
endif

debug_flags = -od$(objdir) $(DFLAGS)
release_flags = $(release_flags_base) -od$(objdir) $(DFLAGS)
unittest_flags = $(DFLAGS) -unittest -main -run
codecov_flags = -od$(objdir) $(DFLAGS) -cov
unittest_codecov_flags = -od$(objdir) $(DFLAGS) -cov -unittest -main -run
