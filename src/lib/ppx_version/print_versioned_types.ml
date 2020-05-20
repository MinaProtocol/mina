(* print_versioned_types.ml *)

let () =
  Ppx_version.Versioned_type.set_printing () ;
  Ppxlib.Driver.standalone ()
