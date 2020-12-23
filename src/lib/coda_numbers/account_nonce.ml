module T = Nat.Make32 ()

include T

(* OCaml int is 63-bits, so codings are lossless *)
include Codable.Make_of_int (T)
