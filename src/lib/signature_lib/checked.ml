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

  val hash : t -> nonce:bool Triple.t list -> curve_scalar

  val hash_checked :
    var -> nonce:boolean_var Triple.t list -> (curve_scalar_var, _) checked
end

module type S = sig
  module Impl : Snark_intf.S

  open Impl

  type curve

  type curve_var

  type curve_scalar

  type curve_scalar_var

  module Shifted : sig
    module type S =
      Snarky_curves.Shifted_intf
      with module Impl := Impl
       and type curve_var := curve_var
  end

  module Message :
    Message_intf
    with type boolean_var := Boolean.var
     and type curve_scalar := curve_scalar
     and type curve_scalar_var := curve_scalar_var
     and type ('a, 'b) checked := ('a, 'b) Checked.t

  module Signature : sig
    type t = field * curve_scalar [@@deriving sexp]

    type var = Field.Var.t * curve_scalar_var

    val typ : (var, t) Typ.t
  end

  module Private_key : sig
    type t = curve_scalar
  end

  module Public_key : sig
    type t = curve

    type var = curve_var
  end

  module Checked : sig
    val compress : curve_var -> (Boolean.var list, _) Checked.t

    val verifies :
         (module Shifted.S with type t = 't)
      -> Signature.var
      -> Public_key.var
      -> Message.var
      -> (Boolean.var, _) Checked.t

    val assert_verifies :
         (module Shifted.S with type t = 't)
      -> Signature.var
      -> Public_key.var
      -> Message.var
      -> (unit, _) Checked.t
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

          val zero : t

          val ( * ) : t -> t -> t

          val ( + ) : t -> t -> t

          val negate : t -> t

          val unpack : t -> bool list

          module Checked : sig
            val to_bits :
              var -> Boolean.var Bitstring_lib.Bitstring.Lsb_first.t
          end
        end

        type t [@@deriving eq]

        type var = Field.Var.t * Field.Var.t

        module Checked :
          Snarky_curves.Weierstrass_checked_intf
          with module Impl := Impl
           and type t = var
           and type unchecked := t

        val one : t

        val zero : t

        val ( + ) : t -> t -> t

        val negate : t -> t

        val scale : t -> Scalar.t -> t

        val to_affine_exn : t -> Field.t * Field.t
    end)
    (Message : Message_intf
               with type boolean_var := Impl.Boolean.var
                and type curve_scalar_var := Curve.Scalar.var
                and type curve_scalar := Curve.Scalar.t
                and type ('a, 'b) checked := ('a, 'b) Impl.Checked.t) :
  S
  with module Impl := Impl
   and type curve := Curve.t
   and type curve_var := Curve.var
   and type curve_scalar := Curve.Scalar.t
   and type curve_scalar_var := Curve.Scalar.var
   and module Shifted := Curve.Checked.Shifted
   and module Message := Message = struct
  open Impl

  module Signature = struct
    type t = Field.t * Curve.Scalar.t [@@deriving sexp]

    type var = Field.Var.t * Curve.Scalar.var

    let typ : (var, t) Typ.t = Typ.tuple2 Field.typ Curve.Scalar.typ
  end

  module Private_key = struct
    type t = Curve.Scalar.t
  end

  let compress (t : Curve.t) =
    let x, _ = Curve.to_affine_exn t in
    Field.unpack x

  let is_even (t : Field.t) = not (Bigint.test_bit (Bigint.of_field t) 0)

  module Public_key : sig
    type t = Curve.t

    type var = Curve.var
  end =
    Curve

  open Fold_lib

  let to_triples x = Fold.to_list Fold.(group3 ~default:false (of_list x))

  let sign (d : Private_key.t) m =
    let nonce = to_triples (Curve.Scalar.unpack d) in
    let k_prime = Message.hash m ~nonce in
    assert (not Curve.Scalar.(equal k_prime zero)) ;
    let r_pt = Curve.scale Curve.one k_prime in
    let rx, ry = Curve.to_affine_exn r_pt in
    let k = if is_even ry then k_prime else Curve.Scalar.negate k_prime in
    let nonce =
      to_triples (compress r_pt @ compress (Curve.scale Curve.one d))
    in
    let e = Message.hash m ~nonce in
    let s = Curve.Scalar.(k + (e * d)) in
    (rx, s)

  let verify ((r, s) : Signature.t) (pk : Public_key.t) (m : Message.t) =
    let nonce = to_triples (Field.unpack r @ compress pk) in
    let e = Message.hash m ~nonce in
    let r_pt = Curve.(scale one s + negate (scale pk e)) in
    let rx, ry = Curve.to_affine_exn r_pt in
    (not Curve.(equal zero r_pt)) && is_even ry && Field.(equal rx r)

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
    let to_bits x =
      Field.Checked.choose_preimage_var x ~length:Field.size_in_bits

    let compress ((x, _) : Curve.var) = to_bits x

    let to_triples x =
      Fold.to_list Fold.(group3 ~default:Boolean.false_ (of_list x))

    let is_even y =
      let%map bs = Field.Checked.unpack_full y in
      Bitstring_lib.Bitstring.Lsb_first.to_list bs
      |> List.hd_exn |> Boolean.not

    (* returning r_point as a representable point ensures it is nonzero so the nonzero
     * check does not have to explicitly be performed *)

    let%snarkydef verifier (type s) ~equal ~final_check
        ((module Shifted) as shifted :
          (module Curve.Checked.Shifted.S with type t = s))
        ((r, s) : Signature.var) (public_key : Public_key.var)
        (m : Message.var) =
      let%bind pk_bits = compress public_key in
      let%bind r_bits = to_bits r in
      let nonce = to_triples (r_bits @ pk_bits) in
      let%bind e = Message.hash_checked m ~nonce in
      (* s * g - e * public_key *)
      let%bind e_pk =
        Curve.Checked.scale shifted
          (Curve.Checked.negate public_key)
          (Curve.Scalar.Checked.to_bits e)
          ~init:Shifted.zero
      in
      let%bind s_g_e_pk =
        Curve.Checked.scale_known shifted Curve.one
          (Curve.Scalar.Checked.to_bits s)
          ~init:e_pk
      in
      let%bind rx, ry = Shifted.unshift_nonzero s_g_e_pk in
      let%bind y_even = is_even ry in
      let%bind r_correct = equal r rx in
      final_check r_correct y_even

    let verifies s =
      verifier ~equal:Field.Checked.equal ~final_check:Boolean.( && ) s

    let assert_verifies s =
      verifier ~equal:Field.Checked.Assert.equal
        ~final_check:(fun () ry_even -> Boolean.Assert.is_true ry_even)
        s
  end
end

open Snark_params

module Message = struct
  include Tick.Field

  type var = Tick.Field.Var.t

  let hash t ~nonce =
    Random_oracle.digest_field
      (Tick.Pedersen.digest_fold
         (Tick.Pedersen.State.create ())
         (Fold_lib.Fold.of_list
            ( nonce
            @ Bitstring_lib.Bitstring.pad_to_triple_list ~default:false
                (Tick.Field.unpack t) )))
    |> Random_oracle.Digest.to_bits |> Array.to_list |> Tock.Field.project

  let hash_checked t ~nonce =
    let open Tick.Checked.Let_syntax in
    let%bind bits = Checked.choose_preimage_var ~length:size_in_bits t in
    Tick.Pedersen.Checked.digest_triples
      ~init:(Tick.Pedersen.State.create ())
      ( nonce
      @ Bitstring_lib.Bitstring.pad_to_triple_list ~default:Tick.Boolean.false_
          bits )
    >>= Random_oracle.Checked.digest_field
    >>| Random_oracle.Digest.Checked.to_bits >>| Array.to_list
    >>| Bitstring_lib.Bitstring.Lsb_first.of_list
end

module S = Schnorr (Tick) (Tick.Inner_curve) (Message)

let gen =
  let open Quickcheck.Let_syntax in
  let%map pk = Private_key.gen and msg = Message.gen in
  (pk, msg)

let%test_unit "schnorr checked + unchecked" =
  Quickcheck.test ~trials:5 gen ~f:(fun (pk, msg) ->
      let s = S.sign pk msg in
      let pubkey = Tick.Inner_curve.(scale one pk) in
      assert (S.verify s pubkey msg) ;
      (Tick.Test.test_equal ~sexp_of_t:[%sexp_of: bool] ~equal:Bool.equal
         Tick.Typ.(tuple3 Tick.Inner_curve.typ Message.typ S.Signature.typ)
         Tick.Boolean.typ
         (fun (public_key, msg, s) ->
           let open Tick.Checked in
           let%bind (module Shifted) =
             Tick.Inner_curve.Checked.Shifted.create ()
           in
           S.Checked.verifies (module Shifted) s public_key msg )
         (fun _ -> true))
        (pubkey, msg, s) )
