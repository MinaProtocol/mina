open Core
open Permutation
open Default_backend.Backend
open Utils
open Permutation_utils

module Srs = Srs.Make (Default_backend.Backend)

let shift_s_poly s_poly n =
  (* cancel out (-Y^i -Y^-i)X^i+n terms *)
  let rec gen_cancel_poly i =
    if i > n then Bivariate_fr_laurent.zero else
    Bivariate_fr_laurent.(
      ((create Int.(i + n) [Fr_laurent.create i [Fr.of_int 1]]) + (create Int.(i + n) [Fr_laurent.create Int.(-i) [Fr.of_int 1]]))
      + (gen_cancel_poly Int.(i + 1))
    ) in
  let cancel_poly = gen_cancel_poly 1 in
  let canceled_poly = Bivariate_fr_laurent.( + ) cancel_poly s_poly in

  let y_shifted_poly = shift_y canceled_poly (- n) in
  
  let degree = Bivariate_fr_laurent.deg y_shifted_poly in
  let shifted_poly = Bivariate_fr_laurent.(create Int.((n + 1) + degree) (coeffs y_shifted_poly)) in
  shifted_poly

let coeffs_list_to_triple deg coeffs =
  let rec helper deg lst =
    match lst with
    | [] -> (0, Fr.zero, (0, []))
    | hd::tl -> if Fr.(equal hd zero) then helper (deg + 1) tl else (deg, hd, (deg + 1, tl)) in
  let first_deg, first_val, first_rest = helper deg coeffs in
  let first_rest_deg, first_rest_coeffs = first_rest in
  let second_deg, second_val, second_rest = helper first_rest_deg first_rest_coeffs in
  let second_rest_deg, second_rest_coeffs = second_rest in
  let third_deg, third_val, _ = helper second_rest_deg second_rest_coeffs in
  ((first_deg, first_val), (second_deg, second_val), (third_deg, third_val))

let convert_to_psi_polys poly n =
  (* assume poly has <= 3 different Y^j terms multiplying any particular X^i *)
  (* assume deg of poly = 1 *)

  let sigma_1, sigma_2, sigma_3, psi_1, psi_2, psi_3 = convert_to_sigmas_psis poly n in

  let psi_poly_1 = psi_poly_from_sigma_psi sigma_1 psi_1 in
  let psi_poly_2 = psi_poly_from_sigma_psi sigma_2 psi_2 in
  let psi_poly_3 = psi_poly_from_sigma_psi sigma_3 psi_3 in
  psi_poly_1, psi_poly_2, psi_poly_3

(* unhelped signature of correct computation from Sonic, Sec. 7 *)
(* proving the value of s(z_j, y_j) is computed correctly, for y_j in ys *)
let sc_p (srs : Srs.t) y z psi_polys =
  let proofs = List.map psi_polys ~f:(fun psi_poly -> perm_p srs y z psi_poly) in
  let psi_evals = List.map proofs ~f:(fun (proof : Perm_proof.t) -> proof.perm_psi_eval) in
  List.iter ~f:(fun x -> Printf.printf "psi_eval: %s\n" ((Fr.to_string x))) psi_evals;
  let s = List.fold_left ~init:Fr.zero ~f:Fr.( + ) psi_evals in
  (s, proofs)

let sc_v (srs : Srs.t) y z psi_polys (s, proofs) =
  let psi_evals = List.map proofs ~f:(fun (proof : Perm_proof.t) -> proof.perm_psi_eval) in
  Fr.equal s (List.fold_left ~init:Fr.zero ~f:Fr.( + ) psi_evals) &&
  List.fold_left ~init:true ~f:( && ) (List.map2_exn psi_polys proofs ~f:(fun psi_poly proof -> perm_v srs y z psi_poly proof))