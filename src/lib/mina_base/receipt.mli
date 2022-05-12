(* receipt.mli *)

[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params.Tick

module Elt : sig
  type t =
    | Signed_command of Signed_command.Payload.t
    | Parties of Random_oracle.Digest.t
end

module Chain_hash : sig
  include Data_hash.Full_size

  include Codable.S with type t := t

  val to_base58_check : t -> string

  val of_base58_check : string -> t Or_error.t

  val empty : t

  val cons : Elt.t -> t -> t

  [%%ifdef consensus_mechanism]

  val gen : t Quickcheck.Generator.t

  module Checked : sig
    module Elt : sig
      type t =
        | Signed_command of Transaction_union_payload.var
        | Parties of Random_oracle.Checked.Digest.t
    end

    val constant : t -> var

    type t = var

    val if_ : Boolean.var -> then_:t -> else_:t -> t Checked.t

    val cons : Elt.t -> t -> t Checked.t
  end

  [%%endif]

  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      type t = Field.t [@@deriving sexp, compare, hash, yojson]

      val to_latest : t -> t

      include Comparable.S with type t := t

      include Hashable_binable with type t := t
    end
  end]
end
