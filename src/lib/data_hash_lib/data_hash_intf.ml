[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params.Tick

[%%ifdef consensus_mechanism]

open Snark_bits

[%%endif]

module type Data_hash_descriptor = sig
  val version_byte : char

  val description : string
end

module type Basic = sig
  type t = Field.t [@@deriving sexp, yojson]

  val to_decimal_string : t -> string

  val of_decimal_string : string -> t

  val to_bytes : t -> string

  [%%ifdef consensus_mechanism]

  val gen : t Quickcheck.Generator.t

  type var

  val var_to_hash_packed : var -> Random_oracle.Checked.Digest.t

  val var_to_input : var -> Field.Var.t Random_oracle.Input.Chunked.t

  val var_to_bits : var -> Boolean.var list Checked.t

  val typ : (var, t) Typ.t

  val assert_equal : var -> var -> unit Checked.t

  val equal_var : var -> var -> Boolean.var Checked.t

  val var_of_t : t -> var

  (* TODO : define bit ops using Random_oracle instead of Pedersen.Digest,
     move this outside of consensus_mechanism guard
  *)
  include Bits_intf.S with type t := t

  [%%endif]

  val to_base58_check : t -> string

  val of_base58_check : string -> t Base.Or_error.t

  val of_base58_check_exn : string -> t

  val to_input : t -> Field.t Random_oracle.Input.Chunked.t
end

module type Full_size = sig
  include Basic

  include Comparable.S with type t := t

  include Hashable with type t := t

  [%%ifdef consensus_mechanism]

  val if_ : Boolean.var -> then_:var -> else_:var -> var Checked.t

  val var_of_hash_packed : Random_oracle.Checked.Digest.t -> var

  val var_to_field : var -> Random_oracle.Checked.Digest.t

  [%%endif]

  val of_hash : Field.t -> t

  val to_field : t -> Field.t
end
