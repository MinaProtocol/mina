; The content of 'dune-linker' is to be passed as a -ccopt to ocamlopt
; or directly to the C compiler.
; since ocamlopt -ccopt=<dune-linker> does not behave correctly
; if <dune-linker> is empty, we pass "-O2" (which is already passed by default,
; meaning it's a no-op) in the default case (to let the compiler choose
; the linker)

(rule
  (target dune-linker)
  (enabled_if %{bin-available:lld})
  (action (with-stdout-to dune-linker (echo "-fuse-ld=lld"))))

(rule
  (target dune-linker)
  (enabled_if
    (or
      (= %{bin-available:lld} false)
      (= %{env:DUNE_USE_DEFAULT_LINKER=n} y)))
  (action (with-stdout-to dune-linker (echo "-O2"))))
