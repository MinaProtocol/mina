open Core_kernel
open Pickles_types
open Import
open Plonk_types

let create (type a) ~uses_lookup ~uses_runtime ~(of_int : int -> a) :
    a Plonk_types.Evals.t =
  let one = of_int 1 in
  { w = Vector.init Columns.n ~f:(fun _ -> one)
  ; z = one
  ; s = Vector.init Permuts_minus_1.n ~f:(fun _ -> one)
  ; generic_selector = one
  ; poseidon_selector = one
  ; lookup_evals =
      ( if uses_lookup then
        Some
          { lookup_sorted = [ one; one; one; one ]
          ; lookup_aggreg = one
          ; lookup_table = one
          ; lookup_runtime_table = (if uses_runtime then one else of_int 0)
          }
      else None )
  }
