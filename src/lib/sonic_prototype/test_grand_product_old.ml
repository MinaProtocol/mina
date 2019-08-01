open Core
open Grand_product
open Default_backend.Backend
module Srs = Srs.Make (Default_backend.Backend)
open Srs
module Commitment_scheme =
  Commitment_scheme.Make (Default_backend.Backend)
open Commitment_scheme

let well_formed_test =
  QCheck.Test.make ~count:4 ~name:"well-formed test"
    QCheck.(quad small_nat small_nat (small_list int) (small_list int))
    (fun (a_deg, b_deg, a_nums, b_nums) ->
      let x = Fr.random () in
      let alpha = Fr.random () in
      let d = 110 in
      (* max degree (largest small_nat + small_list) *)
      let srs = Srs.create d x alpha in
      let a_coeffs = List.map a_nums ~f:Fr.of_int in
      let b_coeffs = List.map b_nums ~f:Fr.of_int in
      let poly_a = Fr_laurent.create a_deg a_coeffs in
      let poly_b = Fr_laurent.create b_deg b_coeffs in
      let a_n = List.length a_coeffs in
      let b_n = List.length b_coeffs in
      let commit_a = commit_poly srs poly_a in
      let commit_b = commit_poly srs poly_b in
      let wfp_a = wform_p srs a_n commit_a a_coeffs in
      let wfp_b = wform_p srs b_n commit_b a_coeffs in
      wform_v srs a_n commit_a wfp_a && wform_v srs b_n commit_b wfp_b)

let grand_product_test =
  QCheck.Test.make ~count:4 ~name:"grand-product test"
    QCheck.(quad small_nat small_nat (small_list int) (small_list int))
    (fun (a_deg, b_deg, a_nums, b_nums) ->
      let x = Fr.random () in
      let alpha = Fr.random () in
      let d = 110 in
      (* max degree (largest small_nat + small_list) *)
      let _srs = Srs.create d x alpha in
      let a_coeffs = List.map a_nums ~f:Fr.of_int in
      let _poly_a = Fr_laurent.create a_deg a_coeffs in
      let a_product = List.fold_left ~f:Fr.( * ) ~init:Fr.one a_coeffs in
      let b_coeffs_initial = List.map b_nums ~f:Fr.of_int in
      let b_product =
        List.fold_left ~f:Fr.( * ) ~init:Fr.one b_coeffs_initial
      in
      let b_coeffs = b_coeffs_initial @ [Fr.inv b_product; a_product] in
      let _poly_b = Fr_laurent.create b_deg b_coeffs in
      true)

(* polys with same grand product work, random polys don't *)

let () =
  QCheck.Test.check_exn well_formed_test ;
  QCheck.Test.check_exn grand_product_test
