appdirs = csv2tsv keep-header number-lines tsv-append tsv-filter tsv-join tsv-sample tsv-select tsv-summarize tsv-uniq
subdirs = common $(appdirs)

help:
	@echo 'Note: Commands that run builds use the DMD compiler by default.'
	@echo '      Add DCOMPILER=ldc2 or DCOMPILER=<path> to change the compiler.'
	@echo 'Commands:'
	@echo '========='
	@echo 'release      - Release mode build.'
	@echo 'debug        - Debug build. (Apps are written with a .dbg extension.)'
	@echo 'codecov      - Code coverage build. (Apps are written with a .cov extension.)'
	@echo '               Note: This doesn't generate reports, just builds the apps.'
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

release: make_subdirs
debug: make_subdirs
clean: make_subdirs
test: make_subdirs
unittest: make_subdirs
test-debug: make_subdirs
test-release: make_subdirs
test-nobuild: make_appdirs
test-codecov: make_subdirs
apptest-codecov: make_appdirs
unittest-codecov: make_subdirs

.PHONY: make_subdirs $(subdirs)
make_subdirs: $(subdirs)

.PHONY: make_appdirs $(appdirs)
make_appdirs: $(appdirs)

$(subdirs):
	@echo ''
	@echo 'make -C $@ $(MAKEFLAGS) $(MAKECMDGOALS)'
	@$(MAKE) -C $@ $(MAKEFLAGS) $(MAKECMDGOALS) 
