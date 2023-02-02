open! Core
open Mina_transaction_logic.Transaction_applied
open Mina_base

let%test_module "transaction_applied" =
  ( module struct
    let stable_type_generator : t =
      let open Snark_params.Tick0 in
      let payload : Signed_command_payload.t =
        { common =
            { Signed_command_payload.Common.Poly.fee = Currency.Fee.one
            ; fee_payer_pk =
                { Signature_lib.Public_key.Compressed.Poly.x = Field.of_int 1
                ; is_odd = false
                }
            ; nonce = Unsigned.UInt32.of_int 1
            ; valid_until = Mina_transaction_logic.Global_slot.of_int 1
            ; memo = Signed_command_memo.empty
            }
        ; body =
            Signed_command_payload.Body.Payment
              { source_pk =
                  { Signature_lib.Public_key.Compressed.Poly.x = Field.of_int 1
                  ; is_odd = false
                  }
              ; receiver_pk =
                  { Signature_lib.Public_key.Compressed.Poly.x = Field.of_int 1
                  ; is_odd = false
                  }
              ; amount = Currency.Amount.zero
              }
        }
      and signer : Import.Public_key.t = (Field.of_int 1, Field.of_int 1)
      and signature : Signature.t =
        (Field.of_int 1, Pasta_bindings.Fq.of_int 1)
      in
      let data_input : Signed_command.Stable.V2.t =
        { Signed_command.Poly.payload
        ; Signed_command.Poly.signer
        ; Signed_command.Poly.signature
        }
      in
      let user_command_input : Signed_command.t With_status.t =
        { data = data_input; status = Transaction_status.Applied }
      in
      let common_input : Signed_command_applied.Common.t =
        { user_command = user_command_input }
      in
      let signed_command_input : Signed_command_applied.t =
        { common = common_input; body = Signed_command_applied.Body.Failed }
      in
      let command_input = Command_applied.Signed_command signed_command_input in
      let varying_input = Varying.Command command_input
      and previous_hash_input = Field.of_int 0 in
      { varying = varying_input; previous_hash = previous_hash_input }

    type signed_amount = Currency.Amount.Signed.t
    [@@deriving equal, sexp, compare]

    (* let signed_amount_equal (expr1 : signed_amount) (expr2 : signed_amount) =
         Currency.Amount.Signed.equal expr1 expr2

       let sexp_of_signed_amount = Currency.Amount.Signed.sexp_of_t *)

    let%test_unit "supply_increase" =
      [%test_eq: signed_amount Or_error.t]
        (Or_error.return Currency.Amount.Signed.zero)
        (supply_increase stable_type_generator)
  end )
