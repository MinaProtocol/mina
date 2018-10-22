[%%import
"../../../../config.mlh"]

module Bignum_bigint = Bigint
open Core_kernel
open Snark_params.Tick
open Coda_spec

module Schnorr (Message : Signature_intf.Message.S) : Signature_intf.S with module Message = Message = struct
  type 'a shifted = (module Inner_curve.Checked.Shifted.S with type t = 'a)

  module Message = Message

  module Signature = struct
    type 'a t_ = 'a * 'a [@@deriving bin_io, eq, hash, sexp]

    type var = Inner_curve.Scalar.var t_

    type t = Inner_curve.Scalar.t t_ [@@deriving bin_io, eq, hash, sexp]

    let typ : (var, t) Typ.t =
      let typ = Inner_curve.Scalar.typ in
      Typ.tuple2 typ typ
  end

  module Private_key = struct
    type t = Inner_curve.Scalar.t
  end

  let compress (t: Inner_curve.t) =
    let x, _ = Inner_curve.to_coords t in
    Field.unpack x

  module Public_key : sig
    type t = Inner_curve.t

    type var = Inner_curve.var
  end = Inner_curve

  let sign (k: Private_key.t) m =
    let e_r = Inner_curve.Scalar.random () in
    let r = compress (Inner_curve.scale Inner_curve.one e_r) in
    let h = Message.hash ~nonce:r m in
    let s = Inner_curve.Scalar.(e_r - (k * h)) in
    (s, h)

  (* TODO: Have expect test for this *)
  let shamir_sum ((sp, p): Inner_curve.Scalar.t * Inner_curve.t)
      ((sq, q): Inner_curve.Scalar.t * Inner_curve.t) =
    let pq = Inner_curve.add p q in
    let rec go i acc =
      if i < 0 then acc
      else
        let acc = Inner_curve.double acc in
        let acc =
          match (Inner_curve.Scalar.test_bit sp i, Inner_curve.Scalar.test_bit sq i) with
          | true, false -> Inner_curve.add p acc
          | false, true -> Inner_curve.add q acc
          | true, true -> Inner_curve.add pq acc
          | false, false -> acc
        in
        go (i - 1) acc
    in
    go (Inner_curve.Scalar.length_in_bits - 1) Inner_curve.zero

  let verify ((s, h): Signature.t) (pk: Public_key.t) (m: Message.Payload.t) =
    let pre_r = shamir_sum (s, Inner_curve.one) (h, pk) in
    if Inner_curve.equal Inner_curve.zero pre_r then false
    else
      let r = compress pre_r in
      let h' = Message.hash ~nonce:r m in
      Inner_curve.Scalar.equal h' h

  [%%if
  log_calls]

  let verify s pk m =
    Coda_debug.Call_logger.record_call "Signature_lib.Schnorr.verify" ;
    if Random.int 1000 = 0 then (
      print_endline "SCHNORR BACKTRACE:" ;
      Printexc.print_backtrace stdout ) ;
    verify s pk m

  [%%endif]

  module Checked = struct
    let compress ((x, _): Inner_curve.var) =
      Field.Checked.choose_preimage_var x ~length:Field.size_in_bits

    open Let_syntax

    let verification_hash (type s)
        ((module Shifted) as shifted:
          (module Inner_curve.Checked.Shifted.S with type t = s))
        ((s, h): Signature.var) (public_key: Public_key.var) (m: Message.var) =
      with_label __LOC__
        (let%bind pre_r =
           (* s * g + h * public_key *)
           let%bind s_g =
             Inner_curve.Checked.scale_known shifted Inner_curve.one
               (Inner_curve.Scalar.Checked.to_bits s)
               ~init:Shifted.zero
           in
           let%bind s_g_h_pk =
             Inner_curve.Checked.scale shifted public_key
               (Inner_curve.Scalar.Checked.to_bits h)
               ~init:s_g
           in
           Shifted.unshift_nonzero s_g_h_pk
         in
         let%bind r = compress pre_r in
         Message.hash_checked m ~nonce:r)

    let verifies shifted ((_, h) as signature) pk m =
      with_label __LOC__
        ( verification_hash shifted signature pk m
        >>= Inner_curve.Scalar.Checked.equal h )

    let assert_verifies shifted ((_, h) as signature) pk m =
      with_label __LOC__
        ( verification_hash shifted signature pk m
        >>= Inner_curve.Scalar.Checked.Assert.equal h )
  end
end
