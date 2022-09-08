open Core_kernel
open Pickles_types
open Import
open Plonk_types

(* Specifies the number of group elements in each message in the protocol, which
   are polynomials committed to as "split commitments". I.e., we fix an SRS length N,
   and then a polynomial of degree d is committed to by chunking it up into ceil(d / N)
   polynomials of degree N, and committing to each individually.

   All commitments have length 1, except the quotient polynomial commitment
   which has length 7. *)
let create (type a) ~(of_int : int -> a) :
    (a Columns_vec.t, a, a) Messages.Poly.t =
  let one = of_int 1 in
  { w = Vector.init Plonk_types.Columns.n ~f:(fun _ -> one)
  ; z = one
  ; t = of_int 7
  }
