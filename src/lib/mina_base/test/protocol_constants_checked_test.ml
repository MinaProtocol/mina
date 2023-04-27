(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^protocol constants checked$'
    Subject:    Test checked protocol constants.
 *)

open Core_kernel
open Snark_params.Tick
open Mina_base
open Protocol_constants_checked

let value_equals_var () =
  let compiled = Genesis_constants.for_unit_tests.protocol in
  let test (protocol_constants : Value.t) =
    let open Snarky_backendless in
    let p_var =
      let%map p = exists typ ~compute:(As_prover0.return protocol_constants) in
      As_prover0.read typ p
    in
    let res = Or_error.ok_exn (run_and_check p_var) in
    [%test_eq: Value.t] res protocol_constants ;
    [%test_eq: Value.t] protocol_constants
      (t_of_value protocol_constants |> value_of_t)
  in
  Quickcheck.test ~trials:100 Value.gen
    ~examples:[ value_of_t compiled ]
    ~f:test
