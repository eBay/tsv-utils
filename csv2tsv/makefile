include ../makedefs.mk
include ../makeapp.mk
test: unittest test-debug test-release

.PHONY: unittest
unittest:
	@echo '---> Running $(notdir $(basename $(CURDIR))) unit tests.'
	$(DCOMPILER) $(unittest_flags) $(srcs)
	@echo '---> Unit tests completed successfully.'
