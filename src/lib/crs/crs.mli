type t = unit -> bool

val ith_bit : string -> int -> bool

val digest_length_in_bits : int

module State : sig
  type t = { digest : string; i : int; j : int }

  val update : seed:string -> t -> bool * t

  val init : seed:String.t -> t
end

val create : seed:String.t -> t
