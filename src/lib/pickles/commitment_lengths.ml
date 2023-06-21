open Pickles_types
open Plonk_types

let create ~num_chunks =
  { Messages.Poly.w = Vector.init Plonk_types.Columns.n ~f:(fun _ -> num_chunks)
  ; z = num_chunks
  ; t = 7 * num_chunks
  }
