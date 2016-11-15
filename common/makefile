include ../makedefs.mk

srcs = src/tsvutil.d src/getopt_inorder.d

release: ;
debug: ;
clean: ;
test test-release:
	@echo '---> Running $(notdir $(basename $(CURDIR))) unit tests.'
	$(DCOMPILER) $(unittest_flags) $(srcs)
	@echo '---> Unit tests completed successfully.'
