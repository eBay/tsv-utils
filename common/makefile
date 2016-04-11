include ../makedefs.mk

srcs = src/tsvutil.d

release: ;
debug: ;
clean: ;
test:
	@echo '---> Running $(notdir $(basename $(CURDIR))) unit tests.'
	$(DCOMPILER) $(unittest_flags) $(srcs)
	@echo '---> Unit tests completed successfully.'
