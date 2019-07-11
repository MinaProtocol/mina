open Core
open Commitment_scheme
open Srs
open Grand_product
open Default_backend.Backend

let run_well_formed_test a_nums b_nums =
  let x = Fr.random () in
  let alpha = Fr.random () in
  let d = 15 in
  let srs = Srs.create d x alpha in
  let a_coeffs = List.map a_nums ~f:Fr.of_int in
  let b_coeffs = List.map b_nums ~f:Fr.of_int in
  let poly_a = Fr_laurent.create 1 a_coeffs in
  let poly_b = Fr_laurent.create 1 b_coeffs in
  let a_n = List.length a_coeffs in
  let b_n = List.length b_coeffs in
  let commit_a = commit_poly srs poly_a in
  let commit_b = commit_poly srs poly_b in
  let wfp_a = wform_p srs a_n commit_a a_coeffs in
  let wfp_b = wform_p srs b_n commit_b b_coeffs in
  wform_v srs a_n commit_a wfp_a && wform_v srs b_n commit_b wfp_b

let%test_unit "well_formed_test" =
  let a_nums = [1; 2; 3; 4; 5] in
  let b_nums = [-1; 2; -3; 4; -5] in
  assert (run_well_formed_test a_nums b_nums)

let run_grand_product_test a_coeffs b_coeffs srs x =
  let poly_a = Fr_laurent.create 1 a_coeffs in
  let poly_b = Fr_laurent.create 1 b_coeffs in
  let commit_a = commit_poly srs poly_a in
  let commit_b = commit_poly srs poly_b in
  let gprod_proof = gprod_p srs commit_a commit_b a_coeffs b_coeffs x in
  gprod_v srs commit_a commit_b gprod_proof

let true_grand_product_test a_nums b_nums =
  let x = Fr.random () in
  let alpha = Fr.random () in
  let d = 15 in
  let srs = Srs.create d x alpha in
  let a_coeffs = List.map a_nums ~f:Fr.of_int in
  let a_product = List.fold_left ~f:Fr.( * ) ~init:Fr.one a_coeffs in
  let b_coeffs_initial = List.map b_nums ~f:Fr.of_int in
  let b_product = List.fold_left ~f:Fr.( * ) ~init:Fr.one b_coeffs_initial in
  let b_coeffs = b_coeffs_initial @ [Fr.inv b_product; a_product] in
  run_grand_product_test a_coeffs b_coeffs srs x

let false_grand_product_test a_nums b_nums =
  let x = Fr.random () in
  let alpha = Fr.random () in
  let d = 15 in
  let srs = Srs.create d x alpha in
  let a_coeffs = List.map a_nums ~f:Fr.of_int in
  let b_coeffs_initial = List.map b_nums ~f:Fr.of_int in
  let b_product = List.fold_left ~f:Fr.( * ) ~init:Fr.one b_coeffs_initial in
  let b_coeffs = b_coeffs_initial @ [Fr.inv b_product; Fr.random ()] in
  run_grand_product_test a_coeffs b_coeffs srs x

(* polys with same grand product work, random polys don't *)

let%test_unit "grand_product_test" =
  let a_nums = [1; 2; 3; 4; 5] in
  let b_nums = [-1; 2; -3] in
  assert (true_grand_product_test a_nums b_nums) ;
  assert (not (false_grand_product_test a_nums b_nums))
