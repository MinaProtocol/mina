(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^coinbase$'
    Subject:    Test coinbase.
 *)

open Core_kernel
open Mina_base
open Coinbase
open Genesis_constants

let constraint_constants = Constraint_constants.compiled

let accessed_accounts_are_also_referenced () =
  Quickcheck.test
    (Quickcheck.Generator.map ~f:fst @@ Gen.gen ~constraint_constants)
    ~f:(fun cb ->
      [%test_eq: Account_id.t list] (accounts_referenced cb)
        ( List.map ~f:fst
        @@ account_access_statuses cb Transaction_status.Applied ) )

let referenced_accounts_either_1_or_2 () =
  Quickcheck.test
    (Quickcheck.Generator.map ~f:fst @@ Gen.gen ~constraint_constants)
    ~f:(fun cb ->
      [%test_eq: int]
        (match cb.fee_transfer with None -> 1 | Some _ -> 2)
        (List.length @@ accounts_referenced cb) )
