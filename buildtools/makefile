DCOMPILER = dmd
DFLAGS =
DOCKER_LDC_IMAGE = dlanguage/ldc

all:  docker-ldc-wrappers aggregate-codecov codecov-to-relative-paths

aggregate-codecov: docker-ldc-wrappers aggregate-codecov.d
	$(DCOMPILER) -release -O aggregate-codecov.d

codecov-to-relative-paths: docker-ldc-wrappers codecov-to-relative-paths.d
	$(DCOMPILER) -release -O codecov-to-relative-paths.d

docker-ldc-wrappers: docker-ldc2.sh docker-ldc-build-runtime.sh

docker-ldc2.sh:
	echo '#!/bin/sh\ndocker run --rm -ti -v $$(pwd):/src $(DOCKER_LDC_IMAGE) ldc2 $$*' > ./docker-ldc2.sh
	chmod a+x docker-ldc2.sh

docker-ldc-build-runtime.sh:
	echo '#!/bin/sh\ndocker run --rm -ti -v $$(pwd):/src $(DOCKER_LDC_IMAGE) ldc-build-runtime $$*' > docker-ldc-build-runtime.sh
	chmod a+x docker-ldc-build-runtime.sh

clean:
	-rm aggregate-codecov
	-rm codecov-to-relative-paths
	-rm *.o
	-rm docker-ldc2.sh
	-rm docker-ldc-build-runtime.sh
