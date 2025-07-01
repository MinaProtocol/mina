module type T = sig
  type t

  val size_in_bits : int

  val zero : t

  val one : t

  val of_int : int -> t

  val ( * ) : t -> t -> t

  val ( / ) : t -> t -> t

  val ( + ) : t -> t -> t

  val ( - ) : t -> t -> t

  val inv : t -> t

  val negate : t -> t
end
