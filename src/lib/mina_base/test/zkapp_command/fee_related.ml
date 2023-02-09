open Core_kernel
open Mina_base.Zkapp_command
open Mina_base
open Snarky_backendless
open Snark_params.Tick

let%test_module "fee_related_tests" =
  ( module struct
    let feepayer_body_generator :
        Mina_wire_types.Mina_base.Account_update.Body.Fee_payer.V1.t
        Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%bind public_key = Int.quickcheck_generator in
      let%bind is_odd = Bool.quickcheck_generator in
      let%map nonce = Int.quickcheck_generator in
      { Mina_wire_types.Mina_base.Account_update.Body.Fee_payer.V1.public_key =
          { x = Field.of_int 1; is_odd = false }
          (* How can I generate Fee rather than have it fixed as one? *)
      ; fee = Currency.Fee.one
      ; valid_until = Some (Mina_numbers.Global_slot.random ())
      ; nonce = Unsigned.UInt32.of_int nonce
      }

    let body_maker input : T.t =
      let fee_payer : Account_update.Fee_payer.Stable.V1.t =
        { body = input; authorization = Signature.dummy }
      and account_updates = []
      and memo = Signed_command_memo.empty in
      { fee_payer; account_updates; memo }

    (* Tests for fee *)
    let%test_unit "fee" =
      Quickcheck.test feepayer_body_generator ~f:(fun x ->
          [%test_eq: Currency.Fee.t] x.fee (fee @@ body_maker x) )

    (* Tests for fee_payer_account_update *)
    let%test_unit "fee_payer_account_update" =
      Quickcheck.test feepayer_body_generator ~f:(fun x ->
          [%test_eq: Account_update.Fee_payer.Stable.V1.t]
            (body_maker x).fee_payer
            (fee_payer_account_update @@ body_maker x) )

    (* Tests for fee_payer_pk *)
    let%test_unit "fee_payer_pk" =
      Quickcheck.test feepayer_body_generator ~f:(fun x ->
          [%test_eq: Signature_lib.Public_key.Compressed.Stable.V1.t]
            x.public_key
            (fee_payer_pk @@ body_maker x) )

    (* Tests for fee_excess *)
    (* let%test_unit "fee_excess" =
       [%test_eq: Currency.Fee.t] () (fee_excess @@ body_maker x) *)
  end )
