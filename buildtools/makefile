DCOMPILER = dmd
DFLAGS =

all: aggregate-codecov codecov-to-relative-paths diff-test-result-dirs dircat

aggregate-codecov: aggregate-codecov.d
	$(DCOMPILER) -release -O aggregate-codecov.d

codecov-to-relative-paths: codecov-to-relative-paths.d
	$(DCOMPILER) -release -O codecov-to-relative-paths.d

diff-test-result-dirs: diff-test-result-dirs.d
	$(DCOMPILER) -release -O diff-test-result-dirs.d

dircat: dircat.d
	$(DCOMPILER) -release -O dircat.d

clean:
	-rm aggregate-codecov
	-rm codecov-to-relative-paths
	-rm diff-test-result-dirs
	-rm dircat
	-rm *.o
