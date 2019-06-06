[%%import
"../../config.mlh"]

module Bignum_bigint = Bigint
open Core_kernel
open Tuple_lib
open Snarky

module type Message_intf = sig
  type boolean_var

  type curve_scalar

  type curve_scalar_var

  type (_, _) checked

  type t

  type var

  val to_bits : t -> bool list

  val hash : t -> nonce:bool Triple.t list -> curve_scalar

  val hash_checked :
    var -> nonce:boolean_var Triple.t list -> (curve_scalar_var, _) checked
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
    type t = bool list * curve_scalar [@@deriving sexp]

    type var = boolean_var list * curve_scalar_var

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
    val is_even : (boolean_var list, _) checked -> (boolean_var, _) checked

    val verification :
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
          val zero : t
          val order : t
          val field_order : t

          val ( * ) : t -> t -> t
          val ( + ) : t -> t -> t
          val ( - ) : t -> t -> t

          val to_bits : t -> bool list
          val of_bits : bool list -> t

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
        val subtract : t -> t -> t

        val double : t -> t

        val scale : t -> Scalar.t -> t

        val to_affine_coordinates : t -> Field.t * Field.t
        val is_on_curve : t -> bool
        val is_inf : t -> bool
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
    type t = Field.t * Curve.Scalar.t  [@@deriving sexp]
    type var = Field.Var.t * Curve.Scalar.var

    let typ : (var, t) Typ.t =
      Typ.tuple2 Field.typ Curve.Scalar.typ
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

  let is_even (t : Field.t) =
    not (Bigint.test_bit (Bigint.of_field t) 0)

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

    open Fold_lib

  (* use with Field.unpack for field elements, Curve.Scalar.to_bits with scalars... *)
  let to_triples x =
    Fold.to_list Fold.(group3 ~default:false (of_list x))

  let sign (d : Private_key.t) m =
    let nonce = to_triples (Curve.Scalar.to_bits d) in
    let k_prime = Message.hash m ~nonce in
    assert (not (Curve.Scalar.(equal k_prime zero))) ;
    let r_point = Curve.scale Curve.one k_prime in
    let yr = get_y r_point in
    let k =
    if is_even yr then k_prime
    else Curve.Scalar.(order - k_prime)
    in
    let nonce = to_triples ((compress r_point) @ compress (Curve.scale Curve.one d)) in
    let e = Message.hash m ~nonce in
    let s = Curve.Scalar.(k + e * d) in
    (get_x r_point, s)

  let verify ((r, s) : Signature.t) (pk : Public_key.t) (m : Message.t) =
    let nonce = to_triples (Field.unpack r @ (compress pk)) in
    let e = Message.hash m ~nonce in
    let r_point = Curve.(subtract (scale one s) (scale pk e)) in
    (not Curve.(equal zero r_point)) && (is_even (get_y r_point)) &&
    Field.(equal (get_x r_point) r)

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
    open Impl.Let_syntax

    let compress ((x, _) : Curve.var) =
      Field.Checked.choose_preimage_var x ~length:Field.size_in_bits
    let to_bits x =
      Field.Checked.choose_preimage_var x ~length:Field.size_in_bits
    let to_triples x = Fold.to_list Fold.(group3 ~default:Boolean.false_ x)

    let y_even ((_, y) : Curve.var) =
      let%map bs = Field.Checked.unpack_full y in
      List.hd_exn (Bitstring_lib.Bitstring.Lsb_first.to_list bs)
      >>= Boolean.Assert.(( = ) Boolean.true_ )


    (* returning r_point as a representable point ensures it is nonzero so the nonzero
     * check does not have to explicitly be performed *)

    let%snarkydef verification (type s)
        ((module Shifted) as shifted :
          (module Curve.Checked.Shifted.S with type t = s))
        ((r, s) : Signature.var)
        (public_key : Public_key.var)
        (m : Message.var) =
    let%bind nonce = to_triples ((to_bits r) @ (compress pk)) in
    let%bind e = Message.hash_checked m ~nonce in
        (* s * g - e * public_key *)
        let%bind e_pk =
          Curve.Checked.scale shifted public_key
            (Curve.Scalar.Checked.to_bits e)
            ~init:Shifted.zero in
        let%bind s_g_e_pk =
          Curve.Checked.scale_known shifted Curve.one
            (Curve.Scalar.Checked.to_bits s)
            ~init:(Curve.Checked.negate e_pk)
        in
        compress (Shifted.unshift_nonzero s_g_e_pk)

    let%snarkydef verifies shifted ((r, s) as signature) pk m =
      verification shifted signature pk m
      >>= Field.Checked.equal r

    let%snarkydef assert_verifies shifted ((r, s) as signature) pk m =
      verification shifted signature pk m
      >>= Field.Checked.Assert.equal r

  end
end
