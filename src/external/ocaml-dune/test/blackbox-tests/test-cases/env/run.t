  $ dune printenv --profile default .
  (
   (flags (-w -40 ":standard + in ."))
   (ocamlc_flags (-g))
   (ocamlopt_flags (-g))
  )
  $ dune printenv --profile default src
  (
   (flags (-w -40 ":standard + in ." ":standard + in src"))
   (ocamlc_flags (-g))
   (ocamlopt_flags (-g))
  )
  $ dune printenv --profile default bin
  (
   (flags ("in bin"))
   (ocamlc_flags (-g))
   (ocamlopt_flags (-g))
  )
  $ dune printenv --profile default vendor
  (
   (flags (-w -40 ":standard + in ."))
   (ocamlc_flags (-g))
   (ocamlopt_flags (-g))
  )

Vendored project without env customization, the global default should
apply:

  $ dune printenv --profile default vendor/without-env-customization
  (
   (flags (-w -40))
   (ocamlc_flags (-g))
   (ocamlopt_flags (-g))
  )

Vendored project with env customization, the global default +
customization of vendored project should apply:

  $ dune printenv --profile default vendor/with-env-customization
  (
   (flags (-w -40 ":standard + in vendor/with-env-customization"))
   (ocamlc_flags (-g))
   (ocamlopt_flags (-g))
  )
  $ dune printenv --profile default vendor/with-env-customization/src
  (
   (flags ("in vendor/with-env-customization/src"))
   (ocamlc_flags (-g))
   (ocamlopt_flags (-g))
  )

