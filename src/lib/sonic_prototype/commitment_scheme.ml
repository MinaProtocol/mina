open Core
open Snarkette.Mnt6_80
open Srs
open Laurent
module Fq_target = Fq6

module FqLaurent = Make_field_laurent(N)(Fq)

let commitPoly (srs : Srs.t) maxm x poly =
  let diff = srs.d - maxm in
  let gxi =
    if diff >= 0 then List.nth_exn srs.gPositiveAlphaX diff
    else List.nth_exn srs.gNegativeAlphaX (abs diff - 1)
  in
  G1.scale gxi (Fq.to_bigint (FqLaurent.eval poly x))

let openPoly _srs _commitment x z fPoly =
  let fz = FqLaurent.eval fPoly z in
  let wPoly =
    FqLaurent.( / )
      (FqLaurent.( - ) fPoly (FqLaurent.create 0 [fz]))
      (FqLaurent.create 0 [Fq.negate z; Fq.one])
  in
  let w = G1.scale G1.one (Fq.to_bigint (FqLaurent.eval wPoly x)) in
  (fz, w)

let pcV (srs : Srs.t) maxm commitment z (v, w) =
  let diff = maxm - srs.d in
  let hxi =
    if diff >= 0 then List.nth_exn srs.hPositiveX diff
    else List.nth_exn srs.hNegativeX (abs diff - 1)
  in
  Fq_target.( * )
    (Pairing.reduced_pairing w (List.nth_exn srs.hPositiveAlphaX 1))
    (Pairing.reduced_pairing
       (G1.( + )
          (G1.scale G1.one (Fq.to_bigint v))
          (G1.scale w (Fq.to_bigint (Fq.negate z))))
       (List.hd_exn srs.hPositiveAlphaX))
  = Pairing.reduced_pairing commitment hxi
