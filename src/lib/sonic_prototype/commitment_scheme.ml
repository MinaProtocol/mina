open Core
open Srs
open Default_backend.Backend

let commit_poly_orig (srs : Srs.t) x poly =
  let g_alpha = List.hd_exn srs.gPositiveAlphaX in
  
  G1.scale g_alpha (Fr.to_bigint (Fr_laurent.eval poly x))

let commit_poly (srs : Srs.t) _x poly =
  (* TODO: construct from SRS *) 
  let deg = Fr_laurent.deg poly in
  let coeffs = Fr_laurent.coeffs poly in
  (* let new_coeffs = if deg > 0 then coeffs else list_replace coeffs (- deg) Fr.zero in *)

  let rec accum current_deg remaining_coeffs so_far =
    match remaining_coeffs with
    | [] -> so_far
    | hd::tl ->
    let next = if current_deg < 0 then (List.nth_exn srs.gNegativeAlphaX (-1 - current_deg))
               else if current_deg = 0 then G1.one
               else List.nth_exn srs.gPositiveAlphaX current_deg in
    accum (current_deg + 1) tl (G1.( + ) (G1.scale next (Fr.to_bigint hd)) so_far) in
  accum deg coeffs G1.one

let open_poly _srs _commitment x z f_poly =
  let fz = Fr_laurent.eval f_poly z in
  let w_poly =
    Fr_laurent.( / )
      (Fr_laurent.( - ) f_poly (Fr_laurent.create 0 [fz]))
      (Fr_laurent.create 0 [Fr.negate z; Fr.one])
  in
  let w = G1.scale G1.one (Fr.to_bigint (Fr_laurent.eval w_poly x)) in
  (fz, w)

let pc_v (srs : Srs.t) commitment z (v, w) =
  let h = List.hd_exn srs.hPositiveX in
  let h_alpha = List.hd_exn srs.hPositiveAlphaX in
  let h_alpha_x = List.nth_exn srs.hPositiveAlphaX 1 in
  let first =
    Fq_target.( * )
      (Pairing.reduced_pairing w h_alpha_x)
      (Pairing.reduced_pairing
         (G1.( + )
            (G1.scale G1.one (Fr.to_bigint v))
            (G1.scale w (Fr.to_bigint (Fr.negate z))))
         h_alpha)
  in
  let second = Pairing.reduced_pairing commitment h in
  Fq_target.equal first second
