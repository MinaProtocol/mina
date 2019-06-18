open Default_backend.Backend
open Signature
open Arithmetic_circuit
open Srs

let%test_unit "test signatures of computation" =
  let x = Fr.random () in
  let alpha = Fr.random () in
  let d = Random.int 99 + 2 in
  let wL = [[Fr.of_string "1"]; [Fr.of_string "0"]] in
  let wR = [[Fr.of_string "0"]; [Fr.of_string "1"]] in
  let wO = [[Fr.of_string "0"]; [Fr.of_string "0"]] in
  let (gate_weights : Gate_weights.t) = {wL; wR; wO} in
  let srs = Srs.create d x alpha in
  let m = List.length wL in
  let rec make_ys n =
    if n = 0 then [] else (Fr.random ()) :: (make_ys (n - 1)) in
  let ys = make_ys m in
  let proof = hscP srs gate_weights x ys in
  assert (hscV srs ys gate_weights proof)