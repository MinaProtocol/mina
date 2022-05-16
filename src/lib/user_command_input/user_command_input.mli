open Mina_base
open Signature_lib
open Mina_numbers
open Core_kernel
open Async_kernel

(*FIX: #4597*)
module Payload : sig
  module Common : sig
    [%%versioned:
    module Stable : sig
      module V2 : sig
        type t [@@deriving sexp, to_yojson]
      end
    end]

    val fee_payer : t -> Account_id.t
  end

  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t [@@deriving sexp, to_yojson]
    end
  end]

  val fee_payer : t -> Account_id.t
end

module Sign_choice : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t =
        | Signature of Signature.Stable.V1.t
        | Hd_index of Unsigned_extended.UInt32.Stable.V1.t
        | Keypair of Keypair.Stable.V1.t
      [@@deriving sexp, to_yojson]
    end
  end]
end

[%%versioned:
module Stable : sig
  module V2 : sig
    type t =
      ( Payload.Stable.V2.t
      , Public_key.Compressed.Stable.V1.t
      , Sign_choice.Stable.V1.t )
      Signed_command.Poly.Stable.V1.t
    [@@deriving sexp, to_yojson]
  end
end]

val fee_payer : t -> Account_id.t

val create :
     ?nonce:Account.Nonce.t
  -> fee:Currency.Fee.t
  -> fee_payer_pk:Public_key.Compressed.t
  -> valid_until:Global_slot.t option
  -> memo:Signed_command_memo.t
  -> body:Signed_command_payload.Body.t
  -> signer:Public_key.Compressed.t
  -> sign_choice:Sign_choice.t
  -> unit
  -> t

val to_user_command :
     ?nonce_map:(Account.Nonce.t * Account.Nonce.t) Account_id.Map.t
  -> get_current_nonce:
       (   Account_id.t
        -> ([ `Min of Account_nonce.t ] * Account_nonce.t, string) Result.t )
  -> get_account:(Account_id.t -> Account.t option Participating_state.T.t)
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> logger:Logger.t
  -> t
  -> (Signed_command.t * (Account.Nonce.t * Account.Nonce.t) Account_id.Map.t)
     Deferred.Or_error.t

val to_user_commands :
     ?nonce_map:(Account.Nonce.t * Account.Nonce.t) Account_id.Map.t
  -> get_current_nonce:
       (   Account_id.t
        -> ([ `Min of Account_nonce.t ] * Account_nonce.t, string) Result.t )
  -> get_account:(Account_id.t -> Account.t option Participating_state.T.t)
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> logger:Logger.t
  -> t list
  -> Signed_command.t list Deferred.Or_error.t
