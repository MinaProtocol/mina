open Core_kernel

module type S = sig
  module Field : sig
    type t [@@deriving sexp, bin_io, compare, hash]

    include Snarky.Field_intf.S with type t := t

    val project : bool list -> t
  end

  module Bigint : Snarky.Bigint_intf.Extended with type field := Field.t

  module Scalar_field : Snarky.Field_intf.Extended

  module rec Curve : sig
    type t [@@deriving sexp, eq]

    val to_affine_coordinates : t -> Field.t * Field.t

    val point_near_x : Field.t -> t

    val zero : t

    val add : t -> t -> t

    val negate : t -> t

    val scale_field : t -> Scalar_field.t -> t

    module Window_table : sig
      type t

      val scale_field : t -> Scalar_field.t -> Curve.t
    end
  end

  val params : Curve.t array

  val window_tables : Curve.Window_table.t array Lazy.t
end
