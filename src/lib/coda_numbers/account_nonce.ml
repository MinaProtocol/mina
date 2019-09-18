module T = Nat.Make32 ()

include T

let to_bits = Bits.to_bits

(* Needs to be string not int since we use unsigned uint32 *)
include Codable.Make_of_string (T)
