appdirs =  csv2tsv number-lines tsv-append tsv-filter tsv-join tsv-sample tsv-select tsv-summarize tsv-uniq
subdirs = common $(appdirs)

release: make_subdirs
debug: make_subdirs
clean: make_subdirs
test: make_subdirs
test-release: make_subdirs
test-nobuild: make_appdirs
unittest: make_subdirs

.PHONY: make_subdirs $(subdirs)
make_subdirs: $(subdirs)

.PHONY: make_appdirs $(appdirs)
make_appdirs: $(appdirs)

$(subdirs):
	@echo ''
	@echo 'make -C $@ $(MAKEFLAGS) $(MAKECMDGOALS)'
	@$(MAKE) -C $@ $(MAKEFLAGS) $(MAKECMDGOALS) 
