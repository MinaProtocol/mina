open Core
open Default_backend.Backend
open Helped_signature
open Arithmetic_circuit
open Constraints

let%test_unit "small test helped signatures of computation" =
  let x = Fr.random () in
  let alpha = Fr.random () in
  let d = 45 in
  let w_l = [[Fr.of_int 1]; [Fr.of_int 0]] in
  let w_r = [[Fr.of_int 0]; [Fr.of_int 1]] in
  let w_o = [[Fr.of_int 0]; [Fr.of_int 0]] in
  let (gate_weights : Gate_weights.t) = {w_l; w_r; w_o} in
  let srs = Srs.create d x alpha in
  let m = List.length w_l in
  let rec make_ys n = if n = 0 then [] else Fr.random () :: make_ys (n - 1) in
  let ys = make_ys m in
  let other_ys = make_ys m in
  let s_poly = s_poly gate_weights in
  let proof = hsc_p srs s_poly ys in
  let other_proof = hsc_p srs s_poly other_ys in
  assert (hsc_v srs ys s_poly proof);
  assert (hsc_v srs other_ys s_poly other_proof);
  assert (not (hsc_v srs ys s_poly other_proof));
  assert (not (hsc_v srs other_ys s_poly proof))

let%test_unit "big test helped signatures of computation" =
  let x = Fr.random () in
  let alpha = Fr.random () in
  let d = 45 in
  let w_l = [[Fr.of_int 1]; [Fr.of_int 0]; [Fr.of_int 1]; [Fr.of_int 1]; [Fr.of_int 2]; [Fr.of_int 3]] in
  let w_r = [[Fr.of_int 0]; [Fr.of_int 1]; [Fr.of_int 1]; [Fr.of_int 1]; [Fr.of_int 4]; [Fr.of_int 3]] in
  let w_o = [[Fr.of_int 0]; [Fr.of_int 0]; [Fr.of_int 1]; [Fr.of_int 1]; [Fr.of_int 3]; [Fr.of_int 3]] in
  let (gate_weights : Gate_weights.t) = {w_l; w_r; w_o} in
  let srs = Srs.create d x alpha in
  let m = List.length w_l in
  let rec make_ys n = if n = 0 then [] else Fr.random () :: make_ys (n - 1) in
  let ys = make_ys m in
  let other_ys = make_ys m in
  let s_poly = s_poly gate_weights in
  let proof = hsc_p srs s_poly ys in
  let other_proof = hsc_p srs s_poly other_ys in
  assert (hsc_v srs ys s_poly proof);
  assert (hsc_v srs other_ys s_poly other_proof);
  assert (not (hsc_v srs ys s_poly other_proof));
  assert (not (hsc_v srs other_ys s_poly proof))
