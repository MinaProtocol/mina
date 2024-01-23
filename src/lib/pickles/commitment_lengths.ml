open Pickles_types

let default ~num_chunks =
  { Plonk_types.Messages.Poly.w =
      Vector.init Plonk_types.Columns.n ~f:(fun _ -> num_chunks)
  ; z = num_chunks
  ; t = 7 * num_chunks
  }
