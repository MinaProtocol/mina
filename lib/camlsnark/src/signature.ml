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


module Make
    (Impl : Snark_intf.S)
= struct
module Curve_intf = Curves.Make_intf(Impl)

open Impl

module Schnorr
    (Scalar : Scalar_field_intf)
    (Curve : Curve_intf.S with type Scalar.value = Scalar.Bigint.t)
    (Hash : sig
       val hash : bool list -> Scalar.Field.t
       val hash_checked : Boolean.var list -> (Curve.Scalar.var, _) Impl.Checked.t
     end)
=
struct
  (* There is a subtle issue to be aware of around doing multi-sums.
     A signature is a pair (s, e) and to verify we compute

     s * generator + e * public_key.

     to do a multisum we need to have an initial value init != identity. I.e., we can
     only compute

     s * generator + e * public_key + init.

     One of of doing this is to have a fixed initial value in the signature scheme.
     This is probably fine but it's a little non-standard. Also, it can NEVER be allowed
     that one of the intermediate sums
     in the computation of

     s * generator + e * public_key + init

     is = identity. This can be avoided by considering as invalid any signature that has that property.
     This is annoying to check in practice, since it means sacrificing shamir's trick.
  *)

  module Public_key = struct
    type 'a t = 'a Curve.t
    type var = Cvar.t t
    type value = Field.t t
    let typ = Curve.typ

    let equal = Curve.equal

    module Checked = struct
      let assert_equal = Curve.Checked.assert_equal
    end
  end

  type point_or_identity =
    [ `Identity
    | `Point of Curve.value
    ]

  let point_exn : point_or_identity -> Curve.value = function
    | `Identity -> failwith "point_exn"
    | `Point x -> x

  let add_curve_point (t1 : point_or_identity) c2 =
    match t1 with
    | `Identity -> `Point c2
    | `Point c1 -> `Point (Curve.add c1 c2)

  let exp g e =
    let rec go acc pt i =
      if i = Scalar.Field.size_in_bits
      then acc
      else
        let acc =
          if Scalar.Bigint.test_bit e i
          then add_curve_point acc pt
          else acc
        in
        go acc (Curve.double pt) (i + 1)
    in
    go `Identity g 0
  ;;

  let init =
    point_exn (exp Curve.generator (Scalar.Bigint.of_field (Scalar.Field.random ())))
  ;;

  let rec create_private_key () =
    let x = Scalar.Field.random () in
    if Scalar.Field.(equal x zero)
    then create_private_key ()
    else x
  ;;

  let create_public_key sk =
    match exp Curve.generator (Scalar.Bigint.of_field sk) with
    | `Identity -> failwith "Schnorr.create_public_key: Invalid private key"
    | `Point p -> p
  ;;

  let prepend_curve_to_bits =
    let field_to_bits x acc0 =
      let n = Bigint.of_field x in
      let rec go i acc =
        if i < 0
        then acc
        else go (i - 1) (Bigint.test_bit n i :: acc)
      in
      go (Field.size_in_bits - 1) acc0
    in
    fun (x, y) acc0 -> field_to_bits x (field_to_bits y acc0)
  ;;

  module Signature = struct
    type 'a t = 'a * 'a
    type var = Curve.Scalar.var t
    type value = Curve.Scalar.value t
    let typ : (var, value) Typ.t =
      Typ.tuple2 Curve.Scalar.typ Curve.Scalar.typ
  end

  let sign sk m : Signature.value =
    let k, r =
      let rec go () =
        let k = Scalar.Bigint.of_field (Scalar.Field.random ()) in
        let r = exp Curve.generator k in
        match r with
        | `Identity -> go ()
        | `Point r -> (Scalar.Bigint.to_field k, r)
      in
      go ()
    in
    let hr = Curve.add init r in
    let e = Hash.hash (prepend_curve_to_bits hr m) in
    let s = Scalar.Field.(sub k (mul sk e)) in
    Scalar.Bigint.(of_field s, of_field e)
  ;;

  module Checked = struct
    let init : Curve.var = Curve.value_to_var init

    let curve_to_bits ((x, y) : Curve.var) =
      with_label "Schnorr.Checked.curve_to_bits" begin
        let open Let_syntax in
        let%map xb = Checked.unpack x ~length:Field.size_in_bits
        and yb = Checked.unpack y ~length:Field.size_in_bits in
        xb @ yb
      end
    ;;

    let assert_verifies
          (* Make one of s, e a non-zero number. *)
          ((s, e) : Signature.var)
          (public_key : Public_key.var)
          (m : Boolean.var list)
      =
      with_label "Schnorr.Checked.assert_verifies" begin
        let open Let_syntax in
        let%bind hr = Curve.Checked.multi_sum [ (s, Curve.Checked.generator); (e, public_key) ] ~init in
        let%bind r_bits = curve_to_bits hr in
        let%bind h = Hash.hash_checked (r_bits @ m) in
        Curve.Scalar.assert_equal h e
      end
    ;;

  end

end
end

