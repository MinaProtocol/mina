open Async_kernel
open Mina_transaction

type t

type signed_command_result =
  { id : string
  ; hash : Transaction_hash.t
  ; nonce : Mina_numbers.Account_nonce.t
  }

type metrics_t =
  { block_production_delay : int list
  ; transaction_pool_diff_received : int
  ; transaction_pool_diff_broadcasted : int
  ; transactions_added_to_pool : int
  ; transaction_pool_size : int
  }

type best_chain_block =
  { state_hash : string; command_transaction_count : int; creator_pk : string }

(* val from_string: graphql_target_node: string -> logger:Logger.t  -> t

   val default: uri: Uri.t -> logger:Logger.t  -> t *)

val create :
     logger_metadata:(string * Yojson.Safe.t) list
  -> uri:Uri.t
  -> enabled:bool
  -> logger:Logger.t
  -> t

val graphql_uri : t -> string

val send_payment :
     t
  -> password:string
  -> sender_pub_key:Signature_lib.Public_key.Compressed.t
  -> receiver_pub_key:Signature_lib.Public_key.Compressed.t
  -> amount:Currency.Amount.t
  -> fee:Currency.Fee.t
  -> signed_command_result Deferred.Or_error.t

val send_payment_with_raw_sig :
     t
  -> sender_pub_key:Signature_lib.Public_key.Compressed.t
  -> receiver_pub_key:Signature_lib.Public_key.Compressed.t
  -> amount:Currency.Amount.t
  -> fee:Currency.Fee.t
  -> nonce:Mina_numbers.Account_nonce.t
  -> memo:string
  -> valid_until:Mina_numbers.Global_slot.t
  -> raw_signature:string
  -> signed_command_result Deferred.Or_error.t

val send_test_payments :
     repeat_count:Unsigned.UInt32.t
  -> repeat_delay_ms:Unsigned.UInt32.t
  -> t
  -> senders:Signature_lib.Private_key.t list
  -> receiver_pub_key:Signature_lib.Public_key.Compressed.t
  -> amount:Currency.Amount.t
  -> fee:Currency.Fee.t
  -> unit Deferred.Or_error.t

val send_delegation :
     t
  -> sender_pub_key:Signature_lib.Public_key.Compressed.t
  -> receiver_pub_key:Signature_lib.Public_key.Compressed.t
  -> fee:Currency.Fee.t
  -> signed_command_result Deferred.Or_error.t

val set_snark_worker :
     t
  -> new_snark_pub_key:Signature_lib.Public_key.Compressed.t
  -> unit Deferred.Or_error.t

(** Send a batch of zkApp transactions.
       Returned is a list of transaction id *)
val send_zkapp_batch :
     t
  -> zkapp_commands:Mina_base.Zkapp_command.t list
  -> string list Deferred.Or_error.t

type account_data =
  { nonce : Mina_numbers.Account_nonce.t
  ; total_balance : Currency.Balance.t
  ; liquid_balance_opt : Currency.Balance.t option
  ; locked_balance_opt : Currency.Balance.t option
  }

val get_account_data :
  t -> account_id:Mina_base.Account_id.t -> account_data Deferred.Or_error.t

val get_account_data_by_pk :
  t -> public_key:Signature_lib.Public_key.t -> account_data Deferred.Or_error.t

val get_account_permissions :
     t
  -> account_id:Mina_base.Account_id.t
  -> Mina_base.Permissions.t Deferred.Or_error.t

(** the returned Update.t is constructed from the fields of the
       given account, as if it had been applied to the account
   *)
val get_account_update :
     t
  -> account_id:Mina_base.Account_id.t
  -> Mina_base.Account_update.Update.t Deferred.Or_error.t

val get_pooled_zkapp_commands :
     t
  -> pk:Signature_lib.Public_key.Compressed.t
  -> string list Deferred.Or_error.t

val get_peer_id : t -> (string * string list) Deferred.Or_error.t

val get_best_chain :
  ?max_length:int -> t -> best_chain_block list Deferred.Or_error.t

val get_metrics : t -> metrics_t Deferred.Or_error.t
