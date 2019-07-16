open Core
open Srs
open Helped_signature
open Utils
open Commitment_scheme
open Constraints
open Arithmetic_circuit
open Default_backend.Backend

module Proof = struct
  type t =
    { pr_r: G1.t
    ; pr_t: G1.t
    ; pr_a: Fr.t
    ; pr_wa: G1.t
    ; pr_b: Fr.t
    ; pr_wb: G1.t
    ; pr_wt: G1.t
    ; pr_s: Fr.t
    ; pr_hsc_proof: Hsc_proof.t }
end

let prover (srs : Srs.t) (assignment : Assignment.t)
    (arith_circuit : Arith_circuit.t) : Proof.t * Fr.t * Fr.t * Fr.t list =
  let n = List.length assignment.a_l in
  let m = List.length arith_circuit.weights.w_l in
  let cns = replicate 4 Fr.random in
  let r_xy = r_poly assignment in
  let rec cn_poly_fn remaining i =
    match remaining with
    | [] ->
        []
    | hd :: tl ->
        Fr_laurent.create (-((2 * n) + i)) [hd] :: cn_poly_fn tl (i + 1)
  in
  let sumc_xy =
    Bivariate_fr_laurent.create (-((2 * n) + 4)) (reverse (cn_poly_fn cns 1))
  in
  let poly_r' = Bivariate_fr_laurent.( + ) r_xy sumc_xy in
  let commit_r = commit_poly srs (eval_on_y Fr.one poly_r') in
  let y = Fr.random () in
  let ky = k_poly arith_circuit.cs n in
  let s_p = s_poly arith_circuit.weights in
  let t_p = t_poly poly_r' s_p ky in
  let commit_t = commit_poly srs (eval_on_y y t_p) in
  let z = Fr.random () in
  let a, wa = open_poly srs commit_r z (eval_on_y Fr.one poly_r') in
  let b, wb =
    open_poly srs commit_r (Fr.( * ) y z) (eval_on_y Fr.one poly_r')
  in
  let _t', wt = open_poly srs commit_t z (eval_on_y y t_p) in
  let s = eval_on_x_y z y s_p in
  let ys = replicate m Fr.random in
  let hsc_proof = hsc_p srs (s_poly arith_circuit.weights) ys in
  ( { pr_r= commit_r
    ; pr_t= commit_t
    ; pr_a= a
    ; pr_wa= wa
    ; pr_b= b
    ; pr_wb= wb
    ; pr_wt= wt
    ; pr_s= s
    ; pr_hsc_proof= hsc_proof }
  , y
  , z
  , ys )

let verifier (srs : Srs.t) (arith_circuit : Arith_circuit.t) (proof : Proof.t)
    y z ys =
  let n = List.length (List.hd_exn arith_circuit.weights.w_l) in
  let ky = k_poly arith_circuit.cs n in
  let t =
    Fr.(
      (proof.pr_a * (proof.pr_b + proof.pr_s)) + negate (Fr_laurent.eval ky y))
  in
  let checks =
    [ hsc_v srs ys (s_poly arith_circuit.weights) proof.pr_hsc_proof
    ; pc_v srs proof.pr_r z (proof.pr_a, proof.pr_wa)
    ; pc_v srs proof.pr_r (Fr.( * ) y z) (proof.pr_b, proof.pr_wb)
    ; pc_v srs proof.pr_t z (t, proof.pr_wt) ]
  in
  List.fold_left ~f:( && ) ~init:true checks
