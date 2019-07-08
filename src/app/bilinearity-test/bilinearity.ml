open Core

(* 
   Check

   e(p, a x + b y) = a e(p, x) + b e(p, y)
*)

open Snarkette.Mnt6753

(* 
   Check

   e(p, x + y) = e(p, x) + e(p, y)
*)
let check_bilinearity (p : G1.t) (x : G2.t) (y : G2.t) =
  Fq6.equal
    (Pairing.reduced_pairing p G2.(x + y))
    Fq6.(Pairing.reduced_pairing p x * Pairing.reduced_pairing p y)

(* TODO:

   - Sample random pts on E2 using sage
   - use G2.of_affine_coordinates and copy/paste in to this file.
   - call this function

   dune exec app/bilinearity-test/bilinearity.exe

   in src directory. *)

let () = G2.one
