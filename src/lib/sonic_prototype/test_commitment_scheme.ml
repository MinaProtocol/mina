open Utils
open Constraints
open Arithmetic_circuit

(* module Verifier = struct
  include Snarky_verifier.Sonic_commitment_scheme.Make (Snark_params.Tock.Pairing)
end *)

module Commitment_scheme = Commitment_scheme.Make_commitment_scheme (Default_backend.Backend)
open Commitment_scheme

open Default_backend.Backend

let%test_unit "basic commitment scheme test" =
  let x = Fr.random () in
  let z = Fr.random () in
  let alpha = Fr.random () in
  let d = 15 in
  let srs = Srs.create d x alpha in
  let f = Fr_laurent.create 1 [Fr.of_int 10] in
  let commitment = commit_poly srs f in
  let opening = open_poly srs commitment z f in
  assert (pc_v srs commitment z opening)

let poly_commitment_scheme_test =
  QCheck.Test.make ~count:10 ~name:"polynomial commitment scheme"
    QCheck.(int)
    (fun l ->
      Random.init l ;
      let x = Fr.random () in
      let y = Fr.random () in
      let z = Fr.random () in
      let alpha = Fr.random () in
      let d = 15 in
      let bL0 = Fr.of_int 7 in
      let bR0 = Fr.of_int 3 in
      let bL1 = Fr.of_int 2 in
      let w_l = [[Fr.of_int 1]; [Fr.of_int 0]] in
      let w_r = [[Fr.of_int 0]; [Fr.of_int 1]] in
      let w_o = [[Fr.of_int 0]; [Fr.of_int 0]] in
      let cs = [Fr.(bL0 + bR0); Fr.(bL1 + of_int 10)] in
      let a_l = [Fr.of_int 10] in
      let a_r = [Fr.of_int 12] in
      let a_o = hadamardp a_l a_r in
      let (gate_weights : Gate_weights.t) = {w_l; w_r; w_o} in
      let (gate_inputs : Assignment.t) = {a_l; a_r; a_o} in
      let srs = Srs.create d x alpha in
      let n = List.length a_l in
      let fX =
        eval_on_y y
          (t_poly (r_poly gate_inputs) (s_poly gate_weights) (k_poly cs n))
      in
      let commitment = commit_poly srs fX in
      let opening = open_poly srs commitment z fX in
      pc_v srs commitment z opening)

let () = QCheck.Test.check_exn poly_commitment_scheme_test
