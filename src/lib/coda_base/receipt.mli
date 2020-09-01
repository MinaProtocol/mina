(* receipt.mli *)

[%%import "/src/config.mlh"]

open Core_kernel

[%%ifdef consensus_mechanism]

open Snark_params.Tick

[%%else]

open Snark_params_nonconsensus

[%%endif]

module Chain_hash : sig
  include Data_hash.Full_size

  include Codable.S with type t := t

  val to_string : t -> string

  val of_string : string -> t

  val empty : t

  val cons : User_command.Payload.t -> t -> t

  [%%ifdef consensus_mechanism]

  val gen : t Quickcheck.Generator.t

  module Checked : sig
    val constant : t -> var

    type t = var

    val if_ : Boolean.var -> then_:t -> else_:t -> (t, _) Checked.t

    val cons : payload:Transaction_union_payload.var -> t -> (t, _) Checked.t
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
