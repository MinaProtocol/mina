(** {1 Impls - Snarky Implementation Modules for Step and Wrap}

    This module provides the snarky implementation modules for both step
    (Tick/Vesta) and wrap (Tock/Pallas) circuits. These modules define the
    field types, constraint systems, and circuit building primitives.

    {2 Overview}

    Pickles uses two curves in a 2-cycle:
    - {b Step (Tick/Vesta)}: Application logic, verifies wrap proofs
    - {b Wrap (Tock/Pallas)}: Uniform format, no application logic, verifies
      step proofs

    Each has its own snarky implementation with different field types.

    {2 Field Relationships}

    {v
    Step (Tick/Vesta)              Wrap (Tock/Pallas)
    ┌────────────────────┐         ┌────────────────────┐
    │ Base field: Fp     │ ═══════ │ Scalar field: Fp   │
    │ Scalar field: Fq   │ ═══════ │ Base field: Fq     │
    └────────────────────┘         └────────────────────┘
    v}

    This relationship enables efficient recursion: Tick's scalar operations
    are native in Wrap, and vice versa.

    {2 Key Types}

    - {!Step.Impl}: Snarky module for step circuits
    - {!Wrap.Impl}: Snarky module for wrap circuits
    - {!Step.Other_field}: Tock base field in step circuits (non-native)
    - {!Wrap.Other_field}: Tick base field in wrap circuits (native!)
    - {!type:Step.unfinalized_proof}: Deferred data for wrap
    - {!type:Step.statement}: Step circuit public input type

    {2 Shifted Values}

    Non-native field elements use shifted representations:
    - {!Pickles_types.Shifted_value.Type1}: For Tick elements in Wrap (simple shift)
    - {!Pickles_types.Shifted_value.Type2}: For Tock elements in Step (split high/low)

    {2 Keypairs}

    Both modules provide {!Step.Keypair} and {!Wrap.Keypair} modules for
    generating proving/verification key pairs from constraint systems.

    {2 See Also}

    - {!module:Step_main} for step circuit logic
    - {!module:Wrap_main} for wrap circuit logic
    - {!module:Snarky_backendless} for the underlying snarky implementation
*)

open Pickles_types

(** Wrap circuit implementation (Tock/Pallas based). *)
module Wrap_impl :
    module type of
      Snarky_backendless.Snark.Run.Make
        (Kimchi_pasta_snarky_backend.Pallas_based_plonk)

(** Step circuit implementation module (Tick/Vesta based).

    Step circuits execute application logic and partially verify wrap proofs.
    They operate over the Tick (Vesta) curve where the base field is Fp.
    Step circuits can use lookup arguments for application logic. *)
module Step : sig
  (** The underlying snarky implementation for step circuits, instantiated
      with the Vesta-based PLONK backend. *)
  module Impl :
      module type of
        Snarky_backendless.Snark.Run.Make
          (Kimchi_pasta_snarky_backend.Vesta_based_plonk)

  include module type of Impl

  (** Verification key for step circuits (Tick curve). *)
  module Verification_key = Backend.Tick.Verification_key

  (** Proving key for step circuits (Tick curve). *)
  module Proving_key = Backend.Tick.Proving_key

  (** Digest (hash) operations for step circuits. *)
  module Digest : module type of Import.Digest.Make (Impl)

  (** Challenge generation for step circuits. *)
  module Challenge : module type of Import.Challenge.Make (Impl)

  (** Keypair management for step circuits. *)
  module Keypair : sig
    (** A keypair consists of a proving key and verification key. *)
    type t = { pk : Proving_key.t; vk : Verification_key.t } [@@deriving fields]

    (** Create a keypair from existing proving and verification keys. *)
    val create : pk:Proving_key.t -> vk:Verification_key.t -> t

    (** Generate a new keypair from a constraint system.
        @param lazy_mode If true, delays key generation until needed
        @param prev_challenges Number of challenges from previous proofs *)
    val generate :
         ?lazy_mode:bool
      -> prev_challenges:int
      -> Kimchi_pasta_constraint_system.Vesta_constraint_system.t
      -> t
  end

  (** Representation of Tock field elements within step circuits (non-native).

      Both Tick and Tock fields are 255 bits with orders larger than 254 bits,
      but Tock's field is larger than Tick's (p < q). To encode a Tock field
      element in a Tick circuit, we split it into the low bits (stored as a
      Tick field element) and the high bit (stored as a boolean).
      This uses {!Pickles_types.Shifted_value.Type2} encoding. *)
  module Other_field : sig
    (** A Tock field element in-circuit: (low bits, high bit). *)
    type t = Field.t * Boolean.var

    (** The constant (out-of-circuit) representation uses Tock's field. *)
    module Constant = Backend.Tock.Field

    (** Field values that cannot be used due to shifted value encoding.
        These values would alias with other values after shifting. *)
    val forbidden_shifted_values : (Impl.field * bool) list lazy_t

    (** Typ without range checking - use only when values are known safe. *)
    val typ_unchecked : (t, Constant.t) Typ.t

    (** Typ with proper range checking for safe conversion. *)
    val typ : (t, Constant.t) Impl.Typ.t
  end

  (** Constant (out-of-circuit) representation of proof state that has not
      yet been finalized by the wrap circuit. Contains deferred scalar-field
      computations that will be completed in wrap. *)
  type unfinalized_proof =
    ( Challenge.Constant.t
    , Challenge.Constant.t Import.Scalar_challenge.t
    , Backend.Tock.Field.t Shifted_value.Type2.t
    , ( Challenge.Constant.t Import.Scalar_challenge.t
        Import.Types.Bulletproof_challenge.t
      , Backend.Tock.Rounds.n )
      Vector.t
    , Digest.Constant.t
    , bool )
    Import.Types.Step.Proof_state.Per_proof.In_circuit.t

  (** Constant (out-of-circuit) step statement type, parameterized by the
      number of proofs verified. Contains unfinalized proofs and message
      digests for the next proof. *)
  type 'proofs_verified statement =
    ( (unfinalized_proof, 'proofs_verified) Vector.t
    , Import.Types.Digest.Constant.t
    , (Import.Types.Digest.Constant.t, 'proofs_verified) Vector.t )
    Import.Types.Step.Statement.t

  (** In-circuit representation of unfinalized proof state. Uses circuit
      variables instead of constants. *)
  type unfinalized_proof_var =
    ( Field.t
    , Field.t Import.Scalar_challenge.t
    , Other_field.t Shifted_value.Type2.t
    , ( Field.t Import.Scalar_challenge.t Import.Types.Bulletproof_challenge.t
      , Backend.Tock.Rounds.n )
      Vector.t
    , Field.t
    , Boolean.var )
    Import.Types.Step.Proof_state.Per_proof.In_circuit.t

  (** In-circuit step statement type. The circuit variable version of
      {!statement}. *)
  type 'proofs_verified statement_var =
    ( (unfinalized_proof_var, 'proofs_verified) Vector.t
    , Impl.Field.t
    , (Impl.Field.t, 'proofs_verified) Vector.t )
    Import.Types.Step.Statement.t

  (** Create the input specification for a step circuit.
      @param proofs_verified Type-level natural for number of proofs verified
      @return A specification mapping circuit variables to constants *)
  val input :
       proofs_verified:'proofs_verified Nat.t
    -> ( 'proofs_verified statement_var
       , 'proofs_verified statement )
       Import.Spec.Step_etyp.t

  (** Async operations using Promise for non-blocking proof generation. *)
  module Async_promise : module type of Async_generic (Promise)
end

(** Wrap circuit implementation module (Tock/Pallas based).

    Wrap circuits verify step proofs and complete deferred scalar-field
    computations. They operate over the Tock (Pallas) curve where the base
    field is Fq. Wrap proofs have a uniform format suitable for recursive
    verification.

    Note: Wrap circuits do not use lookup arguments - only step circuits
    (application logic) can use lookups. *)
module Wrap : sig
  (** The underlying snarky implementation for wrap circuits, instantiated
      with the Pallas-based PLONK backend. *)
  module Impl :
      module type of
        Snarky_backendless.Snark.Run.Make
          (Kimchi_pasta_snarky_backend.Pallas_based_plonk)

  include module type of Impl

  (** Challenge generation for wrap circuits. *)
  module Challenge : module type of Import.Challenge.Make (Impl)

  (** Digest (hash) operations for wrap circuits. *)
  module Digest : module type of Import.Digest.Make (Impl)

  (** The native field for wrap circuits (Tock/Pallas base field Fq). *)
  module Wrap_field = Backend.Tock.Field

  (** The step circuit's native field (Tick/Vesta base field Fp).
      This equals Tock's scalar field, so scalar operations from step
      are native in wrap. *)
  module Step_field = Backend.Tick.Field

  (** Verification key for wrap circuits (Tock curve). *)
  module Verification_key = Backend.Tock.Verification_key

  (** Proving key for wrap circuits (Tock curve). *)
  module Proving_key = Backend.Tock.Proving_key

  (** Keypair management for wrap circuits. *)
  module Keypair : sig
    (** A keypair consists of a proving key and verification key. *)
    type t = { pk : Proving_key.t; vk : Verification_key.t } [@@deriving fields]

    (** Create a keypair from existing proving and verification keys. *)
    val create : pk:Proving_key.t -> vk:Verification_key.t -> t

    (** Generate a new keypair from a constraint system.
        @param lazy_mode If true, delays key generation until needed
        @param prev_challenges Number of challenges from previous proofs *)
    val generate :
         ?lazy_mode:bool
      -> prev_challenges:int
      -> Kimchi_pasta_constraint_system.Pallas_constraint_system.t
      -> t
  end

  (** Representation of Tick field elements within wrap circuits.

      Both Tick and Tock fields are 255 bits with orders larger than 254 bits,
      but Tock's field is larger than Tick's (p < q). Since Tock can represent
      all Tick field elements directly, we only need a single field element
      (no splitting required). Uses {!Pickles_types.Shifted_value.Type1} encoding.

      Additionally, Tick's base field (Fp) equals Tock's scalar field, so
      scalar operations from step are {b native} in wrap circuits. This is
      why wrap can efficiently complete the deferred scalar-field computations
      from step. *)
  module Other_field : sig
    (** A Tick field element in-circuit - a single field element since
        Tock's field is larger and can represent all Tick values. *)
    type t = Field.t

    (** The constant (out-of-circuit) representation uses Tick's field. *)
    module Constant = Backend.Tick.Field

    (** Field values that cannot be used due to shifted value encoding. *)
    val forbidden_shifted_values : Impl.field list lazy_t

    (** Typ without range checking - use only when values are known safe. *)
    val typ_unchecked : (Impl.Field.t, Backend.Tick.Field.t) Impl.Typ.t

    (** Typ with proper range checking for safe conversion. *)
    val typ : (Impl.Field.t, Backend.Tick.Field.t) Impl.Typ.t
  end

  (** Create the input specification for a wrap circuit.

      The wrap statement is more complex than step, containing PLONK
      challenges, deferred values, bulletproof challenges, and branch data.

      @param feature_flags Flags indicating which optional features are enabled
        (e.g., lookup arguments, runtime tables)
      @return A specification mapping circuit variables to constants *)
  val input :
       feature_flags:Opt.Flag.t Plonk_types.Features.Full.t
    -> unit
    -> ( ( Impl.Field.t
         , Impl.Field.t Composition_types.Scalar_challenge.t
         , Impl.Field.t Pickles_types.Shifted_value.Type1.t
         , ( Impl.Field.t Pickles_types.Shifted_value.Type1.t
           , Impl.Field.t Snarky_backendless.Snark_intf.Boolean0.t )
           Pickles_types.Opt.t
         , ( Impl.Field.t Composition_types.Scalar_challenge.t
           , Impl.Field.t Snarky_backendless.Snark_intf.Boolean0.t )
           Pickles_types.Opt.t
         , Impl.Boolean.var
         , Impl.Field.t
         , Impl.Field.t
         , Impl.Field.t
         , ( Impl.Field.t Kimchi_backend_common.Scalar_challenge.t
             Composition_types.Bulletproof_challenge.t
           , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
           Pickles_types.Vector.t
         , Impl.Field.t )
         Import.Types.Wrap.Statement.In_circuit.t
       , ( Limb_vector.Challenge.Constant.t
         , Limb_vector.Challenge.Constant.t Composition_types.Scalar_challenge.t
         , Other_field.Constant.t Pickles_types.Shifted_value.Type1.t
         , Other_field.Constant.t Pickles_types.Shifted_value.Type1.t option
         , Limb_vector.Challenge.Constant.t Composition_types.Scalar_challenge.t
           option
         , bool
         , Import.Types.Digest.Constant.t
         , Import.Types.Digest.Constant.t
         , Import.Types.Digest.Constant.t
         , ( Limb_vector.Challenge.Constant.t
             Kimchi_backend_common.Scalar_challenge.t
             Composition_types.Bulletproof_challenge.t
           , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
           Pickles_types.Vector.t
         , Composition_types.Branch_data.t )
         Import.Types.Wrap.Statement.In_circuit.t )
       Import.Spec.Wrap_etyp.t
end
