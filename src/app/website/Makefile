.PHONY: all
all:
	dune exec website -- public -working-directory "$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))"
