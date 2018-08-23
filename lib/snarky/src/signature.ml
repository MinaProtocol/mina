module Bignum_bigint = Bigint
open Core_kernel

module Schnorr
    (Impl : Snark_intf.S)
    (*Curve : Curves.Edwards.S
             with type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
              and type Scalar.t = Bignum_bigint.t
              and type ('a, 'b) typ := ('a, 'b) Impl.Typ.t
              and type boolean_var := Impl.Boolean.var
              and type var = Impl.Field.Checked.t * Impl.Field.Checked.t
              and type field := Impl.Field.t*)
    (Curve : sig
       open Impl

       module Scalar : sig
         type t [@@deriving sexp, eq]
         type var
         val typ : (var, t) Typ.t
         val random : unit -> t
         val ( * ) : t -> t -> t
         val (+) : t -> t -> t
         val (-) : t -> t -> t

         val test_bit : t -> int -> bool

         val length_in_bits : int
         module Checked : sig
          val equal : var -> var -> (Boolean.var, _) Checked.t
          module Assert : sig val equal : var -> var -> (unit, _) Checked.t end
         end
       end

       type t
       type var = Field.Checked.t * Field.Checked.t

       module Checked : sig
         val add : var -> var -> (var, _) Checked.t
         val scale : var -> Scalar.var -> (var, _) Checked.t
         val scale_known : t -> Scalar.var -> (var, _) Checked.t
       end

       val one : t
       val zero : t

       val add : t -> t -> t

       val typ : (var, t) Typ.t

       val scale : t -> Scalar.t -> t

       val to_coords : t -> Field.t * Field.t
    end)
    (Message : sig
        type t

        type var

        val hash : t -> nonce:bool list -> Curve.Scalar.t

        val hash_checked :
             var
          -> nonce:Impl.Boolean.var list
          -> (Curve.Scalar.var, _) Impl.Checked.t
    end) =
struct
  open Impl

  module Signature = struct
    type 'a t_ = 'a * 'a [@@deriving eq, sexp]

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
    let (x, _) = Curve.to_coords t in
    Field.unpack x

  module Public_key : sig
    type var = Curve.var

    type t = Curve.t

    val typ : (var, t) Typ.t
  end = Curve

  let sign (k: Private_key.t) m =
    let e_r = Curve.Scalar.random () in
    let r = compress (Curve.scale Curve.one e_r) in
    let h = Message.hash ~nonce:r m in
    let s = Curve.Scalar.(e_r - (k * h)) in
    (s, h)

  (* TODO: Have expect test for this *)
  (* TODO: Have optimized double function *)
  let shamir_sum
        ((sp, p): Curve.Scalar.t * Curve.t)
        ((sq, q): Curve.Scalar.t * Curve.t) =
    let pq = Curve.add p q in
    let rec go i acc =
      if i < 0 then acc
      else
        let acc = Curve.add acc acc in
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

  let verify ((s, h): Signature.t) (pk: Public_key.t) (m: Message.t) =
    let r = compress (shamir_sum (s, Curve.one) (h, pk)) in
    let h' = Message.hash ~nonce:r m in
    Curve.Scalar.equal h' h

  module Keypair = struct
    type t = {public: Public_key.t; secret: Private_key.t}
  end

  module Checked = struct
    let compress ((x, _): Curve.var) =
      Field.Checked.choose_preimage_var x ~length:Field.size_in_bits

    open Impl.Let_syntax

    let verification_hash ((s, h): Signature.var) (public_key: Public_key.var)
        (m: Message.var) =
      with_label __LOC__
        (let%bind r =
           let%bind s_g = Curve.Checked.scale_known Curve.one s
           and h_pk = Curve.Checked.scale public_key h in
           Checked.bind ~f:compress (Curve.Checked.add s_g h_pk)
         in
         Message.hash_checked m ~nonce:r)

    let verifies ((_, h) as signature) pk m =
      with_label __LOC__
        (verification_hash signature pk m >>= Curve.Scalar.Checked.equal h)

    let assert_verifies ((_, h) as signature) pk m =
      with_label __LOC__
        ( verification_hash signature pk m
        >>= Curve.Scalar.Checked.Assert.equal h )
  end
end
