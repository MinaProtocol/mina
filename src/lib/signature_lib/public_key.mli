[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params
open Tick

[%%versioned:
module Stable : sig
  module V1 : sig
    [@@@with_all_version_tags]

    type t = Field.t * Field.t [@@deriving sexp, hash, compare, yojson]
  end
end]

include Comparable.S_binable with type t := t

[%%ifdef consensus_mechanism]

type var = Field.Var.t * Field.Var.t

val typ : (var, t) Typ.t

val var_of_t : t -> var

val assert_equal : var -> var -> unit Checked.t

[%%endif]

val of_private_key_exn : Private_key.t -> t

module Compressed : sig
  module Poly : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type ('field, 'boolean) t =
              ('field, 'boolean) Mina_wire_types.Public_key.Compressed.Poly.V1.t =
          { x : 'field; is_odd : 'boolean }
      end
    end]
  end

  [%%versioned:
  module Stable : sig
    module V1 : sig
      [@@@with_all_version_tags]

      type t = (Field.t, bool) Poly.t [@@deriving sexp, equal, compare, hash]

      include Codable.S with type t := t

      include Hashable.S_binable with type t := t
    end
  end]

  include Codable.S with type t := t

  val gen : t Quickcheck.Generator.t

  val empty : t

  include Comparable.S with type t := t

  include Hashable.S_binable with type t := t

  val to_input_legacy : t -> (Field.t, bool) Random_oracle.Input.Legacy.t

  val to_input : t -> Field.t Random_oracle.Input.Chunked.t

  val to_string : t -> string

  val to_base58_check : t -> string

  val of_base58_check_exn : string -> t

  val of_base58_check : string -> t Or_error.t

  [%%ifdef consensus_mechanism]

  type var = (Field.Var.t, Boolean.var) Poly.t

  val typ : (var, t) Typ.t

  val var_of_t : t -> var

  module Checked : sig
    val equal : var -> var -> Boolean.var Checked.t

    val to_input_legacy :
      var -> (Field.Var.t, Boolean.var) Random_oracle.Input.Legacy.t

    val to_input : var -> Field.Var.t Random_oracle.Input.Chunked.t

    val if_ : Boolean.var -> then_:var -> else_:var -> var Checked.t

    module Assert : sig
      val equal : var -> var -> unit Checked.t
    end
  end

  [%%endif]
end

val gen : t Quickcheck.Generator.t

val of_bigstring : Bigstring.t -> t Or_error.t

val to_bigstring : t -> Bigstring.t

val compress : t -> Compressed.t

val decompress : Compressed.t -> t option

val decompress_exn : Compressed.t -> t

(** Same as [Compressed.of_base58_check_exn] except that [of_base58_check_decompress_exn] fails if [decompress_exn] fails *)
val of_base58_check_decompress_exn : string -> Compressed.t

[%%ifdef consensus_mechanism]

val compress_var : var -> Compressed.var Checked.t

val decompress_var : Compressed.var -> var Checked.t

[%%endif]
