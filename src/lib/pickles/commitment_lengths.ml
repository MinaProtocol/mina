open Pickles_types
open Plonk_types

(* Do not export this function unless you have very good reasons.
   [t] is unused at this point but this function is future-ready.
*)
let create_unsafe ?(t = 7) length =
  { Messages.Poly.w = Vector.init Plonk_types.Columns.n ~f:(fun _ -> length)
  ; z = length
  ; t
  }

let of_length length =
  if length <= 0 then invalid_arg "of_length: length must be > 0" ;
  create_unsafe length

let one = create_unsafe 1
