OCB_INC   = -I src -I tests 
OCB_FLAGS = 
OCB       = ocamlbuild $(OCB_FLAGS) $(OCB_INC)

.PHONY: all doc test lib.native lib.byte lib.install lib.uninstall clean 

all: test lib.native lib.byte doc

lib.native:
	$(OCB) base58.cmxa
	$(OCB) base58.cmxs

lib.byte:
	$(OCB) base58.cma

clean:
	$(OCB) -clean

LIB_BUILD     =_build/src/
LIB_INSTALL   = META 
LIB_INSTALL  += $(LIB_BUILD)/b58.mli
LIB_INSTALL  += $(LIB_BUILD)/b58.cmi
LIB_INSTALL  += $(LIB_BUILD)/b58.annot
LIB_INSTALL  += $(LIB_BUILD)/base58.cma 

LIB_INSTALL  +=-optional  
LIB_INSTALL  += $(LIB_BUILD)/b58.cmx
LIB_INSTALL  += $(LIB_BUILD)/b58.cmt
LIB_INSTALL  += $(LIB_BUILD)/b58.cmti
LIB_INSTALL  += $(LIB_BUILD)/base58.cmxs
LIB_INSTALL  += $(LIB_BUILD)/base58.a
LIB_INSTALL  += $(LIB_BUILD)/base58.cmxa

lib.install:
	ocamlfind install base58 $(LIB_INSTALL)

lib.uninstall:
	ocamlfind remove base58

doc:
	$(OCB) src/base58.docdir/index.html

test: 
	$(OCB) test.native
	export OCAMLRUNPARAM="b" && time ./test.native 

