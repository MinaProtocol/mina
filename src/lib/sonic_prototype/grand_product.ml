open Core
open Snarkette
open Srs
open Commitment_scheme
open Utils
open Default_backend.Backend

let pair = Pairing.reduced_pairing

let wform_p (srs : Srs.t) n _commitment coeffs =
  let poly_shifted_neg_d = Fr_laurent.create (1 - srs.d) coeffs in
  let l = select_g srs poly_shifted_neg_d in
  let poly_shifted_d_n = Fr_laurent.create (1 + srs.d - n) coeffs in
  let r = select_g srs poly_shifted_d_n in
  (l, r)

let wform_v (srs : Srs.t) n commitment (l, r) =
  let h = List.hd_exn srs.hPositiveX in
  let lhs = pair commitment h in
  let h_alpha_x_d = List.nth_exn srs.hPositiveAlphaX srs.d in
  let rhs1 = pair l h_alpha_x_d in
  let h_alpha_x_n_d = List.nth_exn srs.hNegativeAlphaX (srs.d - n - 1) in
  let rhs2 = pair r h_alpha_x_n_d in
  Fq_target.equal lhs rhs1 && Fq_target.equal lhs rhs2

module Gprod_proof = struct
  type t =
    { gprod_n: int
    ; gprod_a: G1.t
    ; gprod_c: G1.t
    ; gprod_cw: G1.t * G1.t
    ; gprod_uw: G1.t * G1.t
    ; gprod_vw: G1.t * G1.t
    ; gprod_cn_inv: Fr.t
    ; gprod_t: G1.t
    ; gprod_va: Fr.t
    ; gprod_wa: G1.t
    ; gprod_vc: Fr.t
    ; gprod_wc: G1.t
    ; gprod_vk: Fr.t
    ; gprod_wk: G1.t
    ; gprod_wt: G1.t
    ; gprod_y: Fr.t
    ; gprod_z: Fr.t }
end

(* helper function *)
let partial_products lst mul one =
  let rec helper lst prod_so_far =
    match lst with
    | [] ->
        []
    | hd :: tl ->
        let new_prod = mul hd prod_so_far in
        new_prod :: helper tl new_prod
  in
  helper lst one

let gprod_p (srs : Srs.t) u v u_coeffs v_coeffs x : Gprod_proof.t =
  let n = List.length u_coeffs in
  assert (List.length v_coeffs = n) ;
  let u_partial_prods = partial_products u_coeffs Fr.( * ) Fr.one in
  let v_partial_prods = partial_products v_coeffs Fr.( * ) Fr.one in
  let c = u_partial_prods @ [Fr.one] @ v_partial_prods in
  let cn_inv =
    Fr.inv (List.nth_exn v_partial_prods (List.length v_partial_prods - 1))
  in
  let a = u_coeffs @ [cn_inv] @ v_coeffs in
  let a_poly = Fr_laurent.create 1 a in
  let a_commit =
    G1.(
      scale
        (List.nth_exn srs.gPositiveAlphaX Int.(n + 1))
        (Fr.to_bigint cn_inv)
      + (u + scale v (Fr.to_bigint (Fr.( ** ) x (Nat.of_int Int.(n + 1))))))
  in
  let c_poly = Fr_laurent.create 1 c in
  let c_commit = commit_poly srs c_poly in
  let cw = wform_p srs ((2 * n) + 1) c_commit c in
  let uw = wform_p srs n u u_coeffs in
  let vw = wform_p srs n v v_coeffs in
  (* verifier samples y (from random oracle) and sends to prover *)
  let y = Fr.random () in
  let rec gen_r_poly_coeffs idx a_rest =
    match a_rest with
    | [] ->
        []
    | hd :: tl ->
        Fr_laurent.create (idx + 1) [hd] :: gen_r_poly_coeffs (idx + 1) tl
  in
  let r_poly = Bivariate_fr_laurent.create 1 (gen_r_poly_coeffs 1 a) in
  let rec gen_zeros num =
    if num = 0 then [] else Fr_laurent.zero :: gen_zeros (num - 1)
  in
  let s_poly =
    Bivariate_fr_laurent.create (n + 1)
      ( [Fr_laurent.create 1 [Fr.one]; Fr_laurent.create 0 [Fr.one]]
      @ gen_zeros (n - 1)
      @ [Fr_laurent.create 1 [Fr.negate Fr.one]] )
  in
  let rec gen_r_prime_poly_coeffs rest =
    match rest with
    | [] ->
        []
    | hd :: tl ->
        Fr_laurent.create 0 [hd] :: gen_r_prime_poly_coeffs tl
  in
  let r_prime_poly =
    Bivariate_fr_laurent.create
      ((-2 * n) - 2)
      (gen_r_prime_poly_coeffs (reverse c @ [Fr.one]))
  in
  let k_poly =
    Bivariate_fr_laurent.create 0 [Fr_laurent.create 0 (Fr.one :: Fr.zero :: c)]
  in
  let t_poly =
    Bivariate_fr_laurent.(((r_poly + s_poly) * r_prime_poly) - k_poly)
  in
  let t = commit_poly srs (eval_on_y y t_poly) in
  (* verifier samples z (from random oracle) and sends to prover *)
  let z = Fr.random () in
  let va, wa = open_poly srs a (Fr.( * ) y z) a_poly in
  let vc, wc = open_poly srs c (Fr.inv z) c_poly in
  let vk, wk = open_poly srs c y c_poly in
  let _, wt = open_poly srs t z (eval_on_y y t_poly) in
  { gprod_n= n
  ; gprod_a= a_commit
  ; gprod_c= c_commit
  ; gprod_cw= cw
  ; gprod_uw= uw
  ; gprod_vw= vw
  ; gprod_cn_inv= cn_inv
  ; gprod_t= t
  ; gprod_va= va
  ; gprod_wa= wa
  ; gprod_vc= vc
  ; gprod_wc= wc
  ; gprod_vk= vk
  ; gprod_wk= wk
  ; gprod_wt= wt
  ; gprod_y= y
  ; gprod_z= z }

let gprod_v (srs : Srs.t) u v (proof : Gprod_proof.t) =
  let n = proof.gprod_n in
  let a = proof.gprod_a in
  let c = proof.gprod_c in
  let cw = proof.gprod_cw in
  let uw = proof.gprod_uw in
  let vw = proof.gprod_vw in
  let cn_inv = proof.gprod_cn_inv in
  let t_commit = proof.gprod_t in
  let va = proof.gprod_va in
  let wa = proof.gprod_wa in
  let vc = proof.gprod_vc in
  let wc = proof.gprod_wc in
  let vk = proof.gprod_vk in
  let wk = proof.gprod_wk in
  let wt = proof.gprod_wt in
  let y = proof.gprod_y in
  let z = proof.gprod_z in
  let h = List.nth_exn srs.hPositiveX 0 in
  let r = Fr.( * ) y va in
  let s =
    Fr.(
      (z ** Nat.of_int Int.(n + 2))
      + ((z ** Nat.of_int Int.(n + 1)) * y)
      - ((z ** Nat.of_int Int.((2 * n) + 2)) * y))
  in
  let r_prime = Fr.((vc * inv z) + inv z) in
  let k = Fr.((vk * y) + one) in
  let t = Fr.(((r + s) * r_prime) - k) in
  Fq_target.equal (pair a h)
    (Fq_target.( * )
       (pair
          G1.(
            scale
              (List.nth_exn srs.gPositiveAlphaX Int.(n + 1))
              (Fr.to_bigint cn_inv)
            + u)
          h)
       (pair v (List.nth_exn srs.hPositiveX (n + 1))))
  && pc_v srs a (Fr.( * ) y z) (va, wa)
  && pc_v srs c (Fr.inv z) (vc, wc)
  && pc_v srs c y (vk, wk)
  && pc_v srs t_commit z (t, wt)
  && wform_v srs ((2 * n) + 1) c cw
  && wform_v srs n u uw
  && wform_v srs n v vw
