APP_USES_LDC_PGO=2

include ../makedefs.mk

# tsv-filter has issues with LTO on OS X with xcode 9.3, LDC 1.8.0.
# LDC Issue 2585: https://github.com/ldc-developers/ldc/issues/2585
# Issues go beyond issue 2585 discussion. Using LTO with only the app
# fails with multiple compiler versions. Using LTO with LDC_BUILD_RUNTIME=1
# works, but using LDC_LTO_RUNTIME=1 fails. Could be different linkers,
# not clear. Fix by adding -disable-fp-elim to release_flags created by
# makedefs.mk.
#
# Update - With LDC version 1.24 the -disable-fp-elim option was removed.
# It is no longer supported by the default LLVM version 11. At present
# there are no known cases of failure using LDC 1.24. Use of the flag is
# now conditioned on the older compiler versions.

ifeq ($(shell uname -s),Darwin)
	ifeq ($(compiler_type),ldc)
		ifeq ($(ldc_version_major_minor),1.8)
			override release_flags += -disable-fp-elim
		else ifeq ($(ldc_version_major_minor),1.9)
			override release_flags += -disable-fp-elim
		else ifeq ($(ldc_version_major_minor),1.10)
			override release_flags += -disable-fp-elim
		else ifeq ($(ldc_version_major_minor),1.11)
			override release_flags += -disable-fp-elim
		else ifeq ($(ldc_version_major_minor),1.12)
			override release_flags += -disable-fp-elim
		else ifeq ($(ldc_version_major_minor),1.13)
			override release_flags += -disable-fp-elim
		else ifeq ($(ldc_version_major_minor),1.14)
			override release_flags += -disable-fp-elim
		else ifeq ($(ldc_version_major_minor),1.15)
			override release_flags += -disable-fp-elim
		else ifeq ($(ldc_version_major_minor),1.16)
			override release_flags += -disable-fp-elim
		else ifeq ($(ldc_version_major_minor),1.17)
			override release_flags += -disable-fp-elim
		else ifeq ($(ldc_version_major_minor),1.18)
			override release_flags += -disable-fp-elim
		else ifeq ($(ldc_version_major_minor),1.19)
			override release_flags += -disable-fp-elim
		else ifeq ($(ldc_version_major_minor),1.20)
			override release_flags += -disable-fp-elim
		else ifeq ($(ldc_version_major_minor),1.21)
			override release_flags += -disable-fp-elim
		else ifeq ($(ldc_version_major_minor),1.22)
			override release_flags += -disable-fp-elim
		else ifeq ($(ldc_version_major_minor),1.23)
			override release_flags += -disable-fp-elim
		endif
	endif
endif

include ../makeapp.mk

# No built-in unit tests
unittest: ;
unittest-codecov: ;
