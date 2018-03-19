# tsv-filter should be able to use PGO, but a bug causes problems on OS X
# LDC Issue 2585: https://github.com/ldc-developers/ldc/issues/2585
ifneq ($(shell uname -s),Darwin)
	APP_USES_LDC_PGO=2
endif

include ../makedefs.mk
include ../makeapp.mk

# No built-in unit tests
unittest: ;
unittest-codecov: ;
