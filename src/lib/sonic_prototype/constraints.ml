open Snarkette
open Arithmetic_circuit
open Utils
open Default_backend.Backend

let rec zip f x y =
  match (x, y) with
  | [], _ | _, [] ->
      []
  | x0 :: xs, y0 :: ys ->
      f x0 y0 :: zip f xs ys

let compress_mul_constraints (assignment : Assignment.t) y =
  let rec accum a_l a_r a_o y i =
    match (a_l, a_r, a_o) with
    | [], _, _ | _, [], _ | _, _, [] ->
        Fr.zero
    | a_lHd :: a_lTl, a_rHd :: a_rTl, a_oHd :: a_oTl ->
        Fr.( + )
          (Fr.( * )
             (Fr.( - ) (Fr.( * ) a_lHd a_rHd) a_oHd)
             (Fr.( + )
                (Fr.( ** ) y (Nat.of_int i))
                (Fr.( ** ) y (Nat.of_int (-i)))))
          (accum a_lTl a_rTl a_oTl y (i + 1))
  in
  accum assignment.a_l assignment.a_r assignment.a_o y 0

let r_poly (assignment : Assignment.t) =
  let n = List.length assignment.a_l in
  let f ai bi ci i =
    [ Fr_laurent.create i [ai]
    ; Fr_laurent.create (-i) [bi]
    ; Fr_laurent.create (-i - n) [ci] ]
  in
  let rec process a_l a_r a_o i =
    match (a_l, a_r, a_o) with
    | [], _, _ | _, [], _ | _, _, [] ->
        []
    | a_lHd :: a_lTl, a_rHd :: a_rTl, a_oHd :: a_oTl ->
        List.concat [f a_lHd a_rHd a_oHd i; process a_lTl a_rTl a_oTl (i + 1)]
  in
  let processed = process assignment.a_l assignment.a_r assignment.a_o 1 in
  let reorder =
    List.sort (fun l1 l2 -> Fr_laurent.deg l1 - Fr_laurent.deg l2)
  in
  Bivariate_fr_laurent.create (-2 * n)
    (reorder (Fr_laurent.create 0 [] :: processed))

(* bivariate polynomial; X deg = Y deg, so we just sort Y polys as coeffs of X polys *)

let s_poly (gate_weights : Gate_weights.t) =
  let w_l, w_r, w_o = (gate_weights.w_l, gate_weights.w_r, gate_weights.w_o) in
  let n = List.length w_l in
  let f wi _i = Fr_laurent.create (n + 1) wi in
  let rec ff wis i =
    match wis with [] -> [] | wi :: wiss -> f wi i :: ff wiss (i + 1)
  in
  let g wi i =
    Fr_laurent.( + )
      (Fr_laurent.( + )
         (Fr_laurent.create i [Fr.of_int (-1)])
         (Fr_laurent.create (-i) [Fr.of_int (-1)]))
      (Fr_laurent.create (n + 1) wi)
  in
  let rec gg wis i =
    match wis with [] -> [] | wi :: wiss -> g wi i :: gg wiss (i + 1)
  in
  Bivariate_fr_laurent.( + )
    (Bivariate_fr_laurent.( + )
       (Bivariate_fr_laurent.create (-n) (ff (reverse w_l) 1))
       (Bivariate_fr_laurent.create 1 (ff w_r 1)))
    (Bivariate_fr_laurent.create (n + 1) (gg w_o 1))

let t_poly r_p s_p k_p =
  Bivariate_fr_laurent.( + )
    (Bivariate_fr_laurent.( * )
       (convert_to_two_variate_X (eval_on_y Fr.one r_p))
       (Bivariate_fr_laurent.( + ) r_p s_p))
    (convert_to_two_variate_Y (Fr_laurent.negate k_p))

let k_poly k n = Fr_laurent.create (n + 1) k
