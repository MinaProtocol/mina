open Pickles_types
open Plonk_types

(* Do not export this function unless you have very good reasons.
   [t] is unused at this point but this function is future-ready.
*)
let create_unsafe ?(t = 7) ?w length =
  (* Set [f] to setting value to [length] by default. *)
  let f =
    let v = match w with None -> length | Some w -> w in
    fun _ -> v
  in
  { Messages.Poly.w = Vector.init Plonk_types.Columns.n ~f; z = length; t }

let of_length length =
  if length <= 0 then invalid_arg "of_length: length must be > 0" ;
  create_unsafe length

let one = create_unsafe ~w:1 1
