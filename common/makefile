include ../makedefs.mk

srcdir = $(CURDIR)/src/tsv_utils/common
unittest_utils_srcs ?= $(srcdir)/unittest_utils.d
imports ?= -I$(srcdir)

release: ;
debug: ;
codecov: ;

.PHONY: clean-bin-relics
clean-bin-relics: ;

.PHONY: clean-relics
clean-relics:
	-rm -f ./*.lst
	-rm -f ./*.o

.PHONY: clean
clean: clean-relics

test: unittest

.PHONY: unittest
unittest:
	@echo '---> Running $(notdir $(basename $(CURDIR))) unit tests'
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_flags) $(srcdir)/utils.d
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_flags) $(srcdir)/getopt_inorder.d
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_flags) $(srcdir)/numerics.d
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_flags) $(srcdir)/fieldlist.d
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_flags) $(srcdir)/tsvutils_version.d
	@echo '---> Unit tests completed successfully.'

test-debug: ;
test-release: ;
test-nobuild: ;

.PHONY: test-codecov
test-codecov: unittest-codecov

.PHONY: unittest-codecov
unittest-codecov:
	@echo '---> Running $(notdir $(basename $(CURDIR))) unit tests with code coverage.'
	-rm ./*.lst
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_codecov_flags) $(srcdir)/utils.d
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_codecov_flags) $(srcdir)/getopt_inorder.d
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_codecov_flags) $(srcdir)/numerics.d
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_codecov_flags) $(srcdir)/fieldlist.d
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_codecov_flags) $(srcdir)/tsvutils_version.d
	-rm ./__main.lst
	@echo '---> Unit tests completed successfully (code coverage on).'

apptest-codecov: ;
