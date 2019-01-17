module type S = sig
  type t [@@deriving sexp, bin_io]

  val of_int : int -> t

  val one : t

  val zero : t

  val add : t -> t -> t

  val sub : t -> t -> t

  val mul : t -> t -> t

  val inv : t -> t

  val square : t -> t

  val sqrt : t -> t

  val is_square : t -> bool

  val equal : t -> t -> bool

  val size_in_bits : int

  val print : t -> unit

  val random : unit -> t

  module Vector : Vector.S with type elt = t
end

module type Extended = sig
  include S

  val negate : t -> t

  module Infix : sig
    val ( + ) : t -> t -> t

    val ( * ) : t -> t -> t

    val ( - ) : t -> t -> t

    val ( / ) : t -> t -> t
  end
end
