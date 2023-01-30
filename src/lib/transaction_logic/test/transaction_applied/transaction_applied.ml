open! Core
open Mina_transaction_logic.Transaction_applied
open Mina_base

let%test_module "transaction_applied" =
  ( module struct
    let stable_type_generator : Stable.V2.t =
      let open Signed_command_payload.Poly.Stable.V1 in
      let payload =
        { common =
            { Signed_command_payload.Common.Poly.Stable.V2.fee = 1
            ; fee_payer_pk =
                { Signature_lib.Public_key.Compressed.Poly.x = 1
                ; is_odd = false
                }
            ; nonce = 1
            ; valid_until = 1
            ; memo = "memo"
            }
        ; body =
            Signed_command_payload.Body.Payment
              { source_pk =
                  { Signature_lib.Public_key.Compressed.Poly.x = 1
                  ; is_odd = false
                  }
              ; receiver_pk =
                  { Signature_lib.Public_key.Compressed.Poly.x = 1
                  ; is_odd = false
                  }
                  (* ; token_id = 1 *)
              ; amount = Currency.Amount.zero
              }
        }
      in
      let data_input =
        { Signed_command.Poly.Stable.V1.payload
        ; Signed_command.Poly.Stable.V1.signer = 0
        ; Signed_command.Poly.Stable.V1.signature = 0
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
      (* let zkapp_input = {accounts= []} in
         let command_input = Zkapp_command zkapp_input in *)
      let varying_input = Command command_input and previous_hash_input = 0 in
      { varying = varying_input; previous_hash = previous_hash_input }

    let%test "burned_tokens" = true
    (* Currency.Amount.zero == burned_tokens stable_type_generator *)
  end )
