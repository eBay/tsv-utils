appdirs = csv2tsv keep-header number-lines tsv-append tsv-filter tsv-join tsv-pretty tsv-sample tsv-select tsv-summarize tsv-uniq
subdirs = common $(appdirs)
buildtools_dir = buildtools

# Package variables
OS ?= UnkOS
ARCH ?= x86_64
APP_VERSION ?= v~dev
PKG_ROOT_DIR ?= $(notdir $(basename $(CURDIR)))
DCOMPILER_BASENAME = $(notdir $(basename $(DCOMPILER)))
PKG_DIR = $(PKG_ROOT_DIR)-$(APP_VERSION)_$(OS)-$(ARCH)_$(DCOMPILER_BASENAME)
TAR_FILE ?= $(PKG_DIR).tar.gz

all: release

help:
	@echo 'Commands:'
	@echo '========='
	@echo 'release      - Release mode build.'
	@echo 'debug        - Debug build. (Apps are written with a .dbg extension.)'
	@echo 'clean        - Removes executables and other build artifacts.'
	@echo 'clean-relics - Removes build artifacts, but not release artifacts.'
	@echo 'clean-bin-relics - Removes build artifacts from the bin directory, except for release'
	@echo '               binaries. Used to create a release package.'
	@echo 'test         - Runs all tests. Unit tests, and release and debug executable tests.'
	@echo 'unittest     - Runs unit tests.'
	@echo 'test-debug   - Builds debug apps and runs command line tests against the apps.'
	@echo 'test-release - Builds release apps and runs command line tests against the apps.'
	@echo 'test-nobuild - Runs command line app tests without doing a build.'
	@echo '               This is useful when testing a build done with dub.'
	@echo 'test-codecov - Runs unit tests and app tests (executables) with code coverage'
	@echo '               reports. This is the simplest way to run code coverage. Reports are'
	@echo '               are written to .lst files, apps are built with .cov extensions.'
	@echo 'apptest-codecov  - Runs app tests (executables) with code coverage reports on.'
	@echo 'unittest-codecov - Runs unit tests with code coverage reports on.'
	@echo 'package      - Creates a release package. Used with travis-ci.'
	@echo ''
	@echo 'Note: DMD is the default compiler. Use the DCOMPILER parameter to switch. For example:'
	@echo ''
	@echo '    $$ make DCOMPILER=ldc2'
	@echo ''
	@echo 'Parameters:'
	@echo '==========='
	@echo 'DCOMPILER - Compiler to use. Defaults to DMD. Value can be a path.'
	@echo 'DFLAGS - Extra flags to pass to the compiler.'
	@echo 'LDC_HOME - The LDC install directory. If provided, all LDC binaries will located in'
	@echo '    in the bin directory inside LDC_HOME.'
	@echo 'LDC_BUILD_RUNTIME - Enables LDC support for using LTO on the runtime libraries. Use'
	@echo '    the value 1 to turn on.'
	@echo "LDC_LTO - LDC LTO options. One of 'thin', 'full', 'off', or 'default'. Leave unspecified"
	@echo '    to use the default (recommended).'
	@echo 'LDC_PGO - Turns on Profile Guided Optimization. This is available for a subset of apps,'
	@echo '    release builds with LDC_BUILD_RUNTIME=1 only. If LDC_PGO=1, PGO is used on the apps'
	@echo '    showing the largest performance benefits. If LDC_PGO=2, PGO is used on all apps it'
	@echo '    has been enabled for. Speed gains are smaller for the additional apps. PGO has'
	@echo '    longer build times. LDC_PGO=1 is a good compromise between build time and performance.'
	@echo "LDC_PGO_TYPE - Either 'IR' or 'AST'. Defaults to AST. Currently only AST is supported.'
	@echo "    IR-PGO is anticipated in a future LDC release.
	@echo ''

release: make_subdirs
debug: make_subdirs
clean: make_subdirs
	-rm -f ./*.lst
clean-relics: make_subdirs
	-rm -f ./*.lst
clean-bin-relics: make_subdirs

test: make_subdirs
unittest: make_subdirs
test-debug: make_subdirs
test-release: make_subdirs
test-nobuild: make_appdirs

.PHONY: test-codecov
test-codecov: make_subdirs buildtools
	$(buildtools_dir)/aggregate-codecov $(CURDIR) $(subdirs:%=%/*.lst)
	$(buildtools_dir)/codecov-to-relative-paths $(CURDIR)/*.lst

apptest-codecov: make_appdirs
unittest-codecov: make_subdirs

.PHONY: make_subdirs $(subdirs)
make_subdirs: $(subdirs)

.PHONY: make_appdirs $(appdirs)
make_appdirs: $(appdirs)

$(subdirs):
	@echo ''
	@echo 'make -C $@ $(MAKECMDGOALS)'
	@$(MAKE) -C $@ $(MAKECMDGOALS)

buildtools:
	@echo ''
	@echo 'make -C $(buildtools_dir)'
	@$(MAKE) -C $(buildtools_dir)

.PHONY: package
package:
	@$(MAKE) -C $(CURDIR) clean
	@$(MAKE) -C $(CURDIR) release
	@$(MAKE) -C $(CURDIR) test-nobuild
	@$(MAKE) -C $(CURDIR) clean-bin-relics
	@echo ''
	@echo '---> Build successful. Creating package.'
	@echo ''
	-rm -rf $(PKG_DIR)
	mkdir $(PKG_DIR)
	cp -pr $(CURDIR)/bin $(PKG_DIR)
	cp -pr $(CURDIR)/bash_completion $(PKG_DIR)
	cp -pr $(CURDIR)/LICENSE.txt $(PKG_DIR)
	cp -pr $(buildtools_dir)/ReleasePackageReadme.txt $(PKG_DIR)
	tar -czf $(TAR_FILE) $(PKG_DIR)
	-rm -r $(PKG_DIR)
