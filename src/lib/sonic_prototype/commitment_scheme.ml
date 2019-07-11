open Core
open Srs
open Utils
open Default_backend.Backend

let commit_poly_orig (srs : Srs.t) x poly =
  let g_alpha = List.hd_exn srs.gPositiveAlphaX in
  
  G1.scale g_alpha (Fr.to_bigint (Fr_laurent.eval poly x))

let commit_poly (srs : Srs.t) x poly =
  (* TODO: construct from SRS *)
  let g_alpha = List.hd_exn srs.gPositiveAlphaX in
  
  let deg = Fr_laurent.deg poly in
  let coeffs = Fr_laurent.coeffs poly in
  let new_coeffs = if deg > 0 then coeffs else list_replace coeffs (- deg) Fr.zero in
  let new_poly = Fr_laurent.create deg new_coeffs in
  
  G1.scale g_alpha (Fr.to_bigint (Fr_laurent.eval new_poly x))

let open_poly _srs _commitment x z f_poly =
  let fz = Fr_laurent.eval f_poly z in
  let wPoly =
    Fr_laurent.( / )
      (Fr_laurent.( - ) f_poly (Fr_laurent.create 0 [fz]))
      (Fr_laurent.create 0 [Fr.negate z; Fr.one])
  in
  let w = G1.scale G1.one (Fr.to_bigint (Fr_laurent.eval wPoly x)) in
  (fz, w)

let pc_v (srs : Srs.t) commitment z (v, w) =
  let h = List.hd_exn srs.hPositiveX in
  let first =
    Fq_target.( * )
      (Pairing.reduced_pairing w (List.nth_exn srs.hPositiveAlphaX 1))
      (Pairing.reduced_pairing
         (G1.( + )
            (G1.scale G1.one (Fr.to_bigint v))
            (G1.scale w (Fr.to_bigint (Fr.negate z))))
         (List.hd_exn srs.hPositiveAlphaX))
  in
  let second = Pairing.reduced_pairing commitment h in
  Fq_target.equal first second
