open Core

module Make_commitment_scheme (Backend : Backend.Backend_intf) = struct
  open Backend
  module Srs = Srs.Make (Backend)
  open Srs

  let commit_poly (srs : Srs.t) poly = select_g_alpha srs poly

  let open_poly srs _commitment z f_poly =
    let fz = Fr_laurent.eval f_poly z in
    let w_poly =
      Fr_laurent.( / )
        (Fr_laurent.( - ) f_poly (Fr_laurent.create 0 [fz]))
        (Fr_laurent.create 0 [Fr.negate z; Fr.one])
    in
    let w = select_g srs w_poly in
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
end
