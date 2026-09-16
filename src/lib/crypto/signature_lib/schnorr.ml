(** Schnorr Digital Signature Implementation

    This module implements Schnorr signatures for the Mina protocol, providing
    both legacy and chunked message variants. Schnorr signatures are used for
    transaction authorization and other cryptographic operations in the
    protocol.

    Message formats:
    - Legacy: Uses bitstring arrays (older format for backward compatibility)
    - Chunked: Packs small values into field elements (more efficient)

    The implementation supports:
    - Mainnet, testnet, and custom network signatures
    - Both unchecked (native) and checked (constraint system) verification
    - Legacy and chunked message formats for backward compatibility
    - Elliptic curve operations over the Pasta curves used in Mina

    For detailed specification, see:
    https://github.com/MinaProtocol/mina/tree/compatible/docs/specs/signatures
*)

module Bignum_bigint = Bigint
open Core_kernel

(** Message interface for Schnorr signature operations.

    This interface defines how messages are processed for signature generation
    and verification, including key derivation and hashing operations.
*)
module type Message_intf = sig
  (** Base field element type *)
  type field

  (** Message type to be signed *)
  type t

  (** Elliptic curve point type *)
  type curve

  (** Curve scalar field element type *)
  type curve_scalar

  (** Derive a scalar value from message, private key, and public key.
      Used for generating the ephemeral key k in signature generation.

      @param signature_kind Network type (Mainnet/Testnet/Other)
      @param t Message to be signed
      @param private_key Signer's private key
      @param public_key Signer's public key
      @return Derived scalar value for signature generation
  *)
  val derive :
       signature_kind:Mina_signature_kind.t
    -> t
    -> private_key:curve_scalar
    -> public_key:curve
    -> curve_scalar

  (** Mainnet-specific derivation function *)
  val derive_for_mainnet :
    t -> private_key:curve_scalar -> public_key:curve -> curve_scalar

  (** Testnet-specific derivation function *)
  val derive_for_testnet :
    t -> private_key:curve_scalar -> public_key:curve -> curve_scalar

  (** Hash function for signature verification.
      Computes the challenge value e = H(m || pk || r) used in signature
      verification.

      @param signature_kind Network type
      @param t Message being verified
      @param public_key Signer's public key
      @param r R component of the signature
      @return Challenge scalar for verification
  *)
  val hash :
       signature_kind:Mina_signature_kind.t
    -> t
    -> public_key:curve
    -> r:field
    -> curve_scalar

  (** Mainnet-specific hash function *)
  val hash_for_mainnet : t -> public_key:curve -> r:field -> curve_scalar

  (** Testnet-specific hash function *)
  val hash_for_testnet : t -> public_key:curve -> r:field -> curve_scalar

  (** Circuit variable types for checked computation *)
  type field_var

  type boolean_var

  type var

  type curve_var

  type curve_scalar_var

  type _ checked

  (** Checked (in-circuit) version of hash function for constraint system
      verification *)
  val hash_checked :
       signature_kind:Mina_signature_kind.t
    -> var
    -> public_key:curve_var
    -> r:field_var
    -> curve_scalar_var checked
end

(** Main Schnorr signature module signature.

    This signature defines the complete interface for Schnorr signature
    operations including key types, signature operations, and both native and
    constraint system verification.
*)
module type S = sig
  (** The underlying constraint system implementation *)
  module Impl : Snarky_backendless.Snark_intf.S

  open Impl

  (** Elliptic curve point type *)
  type curve

  (** Circuit variable type for curve points *)
  type curve_var

  (** Scalar field element type *)
  type curve_scalar

  (** Circuit variable type for scalars *)
  type curve_scalar_var

  (** Module for shifted curve representations used in circuits *)
  module Shifted : sig
    module type S =
      Snarky_curves.Shifted_intf
        with type curve_var := curve_var
         and type boolean_var := Boolean.var
         and type 'a checked := 'a Checked.t
  end

  (** Message module instance conforming to Message_intf *)
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

  (** Schnorr signature representation *)
  module Signature : sig
    (** A signature is a pair (r, s) where r is a field element and s is a
        scalar *)
    type t = field * curve_scalar [@@deriving sexp]

    (** Circuit variable version of signature *)
    type var = Field.Var.t * curve_scalar_var

    (** Type conversion for constraint system circuits *)
    val typ : (var, t) Typ.t
  end

  module Private_key : sig
    (** Private key is a curve scalar *)
    type t = curve_scalar [@@deriving sexp]
  end

  (** Public key representation *)
  module Public_key : sig
    (** Public key is a curve point *)
    type t = curve [@@deriving sexp]

    (** Circuit variable version *)
    type var = curve_var
  end

  (** Constraint system checked computation functions *)
  module Checked : sig
    (** Compress a curve point to its bit representation *)
    val compress : curve_var -> Boolean.var list Checked.t

    (** Verify a signature in a constraint system circuit, returning boolean
        result *)
    val verifies :
         signature_kind:Mina_signature_kind.t
      -> (module Shifted.S with type t = 't)
      -> Signature.var
      -> Public_key.var
      -> Message.var
      -> Boolean.var Checked.t

    (** Assert that a signature verifies in a constraint system circuit (fails
        if invalid) *)
    val assert_verifies :
         signature_kind:Mina_signature_kind.t
      -> (module Shifted.S with type t = 't)
      -> Signature.var
      -> Public_key.var
      -> Message.var
      -> unit Checked.t
  end

  (** Compress a curve point to its bit representation (native version) *)
  val compress : curve -> bool list

  (** Sign a message with a private key

      @param signature_kind Network type for signature
      @param private_key Signer's private key
      @param message Message to sign
      @return Schnorr signature (r, s)
  *)
  val sign :
       signature_kind:Mina_signature_kind.t
    -> Private_key.t
    -> Message.t
    -> Signature.t

  (** Verify a signature

      @param signature_kind Network type
      @param signature The signature to verify
      @param public_key Signer's public key
      @param message Original message
      @return true if signature is valid, false otherwise
  *)
  val verify :
       signature_kind:Mina_signature_kind.t
    -> Signature.t
    -> Public_key.t
    -> Message.t
    -> bool
end

(** Functor to create a Schnorr signature implementation.

    This functor takes a constraint system implementation and curve
    specification to create a concrete Schnorr signature module. It implements
    the complete signature interface including signing, verification, and
    constraint system circuit operations.

    @param Impl The constraint system implementation (typically Tick)
    @param Curve Elliptic curve specification with required operations
    @param Message Message processing module for this signature instance
*)
module Make
    (Impl : Snarky_backendless.Snark_intf.S) (Curve : sig
      open Impl

      (** Curve scalar field operations *)
      module Scalar : sig
        (** Scalar field element type *)
        type t [@@deriving sexp, equal]

        (** Circuit variable for scalars *)
        type var

        (** Type conversion for constraint systems *)
        val typ : (var, t) Typ.t

        (** Zero element *)
        val zero : t

        (** Scalar multiplication *)
        val ( * ) : t -> t -> t

        (** Scalar addition *)
        val ( + ) : t -> t -> t

        (** Scalar negation *)
        val negate : t -> t

        (** Constraint system checked operations *)
        module Checked : sig
          (** Convert scalar to bit representation for circuit use *)
          val to_bits : var -> Boolean.var Bitstring_lib.Bitstring.Lsb_first.t
        end
      end

      (** Elliptic curve point type *)
      type t [@@deriving sexp]

      (** Circuit variable for curve points (affine coordinates) *)
      type var = Field.Var.t * Field.Var.t

      (** Constraint system checked curve operations *)
      module Checked :
        Snarky_curves.Weierstrass_checked_intf
          with module Impl := Impl
           and type t = var
           and type unchecked := t

      (** Curve generator point *)
      val one : t

      (** Point addition *)
      val ( + ) : t -> t -> t

      (** Point negation *)
      val negate : t -> t

      (** Scalar multiplication: scale point by scalar *)
      val scale : t -> Scalar.t -> t

      (** Convert point to affine coordinates (x, y) *)
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

  (** Compress a curve point to its x-coordinate in bit representation *)
  let compress (t : Curve.t) =
    let x, _ = Curve.to_affine_exn t in
    Field.unpack x

  (** Check if a field element is even (used for point compression) *)
  let is_even (t : Field.t) = not (Bigint.test_bit (Bigint.of_field t) 0)

  (** Sign a message using Schnorr signatures.

      Implementation follows the standard Schnorr signature algorithm:
      1. Derive ephemeral key k from message, private key, and public key
      2. Compute R = k * G (ensure R has even y-coordinate)
      3. Compute challenge e = H(m || pk || r)
      4. Compute s = k + e * d
      5. Return signature (r, s)
  *)
  let sign ~signature_kind (d_prime : Private_key.t) (m : Message.t) =
    let public_key =
      (* TODO: Don't recompute this. *) Curve.scale Curve.one d_prime
    in
    (* TODO: Once we switch to implicit sign-bit we'll have to conditionally
       negate d_prime. *)
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

  (** Verify a Schnorr signature.

      Implementation follows standard Schnorr verification:
      1. Compute challenge e = H(m || pk || r)
      2. Compute R' = s * G - e * pk
      3. Check that R'.x == r and R'.y is even

      @param signature_kind Network type for signature verification
      @param signature The (r, s) signature pair to verify
      @param pk The signer's public key
      @param m The original message
      @return true if signature is valid, false otherwise
  *)
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

    let is_even y =
      let%map bs = Field.Checked.unpack_full y in
      Bitstring_lib.Bitstring.Lsb_first.to_list bs |> List.hd_exn |> Boolean.not

    (* returning r_point as a representable point ensures it is nonzero so the
     * nonzero check does not have to explicitly be performed *)

    let%snarkydef_ verifier (type s) ~signature_kind ~equal ~final_check
        ((module Shifted) as shifted :
          (module Curve.Checked.Shifted.S with type t = s) )
        ((r, s) : Signature.var) (public_key : Public_key.var) (m : Message.var)
        =
      let%bind e = Message.hash_checked ~signature_kind m ~public_key ~r in
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

(** Message processing for Schnorr signatures.

    This module provides concrete implementations of the Message_intf for
    different input formats: Legacy (uses bitstrings) and Chunked (uses packed
    field elements). Both variants support network-specific signatures through
    domain separation.
*)
module Message = struct
  (** Network identifier for mainnet (character with value 1) *)
  let network_id_mainnet = String.of_char @@ Char.of_int_exn 1

  (** Network identifier for testnet (character with value 0) *)
  let network_id_testnet = String.of_char @@ Char.of_int_exn 0

  (** Network identifier for custom networks (uses chain name directly) *)
  let network_id_other chain_name = chain_name

  (** Get network identifier string based on signature kind *)
  let network_id ~(signature_kind : Mina_signature_kind.t) =
    match signature_kind with
    | Mainnet ->
        network_id_mainnet
    | Testnet ->
        network_id_testnet
    | Other_network chain_name ->
        network_id_other chain_name

  (** Legacy message format using bitstrings.

      This variant uses the older Random_oracle.Input.Legacy format which
      represents packed data as arrays of bitstrings. It's maintained for
      backward compatibility with older parts of the protocol.
  *)
  module Legacy = struct
    open Tick

    (** Message type using legacy input format *)
    type t = (Field.t, bool) Random_oracle.Input.Legacy.t [@@deriving sexp]

    (** Derive ephemeral key for signature generation.

        Combines message, public key, private key, and network ID through
        Blake2 hashing to produce a deterministic but unpredictable scalar for
        signing.

        @param network_id Network-specific domain separator
        @param t Message to be signed
        @param private_key Signer's private key
        @param public_key Signer's public key
        @return Derived scalar for signature generation
    *)
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
            (pack_input input)
          |> Digest.to_bits ~length:Field.size_in_bits
          |> Bitstring_lib.Bitstring.Lsb_first.of_list )
  end

  (** Chunked message format using packed field elements.

      This is the newer message format that uses Random_oracle.Input.Chunked,
      which efficiently packs small values together into field elements rather
      than using bitstrings. This format is more efficient in constraint
      systems and is used for newer protocol features.
  *)
  module Chunked = struct
    open Tick

    (** Message type using chunked input format *)
    type t = Field.t Random_oracle.Input.Chunked.t [@@deriving sexp]

    (** Derive ephemeral key for signature generation using chunked format.

        Similar to Legacy.make_derive but uses the more efficient chunked input
        format for better constraint system performance.

        @param network_id Network-specific domain separator
        @param t Message to be signed
        @param private_key Signer's private key
        @param public_key Signer's public key
        @return Derived scalar for signature generation
    *)
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
            (pack_input input)
          |> Digest.to_bits ~length:Field.size_in_bits
          |> Bitstring_lib.Bitstring.Lsb_first.of_list )
  end
end

(** Legacy Schnorr signature implementation using bitstring message format *)
module Legacy = Make (Tick) (Tick.Inner_curve) (Message.Legacy)

(** Chunked Schnorr signature implementation using packed field element
    message format *)
module Chunked = Make (Tick) (Tick.Inner_curve) (Message.Chunked)

(** Generator for testing Legacy signatures.
    Creates random private key and message pairs for property-based testing.
*)
let gen_legacy =
  let open Quickcheck.Let_syntax in
  let%map pk = Private_key.gen and msg = Tick.Field.gen in
  (pk, Random_oracle.Input.Legacy.field_elements [| msg |])

(** Generator for testing Chunked signatures.
    Creates random private key and message pairs for property-based testing.
*)
let gen_chunked =
  let open Quickcheck.Let_syntax in
  let%map pk = Private_key.gen and msg = Tick.Field.gen in
  (pk, Random_oracle.Input.Chunked.field_elements [| msg |])

(** Type descriptor for Legacy messages in constraint systems.
    Used for reading Legacy message variables in circuits (read-only).

    @return Type descriptor for converting between Legacy message values and
            circuit variables
*)
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

(** Type descriptor for Chunked messages in constraint systems.
    Used for reading Chunked message variables in circuits (read-only).

    @return Type descriptor for converting between Chunked message values and
            circuit variables
*)
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

let%test_unit "schnorr legacy checked + unchecked" =
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
           let open Tick.Checked in
           let%bind (module Shifted) =
             Tick.Inner_curve.Checked.Shifted.create ()
           in
           Legacy.Checked.verifies ~signature_kind
             (module Shifted)
             s public_key msg )
         (fun _ -> true) )
        (pubkey, msg, s) )

let%test_unit "schnorr chunked checked + unchecked" =
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
           let open Tick.Checked in
           let%bind (module Shifted) =
             Tick.Inner_curve.Checked.Shifted.create ()
           in
           Chunked.Checked.verifies ~signature_kind
             (module Shifted)
             s public_key msg )
         (fun _ -> true) )
        (pubkey, msg, s) )
