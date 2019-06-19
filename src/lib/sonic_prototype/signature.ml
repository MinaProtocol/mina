open Core
open Srs
open Arithmetic_circuit
open Constraints
open Commitment_scheme
open Utils
open Default_backend.Backend

module Hsc_proof = struct
  type t =
    { hsc_s: G1.t list
    ; hsc_w: (Fr.t * G1.t) list
    ; hsc_q: (Fr.t * G1.t) list
    ; hsc_qz: G1.t
    ; hsc_c: G1.t
    ; hsc_u: Fr.t
    ; hsc_z: Fr.t }
end

let hsc_p (srs : Srs.t) (gate_weights : Gate_weights.t) x ys : Hsc_proof.t =
  let ss =
    List.map ys ~f:(fun yi ->
        commit_poly srs srs.d x (eval_on_y yi (s_poly gate_weights)) )
  in
  let u = Fr.random () in
  let suX = eval_on_x u (s_poly gate_weights) in
  let commit = commit_poly srs srs.d x suX in
  let sW =
    List.map2_exn ys ss ~f:(fun yi si ->
        open_poly srs si x u (eval_on_y yi (s_poly gate_weights)) )
  in
  let sQ = List.map ys ~f:(fun yi -> open_poly srs commit x yi suX) in
  let z = Fr.random () in
  let _, qz = open_poly srs commit x z suX in
  { hsc_s= ss
  ; hsc_w= sW
  ; hsc_q= sQ
  ; hsc_qz= qz
  ; hsc_c= commit
  ; hsc_u= u
  ; hsc_z= z }

let hsc_v (srs : Srs.t) ys (gate_weights : Gate_weights.t)
    (proof : Hsc_proof.t) =
  let sz =
    Fr_laurent.eval (eval_on_y proof.hsc_z (s_poly gate_weights)) proof.hsc_u
  in
  List.fold_left ~f:( && ) ~init:true
    ( pc_v srs srs.d proof.hsc_c proof.hsc_z (sz, proof.hsc_qz)
      :: List.map2_exn proof.hsc_s proof.hsc_w ~f:(fun sj (wsj, wj) ->
             pc_v srs srs.d sj proof.hsc_u (wsj, wj) )
    @ List.map2_exn ys proof.hsc_q ~f:(fun yj (wsj, wj) ->
          pc_v srs srs.d proof.hsc_c yj (wsj, wj) ) )
