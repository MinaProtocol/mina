open Core_kernel

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t [@@deriving sexp, compare, hash]
  end
end]

type t = Stable.Latest.t [@@deriving sexp, compare, hash, yojson]

val of_base58_check : string -> t Or_error.t

val of_base58_check_exn : string -> t

val to_base58_check : t -> string

val hash_command : Command_transaction.t -> t

val hash_fee_transfer : Fee_transfer.Single.t -> t

val hash_coinbase : Coinbase.t -> t

include Comparable.S with type t := t

module Command_transaction_with_valid_signature : sig
  type hash = t [@@deriving sexp, compare, hash, yojson]

  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      type t =
        private
        (Command_transaction.Valid.Stable.V1.t, hash) With_hash.Stable.V1.t
      [@@deriving sexp, compare, hash, to_yojson]
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, compare, to_yojson]

  val create : Command_transaction.Valid.t -> t

  val data : t -> Command_transaction.Valid.t

  val command : t -> Command_transaction.t

  val hash : t -> hash

  val forget_check : t -> (Command_transaction.t, hash) With_hash.t

  include Comparable.S with type t := t
end

module Command_transaction : sig
  type hash = t [@@deriving sexp, compare, hash, yojson]

  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      type t =
        private
        (Command_transaction.Stable.V1.t, hash) With_hash.Stable.V1.t
      [@@deriving sexp, compare, hash, to_yojson]
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, compare, to_yojson]

  val create : Command_transaction.t -> t

  val data : t -> Command_transaction.t

  val command : t -> Command_transaction.t

  val hash : t -> hash

  include Comparable.S with type t := t
end
