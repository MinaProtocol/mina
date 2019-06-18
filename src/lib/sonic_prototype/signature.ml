open Core
open Srs
open Arithmetic_circuit
open Constraints
open Commitment_scheme
open Utils
open Default_backend.Backend

module Hsc_proof = struct
    type t = { hscS : G1.t list ;
    hscW : (Fr.t * G1.t) list ;
    hscQ : (Fr.t * G1.t) list ;
    hscQz : G1.t ;
    hscC : G1.t ;
    hscU : Fr.t ;
    hscZ : Fr.t
  }
end

let hscP (srs : Srs.t) (gate_weights : Gate_weights.t) x ys : Hsc_proof.t =
  let ss = List.map ys ~f:(fun yi -> commit_poly srs srs.d x (eval_on_Y yi (s_poly gate_weights))) in
  let u = Fr.random () in
  let suX = eval_on_X u (s_poly gate_weights) in
  let commit = commit_poly srs srs.d x suX in
  let sW = List.map2_exn ys ss ~f:(fun yi si -> open_poly srs si x u (eval_on_Y yi (s_poly gate_weights))) in
  let sQ = List.map ys ~f:(fun yi -> open_poly srs commit x yi suX) in
  let z = Fr.random () in
  let (_, qz) = open_poly srs commit x z suX in
  { hscS= ss ;
    hscW= sW ;
    hscQ= sQ ;
    hscQz= qz ;
    hscC= commit ;
    hscU= u ;
    hscZ= z }

let hscV (srs : Srs.t) ys (gate_weights : Gate_weights.t) (proof : Hsc_proof.t) =
  let sz = Fr_laurent.eval (eval_on_Y proof.hscZ (s_poly gate_weights)) proof.hscU in
  List.fold_left ~f:( && ) ~init:true
    ((pcV srs srs.d proof.hscC proof.hscZ (sz, proof.hscQz))
    :: List.map2_exn proof.hscS proof.hscW ~f:(fun sj (wsj, wj) -> pcV srs srs.d sj proof.hscU (wsj, wj))
    @ List.map2_exn ys proof.hscQ ~f:(fun yj (wsj, wj) -> pcV srs srs.d proof.hscC yj (wsj, wj)))