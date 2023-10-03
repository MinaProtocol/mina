open Pickles_types

let default =
  let one = 1 in
  { Plonk_types.Messages.Poly.w =
      Vector.init Plonk_types.Columns.n ~f:(fun _ -> one)
  ; z = one
  ; t = 7
  }
