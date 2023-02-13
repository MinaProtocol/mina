open Core_kernel
open Mina_base.Zkapp_command
open Mina_base
open Snarky_backendless
open Snark_params.Tick

let%test_module "fee_related_tests" =
  ( module struct
    let feepayer_body_generator = Zkapp_command.T.Stable.Latest.Wire.gen

    let%test_unit "fee" =
      Quickcheck.test ~trials:50 feepayer_body_generator ~f:(fun x ->
          [%test_eq: Currency.Fee.t] x.fee_payer.body.fee
            (fee @@ Zkapp_command.T.Stable.Latest.of_wire x) )

    let%test_unit "fee_payer_account_update" =
      Quickcheck.test ~trials:50 feepayer_body_generator ~f:(fun x ->
          [%test_eq: Account_update.Fee_payer.Stable.V1.t] x.fee_payer
            (fee_payer_account_update @@ Zkapp_command.T.Stable.Latest.of_wire x) )

    let%test_unit "fee_payer_pk" =
      Quickcheck.test ~trials:50 feepayer_body_generator ~f:(fun x ->
          [%test_eq: Signature_lib.Public_key.Compressed.Stable.V1.t]
            x.fee_payer.body.public_key
            (fee_payer_pk @@ Zkapp_command.T.Stable.Latest.of_wire x) )

    let%test_unit "fee_excess" =
      Quickcheck.test ~trials:50 feepayer_body_generator ~f:(fun x ->
          [%test_eq: (Token_id.t, Currency.Fee.Signed.t) Fee_excess.Poly.t]
            { fee_token_l = Token_id.default
            ; fee_excess_l =
                Currency.Fee.Signed.of_unsigned @@ x.fee_payer.body.fee
            ; fee_token_r = Token_id.default
            ; fee_excess_r = Currency.Fee.Signed.zero
            }
            (fee_excess @@ Zkapp_command.T.Stable.Latest.of_wire x) )
  end )
