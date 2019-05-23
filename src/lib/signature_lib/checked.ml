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

  module Field : sig
    type t
    val equal : t -> t -> bool
  end

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
    val get_x : curve_var -> field_var
    val get_y : curve_var -> field_var
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

  val get_x : curve -> Field.t
  val get_y curve -> Field.t
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

        type var = Field.Var.t * Field.Var.t

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

        val to_affine_coordinates : t -> Field.t * Field.t
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

  let get_x (t : Curve.t) =
    let x, _ = Curve.to_affine_coordinates t in
    x

  let get_y (t : Curve.t) =
    let _, y = Curve.to_affine_coordinates t in
    y

  let compress (t : Curve.t) =
    let x, _ = Curve.to_affine_coordinates t in
    Field.unpack x

  let get_x_bits (t : Curve.t) =
    Field.unpack get_x t

  let get_y (t : Curve.t) =
    Field.unpack get_y t

  module Public_key : sig
    type t = Curve.t

    type var = Curve.var
  end =
    Curve

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
          | true, false ->
              Curve.add p acc
          | false, true ->
              Curve.add q acc
          | true, true ->
              Curve.add pq acc
          | false, false ->
              acc
        in
        go (i - 1) acc
    in
    go (Curve.Scalar.length_in_bits - 1) Curve.zero

  let sign (d : Private_key.t) m =
    let k_prime =
      ((Curve.Scalar.to_bits d) @ (Message.to_bits m))
          |> Blake2.bits_to_string
          |> Random_oracle.digest_string
          (* TODO : should Random_oracle.digest_bits exist ?
           * currently only Random_oracle.Checked.digest_bits is defined *)
          |> Curve.Scalar.of_bits
    in
    assert (not Curve.Scalar.(equal k_prime zero)) ;
    (* TODO : should this be an if/else instead ? *)
    let r_point = Curve.scale Curve.one k_prime in
    let yr = get_y r_point in
    let k =
      (* TODO : is this testing that y is even? *)
    if Bigint.(test_bit (of_field y) 0) then k_prime
    else Curve.Scalar.(order - k_prime) in
    let e = (get_x_bits r_point) @ (compress Curve.scale Curve.one d) @ (Message.to_bits m) in
    let s = Curve.Scalar.(k + (e * d)) in
    (get_x r_point, s)

  let verify ((r, s) : Signature.t) (pk : Public_key.t) (m : Message.t) =
    assert (Curve.is_on_curve pk) ;
    assert (r < Curve.field_order) ;
    assert (Curve.Scalar.(s < order)) ;
    let r_point = Curve.(scale one s - scale pk e) in
    assert (not Curve.(equal inf r_point)) ;
    assert (Bigint.(test_bit (of_field y) 0)) ;
    assert (Field.equal (get_x r_point) r) ;

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

    let%snarkydef verification_hash (type s)
        ((module Shifted) as shifted :
          (module Curve.Checked.Shifted.S with type t = s))
        ((s, h) : Signature.var) (public_key : Public_key.var)
        (m : Message.var) =
      let%bind pre_r =
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
      Message.hash_checked m ~nonce:r

    let%snarkydef verifies shifted ((_, h) as signature) pk m =
      verification_hash shifted signature pk m >>= Curve.Scalar.Checked.equal h

    let%snarkydef assert_verifies shifted ((_, h) as signature) pk m =
      verification_hash shifted signature pk m
      >>= Curve.Scalar.Checked.Assert.equal h
  end
end
