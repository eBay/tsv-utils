APP_USES_LDC_PGO=2
include ../makedefs.mk

# tsv-sample has issues with uncaught exceptions with LDC versions 1.7 and earlier
# when making debug builds. The -disable-fp-elim option avoids this.

ifeq ($(shell uname -s),Darwin)
	ifeq ($(compiler_type),ldc)
		ifeq ($(ldc_version),1.5.0)
			override debug_flags += -disable-fp-elim
		else ifeq ($(ldc_version),1.6.0)
			override debug_flags += -disable-fp-elim
		else ifeq ($(ldc_version),1.7.0)
			override debug_flags += -disable-fp-elim
		endif
	endif
endif

include ../makeapp.mk
