MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
CURRENT_DIR := $(dir $(MAKEFILE_PATH))

OCAML_LIB_DIR=$(shell ocamlc -where)
include $(OCAML_LIB_DIR)/Makefile.config

CTYPES_LIB_DIR=$(shell ocamlfind query ctypes)

ENV=CTYPES_LIB_DIR=$(CTYPES_LIB_DIR) OCAML_LIB_DIR=$(OCAML_LIB_DIR)
OCAMLBUILD=$(ENV) ocamlbuild -use-ocamlfind -classic-display

all:
	$(OCAMLBUILD) lib/sodium.cma lib/sodium.cmxa

clean:
	$(OCAMLBUILD) -clean

test: _build/lib_test/nacl_runner
	CAML_LD_LIBRARY_PATH=$(CURRENT_DIR)_build/lib:$(CAML_LD_LIBRARY_PATH) \
		$(OCAMLBUILD) lib_test/test_sodium.byte --
	$(OCAMLBUILD) lib_test/test_sodium.native --

install:
	ocamlfind install sodium lib/META \
		$(addprefix _build/lib/,sodium.mli sodium.cmi sodium.cmti \
					sodium.cma sodium.cmx sodium.cmxa \
		                        sodium$(EXT_LIB) \
					libsodium_stubs$(EXT_LIB))

uninstall:
	ocamlfind remove sodium

reinstall: uninstall install

.PHONY: all clean test install uninstall reinstall

_build/%: %.c
	mkdir -p $$(dirname $@)
	$(CC) -Wall -g $(CFLAGS) -lsodium -o $@ $^
