ppx.exe: ppx_source.ml
	ocamlopt.opt -o $@ -I +compiler-libs ocamlcommon.cmxa $<

clean:
	rm -f ppx_source.cm* ppx_source.o ppx.exe
