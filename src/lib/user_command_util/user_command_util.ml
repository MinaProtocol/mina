open Coda_base
open Signature_lib
open Coda_numbers
open Core_kernel

module Client_input = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { sender_kp: Keypair.Stable.V1.t
        ; fee: Currency.Fee.Stable.V1.t
        ; nonce_opt: Account_nonce.Stable.V1.t option
        ; valid_until: Account_nonce.Stable.V1.t
        ; memo: User_command_memo.Stable.V1.t
        ; body: User_command_payload.Body.Stable.V1.t }
      [@@deriving to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    { sender_kp: Keypair.t
    ; fee: Currency.Fee.t
    ; nonce_opt: Account_nonce.t option
    ; valid_until: Account_nonce.t
    ; memo: User_command_memo.t
    ; body: User_command_payload.Body.t }
  [@@deriving make, to_yojson]

  (*let create ~fee ~nonce_opt ~valid_until ~memo ~sender_kp
  user_command_body =
  {fee;sender_kp; nonce_opt; valid_until; memo; body=user_command_body }*)
end

type user_command_input =
  { client_input: Client_input.t list
  ; inferred_nonce: Public_key.Compressed.t -> Account_nonce.t Option.t }

(*; record_payment: User_command.t -> Account.t -> Receipt.Chain_hash.t
  ; result: unit Or_error.t Ivar.t }*)
(*list of accepted and rejected user commands*)

(*let setup_user_command (input: Input.t) =
  let payload =
    User_command.Payload.create ~fee:input.fee ~nonce ~valid_until ~memo
      ~body:user_command_body
  in
  let signed_user_command = User_command.sign sender_kp payload in
  User_command.forget_check signed_user_command

let get_inferred_nonce_from_transaction_pool_and_ledger resource_pool
    (addr : Public_key.Compressed.t) =
  let pooled_transactions =
    Network_pool.Transaction_pool.Resource_pool.all_from_user resource_pool
      addr
  in
  let txn_pool_nonce =
    let nonces =
      List.map pooled_transactions
        ~f:(Fn.compose User_command.nonce User_command.forget_check)
    in
    (* The last nonce gives us the maximum nonce in the transaction pool *)
    List.last nonces
  in
  match txn_pool_nonce with
  | Some nonce ->
      Participating_state.Option.return (Account.Nonce.succ nonce)
  | None ->
      let open Participating_state.Option.Let_syntax in
      let%map account = get_account t addr in
      account.Account.Poly.nonce

let add_transaction input pool =
  let txn = setup_user_command input in
  let nonce = 
    match uc_input.nonce_opt with
    | None -> get_inferred_nonce_from_transaction_pool_and_ledger t 
  let%bind () = Strict_pipe.Writer.write local_txns_writer txn
  in 
  let receipt = *)
