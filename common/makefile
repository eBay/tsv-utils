include ../makedefs.mk

unittest_utils_srcs ?= $(CURDIR)/src/unittest_utils.d
imports ?= -I$(CURDIR)/src

release: ;
debug: ;
codecov: ;

.PHONY: clean-bin-relics
clean-bin-relics: ;

.PHONY: clean-relics
clean-relics:
	-rm -f ./*.lst

.PHONY: clean
clean: clean-relics

test: unittest

.PHONY: unittest
unittest:
	@echo '---> Running $(notdir $(basename $(CURDIR))) unit tests'
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_flags) $(CURDIR)/src/tsvutil.d
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_flags) $(CURDIR)/src/getopt_inorder.d
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_flags) $(CURDIR)/src/tsv_numerics.d
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_flags) $(CURDIR)/src/tsvutils_version.d
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
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_codecov_flags) $(CURDIR)/src/tsvutil.d
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_codecov_flags) $(CURDIR)/src/getopt_inorder.d
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_codecov_flags) $(CURDIR)/src/tsv_numerics.d
	$(DCOMPILER) $(imports) $(unittest_utils_srcs) $(unittest_codecov_flags) $(CURDIR)/src/tsvutils_version.d
	-rm ./__main.lst
	@echo '---> Unit tests completed successfully (code coverage on).'

apptest-codecov: ;
