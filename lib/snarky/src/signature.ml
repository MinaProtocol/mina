module Bignum_bigint = Bigint
open Core_kernel

module Schnorr
    (Impl : Snark_intf.S)
    (Curve : Curves.Edwards.S
             with type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
              and type Scalar.value = Bignum_bigint.t
              and type ('a, 'b) typ := ('a, 'b) Impl.Typ.t
              and type boolean_var := Impl.Boolean.var
              and type var = Impl.Field.Checked.t * Impl.Field.Checked.t
              and type field := Impl.Field.t) (Message : sig
        type t

        type var

        val hash : t -> nonce:bool list -> Bignum_bigint.t

        val hash_checked :
             var
          -> nonce:Impl.Boolean.var list
          -> (Curve.Scalar.var, _) Impl.Checked.t
    end) =
struct
  open Impl
  module Scalar = Bignum_bigint

  module Signature = struct
    type 'a t = 'a * 'a [@@deriving eq, sexp]

    type var = Curve.Scalar.var t

    type value = Curve.Scalar.value t

    let typ : (var, value) Typ.t =
      let typ = Curve.Scalar.typ in
      Typ.tuple2 typ typ
  end

  module Private_key = struct
    type t = Scalar.t [@@deriving bin_io]
  end

  let compress ((x, _): Curve.value) = Field.unpack x

  module Public_key : sig
    type var = Curve.var

    type value = Curve.value

    val typ : (var, value) Typ.t
  end = Curve

  let sign (k: Private_key.t) m =
    let e_r = Scalar.random Curve.Params.order in
    let r = compress (Curve.scale Curve.generator e_r) in
    let h = Message.hash ~nonce:r m in
    let s = Scalar.((e_r - (k * h)) % Curve.Params.order) in
    (s, h)

  (* TODO: Have expect test for this *)
  (* TODO: Have optimized double function *)
  let shamir_sum ((sp, p): Scalar.t * Curve.value)
      ((sq, q): Scalar.t * Curve.value) =
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
    go (Curve.Scalar.length - 1) Curve.identity

  let verify ((s, h): Signature.value) (pk: Public_key.value) (m: Message.t) =
    let r = compress (shamir_sum (s, Curve.generator) (h, pk)) in
    let h' = Message.hash ~nonce:r m in
    Scalar.equal h' h

  module Keypair = struct
    type t = {public: Public_key.value; secret: Private_key.t}

    let create () =
      (* TODO: More secure random *)
      let x = Bignum_bigint.random Curve.Params.order in
      {public= Curve.scale Curve.generator x; secret= x}
  end

  module Checked = struct
    let compress ((x, _): Curve.var) =
      Field.Checked.choose_preimage_var x ~length:Field.size_in_bits

    open Impl.Let_syntax

    let verification_hash ((s, h): Signature.var) (public_key: Public_key.var)
        (m: Message.var) =
      with_label __LOC__
        (let%bind r =
           let%bind s_g = Curve.Checked.scale_known Curve.generator s
           and h_pk = Curve.Checked.scale public_key h in
           Checked.bind ~f:compress (Curve.Checked.add s_g h_pk)
         in
         Message.hash_checked m ~nonce:r)

    let verifies ((_, h) as signature) pk m =
      with_label __LOC__
        (verification_hash signature pk m >>= Curve.Scalar.equal h)

    let assert_verifies ((_, h) as signature) pk m =
      with_label __LOC__
        (verification_hash signature pk m >>= Curve.Scalar.assert_equal h)
  end
end
