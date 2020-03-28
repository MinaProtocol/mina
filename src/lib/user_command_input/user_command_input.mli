open Coda_base
open Signature_lib
open Coda_numbers
open Core_kernel
open Async_kernel

(*FIX: #4597*)
module Payload : sig
  module Common : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type t [@@deriving sexp, to_yojson]
      end
    end]

    type t = Stable.Latest.t [@@deriving sexp, to_yojson]
  end

  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t [@@deriving sexp, to_yojson]
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, to_yojson]
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

  type t = Stable.Latest.t =
    | Signature of Signature.t
    | Hd_index of Unsigned_extended.UInt32.t
    | Keypair of Keypair.t
  [@@deriving sexp, to_yojson]
end

[%%versioned:
module Stable : sig
  module V1 : sig
    type t =
      ( Payload.Stable.V1.t
      , Public_key.Compressed.Stable.V1.t
      , Sign_choice.Stable.V1.t )
      User_command.Poly.Stable.V1.t
    [@@deriving sexp, to_yojson]
  end
end]

type t = Stable.Latest.t [@@deriving sexp, to_yojson]

val create :
     ?nonce_opt:Account.Nonce.t option
  -> fee:Currency.Fee.t
  -> valid_until:Global_slot.t
  -> memo:User_command_memo.t
  -> body:User_command_payload.Body.t
  -> sender:Public_key.Compressed.t
  -> sign_choice:Sign_choice.t
  -> unit
  -> t

val to_user_command :
     result_cb:('a Or_error.t -> unit)
  -> inferred_nonce:(   Public_key.Compressed.t
                     -> Account_nonce.t option Participating_state.t)
  -> logger:Logger.t
  -> t list
  -> (User_command.t list * ('a Or_error.t -> unit)) option Deferred.t
