include ../makedefs.mk

release: ;
debug: ;
clean: ;
test: unittest
test-release: ;
test-nobuild: ;

.PHONY: unittest
unittest:
	@echo '---> Running $(notdir $(basename $(CURDIR))) unit tests'
	$(DCOMPILER) $(common_srcs) $(unittest_flags) src/tsvutil.d
	$(DCOMPILER) $(common_srcs) $(unittest_flags) src/getopt_inorder.d
	$(DCOMPILER) $(common_srcs) $(unittest_flags) src/tsv_numerics.d
	@echo '---> Unit tests completed successfully.'
