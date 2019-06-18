open Utils
open Commitment_scheme
open Srs
open Constraints
open Arithmetic_circuit
open Default_backend.Backend

let%test_unit "polynomial commitment scheme" =
  let x = Fr.random () in
  let y = Fr.random () in
  let z = Fr.random () in
  let alpha = Fr.random () in
  let d = Random.int 99 + 2 in
  let max = Random.int ((2 * d) - 1 - (d / 2)) + (d / 2) in
  let bL0 = Fr.of_string "7" in
  let bR0 = Fr.of_string "3" in
  let bL1 = Fr.of_string "2" in
  let wL = [[Fr.of_string "1"]; [Fr.of_string "0"]] in
  let wR = [[Fr.of_string "0"]; [Fr.of_string "1"]] in
  let wO = [[Fr.of_string "0"]; [Fr.of_string "0"]] in
  let cs = [Fr.(bL0 + bR0); Fr.(bL1 + of_string "10")] in
  let aL = [Fr.of_string "10"] in
  let aR = [Fr.of_string "12"] in
  let aO = hadamardp aL aR in
  let (gate_weights : Gate_weights.t) = {wL; wR; wO} in
  let (gate_inputs : Assignment.t) = {aL; aR; aO} in
  let srs = Srs.create d x alpha in
  let n = List.length aL in
  let fX =
    eval_on_Y y
      (t_poly (r_poly gate_inputs) (s_poly gate_weights) (k_poly cs n))
  in
  let commitment = commit_poly srs max x fX in
  let opening = open_poly srs commitment x z fX in
  assert (pcV srs max commitment z opening)
