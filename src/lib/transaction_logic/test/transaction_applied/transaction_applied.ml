open! Core
open Mina_transaction_logic.Transaction_applied
open Mina_base

let%test_module "transaction_applied" =
  ( module struct
    let stable_type_generator : Stable.V2.t =
      let open Signed_command_payload.Poly.Stable.V1 in
      let open Snark_params.Tick0 in
      let payload : Signed_command_payload.t =
        { common =
            { Signed_command_payload.Common.Poly.Stable.V2.fee =
                Currency.Fee.one
            ; fee_payer_pk =
                { Signature_lib.Public_key.Compressed.Poly.x = Field.of_int 1
                ; is_odd = false
                }
            ; nonce = 1
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
      and signer : Import.Public_key.t = Field.of_int 1 * Field.of_int 1
      and signature : Signature.t = 0 in
      let data_input : Signed_command.Stable.V2.t =
        { Signed_command.Poly.Stable.V1.payload
        ; Signed_command.Poly.Stable.V1.signer
        ; Signed_command.Poly.Stable.V1.signature
        }
      in
      let user_command_input :
          Signed_command.Stable.V2.t With_status.Stable.V2.t =
        { data = data_input; status = Transaction_status.Stable.V2.Applied }
      in
      let common_input : Signed_command_applied.t =
        { user_command = user_command_input }
      in
      let signed_command_input =
        { common = common_input
        ; body = Signed_command_applied.Body.Stable.V2.Failed
        }
      in
      let command_input = Signed_command signed_command_input in
      let varying_input = Command command_input and previous_hash_input = 0 in
      { varying = varying_input; previous_hash = previous_hash_input }

    let%test "burned_tokens" = true
    (* Currency.Amount.zero == burned_tokens stable_type_generator *)
  end )
