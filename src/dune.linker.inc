; The content of 'dune-linker' is to be passed as a -ccopt to ocamlopt
; or directly to the C compiler.

(rule
  (target dune-linker)
  (enabled_if 
    (and
      %{bin-available:lld}
      (= %{env:DUNE_USE_DEFAULT_LINKER=n} n)))
  (action (write-file dune-linker "-fuse-ld=lld")))

(rule
  (target dune-linker)
  (enabled_if
    (or
      (not %{bin-available:lld})
      (= %{env:DUNE_USE_DEFAULT_LINKER=n} y)))
  (action (write-file dune-linker "")))
