subdirs = common number-lines tsv-select tsv-filter tsv-join tsv-uniq

release: make_subdirs
debug: make_subdirs
clean: make_subdirs
test: make_subdirs

.PHONY: make_subdirs $(subdirs)
make_subdirs: $(subdirs)
$(subdirs):
	@echo ''
	@echo 'make -C $@ $(MAKEFLAGS) $(MAKECMDGOALS)'
	@$(MAKE) -C $@ $(MAKEFLAGS) $(MAKECMDGOALS) 
