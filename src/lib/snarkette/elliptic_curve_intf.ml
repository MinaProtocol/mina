module type S = sig
  type field

  type t

  module Coefficients : sig
    val a : field

    val b : field
  end

  val ( + ) : t -> t -> t

  val to_affine_coordinates : t -> field * field
end
