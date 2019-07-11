open Default_backend.Backend
open Arithmetic_circuit
open Srs
open Utils
open Protocol

let%test_unit "test protocol" =
  let x = Fr.random () in
  let z = Fr.random () in
  let alpha = Fr.random () in
  let d = 18 in
  let w_l =
    [ [Fr.of_int 0; Fr.of_int 0]
    ; [Fr.of_int 1; Fr.of_int 0]
    ; [Fr.of_int 0; Fr.of_int 1]
    ; [Fr.of_int 0; Fr.of_int 0]
    ; [Fr.of_int 0; Fr.of_int 0] ]
  in
  let w_r =
    [ [Fr.of_int 0; Fr.of_int 0]
    ; [Fr.of_int 0; Fr.of_int 0]
    ; [Fr.of_int 0; Fr.of_int 0]
    ; [Fr.of_int 1; Fr.of_int 0]
    ; [Fr.of_int 0; Fr.of_int 1] ]
  in
  let w_o =
    [ [Fr.of_int 1; Fr.of_int (-1)]
    ; [Fr.of_int 0; Fr.of_int 0]
    ; [Fr.of_int 0; Fr.of_int 0]
    ; [Fr.of_int 0; Fr.of_int 0]
    ; [Fr.of_int 0; Fr.of_int 0] ]
  in
  let w_v =
    [ [Fr.of_int 0; Fr.of_int 0; Fr.of_int 0; Fr.of_int 0]
    ; [Fr.of_int 1; Fr.of_int 0; Fr.of_int 0; Fr.of_int 0]
    ; [Fr.of_int 0; Fr.of_int 0; Fr.of_int 1; Fr.of_int 0]
    ; [Fr.of_int 0; Fr.of_int 1; Fr.of_int 0; Fr.of_int 0]
    ; [Fr.of_int 0; Fr.of_int 0; Fr.of_int 0; Fr.of_int 1] ]
  in
  let cs = [Fr.zero; Fr.(of_int 4 - z); Fr.(of_int 9 - z); Fr.(of_int 9 - z); Fr.(of_int 4 - z)] in
  let a_l = [Fr.(of_int 4 - z); Fr.(of_int 9 - z)] in
  let a_r = [Fr.(of_int 9 - z); Fr.(of_int 4 - z)] in
  let a_o = hadamardp a_l a_r in
  let (gate_weights : Gate_weights.t) = {w_l; w_r; w_o} in
  let (gate_inputs : Assignment.t) = {a_l; a_r; a_o} in
  let (arith_circuit : Arith_circuit.t) =
    {weights= gate_weights; commitment_weights= w_v; cs}
  in
  let srs = Srs.create d x alpha in
  let proof, y, z, ys = prover srs gate_inputs arith_circuit x in
  assert (verifier srs arith_circuit proof y z ys)
