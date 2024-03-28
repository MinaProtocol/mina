(* receipt.mli *)

[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params.Tick

module Signed_command_elt : sig
  type t = Signed_command_payload of Signed_command.Payload.t
end

module Zkapp_command_elt : sig
  type t = Zkapp_command_commitment of Random_oracle.Digest.t
end

module Chain_hash : sig
  include Data_hash.Full_size

  include Codable.S with type t := t

  val to_base58_check : t -> string

  val of_base58_check : string -> t Or_error.t

  val equal : t -> t -> bool

  val empty : t

  val cons_signed_command_payload : Signed_command_elt.t -> t -> t

  val cons_zkapp_command_commitment :
    Mina_numbers.Index.t -> Zkapp_command_elt.t -> t -> t

  [%%ifdef consensus_mechanism]

  val gen : t Quickcheck.Generator.t

  module Checked : sig
    module Signed_command_elt : sig
      type t = Signed_command_payload of Transaction_union_payload.var
    end

    module Zkapp_command_elt : sig
      type t = Zkapp_command_commitment of Random_oracle.Checked.Digest.t
    end

    val constant : t -> var

    type t = var

    val equal : t -> t -> Boolean.var Checked.t

    val if_ : Boolean.var -> then_:t -> else_:t -> t Checked.t

    val cons_signed_command_payload : Signed_command_elt.t -> t -> t Checked.t

    val cons_zkapp_command_commitment :
      Mina_numbers.Index.Checked.t -> Zkapp_command_elt.t -> t -> t Checked.t
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
