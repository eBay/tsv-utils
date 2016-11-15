include ../makedefs.mk
common_srcs = $(common_srcdir)/tsvutil.d $(common_srcdir)/getopt_inorder.d 
include ../makeapp.mk

test: unittest

# No external call tests yet
test-debug: ;
test-release: ;

.PHONY: unittest
unittest:
	@echo '---> Running $(notdir $(basename $(CURDIR))) unit tests.'
	$(DCOMPILER) $(unittest_flags) $(srcs)
	@echo '---> Unit tests completed successfully.'
