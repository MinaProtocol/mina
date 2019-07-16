open Core
open Default_backend.Backend
open Helped_signature
open Unhelped_signature
open Arithmetic_circuit
open Constraints
open Utils
open Srs

let%test_unit "test helped signatures of computation" =
  let x = Fr.random () in
  let alpha = Fr.random () in
  let d = 15 in
  let w_l = [[Fr.of_int 1]; [Fr.of_int 0]] in
  let w_r = [[Fr.of_int 0]; [Fr.of_int 1]] in
  let w_o = [[Fr.of_int 0]; [Fr.of_int 0]] in
  let (gate_weights : Gate_weights.t) = {w_l; w_r; w_o} in
  let srs = Srs.create d x alpha in
  let m = List.length w_l in
  let rec make_ys n = if n = 0 then [] else Fr.random () :: make_ys (n - 1) in
  let ys = make_ys m in
  let s_poly = s_poly gate_weights in
  let proof = hsc_p srs s_poly ys in
  assert (hsc_v srs ys s_poly proof)

let%test_unit "test unhelped signatures of computation" =
  let x = Fr.random () in
  let alpha = Fr.random () in
  let d = 15 in
  let w_l = [[Fr.of_int 1]; [Fr.of_int 0]] in
  let w_r = [[Fr.of_int 0]; [Fr.of_int 1]] in
  let w_o = [[Fr.of_int 0]; [Fr.of_int 0]] in
  let (gate_weights : Gate_weights.t) = {w_l; w_r; w_o} in
  let srs = Srs.create d x alpha in
  let y = Fr.random () in
  let z = Fr.random () in
  let s_poly = (s_poly gate_weights) in
  let n = List.length (List.hd_exn w_l) in
  let shifted_s_poly = shift_s_poly s_poly n in
  let psi_polys = convert_to_psi_polys shifted_s_poly (3 * n + 1) in
  let ps1, ps2, ps3 = psi_polys in
  let psi_polys_list = [ps1; ps2; ps3] in
  let eval, proofs = sc_p srs y z psi_polys_list in
  assert (Fr.equal eval (eval_on_x_y y z shifted_s_poly));
  assert (sc_v srs y z psi_polys_list (eval, proofs));
  let not_eval = Fr.random () in
  assert (not (sc_v srs y z psi_polys_list (not_eval, proofs)))
