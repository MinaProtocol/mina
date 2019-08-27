include Nat.S

val to_uint32 : t -> Unsigned.uint32

val of_uint32 : Unsigned.uint32 -> t

include Codable.S with type t := t
