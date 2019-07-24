open Core

(* This module implements a snarky function for the gammaless Groth16 verifier. *)
module Make (Inputs : Inputs.S_run) = struct
  open Inputs
  open Impl

  (* imeckler: This is just an example of how to use the functions in Inputs module.

   See the S_run interface in inputs.ml for everything. *)
  let reduced_pairing p q =
    final_exponentiation
      (batch_miller_loop
         [(Pos, G1_precomputation.create p, G2_precomputation.create q)])

  (* Check the pairing equation
   e(a, b) * e(a + d, c) = e(d, b) 

   Or rather check the equivalent equation
   e(a, b) * e(a + d, c) / e(d, b) = 1

   since it's more efficient to do so.
*)
  let check_silly_equation a b c d : Boolean.var =
    (* We use the same precomputation to avoid duplicating work because it's expensive. *)
    let b_precomp = G2_precomputation.create b in
    final_exponentiation
      (batch_miller_loop
         [ (Pos, G1_precomputation.create a, b_precomp)
         ; ( Pos
           , G1_precomputation.create G1.(add_exn a d)
           , G2_precomputation.create c )
         ; (Neg, G1_precomputation.create d, b_precomp) ])
    |> Fqk.(equal one)
end
