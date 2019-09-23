include Nat.S

val to_uint32 : t -> Unsigned.uint32

val of_uint32 : Unsigned.uint32 -> t

val to_bits : t -> bool list

val of_bits : bool list -> t

include Codable.S with type t := t
