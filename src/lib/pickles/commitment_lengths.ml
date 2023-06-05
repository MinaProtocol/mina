open Pickles_types
open Plonk_types

let create (type a) ~num_chunks ~(of_int : int -> a) :
    (a Columns_vec.t, a, a) Messages.Poly.t =
  let one = of_int num_chunks in
  { w = Vector.init Plonk_types.Columns.n ~f:(fun _ -> one)
  ; z = one
  ; t = of_int (7 * num_chunks)
  }
