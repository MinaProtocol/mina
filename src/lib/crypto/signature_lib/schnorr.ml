module Bignum_bigint = Bigint
open Core_kernel

module type Message_intf = sig
  type field

  type t

  type curve

  type curve_scalar

  val derive :
       signature_kind:Mina_signature_kind.t
    -> t
    -> private_key:curve_scalar
    -> public_key:curve
    -> curve_scalar

  val derive_for_mainnet :
    t -> private_key:curve_scalar -> public_key:curve -> curve_scalar

  val derive_for_testnet :
    t -> private_key:curve_scalar -> public_key:curve -> curve_scalar

  val hash :
       signature_kind:Mina_signature_kind.t
    -> t
    -> public_key:curve
    -> r:field
    -> curve_scalar

  val hash_for_mainnet : t -> public_key:curve -> r:field -> curve_scalar

  val hash_for_testnet : t -> public_key:curve -> r:field -> curve_scalar

  type field_var

  type boolean_var

  type var

  type curve_var

  type _ checked

  val hash_checked :
       signature_kind:Mina_signature_kind.t
    -> var
    -> public_key:curve_var
    -> r:field_var
    -> field_var checked
end

module type S = sig
  module Impl : Snarky_backendless.Snark_intf.S

  open Impl

  type curve

  type curve_var

  type curve_scalar

  type curve_scalar_var

  module Message :
    Message_intf
      with type boolean_var := Boolean.var
       and type curve_scalar := curve_scalar
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
         signature_kind:Mina_signature_kind.t
      -> Signature.var
      -> Public_key.var
      -> Message.var
      -> Boolean.var Checked.t

    val assert_verifies :
         signature_kind:Mina_signature_kind.t
      -> Signature.var
      -> Public_key.var
      -> Message.var
      -> unit Checked.t
  end

  val compress : curve -> bool list

  val sign :
       signature_kind:Mina_signature_kind.t
    -> Private_key.t
    -> Message.t
    -> Signature.t

  val verify :
       signature_kind:Mina_signature_kind.t
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

        val zero : t

        val ( * ) : t -> t -> t

        val ( + ) : t -> t -> t

        val negate : t -> t
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
    end) (Scale : sig
      open Impl

      (** The in-circuit representation of a curve scalar. *)
      type scalar_var

      val scalar_typ : (scalar_var, Curve.Scalar.t) Typ.t

      (** [scaled_difference ~s ~e pk] is [s * one - e * pk], where the curve
          scalar [e] is the integer value of a field element. It is not the
          point at infinity.
      *)
      val scaled_difference :
        s:scalar_var -> e:Field.Var.t -> Curve.var -> Curve.var Checked.t
    end) (Parity : sig
      open Impl

      (** The low bit of the canonical representative of a field element. *)
      val parity_var : Field.Var.t -> Boolean.var Checked.t
    end)
    (Message : Message_intf
                 with type boolean_var := Impl.Boolean.var
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
     and type curve_scalar_var := Scale.scalar_var
     and module Message := Message = struct
  open Impl

  module Signature = struct
    type t = Field.t * Curve.Scalar.t [@@deriving sexp]

    type var = Field.Var.t * Scale.scalar_var

    let typ : (var, t) Typ.t = Typ.tuple2 Field.typ Scale.scalar_typ
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

  let sign ~signature_kind (d_prime : Private_key.t) (m : Message.t) =
    let public_key =
      (* TODO: Don't recompute this. *) Curve.scale Curve.one d_prime
    in
    (* TODO: Once we switch to implicit sign-bit we'll have to conditionally negate d_prime. *)
    let d = d_prime in
    let derive = Message.derive ~signature_kind in
    let k_prime = derive m ~public_key ~private_key:d in
    assert (not Curve.Scalar.(equal k_prime zero)) ;
    let r, ry = Curve.(to_affine_exn (scale Curve.one k_prime)) in
    let k = if is_even ry then k_prime else Curve.Scalar.negate k_prime in
    let hash = Message.hash ~signature_kind in
    let e = hash m ~public_key ~r in
    let s = Curve.Scalar.(k + (e * d)) in
    (r, s)

  let verify ~signature_kind ((r, s) : Signature.t) (pk : Public_key.t)
      (m : Message.t) =
    let hash = Message.hash ~signature_kind in
    let e = hash ~public_key:pk ~r m in
    let r_pt = Curve.(scale one s + negate (scale pk e)) in
    match Curve.to_affine_exn r_pt with
    | rx, ry ->
        is_even ry && Field.equal rx r
    | exception _ ->
        false

  module Checked = struct
    let to_bits x =
      Field.Checked.choose_preimage_var x ~length:Field.size_in_bits

    let compress ((x, _) : Curve.var) = to_bits x

    let is_even y = Checked.map (Parity.parity_var y) ~f:Boolean.not

    (* returning r_point as a representable point ensures it is nonzero so the nonzero
     * check does not have to explicitly be performed *)

    let%snarkydef_ verifier ~signature_kind ~equal ~final_check
        ((r, s) : Signature.var) (public_key : Public_key.var) (m : Message.var)
        =
      let%bind e = Message.hash_checked ~signature_kind m ~public_key ~r in
      let%bind rx, ry = Scale.scaled_difference ~s ~e public_key in
      let%bind y_even = is_even ry in
      let%bind r_correct = equal r rx in
      final_check r_correct y_even

    let verifies ~signature_kind s =
      verifier ~signature_kind ~equal:Field.Checked.equal
        ~final_check:Boolean.( && ) s

    let assert_verifies ~signature_kind s =
      verifier ~signature_kind ~equal:Field.Checked.Assert.equal
        ~final_check:(fun () ry_even -> Boolean.Assert.is_true ry_even)
        s
  end
end

open Snark_params

module Message = struct
  let network_id_mainnet = String.of_char @@ Char.of_int_exn 1

  let network_id_testnet = String.of_char @@ Char.of_int_exn 0

  let network_id_other chain_name = chain_name

  let network_id ~(signature_kind : Mina_signature_kind.t) =
    match signature_kind with
    | Mainnet ->
        network_id_mainnet
    | Testnet ->
        network_id_testnet
    | Other_network chain_name ->
        network_id_other chain_name

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
               ; Fold_lib.Fold.(to_list (string_bits network_id))
              |]
          }
      in
      Random_oracle.Input.Legacy.to_bits ~unpack:Field.unpack input
      |> Array.of_list |> Blake2.bits_to_string |> Blake2.digest_string
      |> Blake2.to_raw_string |> Blake2.string_to_bits |> Array.to_list
      |> Fn.flip List.take (Int.min 256 (Tock.Field.size_in_bits - 1))
      |> Tock.Field.project

    let derive ~(signature_kind : Mina_signature_kind.t) =
      make_derive
        ~network_id:
          ( match signature_kind with
          | Mainnet ->
              network_id_mainnet
          | Testnet ->
              network_id_testnet
          | Other_network chain_name ->
              network_id_other chain_name )

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

    let hash ~signature_kind =
      make_hash ~init:(Hash_prefix_states.signature_legacy ~signature_kind)

    let hash_for_mainnet =
      make_hash ~init:Hash_prefix_states.signature_for_mainnet_legacy

    let hash_for_testnet =
      make_hash ~init:Hash_prefix_states.signature_for_testnet_legacy

    type var = (Field.Var.t, Boolean.var) Random_oracle.Input.Legacy.t

    let%snarkydef_ hash_checked ~signature_kind t ~public_key ~r =
      let input =
        let px, py = public_key in
        Random_oracle.Input.Legacy.append t
          { field_elements = [| px; py; r |]; bitstrings = [||] }
      in
      make_checked (fun () ->
          let open Random_oracle.Legacy.Checked in
          hash
            ~init:(Hash_prefix_states.signature_legacy ~signature_kind)
            (pack_input input) )
  end

  module Chunked = struct
    open Tick

    type t = Field.t Random_oracle.Input.Chunked.t [@@deriving sexp]

    let make_derive ~network_id t ~private_key ~public_key =
      let input =
        let x, y = Tick.Inner_curve.to_affine_exn public_key in
        let id = Fold_lib.Fold.(to_list (string_bits network_id)) in
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

    let derive ~(signature_kind : Mina_signature_kind.t) =
      make_derive
        ~network_id:
          ( match signature_kind with
          | Mainnet ->
              network_id_mainnet
          | Testnet ->
              network_id_testnet
          | Other_network chain_name ->
              network_id_other chain_name )

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

    let hash ~signature_kind =
      make_hash ~init:(Hash_prefix_states.signature ~signature_kind)

    let hash_for_mainnet =
      make_hash ~init:Hash_prefix_states.signature_for_mainnet

    let hash_for_testnet =
      make_hash ~init:Hash_prefix_states.signature_for_testnet

    type var = Field.Var.t Random_oracle.Input.Chunked.t

    let%snarkydef_ hash_checked ~signature_kind t ~public_key ~r =
      let input =
        let px, py = public_key in
        Random_oracle.Input.Chunked.append t
          { field_elements = [| px; py; r |]; packeds = [||] }
      in
      make_checked (fun () ->
          let open Random_oracle.Checked in
          hash
            ~init:(Hash_prefix_states.signature ~signature_kind)
            (pack_input input) )
  end
end

(** Scalar multiplication with kimchi's [VarBaseMul] gate, via
    [Pickles.Step_main_inputs.Ops.scale_fast2].

    [scale_fast2] takes a scalar [s] as [(s >> 1, s odd)] with [s >> 1] at
    most [num_bits - 1] bits, and computes [(s + offset) * g]. Its
    ladder can never reach the incomplete-addition case in which a prover could
    choose the result (the accumulator equalling the point being added). The
    cases in which no witness exists (the ladder's other exceptional case, and
    the final subtraction of [g] for an even [s] reaching the point at
    infinity) each need a specific scalar, which neither a hash output nor a
    signer can target.
*)
module Scale = struct
  open Tick
  module Ops = Pickles.Step_main_inputs.Ops

  let num_bits = Inner_curve.Scalar.length_in_bits

  type scalar_var = Field.Var.t * Boolean.var

  let split_bits = function odd :: div_2 -> (div_2, odd) | [] -> assert false

  let scalar_typ : (scalar_var, Inner_curve.Scalar.t) Typ.t =
    Typ.transport
      Typ.(Field.typ * Boolean.typ)
      ~there:(fun s ->
        let div_2, odd = split_bits (Inner_curve.Scalar.unpack s) in
        (Field.project div_2, odd) )
      ~back:(fun (div_2, odd) ->
        Inner_curve.Scalar.project
          (odd :: List.take (Field.unpack div_2) (num_bits - 1)) )

  (** The power of two that [scale_fast2] adds to its scalar: [2] to the number
      of bits its ladder uses, which rounds [num_bits - 1] up to whole chunks.
  *)
  let offset =
    Fn.apply_n_times
      ~n:(Ops.chunks_needed ~num_bits:(num_bits - 1) * Ops.bits_per_chunk)
      (fun x -> Inner_curve.Scalar.(x + x))
      Inner_curve.Scalar.one

  let scaled_difference ~(s : scalar_var) ~(e : Field.Var.t)
      (pk : Inner_curve.var) : Inner_curve.var Checked.t =
    make_checked (fun () ->
        let open Run in
        let scale g x =
          Ops.scale_fast2 g (Pickles_types.Shifted_value.Type2.Shifted_value x)
            ~num_bits
        in
        let e_split =
          exists
            Typ.(Field.typ * Boolean.typ)
            ~compute:(fun () ->
              let div_2, odd =
                split_bits (Field.Constant.unpack (As_prover.read_var e))
              in
              (Field.Constant.project div_2, odd) )
        in
        (* As with the [Random_oracle.Checked.Digest.to_bits] this replaces,
           both [e] and [e + p] satisfy this when [e + p < 2^num_bits]. *)
        Field.Assert.equal
          Field.(
            scale (fst e_split) (Constant.of_int 2) + (snd e_split :> Field.t))
          e ;
        let s_g = scale (Inner_curve.Checked.constant Inner_curve.one) s in
        let e_pk = scale pk e_split in
        let offset_pk = scale pk (Field.zero, Boolean.false_) in
        let offset_g =
          Inner_curve.Checked.constant Inner_curve.(scale one offset)
        in
        (* Accumulate onto a point chosen at random by the prover, so that a
           signer, who chooses the nonce, cannot steer a partial sum to the
           point at infinity, which [add_fast] rejects. *)
        let sigma =
          exists Inner_curve.typ ~compute:(fun () -> Inner_curve.random ())
        in
        let ( + ) p q = Ops.add_fast p q in
        let negate = Inner_curve.Checked.negate in
        sigma + s_g + negate offset_g + negate e_pk + offset_pk + negate sigma )
end

module Legacy =
  Make (Tick) (Tick.Inner_curve) (Scale) (Non_zero_curve_point) (Message.Legacy)
module Chunked =
  Make (Tick) (Tick.Inner_curve) (Scale) (Non_zero_curve_point)
    (Message.Chunked)

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
  let signature_kind = Mina_signature_kind.Testnet in
  Quickcheck.test ~trials:5 gen_legacy ~f:(fun (pk, msg) ->
      let s = Legacy.sign ~signature_kind pk msg in
      let pubkey = Tick.Inner_curve.(scale one pk) in
      assert (Legacy.verify ~signature_kind s pubkey msg) ;
      (Tick.Test.test_equal ~sexp_of_t:[%sexp_of: bool] ~equal:Bool.equal
         Tick.Typ.(
           tuple3 Tick.Inner_curve.typ (legacy_message_typ ())
             Legacy.Signature.typ)
         Tick.Boolean.typ
         (fun (public_key, msg, s) ->
           Legacy.Checked.verifies ~signature_kind s public_key msg )
         (fun _ -> true) )
        (pubkey, msg, s) )

let%test_unit "schnorr checked + unchecked" =
  let signature_kind = Mina_signature_kind.Testnet in
  Quickcheck.test ~trials:5 gen_chunked ~f:(fun (pk, msg) ->
      let s = Chunked.sign ~signature_kind pk msg in
      let pubkey = Tick.Inner_curve.(scale one pk) in
      assert (Chunked.verify ~signature_kind s pubkey msg) ;
      (Tick.Test.test_equal ~sexp_of_t:[%sexp_of: bool] ~equal:Bool.equal
         Tick.Typ.(
           tuple3 Tick.Inner_curve.typ (chunked_message_typ ())
             Chunked.Signature.typ)
         Tick.Boolean.typ
         (fun (public_key, msg, s) ->
           Chunked.Checked.verifies ~signature_kind s public_key msg )
         (fun _ -> true) )
        (pubkey, msg, s) )

(** Signatures that must be rejected, derived from a valid signature [s] by
    [private_key] on [msg], using a second key and message for the
    substitutions.
*)
let invalid_cases ~signature:((r, s) : Tick.Field.t * Tick.Inner_curve.Scalar.t)
    ~public_key ~msg ~other_public_key ~other_msg =
  [ ("tampered s", (public_key, msg, (r, Tick.Inner_curve.Scalar.(s + one))))
  ; ("tampered r", (public_key, msg, (Tick.Field.(r + one), s)))
  ; ("wrong message", (public_key, other_msg, (r, s)))
  ; ("wrong public key", (other_public_key, msg, (r, s)))
  ]

let%test_unit "schnorr checked rejects invalid legacy signatures" =
  let signature_kind = Mina_signature_kind.Testnet in
  Quickcheck.test ~trials:3 (Quickcheck.Generator.tuple2 gen_legacy gen_legacy)
    ~f:(fun ((pk, msg), (other_pk, other_msg)) ->
      let signature = Legacy.sign ~signature_kind pk msg in
      let public_key = Tick.Inner_curve.(scale one pk) in
      let other_public_key = Tick.Inner_curve.(scale one other_pk) in
      List.iter
        (invalid_cases ~signature ~public_key ~msg ~other_public_key ~other_msg)
        ~f:(fun (name, ((public_key, msg, s) as case)) ->
          if Legacy.verify ~signature_kind s public_key msg then
            failwithf "%s: unchecked verification accepted it" name () ;
          Tick.Test.test_equal ~sexp_of_t:[%sexp_of: bool] ~equal:Bool.equal
            Tick.Typ.(
              tuple3 Tick.Inner_curve.typ (legacy_message_typ ())
                Legacy.Signature.typ)
            Tick.Boolean.typ
            (fun (public_key, msg, s) ->
              Legacy.Checked.verifies ~signature_kind s public_key msg )
            (fun _ -> false)
            case ) )

let%test_unit "schnorr checked rejects invalid chunked signatures" =
  let signature_kind = Mina_signature_kind.Testnet in
  Quickcheck.test ~trials:3
    (Quickcheck.Generator.tuple2 gen_chunked gen_chunked)
    ~f:(fun ((pk, msg), (other_pk, other_msg)) ->
      let signature = Chunked.sign ~signature_kind pk msg in
      let public_key = Tick.Inner_curve.(scale one pk) in
      let other_public_key = Tick.Inner_curve.(scale one other_pk) in
      List.iter
        (invalid_cases ~signature ~public_key ~msg ~other_public_key ~other_msg)
        ~f:(fun (name, ((public_key, msg, s) as case)) ->
          if Chunked.verify ~signature_kind s public_key msg then
            failwithf "%s: unchecked verification accepted it" name () ;
          Tick.Test.test_equal ~sexp_of_t:[%sexp_of: bool] ~equal:Bool.equal
            Tick.Typ.(
              tuple3 Tick.Inner_curve.typ (chunked_message_typ ())
                Chunked.Signature.typ)
            Tick.Boolean.typ
            (fun (public_key, msg, s) ->
              Chunked.Checked.verifies ~signature_kind s public_key msg )
            (fun _ -> false)
            case ) )
