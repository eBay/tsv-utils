appdirs = csv2tsv keep-header number-lines tsv-append tsv-filter tsv-join tsv-sample tsv-select tsv-summarize tsv-uniq
subdirs = common $(appdirs)
buildtools_dir = buildtools

# Package variables
OS ?= UnkOS
ARCH ?= x86_64
APP_VERSION ?= v~dev
PKG_ROOT_DIR ?= $(notdir $(basename $(CURDIR)))
PKG_DIR = $(PKG_ROOT_DIR)-$(APP_VERSION)_$(OS)-$(ARCH)_$(DCOMPILER)
TAR_FILE ?= $(PKG_DIR).tar.gz

all: release

help:
	@echo 'Commands:'
	@echo '========='
	@echo 'release      - Release mode build.'
	@echo 'debug        - Debug build. (Apps are written with a .dbg extension.)'
	@echo 'codecov      - Code coverage build. (Apps are written with a .cov extension.)'
	@echo '               Note: This does not generate reports, just builds the apps.'
	@echo 'clean        - Removes executable and other build artifacts.'
	@echo 'test         - Runs all tests. Unit tests, and release and debug executable tests.'
	@echo 'unittest     - Runs unit tests.'
	@echo 'test-debug   - Builds debug apps and runs command line tests against the apps.'
	@echo 'test-release - Builds release apps and runs command line tests against the apps.'
	@echo 'test-nobuild - Runs command line app tests without doing a build.'
	@echo '               This is useful when testing a build done with dub.'
	@echo 'test-codecov - Runs unit tests and debug app tests with code coverage reports turned on.'
	@echo 'apptest-codecov  - Runs debug app tests with code coverage reports on.'
	@echo 'unittest-codecov - Runs unit tests with code coverage reports on.'
	@echo 'package      - Creates a release package. Used with travis-ci.'
	@echo ''
	@echo 'Note: Commands that run builds use the DMD compiler by default.'
	@echo '      Add DCOMPILER=ldc2 or DCOMPILER=<path> to change the compiler.'

release: make_subdirs
debug: make_subdirs
clean: make_subdirs
	-rm ./*.lst

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
	-rm -r $(PKG_DIR)
	mkdir $(PKG_DIR)
	cp -pr $(CURDIR)/bin $(PKG_DIR)
	cp -pr $(CURDIR)/bash_completion $(PKG_DIR)
	cp -pr $(CURDIR)/LICENSE.txt $(PKG_DIR)
	cp -pr $(buildtools_dir)/ReleasePackageReadme.txt $(PKG_DIR)
	tar -czf $(TAR_FILE) $(PKG_DIR)
	-rm -r $(PKG_DIR)
