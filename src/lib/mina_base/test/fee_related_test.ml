(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^fee-related$'
    Subject:    Test zkApp commands (related to fees).
 *)

open Core
open Mina_base

let feepayer_body_generator = Zkapp_command.gen

let test_fee () =
  Quickcheck.test ~trials:50 feepayer_body_generator ~f:(fun x ->
      [%test_eq: Currency.Fee.t] x.fee_payer.body.fee @@ Zkapp_command.fee x )

let fee_payer_account_update () =
  Quickcheck.test ~trials:50 feepayer_body_generator ~f:(fun x ->
      [%test_eq: Account_update.Fee_payer.t] x.fee_payer
      @@ Zkapp_command.fee_payer_account_update x )

let fee_payer_pk () =
  Quickcheck.test ~trials:50 feepayer_body_generator ~f:(fun x ->
      [%test_eq: Signature_lib.Public_key.Compressed.t]
        x.fee_payer.body.public_key
      @@ Zkapp_command.fee_payer_pk x )

let fee_excess () =
  Quickcheck.test ~trials:50 feepayer_body_generator ~f:(fun x ->
      [%test_eq: Fee_excess.t]
        (Currency.Fee.Signed.of_unsigned x.fee_payer.body.fee)
      @@ Zkapp_command.fee_excess x )
