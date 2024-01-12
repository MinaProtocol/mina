open Core_kernel
open Mina_base

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t [@@deriving sexp, compare, hash, equal]
  end
end]

type t = Stable.Latest.t [@@deriving sexp, compare, hash, yojson, equal]

val digest_string : ?off:int -> ?len:int -> string -> t

val of_base58_check : string -> t Or_error.t

val of_base58_check_exn : string -> t

val to_base58_check : t -> string

(* original mainnet transaction hashes *)
val to_base58_check_v1 : t -> string

val of_base58_check_v1 : string -> t Or_error.t

val of_base58_check_exn_v1 : string -> t

val hash_signed_command : Signed_command.t -> t

val hash_signed_command_v1 : Signed_command.Stable.V1.t -> t

val hash_command : User_command.t -> t

val hash_fee_transfer : Fee_transfer.Single.t -> t

val hash_coinbase : Coinbase.t -> t

(** the input string can be either a Base58Check encoding of a
    Signed command.Stable.V1.t instance, or, the Base64 encoding
    of a later version of a signed command or
    any version of a zkApp command
*)
val hash_of_transaction_id : string -> t Or_error.t

include Comparable.S with type t := t

module User_command_with_valid_signature : sig
  type hash = t [@@deriving sexp, compare, hash, yojson]

  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V2 : sig
      type t =
        private
        (User_command.Valid.Stable.V2.t, hash) With_hash.Stable.V1.t
      [@@deriving sexp, compare, hash, to_yojson]
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, compare, to_yojson]

  val create : User_command.Valid.t -> t

  val data : t -> User_command.Valid.t

  val command : t -> User_command.t

  val hash : t -> hash

  val forget_check : t -> (User_command.t, hash) With_hash.t

  include Comparable.S with type t := t

  val make : User_command.Valid.t -> hash -> t
end

module User_command : sig
  type hash = t [@@deriving sexp, compare, hash, yojson]

  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V2 : sig
      type t = private (User_command.Stable.V2.t, hash) With_hash.Stable.V1.t
      [@@deriving sexp, compare, hash, to_yojson]
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, compare, to_yojson]

  val create : User_command.t -> t

  val data : t -> User_command.t

  val command : t -> User_command.t

  val hash : t -> hash

  include Comparable.S with type t := t

  val of_checked : User_command_with_valid_signature.t -> t
end
