(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^receipts$'
    Subject:    Test receipts.
 *)

open Core_kernel
open Snark_params.Tick
open Mina_base
open Receipt
open Chain_hash

let checked_unchecked_equivalence_signed_command () =
  let open Quickcheck in
  test ~trials:20 (Generator.tuple2 gen Signed_command_payload.gen)
    ~f:(fun (base, payload) ->
      let unchecked =
        cons_signed_command_payload (Signed_command_payload payload) base
      in
      let checked =
        let comp =
          let open Snark_params.Tick.Checked.Let_syntax in
          let payload =
            Transaction_union_payload.(
              Checked.constant (of_user_command_payload payload))
          in
          let%map res =
            Checked.cons_signed_command_payload (Signed_command_payload payload)
              (var_of_t base)
          in
          As_prover.read typ res
        in
        Or_error.ok_exn (run_and_check comp)
      in
      [%test_eq: t] unchecked checked )

let checked_unchecked_equivalence_zkapp_command () =
  let open Quickcheck in
  test ~trials:20 (Generator.tuple2 gen Field.gen) ~f:(fun (base, commitment) ->
      let index_int = 17 in
      let unchecked =
        let index = Mina_numbers.Index.of_int index_int in
        cons_zkapp_command_commitment index
          (Zkapp_command_commitment commitment) base
      in
      let checked =
        let open Snark_params.Tick.Checked.Let_syntax in
        let comp =
          let%bind index =
            let open Mina_numbers.Index.Checked in
            let rec go acc (n : int) =
              if Int.equal n 0 then return acc
              else
                let%bind acc' = succ acc in
                go acc' (n - 1)
            in
            go zero index_int
          in
          let commitment = Field.Var.constant commitment in
          let%map res =
            Checked.cons_zkapp_command_commitment index
              (Zkapp_command_commitment commitment) (var_of_t base)
          in
          As_prover.read typ res
        in
        Or_error.ok_exn (run_and_check comp)
      in
      [%test_eq: t] unchecked checked )

let json_roundtrip () =
  Quickcheck.test ~trials:20 gen ~sexp_of:sexp_of_t
    ~f:
      ([%test_pred: t]
         (Codable.For_tests.check_encoding (module Stable.Latest) ~equal) )
