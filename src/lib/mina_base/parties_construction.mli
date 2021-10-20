open Snapp_basic
open Mina_numbers
open Currency
open Signature_lib

module Partial_party : sig
  module Call_data : sig
    type t =
      | Opaque of F.t
      | Structured of { input : F.t array option; output : F.t array option }

    val to_field : t -> F.t

    val opt_to_field : t option -> F.t
  end

  type t

  val set_pk : Public_key.Compressed.t -> t -> t

  val set_token_id : Token_id.t -> t -> t

  val set_delta : Amount.Signed.t -> t -> t

  val emit_event : F.t array -> t -> t

  val emit_rollup_event : F.t array -> t -> t

  val set_opaque_call_data : F.t -> t -> t

  val set_input_call_data : F.t array -> t -> t

  val set_output_call_data : F.t array -> t -> t

  val update_app_state : F.t Snapp_state.V.t -> t -> t

  val update_app_state_partial : F.t option Snapp_state.V.t -> t -> t

  val update_app_state_i : int -> F.t -> t -> t

  val update_delegate : Public_key.Compressed.t -> t -> t

  val update_verification_key :
    (Pickles.Side_loaded.Verification_key.t, F.t) With_hash.t -> t -> t

  val update_permissions : Permissions.t -> t -> t

  val update_snapp_uri : string -> t -> t

  val update_token_symbol : string -> t -> t

  val expect_balance : Balance.t -> t -> t

  val expect_balance_between : min:Balance.t -> max:Balance.t -> t -> t

  val expect_nonce : Account_nonce.t -> t -> t

  val expect_nonce_between :
    min:Account_nonce.t -> max:Account_nonce.t -> t -> t

  val expect_receipt_chain_hash : Receipt.Chain_hash.t -> t -> t

  val expect_public_key : Public_key.Compressed.t -> t -> t

  val expect_delegate : Public_key.Compressed.t -> t -> t

  val expect_app_state : F.t Snapp_state.V.t -> t -> t

  val expect_app_state_partial : F.t option Snapp_state.V.t -> t -> t

  val expect_app_state_i : int -> F.t -> t -> t

  val expect_rollup_state : F.t -> t -> t

  val expect_proved_state : bool -> t -> t

  val init : ?pk:Public_key.Compressed.t -> ?token_id:Token_id.t -> unit -> t
end

type t

val set_pk : Public_key.Compressed.t -> t -> t

val set_token_id : Token_id.t -> t -> t

val set_delta : Amount.Signed.t -> t -> t

val emit_event : F.t array -> t -> t

val emit_rollup_event : F.t array -> t -> t

val set_opaque_call_data : F.t -> t -> t

val set_input_call_data : F.t array -> t -> t

val set_output_call_data : F.t array -> t -> t

val update_app_state : F.t Snapp_state.V.t -> t -> t

val update_app_state_partial : F.t option Snapp_state.V.t -> t -> t

val update_app_state_i : int -> F.t -> t -> t

val update_delegate : Public_key.Compressed.t -> t -> t

val update_verification_key :
  (Pickles.Side_loaded.Verification_key.t, F.t) With_hash.t -> t -> t

val update_permissions : Permissions.t -> t -> t

val update_snapp_uri : string -> t -> t

val update_token_symbol : string -> t -> t

val expect_balance : Balance.t -> t -> t

val expect_balance_between : min:Balance.t -> max:Balance.t -> t -> t

val expect_nonce : Account_nonce.t -> t -> t

val expect_nonce_between : min:Account_nonce.t -> max:Account_nonce.t -> t -> t

val expect_receipt_chain_hash : Receipt.Chain_hash.t -> t -> t

val expect_public_key : Public_key.Compressed.t -> t -> t

val expect_delegate : Public_key.Compressed.t -> t -> t

val expect_app_state : F.t Snapp_state.V.t -> t -> t

val expect_app_state_partial : F.t option Snapp_state.V.t -> t -> t

val expect_app_state_i : int -> F.t -> t -> t

val expect_rollup_state : F.t -> t -> t

val expect_proved_state : bool -> t -> t

val init : ?partial_party:Partial_party.t -> unit -> t

val finish :
     ?control:Control.t
  -> t
  -> (Party.t, Party.Digest.t) Parties.Party_or_stack.t
     * Partial_party.Call_data.t option
