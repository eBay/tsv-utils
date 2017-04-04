DCOMPILER = dmd
DFLAGS =

all: aggregate-codecov

aggregate-codecov:
	$(DCOMPILER) -release -O aggregate-codecov.d

clean:
	-rm aggregate-codecov
	-rm *.o
