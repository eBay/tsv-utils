DCOMPILER = dmd
DFLAGS =

all: aggregate-codecov codecov-to-relative-paths

aggregate-codecov: aggregate-codecov.d
	$(DCOMPILER) -release -O aggregate-codecov.d

codecov-to-relative-paths: codecov-to-relative-paths.d
	$(DCOMPILER) -release -O codecov-to-relative-paths.d

clean:
	-rm aggregate-codecov
	-rm codecov-to-relative-paths
	-rm *.o
