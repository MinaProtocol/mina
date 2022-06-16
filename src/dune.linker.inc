; The content of 'dune-linker' is to be passed as a -ccopt to ocamlopt
; or directly to the C compiler.
; ocamlopt -ccopt=<dune-linker> behaves correctly if <dune-linker> is empty

(rule
  (target dune-linker)
  (enabled_if %{bin-available:lld})
  (action (with-stdout-to dune-linker (echo "-ccopt=%{read:dune-linker} -fuse-ld=lld"))))

(rule
  (target dune-linker)
  (enabled_if (= %{bin-available:lld} false))
  (action (with-stdout-to dune-linker (echo " "))))
