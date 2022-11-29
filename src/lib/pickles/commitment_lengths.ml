open Core_kernel
open Pickles_types
open Import
open Plonk_types

let create (type a) ~(of_int : int -> a) :
    (a Columns_vec.t, a, a) Messages.Poly.t =
  let one = of_int 1 in
  { w = Vector.init Plonk_types.Columns.n ~f:(fun _ -> one)
  ; z = one
  ; t = of_int 7
  }
