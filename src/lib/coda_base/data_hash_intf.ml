[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick
open Snark_bits

[%%else]

open Snark_params_nonconsensus
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

module type Basic = sig
  type t = Field.t [@@deriving sexp, yojson]

  val to_decimal_string : t -> string

  val to_bytes : t -> string

  [%%ifdef consensus_mechanism]

  val gen : t Quickcheck.Generator.t

  type var

  val var_of_hash_unpacked : Pedersen.Checked.Digest.Unpacked.var -> var

  val var_to_hash_packed : var -> Pedersen.Checked.Digest.var

  val var_to_input : var -> (Field.Var.t, Boolean.var) Random_oracle.Input.t

  val var_to_bits : var -> (Boolean.var list, _) Checked.t

  val typ : (vaor, t) Typ.t

  val assert_equal : var -> var -> (unit, _) Checked.t

  val equal_var : var -> var -> (Boolean.var, _) Checked.t

  val var_of_t : t -> var

  (* TODO : define bit ops using Random_oracle instead of Pedersen.Digest,
     move this outside of consensus_mechanism guard
  *)
  include Bits_intf.S with type t := t

  [%%endif]

  val to_input : t -> (Field.t, bool) Random_oracle.Input.t
end

module type Full_size = sig
  include Basic

  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = Field.t [@@deriving sexp, compare, hash, yojson]

      include Comparable.S with type t := t

      include Hashable_binable with type t := t
    end
  end]

  include Comparable.S with type t := t

  include Hashable with type t := t

  [%%ifdef consensus_mechanism]

  val if_ : Boolean.var -> then_:var -> else_:var -> (var, _) Checked.t

  val var_of_hash_packed : Pedersen.Checked.Digest.var -> var

  [%%endif]

  val of_hash : Field.t -> t
end
