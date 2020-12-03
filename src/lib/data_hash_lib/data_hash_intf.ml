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

module type Data_hash_descriptor = sig
  val version_byte : char

  val description : string
end

module type Basic = sig
  type t = Field.t [@@deriving sexp, yojson]

  val to_decimal_string : t -> string

  val to_bytes : t -> string

  [%%ifdef consensus_mechanism]

  val gen : t Quickcheck.Generator.t

  type var

  val var_to_hash_packed : var -> Random_oracle.Checked.Digest.t

  val var_to_input : var -> (Field.Var.t, Boolean.var) Random_oracle.Input.t

  val var_to_bits : var -> (Boolean.var list, _) Checked.t

  val typ : (var, t) Typ.t

  val assert_equal : var -> var -> (unit, _) Checked.t

  val equal_var : var -> var -> (Boolean.var, _) Checked.t

  val var_of_t : t -> var

  (* TODO : define bit ops using Random_oracle instead of Pedersen.Digest,
     move this outside of consensus_mechanism guard
  *)
  include Bits_intf.S with type t := t

  [%%endif]

  val to_string : t -> string

  val of_string : string -> t

  val to_base58_check : t -> string

  val of_base58_check : string -> t Base.Or_error.t

  val of_base58_check_exn : string -> t

  val to_input : t -> (Field.t, bool) Random_oracle.Input.t
end

module type Full_size = sig
  include Basic

  include Comparable.S with type t := t

  include Hashable with type t := t

  [%%ifdef consensus_mechanism]

  val if_ : Boolean.var -> then_:var -> else_:var -> (var, _) Checked.t

  val var_of_hash_packed : Random_oracle.Checked.Digest.t -> var

  [%%endif]

  val of_hash : Field.t -> t
end
