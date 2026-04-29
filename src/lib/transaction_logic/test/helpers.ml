open Core_kernel
open Mina_base
open Mina_base_test_helpers
open Signature_lib
open Protocol_config_examples
module Ledger = Mina_ledger.Ledger.Ledger_inner
module Transaction_logic = Mina_transaction_logic.Make (Ledger)

module Zk_cmd_result = struct
  type t =
    Mina_transaction_logic.Transaction_applied.Zkapp_command_applied.t
    * Ledger.t

  let sexp_of_t (txn, _) =
    Mina_transaction_logic.Transaction_applied.Zkapp_command_applied.Stable
    .Latest
    .sexp_of_t
      (Mina_transaction_logic.Transaction_applied.Zkapp_command_applied
       .read_all_proofs_from_disk txn )
end

(** Wrap an arbitrary signed-command body in a [Mina_transaction.Transaction.t].
    Fee payer is [sender]; the signer defaults to [sender] but can be overridden
    via [?signer] to test fee-payer/signer mismatches. *)
let signed_command
    ?(valid_until = Mina_numbers.Global_slot_since_genesis.max_value) ?signer
    ~(sender : Test_account.t) ~fee body =
  let open Mina_transaction.Transaction in
  let signer_pk =
    Option.value_map ~f:Test_account.public_key signer ~default:sender.pk
    |> Public_key.decompress_exn
  in
  Command
    (User_command.Signed_command
       Signed_command.Poly.
         { payload =
             Signed_command_payload.Poly.
               { body
               ; common =
                   (let open Signed_command.Payload.Common.Poly in
                   { fee
                   ; fee_payer_pk = sender.pk
                   ; nonce = sender.nonce
                   ; valid_until
                   ; memo = Signed_command_memo.dummy
                   })
               }
         ; signer = signer_pk
         ; signature = Signature.dummy
         } )

let payment_body ~(receiver : Test_account.t) ~amount =
  Signed_command_payload.Body.Payment { receiver_pk = receiver.pk; amount }

let delegation_body ~new_delegate =
  Signed_command_payload.Body.(Stake_delegation (Set_delegate { new_delegate }))

(** Look up an account on the default token by compressed public key.
    Panics if the account isn't in the ledger. *)
let get_account_exn ledger pk =
  let account_id = Account_id.create pk Token_id.default in
  Ledger.location_of_account ledger account_id
  |> Option.bind ~f:(Ledger.get ledger)
  |> Option.value_exn

(** Overwrite the [delegate] field of an existing account on the default
    token. Panics if the account isn't in the ledger. *)
let set_delegate ledger pk new_delegate =
  let acc_id = Account_id.create pk Token_id.default in
  let location = Option.value_exn (Ledger.location_of_account ledger acc_id) in
  let account = Option.value_exn (Ledger.get ledger location) in
  Ledger.set ledger location { account with delegate = new_delegate }

(** Overwrite the [permissions] field of an existing account on the default
    token. Panics if the account isn't in the ledger. *)
let set_permissions ledger pk new_permissions =
  let acc_id = Account_id.create pk Token_id.default in
  let location = Option.value_exn (Ledger.location_of_account ledger acc_id) in
  let account = Option.value_exn (Ledger.get ledger location) in
  Ledger.set ledger location { account with permissions = new_permissions }

(** Apply a single transaction to [ledger] and discard the result. Panics on
    error. Defaults [global_slot] and [txn_state_view] to the values from
    [Protocol_config_examples]. *)
let apply_txn_exn
    ?(global_slot = Mina_numbers.Global_slot_since_genesis.of_int 120)
    ?(txn_state_view = protocol_state) ledger txn =
  Transaction_logic.apply_transactions ~signature_kind ~constraint_constants
    ~global_slot ~txn_state_view ledger [ txn ]
  |> Or_error.ok_exn
  |> (ignore : Mina_transaction_logic.Transaction_applied.t list -> unit)
