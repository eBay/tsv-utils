app ?= $(notdir $(basename $(CURDIR)))
common_srcs ?= $(common_srcdir)/utils.d $(common_srcdir)/numerics.d $(common_srcdir)/getopt_inorder.d $(common_srcdir)/unittest_utils.d $(common_srcdir)/tsvutils_version.d
app_src ?= $(CURDIR)/src/$(app).d
srcs ?= $(app_src) $(common_srcs)
imports ?= -I$(common_srcdir)

app_release = $(project_bindir)/$(app)
app_debug = $(project_bindir)/$(app).dbg
app_codecov = $(project_bindir)/$(app).cov
app_instrumented = $(project_bindir)/$(app).instrumented

release: $(app_release)
debug: $(app_debug)
codecov: $(app_codecov)

# Note: If not blank, app_ldc_profdata_file will be the same as ldc_profdata_file
$(app_release): ldc-build-runtime-libs $(app_ldc_profdata_file) $(srcs)
	$(DCOMPILER) $(release_flags) -of$(app_release) $(imports) $(srcs)
$(app_debug):  ldc-build-runtime-libs $(srcs)
	$(DCOMPILER) $(debug_flags) -of$(app_debug) $(imports) $(srcs)
$(app_codecov): ldc-build-runtime-libs $(srcs)
	$(DCOMPILER) $(codecov_flags) -of$(app_codecov) $(imports) $(srcs)

.PHONY: clean-bin-relics
clean-bin-relics:
	-rm -f $(app_debug)
	-rm -f $(app_codecov)
	-rm -f $(app_instrumented)

.PHONY: clean-relics
clean-relics: clean-bin-relics
	-rm -f $(objdir)/*.o
	-rm -f ./*.lst
	-rm -f $(testsdir)/*.lst
	-rm -f $(ldc_profdata_file)
	-rm -f $(ldc_profile_data_dir)/profile.*.raw

.PHONY: clean
clean: clean-relics
	-rm -f $(app_release)

.PHONY: test
test: unittest test-debug test-release

.PHONY: unittest
unittest:
	@echo '---> Running $(notdir $(basename $(CURDIR))) unit tests'
	$(DCOMPILER) $(imports) $(common_srcs) $(unittest_flags) $(app_src)
	@echo '---> Unit tests completed successfully.'

.PHONY: test-debug
test-debug: $(app_debug) buildtools
	-@if [ -d $(testsdir)/latest_debug ]; then echo 'Deleting prior test files.';  rm $(testsdir)/latest_debug/*; fi
	@if [ ! -d $(testsdir)/latest_debug ]; then mkdir $(testsdir)/latest_debug; fi
	cd $(testsdir) && ./tests.sh $(app_debug) latest_debug
	@if $(diff_test_result_dirs) -q -d $(testsdir) latest_debug; \
	then echo '---> $(app) command line tests passed.'; exit 0; \
	else echo '---> $(app) command line tests failed.'; \
	$(diff_test_result_dirs) -d $(testsdir) latest_debug; \
	exit 1; \
	fi

.PHONY: test-release
test-release: $(app_release) buildtools
	-@if [ -d $(testsdir)/latest_release ]; then echo 'Deleting prior test files.';  rm $(testsdir)/latest_release/*; fi
	@if [ ! -d $(testsdir)/latest_release ]; then mkdir $(testsdir)/latest_release; fi
	cd $(testsdir) && ./tests.sh $(app_release) latest_release
	@if $(diff_test_result_dirs) -q -d $(testsdir) latest_release; \
	then echo '---> $(app) command line tests passed.'; exit 0; \
	else echo '---> $(app) command line tests failed.'; \
	$(diff_test_result_dirs) -d $(testsdir) latest_release; \
	exit 1; \
	fi

.PHONY: test-nobuild
test-nobuild: buildtools
	-@if [ -d $(testsdir)/latest_release ]; then echo 'Deleting prior test files.';  rm $(testsdir)/latest_release/*; fi
	@if [ ! -d $(testsdir)/latest_release ]; then mkdir $(testsdir)/latest_release; fi
	cd $(testsdir) && ./tests.sh $(app_release) latest_release
	@if $(diff_test_result_dirs) -q -d $(testsdir) latest_release; \
	then echo '---> $(app) command line tests passed.'; exit 0; \
	else echo '---> $(app) command line tests failed.'; \
	$(diff_test_result_dirs) -d $(testsdir) latest_release; \
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
apptest-codecov: $(app_codecov) buildtools
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
	@if $(diff_test_result_dirs) -q -d $(testsdir) latest_debug; \
	then echo '---> $(app) command line tests passed (code coverage on).'; exit 0; \
	else echo '---> $(app) command line tests failed (code coverage on).'; \
	$(diff_test_result_dirs) -d $(testsdir) latest_debug; \
	exit 1; \
	fi

.PHONY: ldc-build-runtime-libs
ldc-build-runtime-libs: $(ldc_build_runtime_dir)

$(ldc_build_runtime_dir):
ifdef LDC_BUILD_RUNTIME
	$(ldc_build_runtime_tool) --dFlags="$(ldc_build_runtime_dflags)" --buildDir $(ldc_build_runtime_dir) BUILD_SHARED_LIBS=OFF
endif

$(ldc_profdata_file):
	@echo ''
	@echo '---> PGO: Building an instrumented build.'
	@echo ''
	$(DCOMPILER) $(release_instrumented_flags) -of$(app_instrumented) $(imports) $(srcs)
	@echo ''
	@echo '---> PGO: Collecting profile data'
	cd $(ldc_profile_data_dir) && ./$(ldc_profdata_collect_prog) $(app_instrumented) $(LDC_HOME)
	@echo '---> PGO: Collection complete'
	@echo ''

buildtools:
	@echo ''
	@echo 'make -C $(buildtools_dir) DCOMPILER=$(DCOMPILER)'
	@$(MAKE) -C $(buildtools_dir) DCOMPILER=$(DCOMPILER)
