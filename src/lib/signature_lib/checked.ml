[%%import
"../../config.mlh"]

module Bignum_bigint = Bigint
open Core_kernel
open Snarky

module type Message_intf = sig
  type field

  type field_var

  type boolean_var

  type curve

  type curve_var

  type curve_scalar

  type curve_scalar_var

  type (_, _) checked

  type t

  type var

  val derive :
    t -> private_key:curve_scalar -> public_key:curve -> curve_scalar

  val hash : t -> public_key:curve -> r:field -> curve_scalar

  val hash_checked :
    var -> public_key:curve_var -> r:field_var -> (curve_scalar_var, _) checked
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
      with type curve_var := curve_var
       and type boolean_var := Boolean.var
       and type ('a, 'b) checked := ('a, 'b) Checked.t
  end

  module Message :
    Message_intf
    with type boolean_var := Boolean.var
     and type curve_scalar := curve_scalar
     and type curve_scalar_var := curve_scalar_var
     and type ('a, 'b) checked := ('a, 'b) Checked.t
     and type curve := curve
     and type curve_var := curve_var
     and type field := Field.t
     and type field_var := Field.Var.t

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

          module Checked : sig
            val to_bits :
              var -> Boolean.var Bitstring_lib.Bitstring.Lsb_first.t
          end
        end

        type t

        type var = Field.Var.t * Field.Var.t

        module Checked :
          Snarky_curves.Weierstrass_checked_intf
          with module Impl := Impl
           and type t = var
           and type unchecked := t

        val one : t

        val ( + ) : t -> t -> t

        val negate : t -> t

        val scale : t -> Scalar.t -> t

        val to_affine_exn : t -> Field.t * Field.t

        val to_affine : t -> (Field.t * Field.t) option
    end)
    (Message : Message_intf
               with type boolean_var := Impl.Boolean.var
                and type curve_scalar_var := Curve.Scalar.var
                and type curve_scalar := Curve.Scalar.t
                and type curve := Curve.t
                and type curve_var := Curve.var
                and type field := Impl.Field.t
                and type field_var := Impl.Field.Var.t
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

  let sign (d_prime : Private_key.t) m =
    let public_key =
      (* TODO: Don't recompute this. *) Curve.scale Curve.one d_prime
    in
    (* TODO: Once we switch to implicit sign-bit we'll have to conditionally negate d_prime. *)
    let d = d_prime in
    let k_prime = Message.derive m ~public_key ~private_key:d in
    assert (not Curve.Scalar.(equal k_prime zero)) ;
    let r, ry = Curve.(to_affine_exn (scale Curve.one k_prime)) in
    let k = if is_even ry then k_prime else Curve.Scalar.negate k_prime in
    let e = Message.hash m ~public_key ~r in
    let s = Curve.Scalar.(k + (e * d)) in
    (r, s)

  let verify ((r, s) : Signature.t) (pk : Public_key.t) (m : Message.t) =
    let e = Message.hash ~public_key:pk ~r m in
    let r_pt = Curve.(scale one s + negate (scale pk e)) in
    match Curve.to_affine r_pt with
    | None ->
        false
    | Some (rx, ry) ->
        is_even ry && Field.(equal rx r)

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
      let%bind e = Message.hash_checked m ~public_key ~r in
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

  let derive t ~private_key ~public_key =
    let input =
      let x, y = Tick.Inner_curve.to_affine_exn public_key in
      { Random_oracle.Input.field_elements= [|t; x; y|]
      ; bitstrings= [|Tock.Field.unpack private_key|] }
    in
    Tick.Field.unpack Random_oracle.(hash (pack_input input))
    |> Tock.Field.project

  let hash t ~public_key ~r =
    let x, y = Tick.Inner_curve.to_affine_exn public_key in
    Tick.Field.unpack Random_oracle.(hash [|t; r; x; y|]) |> Tock.Field.project

  let hash_checked t ~public_key ~r =
    Tick.make_checked (fun () ->
        let x, y = public_key in
        Random_oracle.Checked.hash [|t; r; x; y|]
        |> Tick.Run.Field.choose_preimage_var ~length:Tick.Field.size_in_bits
        |> Bitstring_lib.Bitstring.Lsb_first.of_list )
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
