[%%import
"../../config.mlh"]

module Bignum_bigint = Bigint
open Core_kernel
open Snarky

module type Message_intf = sig
  type boolean_var

  type curve_scalar

  type curve_scalar_var

  type (_, _) checked

  type t

  type var

  val hash : t -> nonce:bool list -> curve_scalar

  val hash_checked :
    var -> nonce:boolean_var list -> (curve_scalar_var, _) checked
end

module type S = sig
  type boolean_var

  type curve

  type curve_var

  type curve_scalar

  type curve_scalar_var

  type (_, _) checked

  type (_, _) typ

  module Shifted : sig
    module type S =
      Curves.Shifted_intf
      with type curve_var := curve_var
       and type boolean_var := boolean_var
       and type ('a, 'b) checked := ('a, 'b) checked
  end

  module Message :
    Message_intf
    with type boolean_var := boolean_var
     and type curve_scalar := curve_scalar
     and type curve_scalar_var := curve_scalar_var
     and type ('a, 'b) checked := ('a, 'b) checked

  module Signature : sig
    type t = curve_scalar * curve_scalar [@@deriving sexp]

    type var = curve_scalar_var * curve_scalar_var

    val typ : (var, t) typ
  end

  module Private_key : sig
    type t = curve_scalar
  end

  module Public_key : sig
    type t = curve

    type var = curve_var
  end

  module Checked : sig
    val compress : curve_var -> (boolean_var list, _) checked

    val verification_hash :
         (module Shifted.S with type t = 't)
      -> Signature.var
      -> Public_key.var
      -> Message.var
      -> (curve_scalar_var, _) checked

    val verifies :
         (module Shifted.S with type t = 't)
      -> Signature.var
      -> Public_key.var
      -> Message.var
      -> (boolean_var, _) checked

    val assert_verifies :
         (module Shifted.S with type t = 't)
      -> Signature.var
      -> Public_key.var
      -> Message.var
      -> (unit, _) checked
  end

  val compress : curve -> bool list

  val sign : Private_key.t -> Message.t -> Signature.t

  val shamir_sum : curve_scalar * curve -> curve_scalar * curve -> curve

  val verify : Signature.t -> Public_key.t -> Message.t -> bool
end

module Schnorr
    (Impl : Snark_intf.S) (Curve : sig
        open Impl

        module Scalar : sig
          type t [@@deriving sexp, eq]

          type var

          val typ : (var, t) Typ.t

          val random : unit -> t

          val ( * ) : t -> t -> t

          val ( - ) : t -> t -> t

          val test_bit : t -> int -> bool

          val length_in_bits : int

          module Checked : sig
            val equal : var -> var -> (Boolean.var, _) Checked.t

            val to_bits :
              var -> Boolean.var Bitstring_lib.Bitstring.Lsb_first.t

            module Assert : sig
              val equal : var -> var -> (unit, _) Checked.t
            end
          end
        end

        type t [@@deriving eq]

        type var = Field.Checked.t * Field.Checked.t

        module Checked :
          Curves.Weierstrass_checked_intf
          with module Impl := Impl
           and type t := t
           and type var := var

        val one : t

        val zero : t

        val add : t -> t -> t

        val double : t -> t

        val scale : t -> Scalar.t -> t

        val to_coords : t -> Field.t * Field.t
    end)
    (Message : Message_intf
               with type boolean_var := Impl.Boolean.var
                and type curve_scalar_var := Curve.Scalar.var
                and type curve_scalar := Curve.Scalar.t
                and type ('a, 'b) checked := ('a, 'b) Impl.Checked.t) :
  S
  with type boolean_var := Impl.Boolean.var
   and type curve := Curve.t
   and type curve_var := Curve.var
   and type curve_scalar := Curve.Scalar.t
   and type curve_scalar_var := Curve.Scalar.var
   and type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
   and type ('a, 'b) typ := ('a, 'b) Impl.Typ.t
   and module Shifted := Curve.Checked.Shifted
   and module Message := Message = struct
  open Impl

  module Signature = struct
    type 'a t_ = 'a * 'a [@@deriving sexp]

    type var = Curve.Scalar.var t_

    type t = Curve.Scalar.t t_ [@@deriving sexp]

    let typ : (var, t) Typ.t =
      let typ = Curve.Scalar.typ in
      Typ.tuple2 typ typ
  end

  module Private_key = struct
    type t = Curve.Scalar.t
  end

  let compress (t : Curve.t) =
    let x, _ = Curve.to_coords t in
    Field.unpack x

  module Public_key : sig
    type t = Curve.t

    type var = Curve.var
  end =
    Curve

  let sign (k : Private_key.t) m =
    let e_r = Curve.Scalar.random () in
    let r = compress (Curve.scale Curve.one e_r) in
    let h = Message.hash ~nonce:r m in
    let s = Curve.Scalar.(e_r - (k * h)) in
    (s, h)

  (* TODO: Have expect test for this *)
  let shamir_sum ((sp, p) : Curve.Scalar.t * Curve.t)
      ((sq, q) : Curve.Scalar.t * Curve.t) =
    let pq = Curve.add p q in
    let rec go i acc =
      if i < 0 then acc
      else
        let acc = Curve.double acc in
        let acc =
          match (Curve.Scalar.test_bit sp i, Curve.Scalar.test_bit sq i) with
          | true, false -> Curve.add p acc
          | false, true -> Curve.add q acc
          | true, true -> Curve.add pq acc
          | false, false -> acc
        in
        go (i - 1) acc
    in
    go (Curve.Scalar.length_in_bits - 1) Curve.zero

  let verify ((s, h) : Signature.t) (pk : Public_key.t) (m : Message.t) =
    let pre_r = shamir_sum (s, Curve.one) (h, pk) in
    if Curve.equal Curve.zero pre_r then false
    else
      let r = compress pre_r in
      let h' = Message.hash ~nonce:r m in
      Curve.Scalar.equal h' h

  [%%if
  call_logger]

  let verify s pk m =
    Coda_debug.Call_logger.record_call "Signature_lib.Schnorr.verify" ;
    if Random.int 1000 = 0 then (
      print_endline "SCHNORR BACKTRACE:" ;
      Printexc.print_backtrace stdout ) ;
    verify s pk m

  [%%endif]

  module Checked = struct
    let compress ((x, _) : Curve.var) =
      Field.Checked.choose_preimage_var x ~length:Field.size_in_bits

    open Impl.Let_syntax

    let verification_hash (type s)
        ((module Shifted) as shifted :
          (module Curve.Checked.Shifted.S with type t = s))
        ((s, h) : Signature.var) (public_key : Public_key.var)
        (m : Message.var) =
      with_label __LOC__
        (let%bind pre_r =
           (* s * g + h * public_key *)
           let%bind s_g =
             Curve.Checked.scale_known shifted Curve.one
               (Curve.Scalar.Checked.to_bits s)
               ~init:Shifted.zero
           in
           let%bind s_g_h_pk =
             Curve.Checked.scale shifted public_key
               (Curve.Scalar.Checked.to_bits h)
               ~init:s_g
           in
           Shifted.unshift_nonzero s_g_h_pk
         in
         let%bind r = compress pre_r in
         Message.hash_checked m ~nonce:r)

    let verifies shifted ((_, h) as signature) pk m =
      with_label __LOC__
        ( verification_hash shifted signature pk m
        >>= Curve.Scalar.Checked.equal h )

    let assert_verifies shifted ((_, h) as signature) pk m =
      with_label __LOC__
        ( verification_hash shifted signature pk m
        >>= Curve.Scalar.Checked.Assert.equal h )
  end
end
