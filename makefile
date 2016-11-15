appdirs =  csv2tsv number-lines tsv-filter tsv-join tsv-select tsv-uniq tsv-summarize
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
