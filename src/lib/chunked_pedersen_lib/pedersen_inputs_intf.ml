open Core_kernel

module type S = sig
  module Field : sig
    type t [@@deriving sexp, bin_io, compare, hash, eq]

    include Stringable.S with type t := t

    include Snarky.Field_intf.S with type t := t

    val project : bool list -> t
  end

  module Bigint : Snarky.Bigint_intf.Extended with type field := Field.t

  module Curve : sig
    type t

    val to_affine_coordinates : t -> Field.t * Field.t

    val point_near_x : Field.t -> t

    val zero : t

    val add : t -> t -> t

    val negate : t -> t
  end

  val params : Curve.t Tuple_lib.Quadruple.t array

  val chunk_table : Curve.t array array Lazy.t
end
