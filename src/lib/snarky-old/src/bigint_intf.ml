module type S = sig
  type field

  type t

  val of_field : field -> t

  val test_bit : t -> int -> bool
end

module type Extended = sig
  include S

  include Core_kernel.Binable.S with type t := t

  val to_field : t -> field

  val of_decimal_string : string -> t

  val of_numeral : string -> base:int -> t

  val compare : t -> t -> int
end
