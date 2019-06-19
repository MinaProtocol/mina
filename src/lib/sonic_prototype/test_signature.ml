open Default_backend.Backend
open Signature
open Arithmetic_circuit
open Srs

let%test_unit "test signatures of computation" =
  let x = Fr.random () in
  let alpha = Fr.random () in
  let d = Random.int 99 + 2 in
  let w_l = [[Fr.of_string "1"]; [Fr.of_string "0"]] in
  let w_r = [[Fr.of_string "0"]; [Fr.of_string "1"]] in
  let w_o = [[Fr.of_string "0"]; [Fr.of_string "0"]] in
  let (gate_weights : Gate_weights.t) = {w_l; w_r; w_o} in
  let srs = Srs.create d x alpha in
  let m = List.length w_l in
  let rec make_ys n = if n = 0 then [] else Fr.random () :: make_ys (n - 1) in
  let ys = make_ys m in
  let proof = hsc_p srs gate_weights x ys in
  assert (hsc_v srs ys gate_weights proof)
