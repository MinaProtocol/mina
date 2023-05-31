(* print_versioned_types.ml *)

let () =
  Ppx_version.Dummy_derivers.register_dummies () ;
  Ppx_version.Versioned_type.set_printing () ;
  Ppxlib.Driver.standalone ()
