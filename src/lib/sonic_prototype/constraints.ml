open Snarkette
open Snarkette.Mnt6_80
open Arithmetic_circuit
open Laurent
open Utils
module Fq_target = Fq6
module Fr = Snarkette.Mnt4_80.Fq
module Fr_laurent = Make_laurent (N) (Fr)
module Bivariate_Fr_laurent = Make_laurent (N) (Fr_laurent)

(* helper functions *)
let reverse = List.fold_left (fun list x -> x :: list) []

let rec zip f x y =
  match (x, y) with
  | [], _ | _, [] ->
      []
  | x0 :: xs, y0 :: ys ->
      f x0 y0 :: zip f xs ys

let compress_mul_constraints (assignment : Assignment.t) y =
  let rec accum aL aR aO y i =
    match (aL, aR, aO) with
    | [], _, _ | _, [], _ | _, _, [] ->
        Fr.zero
    | aLHd :: aLTl, aRHd :: aRTl, aOHd :: aOTl ->
        Fr.( + )
          (Fr.( * )
             (Fr.( - ) (Fr.( * ) aLHd aRHd) aOHd)
             (Fr.( + )
                (Fr.( ** ) y (Nat.of_int i))
                (Fr.( ** ) y (Nat.of_int (-i)))))
          (accum aLTl aRTl aOTl y (i + 1))
  in
  accum assignment.aL assignment.aR assignment.aO y 0

let r_poly (assignment : Assignment.t) =
  let n = List.length assignment.aL in
  let f ai bi ci i =
    [ Fr_laurent.create i [ai]
    ; Fr_laurent.create (-i) [bi]
    ; Fr_laurent.create (-i - n) [ci] ]
  in
  let rec process aL aR aO i =
    match (aL, aR, aO) with
    | [], _, _ | _, [], _ | _, _, [] ->
        []
    | aLHd :: aLTl, aRHd :: aRTl, aOHd :: aOTl ->
        List.concat [f aLHd aRHd aOHd i; process aLTl aRTl aOTl (i + 1)]
  in
  let processed = process assignment.aL assignment.aR assignment.aO 1 in
  let reorder =
    List.sort (fun l1 l2 -> Fr_laurent.deg l1 - Fr_laurent.deg l2)
  in
  Bivariate_Fr_laurent.create (-2 * n)
    (reorder (Fr_laurent.create 0 [] :: processed))

(* bivariate polynomial; X deg = Y deg, so we just sort Y polys as coeffs of X polys *)

let s_poly (gate_weights : Gate_weights.t) =
  let wL, wR, wO = (gate_weights.wL, gate_weights.wR, gate_weights.wO) in
  let n = List.length (List.hd wL) in
  let f wi _i = Fr_laurent.create (n + 1) wi in
  let rec ff wis i =
    match wis with [] -> [] | wi :: wiss -> f wi i :: ff wiss (i + 1)
  in
  let g wi i =
    Fr_laurent.( + )
      (Fr_laurent.( + )
         (Fr_laurent.create i [Fr.of_string "-1"])
         (Fr_laurent.create (-i) [Fr.of_string "-1"]))
      (Fr_laurent.create (n + 1) wi)
  in
  let rec gg wis i =
    match wis with [] -> [] | wi :: wiss -> g wi i :: gg wiss (i + 1)
  in
  Bivariate_Fr_laurent.( + )
    (Bivariate_Fr_laurent.( + )
       (Bivariate_Fr_laurent.create (-n) (ff (reverse wL) 1))
       (Bivariate_Fr_laurent.create 1 (ff wR 1)))
    (Bivariate_Fr_laurent.create (n + 1) (gg wO 1))

let t_poly rP sP kP =
  Bivariate_Fr_laurent.( + )
    (Bivariate_Fr_laurent.( * )
       (convert_to_two_variate_X (eval_on_Y Fr.one rP))
       (Bivariate_Fr_laurent.( + ) rP sP))
    (convert_to_two_variate_Y (Fr_laurent.negate kP))

let k_poly k n = Fr_laurent.create (n + 1) k
