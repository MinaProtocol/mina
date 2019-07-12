open Core
open Snarkette
open Srs
open Commitment_scheme
open Utils
open Grand_product
open Default_backend.Backend

let pair = Pairing.reduced_pairing

module Perm_proof = struct
  type t =
    { perm_s: G1.t
    ; perm_s_prime: G1.t
    ; perm_u: Fr.t
    ; perm_beta: Fr.t
    ; perm_gamma: Fr.t
    ; perm_psi_eval: Fr.t
    ; perm_w: G1.t
    ; perm_v: Fr.t
    ; perm_w_prime: G1.t
    ; perm_q_prime: G1.t
    ; perm_gprod: Gprod_proof.t }
end

let derive srs psis sigmas =
  let n = List.length psis in
  let p1_coeffs = List.map (List.range 1 (n + 1)) ~f:(fun _ -> Fr.one) in
  let p1_poly = Fr_laurent.create 1 p1_coeffs in
  let p1 = commit_poly srs p1_poly in
  let p2_coeffs = psis in
  let p2_poly = Fr_laurent.create 1 p2_coeffs in
  let p2 = commit_poly srs p2_poly in
  let p3_coeffs = List.map (List.range 1 (n + 1)) ~f:Fr.of_int in
  let p3_poly = Fr_laurent.create 1 p3_coeffs in
  let p3 = commit_poly srs p3_poly in
  let p4_coeffs = List.map sigmas ~f:Fr.of_int in
  let p4_poly = Fr_laurent.create 1 p4_coeffs in
  let p4 = commit_poly srs p4_poly in
  (p1, p2, p3, p4)

let perm_p (srs : Srs.t) y z psis sigmas : Perm_proof.t =
  let n = List.length psis in
  let p1, p2, p3, p4 = derive srs psis sigmas in
  let phi =
    Bivariate_fr_laurent.create 1
      (List.map
         (List.range 1 (n + 1))
         ~f:(fun i -> Fr_laurent.create i [List.nth_exn psis (i - 1)]))
  in
  let psi =
    Bivariate_fr_laurent.create 1
      (List.map
         (List.range 1 (n + 1))
         ~f:(fun i ->
           let sigma_i = List.nth_exn sigmas (i - 1) in
           Fr_laurent.create sigma_i [List.nth_exn psis (sigma_i - 1)]))
  in
  let s = commit_poly srs (eval_on_y y psi) in
  let s_prime = commit_poly srs (eval_on_y y phi) in
  (* verifier samples u, beta, gamma (from random oracle) and sends them to prover *)
  let u = Fr.random () in
  let beta = Fr.random () in
  let gamma = Fr.random () in
  let s_bar =
    G1.( + ) s
      (G1.( + )
         (G1.scale p4 (Fr.to_bigint beta))
         (G1.scale p1 (Fr.to_bigint gamma)))
  in
  let p_bar =
    G1.( + ) s_prime
      (G1.( + )
         (G1.scale p3 (Fr.to_bigint beta))
         (G1.scale p1 (Fr.to_bigint gamma)))
  in
  let psi_eval, w = open_poly srs s z (eval_on_y y psi) in
  let v, w_prime = open_poly srs s_prime u (eval_on_y y phi) in
  let _, q_prime =
    open_poly srs p2 (Fr.( * ) u y) (Fr_laurent.create 1 psis)
  in
  let s_bar_poly_coeffs =
    List.map
      (List.range 1 (n + 1))
      ~f:(fun i ->
        let sigma_i = List.nth_exn sigmas (i - 1) in
        Fr.( + )
          (Fr.( * )
             (List.nth_exn psis (sigma_i - 1))
             (Fr.( ** ) y (Nat.of_int sigma_i)))
          (Fr.( + ) (Fr.( * ) beta (Fr.of_int sigma_i)) gamma))
  in
  let p_bar_poly_coeffs =
    List.map
      (List.range 1 (n + 1))
      ~f:(fun i ->
        Fr.( + )
          (Fr.( * ) (List.nth_exn psis (i - 1)) (Fr.( ** ) y (Nat.of_int i)))
          (Fr.( + ) (Fr.( * ) beta (Fr.of_int i)) gamma))
  in
  let gprod = gprod_p srs s_bar p_bar s_bar_poly_coeffs p_bar_poly_coeffs in
  { perm_s= s
  ; perm_s_prime= s_prime
  ; perm_u= u
  ; perm_beta= beta
  ; perm_gamma= gamma
  ; perm_psi_eval= psi_eval
  ; perm_w= w
  ; perm_v= v
  ; perm_w_prime= w_prime
  ; perm_q_prime= q_prime
  ; perm_gprod= gprod }

let perm_v (srs : Srs.t) y z psis sigmas (proof : Perm_proof.t) =
  let p1, p2, p3, p4 = derive srs psis sigmas in
  let s = proof.perm_s in
  let s_prime = proof.perm_s_prime in
  let u = proof.perm_u in
  let beta = proof.perm_beta in
  let gamma = proof.perm_gamma in
  let psi_eval = proof.perm_psi_eval in
  let w = proof.perm_w in
  let v = proof.perm_v in
  let w_prime = proof.perm_w_prime in
  let q_prime = proof.perm_q_prime in
  let gprod = proof.perm_gprod in
  let s_bar =
    G1.( + ) s
      (G1.( + )
         (G1.scale p4 (Fr.to_bigint beta))
         (G1.scale p1 (Fr.to_bigint gamma)))
  in
  let p_bar =
    G1.( + ) s_prime
      (G1.( + )
         (G1.scale p3 (Fr.to_bigint beta))
         (G1.scale p1 (Fr.to_bigint gamma)))
  in
  pc_v srs s z (psi_eval, w)
  && pc_v srs s_prime u (v, w_prime)
  && pc_v srs p2 (Fr.( * ) u y) (v, q_prime)
  && gprod_v srs s_bar p_bar gprod
