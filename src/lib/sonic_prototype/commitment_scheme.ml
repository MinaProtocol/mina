open Core
open Srs
open Default_backend.Backend

let commit_poly (srs : Srs.t) maxm x poly =
  let diff = srs.d - maxm in
  let gxi =
    if diff >= 0 then List.nth_exn srs.gPositiveAlphaX diff
    else List.nth_exn srs.gNegativeAlphaX (abs diff - 1)
  in
  G1.scale gxi (Fr.to_bigint (Fr_laurent.eval poly x))

let open_poly _srs _commitment x z fPoly =
  let fz = Fr_laurent.eval fPoly z in
  let wPoly =
    Fr_laurent.( / )
      (Fr_laurent.( - ) fPoly (Fr_laurent.create 0 [fz]))
      (Fr_laurent.create 0 [Fr.negate z; Fr.one])
  in
  let w = G1.scale G1.one (Fr.to_bigint (Fr_laurent.eval wPoly x)) in
  (fz, w)

let pcV (srs : Srs.t) maxm commitment z (v, w) =
  let diff = maxm - srs.d in
  let hxi =
    if diff >= 0 then List.nth_exn srs.hPositiveX diff
    else List.nth_exn srs.hNegativeX (abs diff - 1)
  in
  let first =
    Fq_target.( * )
      (Pairing.reduced_pairing w (List.nth_exn srs.hPositiveAlphaX 1))
      (Pairing.reduced_pairing
         (G1.( + )
            (G1.scale G1.one (Fr.to_bigint v))
            (G1.scale w (Fr.to_bigint (Fr.negate z))))
         (List.hd_exn srs.hPositiveAlphaX))
  in
  let second = Pairing.reduced_pairing commitment hxi in
  Fq_target.equal first second
