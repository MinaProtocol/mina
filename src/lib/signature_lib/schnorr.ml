[%%import "/src/config.mlh"]

module Bignum_bigint = Bigint
open Core_kernel

module type Message_intf = sig
  type field

  type t

  type curve

  type curve_scalar

  val derive : t -> private_key:curve_scalar -> public_key:curve -> curve_scalar

  val derive_for_mainnet :
    t -> private_key:curve_scalar -> public_key:curve -> curve_scalar

  val derive_for_testnet :
    t -> private_key:curve_scalar -> public_key:curve -> curve_scalar

  val hash : t -> public_key:curve -> r:field -> curve_scalar

  val hash_for_mainnet : t -> public_key:curve -> r:field -> curve_scalar

  val hash_for_testnet : t -> public_key:curve -> r:field -> curve_scalar

  [%%ifdef consensus_mechanism]

  type field_var

  type boolean_var

  type var

  type curve_var

  type curve_scalar_var

  type _ checked

  val hash_checked :
    var -> public_key:curve_var -> r:field_var -> curve_scalar_var checked

  [%%endif]
end

[%%ifdef consensus_mechanism]

module type S = sig
  module Impl : Snarky_backendless.Snark_intf.S

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
         and type 'a checked := 'a Checked.t
  end

  module Message :
    Message_intf
      with type boolean_var := Boolean.var
       and type curve_scalar := curve_scalar
       and type curve_scalar_var := curve_scalar_var
       and type 'a checked := 'a Checked.t
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
    type t = curve_scalar [@@deriving sexp]
  end

  module Public_key : sig
    type t = curve [@@deriving sexp]

    type var = curve_var
  end

  module Checked : sig
    val compress : curve_var -> Boolean.var list Checked.t

    val verifies :
         (module Shifted.S with type t = 't)
      -> Signature.var
      -> Public_key.var
      -> Message.var
      -> Boolean.var Checked.t

    val assert_verifies :
         (module Shifted.S with type t = 't)
      -> Signature.var
      -> Public_key.var
      -> Message.var
      -> unit Checked.t
  end

  val compress : curve -> bool list

  val sign :
       ?signature_kind:Mina_signature_kind.t
    -> Private_key.t
    -> Message.t
    -> Signature.t

  val verify :
       ?signature_kind:Mina_signature_kind.t
    -> Signature.t
    -> Public_key.t
    -> Message.t
    -> bool
end

module Make
    (Impl : Snarky_backendless.Snark_intf.S) (Curve : sig
      open Impl

      module Scalar : sig
        type t [@@deriving sexp, equal]

        type var

        val typ : (var, t) Typ.t

        val zero : t

        val ( * ) : t -> t -> t

        val ( + ) : t -> t -> t

        val negate : t -> t

        module Checked : sig
          val to_bits : var -> Boolean.var Bitstring_lib.Bitstring.Lsb_first.t
        end
      end

      type t [@@deriving sexp]

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
    end)
    (Message : Message_intf
                 with type boolean_var := Impl.Boolean.var
                  and type curve_scalar_var := Curve.Scalar.var
                  and type curve_scalar := Curve.Scalar.t
                  and type curve := Curve.t
                  and type curve_var := Curve.var
                  and type field := Impl.Field.t
                  and type field_var := Impl.Field.Var.t
                  and type 'a checked := 'a Impl.Checked.t) :
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
    type t = Curve.Scalar.t [@@deriving sexp]
  end

  module Public_key : sig
    type t = Curve.t [@@deriving sexp]

    type var = Curve.var
  end =
    Curve

  let compress (t : Curve.t) =
    let x, _ = Curve.to_affine_exn t in
    Field.unpack x

  let is_even (t : Field.t) = not (Bigint.test_bit (Bigint.of_field t) 0)

  let sign ?signature_kind (d_prime : Private_key.t) (m : Message.t) =
    let public_key =
      (* TODO: Don't recompute this. *) Curve.scale Curve.one d_prime
    in
    (* TODO: Once we switch to implicit sign-bit we'll have to conditionally negate d_prime. *)
    let d = d_prime in
    let derive =
      let open Mina_signature_kind in
      match signature_kind with
      | None ->
          Message.derive
      | Some Mainnet ->
          Message.derive_for_mainnet
      | Some Testnet ->
          Message.derive_for_testnet
    in
    let k_prime = derive m ~public_key ~private_key:d in
    assert (not Curve.Scalar.(equal k_prime zero)) ;
    let r, ry = Curve.(to_affine_exn (scale Curve.one k_prime)) in
    let k = if is_even ry then k_prime else Curve.Scalar.negate k_prime in
    let hash =
      let open Mina_signature_kind in
      match signature_kind with
      | None ->
          Message.hash
      | Some Mainnet ->
          Message.hash_for_mainnet
      | Some Testnet ->
          Message.hash_for_testnet
    in
    let e = hash m ~public_key ~r in
    let s = Curve.Scalar.(k + (e * d)) in
    (r, s)

  let verify ?signature_kind ((r, s) : Signature.t) (pk : Public_key.t)
      (m : Message.t) =
    let hash =
      let open Mina_signature_kind in
      match signature_kind with
      | None ->
          Message.hash
      | Some Mainnet ->
          Message.hash_for_mainnet
      | Some Testnet ->
          Message.hash_for_testnet
    in
    let e = hash ~public_key:pk ~r m in
    let r_pt = Curve.(scale one s + negate (scale pk e)) in
    match Curve.to_affine_exn r_pt with
    | rx, ry ->
        is_even ry && Field.equal rx r
    | exception _ ->
        false

  [%%if call_logger]

  let verify s pk m =
    Mina_debug.Call_logger.record_call "Signature_lib.Schnorr.verify" ;
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
      Bitstring_lib.Bitstring.Lsb_first.to_list bs |> List.hd_exn |> Boolean.not

    (* returning r_point as a representable point ensures it is nonzero so the nonzero
     * check does not have to explicitly be performed *)

    let%snarkydef_ verifier (type s) ~equal ~final_check
        ((module Shifted) as shifted :
          (module Curve.Checked.Shifted.S with type t = s) )
        ((r, s) : Signature.var) (public_key : Public_key.var) (m : Message.var)
        =
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

[%%else]

(* nonconsensus version of the functor; yes, there's some repeated code,
   but seems difficult to abstract over the functors and signatures
*)

module type S = sig
  open Snark_params.Tick

  type curve

  type curve_scalar

  module Message :
    Message_intf
      with type curve_scalar := curve_scalar
       and type curve := curve
       and type field := Field.t

  module Signature : sig
    type t = Field.t * curve_scalar [@@deriving sexp]
  end

  module Private_key : sig
    type t = curve_scalar [@@deriving sexp]
  end

  module Public_key : sig
    type t = curve [@@deriving sexp]
  end

  val sign :
       ?signature_kind:Mina_signature_kind.t
    -> Private_key.t
    -> Message.t
    -> Signature.t

  val verify :
       ?signature_kind:Mina_signature_kind.t
    -> Signature.t
    -> Public_key.t
    -> Message.t
    -> bool
end

module Make
    (Impl : module type of Snark_params.Tick) (Curve : sig
      open Impl

      module Scalar : sig
        type t [@@deriving sexp, equal]

        val zero : t

        val ( * ) : t -> t -> t

        val ( + ) : t -> t -> t

        val negate : t -> t
      end

      type t [@@deriving sexp]

      val one : t

      val ( + ) : t -> t -> t

      val negate : t -> t

      val scale : t -> Scalar.t -> t

      val to_affine_exn : t -> Field.t * Field.t
    end)
    (Message : Message_intf
                 with type curve := Curve.t
                  and type curve_scalar := Curve.Scalar.t
                  and type field := Impl.Field.t) :
  S
    with type curve := Curve.t
     and type curve_scalar := Curve.Scalar.t
     and module Message := Message = struct
  module Private_key = struct
    type t = Curve.Scalar.t [@@deriving sexp]
  end

  module Signature = struct
    type t = Impl.Field.t * Curve.Scalar.t [@@deriving sexp]
  end

  module Public_key : sig
    type t = Curve.t [@@deriving sexp]
  end =
    Curve

  let is_even (t : Impl.Field.t) = not @@ Impl.Field.parity t

  let sign ?signature_kind (d_prime : Private_key.t) m =
    let public_key =
      (* TODO: Don't recompute this. *)
      Curve.scale Curve.one d_prime
    in
    (* TODO: Once we switch to implicit sign-bit we'll have to conditionally negate d_prime. *)
    let d = d_prime in
    let derive =
      let open Mina_signature_kind in
      match signature_kind with
      | None ->
          Message.derive
      | Some Mainnet ->
          Message.derive_for_mainnet
      | Some Testnet ->
          Message.derive_for_testnet
    in
    let k_prime = derive m ~public_key ~private_key:d in
    assert (not Curve.Scalar.(equal k_prime zero)) ;
    let r, (ry : Impl.Field.t) =
      Curve.(to_affine_exn (scale Curve.one k_prime))
    in
    let k = if is_even ry then k_prime else Curve.Scalar.negate k_prime in
    let hash =
      let open Mina_signature_kind in
      match signature_kind with
      | None ->
          Message.hash
      | Some Mainnet ->
          Message.hash_for_mainnet
      | Some Testnet ->
          Message.hash_for_testnet
    in
    let e = hash m ~public_key ~r in
    let s = Curve.Scalar.(k + (e * d)) in
    (r, s)

  let verify ?signature_kind ((r, s) : Signature.t) (pk : Public_key.t)
      (m : Message.t) =
    let hash =
      let open Mina_signature_kind in
      match signature_kind with
      | None ->
          Message.hash
      | Some Mainnet ->
          Message.hash_for_mainnet
      | Some Testnet ->
          Message.hash_for_testnet
    in
    let e = hash ~public_key:pk ~r m in
    let r_pt = Curve.(scale one s + negate (scale pk e)) in
    match Curve.to_affine_exn r_pt with
    | rx, ry ->
        is_even ry && Impl.Field.(equal rx r)
    | exception _ ->
        false
end

[%%endif]

open Snark_params

module Message = struct
  let network_id_mainnet = Char.of_int_exn 1

  let network_id_testnet = Char.of_int_exn 0

  let network_id =
    match Mina_signature_kind.t with
    | Mainnet ->
        network_id_mainnet
    | Testnet ->
        network_id_testnet

  module Legacy = struct
    open Tick

    type t = (Field.t, bool) Random_oracle.Input.Legacy.t [@@deriving sexp]

    let make_derive ~network_id t ~private_key ~public_key =
      let input =
        let x, y = Tick.Inner_curve.to_affine_exn public_key in
        Random_oracle.Input.Legacy.append t
          { field_elements = [| x; y |]
          ; bitstrings =
              [| Tock.Field.unpack private_key
               ; Fold_lib.Fold.(
                   to_list (string_bits (String.of_char network_id)))
              |]
          }
      in
      Random_oracle.Input.Legacy.to_bits ~unpack:Field.unpack input
      |> Array.of_list |> Blake2.bits_to_string |> Blake2.digest_string
      |> Blake2.to_raw_string |> Blake2.string_to_bits |> Array.to_list
      |> Fn.flip List.take (Int.min 256 (Tock.Field.size_in_bits - 1))
      |> Tock.Field.project

    let derive = make_derive ~network_id

    let derive_for_mainnet = make_derive ~network_id:network_id_mainnet

    let derive_for_testnet = make_derive ~network_id:network_id_testnet

    let make_hash ~init t ~public_key ~r =
      let input =
        let px, py = Inner_curve.to_affine_exn public_key in
        Random_oracle.Input.Legacy.append t
          { field_elements = [| px; py; r |]; bitstrings = [||] }
      in
      let open Random_oracle.Legacy in
      hash ~init (pack_input input)
      |> Digest.to_bits ~length:Field.size_in_bits
      |> Inner_curve.Scalar.of_bits

    let hash = make_hash ~init:Hash_prefix_states.signature_legacy

    let hash_for_mainnet =
      make_hash ~init:Hash_prefix_states.signature_for_mainnet_legacy

    let hash_for_testnet =
      make_hash ~init:Hash_prefix_states.signature_for_testnet_legacy

    [%%ifdef consensus_mechanism]

    type var = (Field.Var.t, Boolean.var) Random_oracle.Input.Legacy.t

    let%snarkydef_ hash_checked t ~public_key ~r =
      let input =
        let px, py = public_key in
        Random_oracle.Input.Legacy.append t
          { field_elements = [| px; py; r |]; bitstrings = [||] }
      in
      make_checked (fun () ->
          let open Random_oracle.Legacy.Checked in
          hash ~init:Hash_prefix_states.signature_legacy (pack_input input)
          |> Digest.to_bits ~length:Field.size_in_bits
          |> Bitstring_lib.Bitstring.Lsb_first.of_list )

    [%%endif]
  end

  module Chunked = struct
    open Tick

    type t = Field.t Random_oracle.Input.Chunked.t [@@deriving sexp]

    let make_derive ~network_id t ~private_key ~public_key =
      let input =
        let x, y = Tick.Inner_curve.to_affine_exn public_key in
        let id =
          Fold_lib.Fold.(to_list (string_bits (String.of_char network_id)))
        in
        Random_oracle.Input.Chunked.append t
          { field_elements =
              [| x; y; Field.project (Tock.Field.unpack private_key) |]
          ; packeds = [| (Field.project id, List.length id) |]
          }
      in
      Array.map (Random_oracle.pack_input input) ~f:Tick.Field.unpack
      |> Array.to_list |> List.concat |> Array.of_list |> Blake2.bits_to_string
      |> Blake2.digest_string |> Blake2.to_raw_string |> Blake2.string_to_bits
      |> Array.to_list
      |> Fn.flip List.take (Int.min 256 (Tock.Field.size_in_bits - 1))
      |> Tock.Field.project

    let derive = make_derive ~network_id

    let derive_for_mainnet = make_derive ~network_id:network_id_mainnet

    let derive_for_testnet = make_derive ~network_id:network_id_testnet

    let make_hash ~init t ~public_key ~r =
      let input =
        let px, py = Inner_curve.to_affine_exn public_key in
        Random_oracle.Input.Chunked.append t
          { field_elements = [| px; py; r |]; packeds = [||] }
      in
      let open Random_oracle in
      hash ~init (pack_input input)
      |> Digest.to_bits ~length:Field.size_in_bits
      |> Inner_curve.Scalar.of_bits

    let hash = make_hash ~init:Hash_prefix_states.signature

    let hash_for_mainnet =
      make_hash ~init:Hash_prefix_states.signature_for_mainnet

    let hash_for_testnet =
      make_hash ~init:Hash_prefix_states.signature_for_testnet

    [%%ifdef consensus_mechanism]

    type var = Field.Var.t Random_oracle.Input.Chunked.t

    let%snarkydef_ hash_checked t ~public_key ~r =
      let input =
        let px, py = public_key in
        Random_oracle.Input.Chunked.append t
          { field_elements = [| px; py; r |]; packeds = [||] }
      in
      make_checked (fun () ->
          let open Random_oracle.Checked in
          hash ~init:Hash_prefix_states.signature (pack_input input)
          |> Digest.to_bits ~length:Field.size_in_bits
          |> Bitstring_lib.Bitstring.Lsb_first.of_list )

    [%%endif]
  end
end

module Legacy = Make (Tick) (Tick.Inner_curve) (Message.Legacy)
module Chunked = Make (Tick) (Tick.Inner_curve) (Message.Chunked)

[%%ifdef consensus_mechanism]

let gen_legacy =
  let open Quickcheck.Let_syntax in
  let%map pk = Private_key.gen and msg = Tick.Field.gen in
  (pk, Random_oracle.Input.Legacy.field_elements [| msg |])

let gen_chunked =
  let open Quickcheck.Let_syntax in
  let%map pk = Private_key.gen and msg = Tick.Field.gen in
  (pk, Random_oracle.Input.Chunked.field_elements [| msg |])

(* Use for reading only. *)
let legacy_message_typ () : (Message.Legacy.var, Message.Legacy.t) Tick.Typ.t =
  let to_hlist { Random_oracle.Input.Legacy.field_elements; bitstrings } =
    H_list.[ field_elements; bitstrings ]
  in
  let of_hlist ([ field_elements; bitstrings ] : (unit, _) H_list.t) =
    { Random_oracle.Input.Legacy.field_elements; bitstrings }
  in
  let open Tick.Typ in
  of_hlistable
    [ array ~length:0 Tick.Field.typ
    ; array ~length:0 (list ~length:0 Tick.Boolean.typ)
    ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist

(* Use for reading only. *)
let chunked_message_typ () : (Message.Chunked.var, Message.Chunked.t) Tick.Typ.t
    =
  let open Tick.Typ in
  let const_typ =
    Typ
      { check = (fun _ -> Tick.Checked.return ())
      ; var_to_fields = (fun t -> ([||], t))
      ; var_of_fields = (fun (_, t) -> t)
      ; value_to_fields = (fun t -> ([||], t))
      ; value_of_fields = (fun (_, t) -> t)
      ; size_in_field_elements = 0
      ; constraint_system_auxiliary =
          (fun () -> failwith "Cannot create constant in constraint-system mode")
      }
  in
  let to_hlist { Random_oracle.Input.Chunked.field_elements; packeds } =
    H_list.[ field_elements; packeds ]
  in
  let of_hlist ([ field_elements; packeds ] : (unit, _) H_list.t) =
    { Random_oracle.Input.Chunked.field_elements; packeds }
  in
  of_hlistable
    [ array ~length:0 Tick.Field.typ
    ; array ~length:0 (Tick.Field.typ * const_typ)
    ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist

let%test_unit "schnorr checked + unchecked" =
  Quickcheck.test ~trials:5 gen_legacy ~f:(fun (pk, msg) ->
      let s = Legacy.sign pk msg in
      let pubkey = Tick.Inner_curve.(scale one pk) in
      assert (Legacy.verify s pubkey msg) ;
      (Tick.Test.test_equal ~sexp_of_t:[%sexp_of: bool] ~equal:Bool.equal
         Tick.Typ.(
           tuple3 Tick.Inner_curve.typ (legacy_message_typ ())
             Legacy.Signature.typ)
         Tick.Boolean.typ
         (fun (public_key, msg, s) ->
           let open Tick.Checked in
           let%bind (module Shifted) =
             Tick.Inner_curve.Checked.Shifted.create ()
           in
           Legacy.Checked.verifies (module Shifted) s public_key msg )
         (fun _ -> true) )
        (pubkey, msg, s) )

let%test_unit "schnorr checked + unchecked" =
  Quickcheck.test ~trials:5 gen_chunked ~f:(fun (pk, msg) ->
      let s = Chunked.sign pk msg in
      let pubkey = Tick.Inner_curve.(scale one pk) in
      assert (Chunked.verify s pubkey msg) ;
      (Tick.Test.test_equal ~sexp_of_t:[%sexp_of: bool] ~equal:Bool.equal
         Tick.Typ.(
           tuple3 Tick.Inner_curve.typ (chunked_message_typ ())
             Chunked.Signature.typ)
         Tick.Boolean.typ
         (fun (public_key, msg, s) ->
           let open Tick.Checked in
           let%bind (module Shifted) =
             Tick.Inner_curve.Checked.Shifted.create ()
           in
           Chunked.Checked.verifies (module Shifted) s public_key msg )
         (fun _ -> true) )
        (pubkey, msg, s) )

[%%endif]
