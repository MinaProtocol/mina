(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^control$'
    Subject:    Test control.
 *)

open Core_kernel
open Mina_base.Control

let json_roundtrip () =
  let module Fd = Fields_derivers_zkapps.Derivers in
  let full = deriver (Fd.o ()) in
  List.iter [ None_given; dummy_proof; dummy_signature ] ~f:(fun ctrl ->
      [%test_eq: t] ctrl (Fd.to_json full ctrl |> Fd.of_json full) )
