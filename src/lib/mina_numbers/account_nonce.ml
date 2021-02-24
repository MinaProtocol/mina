module T = Nat.Make32 ()

include T

(* while we could use an int encoding for yojson (an OCaml int is 63-bits)
   we've committed to a string encoding
*)
include Codable.Make_of_string (T)
