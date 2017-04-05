app ?= $(notdir $(basename $(CURDIR)))
common_srcs ?= $(common_srcdir)/tsvutil.d $(common_srcdir)/tsv_numerics.d $(common_srcdir)/getopt_inorder.d $(common_srcdir)/unittest_utils.d
app_src ?= $(CURDIR)/src/$(app).d
srcs ?= $(app_src) $(common_srcs)
imports ?= -I$(common_srcdir)

app_release = $(project_bindir)/$(app)
app_debug = $(project_bindir)/$(app).dbg
app_codecov = $(project_bindir)/$(app).cov

release: $(app_release)
debug: $(app_debug)
codecov: $(app_codecov)

$(app_release): $(srcs)
	$(DCOMPILER) $(release_flags) -of$(app_release) $(imports) $(srcs)
$(app_debug): $(srcs)
	$(DCOMPILER) $(debug_flags) -of$(app_debug) $(imports) $(srcs)
$(app_codecov): $(srcs)
	$(DCOMPILER) $(codecov_flags) -of$(app_codecov) $(imports) $(srcs)

clean:
	-rm $(app_debug)
	-rm $(app_release)
	-rm $(app_codecov)
	-rm $(objdir)/*.o
	-rm ./*.lst
	-rm $(testsdir)/*.lst

.PHONY: test
test: unittest test-debug test-release

.PHONY: unittest
unittest:
	@echo '---> Running $(notdir $(basename $(CURDIR))) unit tests'
	$(DCOMPILER) $(imports) $(common_srcs) $(unittest_flags) $(app_src)
	@echo '---> Unit tests completed successfully.'

.PHONY: test-debug
test-debug: $(app_debug)
	-@if [ -d $(testsdir)/latest_debug ]; then echo 'Deleting prior test files.';  rm $(testsdir)/latest_debug/*; fi
	@if [ ! -d $(testsdir)/latest_debug ]; then mkdir $(testsdir)/latest_debug; fi
	cd $(testsdir) && ./tests.sh $(app_debug) latest_debug
	@if diff -q $(testsdir)/latest_debug $(testsdir)/gold ; \
	then echo '---> $(app) command line tests passed.'; exit 0; \
	else echo '---> $(app) command line tests failed.'; \
	exit 1; \
	fi

.PHONY: test-release
test-release: $(app_release)
	-@if [ -d $(testsdir)/latest_release ]; then echo 'Deleting prior test files.';  rm $(testsdir)/latest_release/*; fi
	@if [ ! -d $(testsdir)/latest_release ]; then mkdir $(testsdir)/latest_release; fi
	cd $(testsdir) && ./tests.sh $(app_release) latest_release
	@if diff -q $(testsdir)/latest_release $(testsdir)/gold ; \
	then echo '---> $(app) command line tests passed.'; exit 0; \
	else echo '---> $(app) command line tests failed.'; \
	exit 1; \
	fi

.PHONY: test-nobuild
test-nobuild:
	-@if [ -d $(testsdir)/latest_release ]; then echo 'Deleting prior test files.';  rm $(testsdir)/latest_release/*; fi
	@if [ ! -d $(testsdir)/latest_release ]; then mkdir $(testsdir)/latest_release; fi
	cd $(testsdir) && ./tests.sh $(app_release) latest_release
	@if diff -q $(testsdir)/latest_release $(testsdir)/gold ; \
	then echo '---> $(app) command line tests passed.'; exit 0; \
	else echo '---> $(app) command line tests failed.'; \
	exit 1; \
	fi

.PHONY: test-codecov
test-codecov: apptest-codecov unittest-codecov buildtools
	@echo 'Aggregating code coverage reports for $(notdir $(basename $(CURDIR)))'
	$(buildtools_dir)/aggregate-codecov $(CURDIR) $(testsdir)/*.lst

.PHONY: unittest-codecov
unittest-codecov:
	@echo '---> Running $(notdir $(basename $(CURDIR))) unit tests with code coverage.'
	-rm ./*.lst
	$(DCOMPILER) $(imports) $(common_srcs) $(unittest_codecov_flags) $(app_src)
	-rm ./__main.lst
	@echo '---> Unit tests completed successfully (code coverage on).'

.PHONY: apptest-codecov
apptest-codecov: $(app_codecov)
# Notes:
# * The app code coverage tests are setup to aggregate with prior files. Files from
#   prior runs need to be deleted first. That's what the first 'find' does.
# * Code coverage output is not useful for files on the compiler line, but not used by the.
#   app being built. Typically utilities from common. The second 'find' deletes these.
	-@if [ -d $(testsdir)/latest_debug ]; then echo 'Deleting prior test files.';  rm $(testsdir)/latest_debug/*; fi
	@if [ ! -d $(testsdir)/latest_debug ]; then mkdir $(testsdir)/latest_debug; fi
	find $(testsdir) -maxdepth 1 -name '*.lst' -exec rm {} \;
	cd $(testsdir) && ./tests.sh $(app_codecov) latest_debug
	find $(testsdir) -maxdepth 1 -name '*.lst' -exec sh -c 'tail -n 1 -- $$0 | grep -q "has no code"' {} \; -exec rm {} \;
	@if diff -q $(testsdir)/latest_debug $(testsdir)/gold ; \
	then echo '---> $(app) command line tests passed (code coverage on).'; exit 0; \
	else echo '---> $(app) command line tests failed (code coverage on).'; \
	exit 1; \
	fi

buildtools:
	@echo ''
	@echo 'make -C $(buildtools_dir) $(MAKEFLAGS)'
	@$(MAKE) -C $(buildtools_dir) $(MAKEFLAGS)
