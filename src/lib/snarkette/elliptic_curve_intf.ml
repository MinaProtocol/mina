module type S = sig
  type field

  type t

  module Coefficients : sig
    val a : field

    val b : field
  end

  module Affine : sig
    type t = field * field
  end

  val ( + ) : t -> t -> t

  val to_affine_exn : t -> field * field

  val to_affine : t -> (field * field) option
end
