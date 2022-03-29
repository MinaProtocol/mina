open Core_kernel
open Pickles_types
open Import
open Plonk_types

let create (type a) ~(of_int : int -> a) : a Plonk_types.Evals.t =
  let one = of_int 1 in
  { w = Vector.init Columns.n ~f:(fun _ -> one)
  ; z = one
  ; s = Vector.init Permuts_minus_1.n ~f:(fun _ -> one)
  ; generic_selector = one
  ; poseidon_selector = one
  }
