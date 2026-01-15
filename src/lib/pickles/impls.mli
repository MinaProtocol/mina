(** {1 Impls - Snarky Implementation Modules for Step and Wrap}

    This module provides the snarky implementation modules for both step
    (Tick/Vesta) and wrap (Tock/Pallas) circuits. These modules define the
    field types, constraint systems, and circuit building primitives.

    {2 Overview}

    Pickles uses two curves in a 2-cycle:
    - {b Step (Tick/Vesta)}: Application logic, verifies wrap proofs
    - {b Wrap (Tock/Pallas)}: Uniform format, verifies step proofs

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

    - [Step.Impl]: Snarky module for step circuits
    - [Wrap.Impl]: Snarky module for wrap circuits
    - [Step.Other_field]: Tock base field in step circuits (non-native)
    - [Wrap.Other_field]: Tick base field in wrap circuits (native!)
    - [Step.unfinalized_proof]: Deferred data for wrap
    - [Step.statement]: Step circuit public input type

    {2 Shifted Values}

    Non-native field elements use shifted representations:
    - [Type1]: For Tick elements in Wrap (simple shift)
    - [Type2]: For Tock elements in Step (split high/low)

    {2 Keypairs}

    Both modules provide [Keypair] modules for generating proving/verification
    key pairs from constraint systems.

    @see {!Step_main} for step circuit logic
    @see {!Wrap_main} for wrap circuit logic
    @see {!Snarky_backendless} for the underlying snarky implementation
*)

open Pickles_types

(** Wrap circuit implementation (Tock/Pallas based). *)
module Wrap_impl :
    module type of
      Snarky_backendless.Snark.Run.Make
        (Kimchi_pasta_snarky_backend.Pallas_based_plonk)

module Step : sig
  module Impl :
      module type of
        Snarky_backendless.Snark.Run.Make
          (Kimchi_pasta_snarky_backend.Vesta_based_plonk)

  include module type of Impl

  module Verification_key = Backend.Tick.Verification_key
  module Proving_key = Backend.Tick.Proving_key

  module Digest : module type of Import.Digest.Make (Impl)

  module Challenge : module type of Import.Challenge.Make (Impl)

  module Keypair : sig
    type t = { pk : Proving_key.t; vk : Verification_key.t } [@@deriving fields]

    val create : pk:Proving_key.t -> vk:Verification_key.t -> t

    val generate :
         ?lazy_mode:bool
      -> prev_challenges:int
      -> Kimchi_pasta_constraint_system.Vesta_constraint_system.t
      -> t
  end

  module Other_field : sig
    type t = Field.t * Boolean.var

    module Constant = Backend.Tock.Field

    val forbidden_shifted_values : (Impl.field * bool) list lazy_t

    val typ_unchecked : (t, Constant.t) Typ.t

    val typ : (t, Constant.t) Impl.Typ.t
  end

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

  type 'proofs_verified statement =
    ( (unfinalized_proof, 'proofs_verified) Vector.t
    , Import.Types.Digest.Constant.t
    , (Import.Types.Digest.Constant.t, 'proofs_verified) Vector.t )
    Import.Types.Step.Statement.t

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

  type 'proofs_verified statement_var =
    ( (unfinalized_proof_var, 'proofs_verified) Vector.t
    , Impl.Field.t
    , (Impl.Field.t, 'proofs_verified) Vector.t )
    Import.Types.Step.Statement.t

  val input :
       proofs_verified:'proofs_verified Nat.t
    -> ( 'proofs_verified statement_var
       , 'proofs_verified statement )
       Import.Spec.Step_etyp.t

  module Async_promise : module type of Async_generic (Promise)
end

module Wrap : sig
  module Impl :
      module type of
        Snarky_backendless.Snark.Run.Make
          (Kimchi_pasta_snarky_backend.Pallas_based_plonk)

  include module type of Impl

  module Challenge : module type of Import.Challenge.Make (Impl)

  module Digest : module type of Import.Digest.Make (Impl)

  module Wrap_field = Backend.Tock.Field
  module Step_field = Backend.Tick.Field
  module Verification_key = Backend.Tock.Verification_key
  module Proving_key = Backend.Tock.Proving_key

  module Keypair : sig
    type t = { pk : Proving_key.t; vk : Verification_key.t } [@@deriving fields]

    val create : pk:Proving_key.t -> vk:Verification_key.t -> t

    val generate :
         ?lazy_mode:bool
      -> prev_challenges:int
      -> Kimchi_pasta_constraint_system.Pallas_constraint_system.t
      -> t
  end

  module Other_field : sig
    type t = Field.t

    module Constant = Backend.Tick.Field

    val forbidden_shifted_values : Impl.field list lazy_t

    val typ_unchecked : (Impl.Field.t, Backend.Tick.Field.t) Impl.Typ.t

    val typ : (Impl.Field.t, Backend.Tick.Field.t) Impl.Typ.t
  end

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
