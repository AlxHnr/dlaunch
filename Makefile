CSC_FLAGS   = -O3

-include build/extra.makefile
build/extra.makefile:
	csi -s chicken-builder/generate-extra-makefile.scm
