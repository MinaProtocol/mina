open Core
open Utils
open Default_backend.Backend
module Srs = Srs.Make (Default_backend.Backend)
module Commitment_scheme =
  Commitment_scheme.Make_commitment_scheme (Default_backend.Backend)
open Commitment_scheme

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

(* helped signature of correct computation from Sonic, Sec. 8 *)
(* proving the value of s(z_j, y_j) is computed correctly, for y_j in ys *)
let hsc_p (srs : Srs.t) s_poly ys : Hsc_proof.t =
  let ss = List.map ys ~f:(fun yi -> commit_poly srs (eval_on_y yi s_poly)) in
  (* verifier samples u (from random oracle) and sends to prover *)
  let u = Fr.random () in
  let suX = eval_on_x u s_poly in
  let commit = commit_poly srs suX in
  let sW =
    List.map2_exn ys ss ~f:(fun yi si ->
        open_poly srs si u (eval_on_y yi s_poly))
  in
  let sQ = List.map ys ~f:(fun yi -> open_poly srs commit yi suX) in
  (* verifier samples z (from random oracle) and sends to prover *)
  let z = Fr.random () in
  let _, qz = open_poly srs commit z suX in
  { hsc_s= ss
  ; hsc_w= sW
  ; hsc_q= sQ
  ; hsc_qz= qz
  ; hsc_c= commit
  ; hsc_u= u
  ; hsc_z= z }

let hsc_v (srs : Srs.t) ys s_poly (proof : Hsc_proof.t) =
  let sz = eval_on_x_y proof.hsc_u proof.hsc_z s_poly in
  List.fold_left ~f:( && ) ~init:true
    ( pc_v srs proof.hsc_c proof.hsc_z (sz, proof.hsc_qz)
      :: List.map2_exn proof.hsc_s proof.hsc_w ~f:(fun sj (wsj, wj) ->
             pc_v srs sj proof.hsc_u (wsj, wj))
    @ List.map2_exn ys proof.hsc_q ~f:(fun yj (qsj, qj) ->
          pc_v srs proof.hsc_c yj (qsj, qj)) )
