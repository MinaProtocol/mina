open Core

module type Scalar_field_intf = sig
  module Field : Field_intf.S

  module Bigint : sig
    type t

    val of_field : Field.t -> t
    val to_field : t -> Field.t

    val test_bit : t -> int -> bool
  end
end

module Schnorr
    (Impl : Snark_intf.S)
    (Scalar : Scalar_field_intf)
    (Curve : Curves.Edwards.S
     with type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
      and type Scalar.value = Scalar.Bigint.t
      and type ('a, 'b) typ := ('a, 'b) Impl.Typ.t
      and type boolean_var := Impl.Boolean.var
      and type var = Impl.Cvar.t * Impl.Cvar.t
      and type field := Impl.Field.t)
    (Hash : sig
       val hash : bool list -> Scalar.Field.t
       val hash_checked : Impl.Boolean.var list -> (Curve.Scalar.var, _) Impl.Checked.t
      end)
=
struct
  open Impl

  module Signature = struct
    type 'a t = 'a * 'a
    type var = Curve.Scalar.var t
    type value = Curve.Scalar.value t
    let typ : (var, value) Typ.t =
      let typ = Curve.Scalar.typ in
      Typ.tuple2 typ typ
  end

  module Private_key = struct
    type t = Scalar.Field.t
  end

  let compress ((x, _) : Curve.value) = Field.unpack x

  module Public_key : sig
    type var = Curve.var
    type value = Curve.value
    val typ : (var, value) Typ.t
  end = Curve

  let scale (x : Curve.value) (s : Scalar.Bigint.t) =
    let n = Scalar.Field.size_in_bits in
    let rec go i pt acc =
      if i >= n
      then acc
      else
        go (i + 1) (Curve.add pt pt)
          (if Scalar.Bigint.test_bit s i then Curve.add acc pt else acc)
    in
    go 0 x Curve.identity
  ;;

  let sign (k : Private_key.t) m =
    let e_r = Scalar.Field.random () in
    let r = compress (scale Curve.generator (Scalar.Bigint.of_field e_r)) in
    let h = Hash.hash (r @ m) in
    let s = Scalar.Field.(sub e_r (mul k h)) in
    (s, h)
  ;;

  (* TODO: Have expect test for this *)
  (* TODO: Have optimized double function *)
  let shamir_sum
        ((sp, p) : Scalar.Bigint.t * Curve.value)
        ((sq, q) : Scalar.Bigint.t * Curve.value)
    =
    let pq = Curve.add p q in
    let rec go i acc =
      if i < 0
      then acc
      else
        let acc = Curve.add acc acc in
        let acc =
          match Scalar.Bigint.test_bit sp i, Scalar.Bigint.test_bit sq i with
          | true, false -> Curve.add p acc
          | false, true -> Curve.add q acc
          | true, true -> Curve.add pq acc
          | false, false -> acc
        in
        go (i - 1) acc
    in
    go (Scalar.Field.size_in_bits - 1) Curve.identity

  let verify
        ((s, h) : Signature.value)
        (pk : Public_key.value)
        (m : bool list)
    =
    let r =
      compress (shamir_sum (s, Curve.generator) (h, pk))
    in
    Scalar.Field.equal (Hash.hash (r @ m)) (Scalar.Bigint.to_field h)
  ;;

  module Checked = struct
    let compress ((x, _) : Curve.var) = Checked.unpack x ~length:Field.size_in_bits

    let assert_verifies
          ((s, h) : Signature.var)
          (public_key : Public_key.var)
          (m : Boolean.var list)
      =
      let open Let_syntax in
      let%bind r =
        let%bind s_g = Curve.Checked.scale_known Curve.generator s
        and h_pk     = Curve.Checked.scale public_key h in
        Checked.bind ~f:compress (Curve.Checked.add s_g h_pk)
      in
      let%bind h' = Hash.hash_checked (r @ m) in
      Curve.Scalar.assert_equal h' h
    ;;
  end
end
