open Core_kernel

module type S = sig
  type t

  val ( + ) : t -> t -> t

  val ( - ) : t -> t -> t

  val ( * ) : t -> t -> t

  val ( / ) : t -> t -> t

  val t_of_sexp : Sexp.t -> t

  val of_int : int -> t

  val one : t

  val zero : t

  val negate : t -> t
end

module type S_unchecked = sig
  include S

  val sqrt : t -> t

  val equal : t -> t -> bool

  val is_square : t -> bool

  val sexp_of_t : t -> Sexp.t
end
