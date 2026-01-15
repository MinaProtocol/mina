(** {1 Compile - Recursive Proof System Compilation}

    This module compiles inductive rules into a complete recursive proof system.
    It is the main entry point for creating Pickles circuits.

    {2 Overview}

    The compilation process transforms a set of inductive rules (defined using
    {!Inductive_rule}) into:
    - Step circuits for each rule (running on Tick/Vesta)
    - A wrap circuit that produces uniform proofs (running on Tock/Pallas)
    - Provers for generating proofs
    - Verifiers for checking proofs

    {2 Compilation Flow}

    {v
    Inductive Rules          Compilation            Proof System
    ┌──────────────┐        ┌──────────┐          ┌─────────────┐
    │ Rule 1       │        │          │          │ Step Prover │
    │ Rule 2       │  ───►  │ compile  │  ───►    │ Wrap Prover │
    │ ...          │        │          │          │ Verifier    │
    │ Rule N       │        │          │          │ Vkey        │
    └──────────────┘        └──────────┘          └─────────────┘
    v}

    {2 Key Concepts}

    - {b Tag}: A unique identifier for a proof system, enabling rules to
      reference each other (including self-references for recursion)
    - {b Branches}: The number of inductive rules in the system
    - {b Max proofs verified}: Maximum number of predecessor proofs any rule
      verifies (0, 1, or 2)
    - {b Public input}: The statement type exposed to verifiers
    - {b Auxiliary output}: Data returned to provers but not exposed publicly

    {2 Side-Loaded Proofs}

    The {!Side_loaded} submodule supports dynamic verification keys, where the
    verification key is not known at compile time. This enables:
    - Verifying proofs from different proof systems
    - Hot-swapping verification keys
    - Generic proof aggregation

    {2 Usage Example}

    A typical compilation looks like:
    {[
      let tag, _cache, proof_module, provers =
        compile
          ~public_input:(Input statement_typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Nat.N2)
          ~name:"my_proof_system"
          ~choices:(fun ~self ->
            [ rule1 ~self
            ; rule2 ~self
            ])
          ()
    ]}

    {2 Implementation Notes for Rust Port}

    - The [choices] function receives [~self] for recursive references
    - Compilation is lazy; circuits are generated when first used
    - The [Promise.t] types indicate asynchronous/deferred computation
    - [Hlist] types encode heterogeneous lists at the type level
    - Cache handles enable persistent storage of proving/verification keys

    @see {!Inductive_rule} for defining rules
    @see {!Tag} for proof system identifiers
    @see {!Proof} for the generated proof type
*)

open Core_kernel
open Async_kernel
open Pickles_types
open Hlist

(** [pad_messages_for_next_wrap_proof maxes messages] pads the messages for
    next wrap proof to the maximum length required by the proof system.

    This is necessary because different rules may verify different numbers of
    predecessor proofs, but the wrap circuit needs a fixed-size input.
*)
val pad_messages_for_next_wrap_proof :
     (module Pickles_types.Hlist.Maxes.S
        with type length = 'max_proofs_verified
         and type ns = 'max_local_max_proofs_verifieds )
  -> 'local_max_proofs_verifieds
     Hlist.H1.T(Proof.Base.Messages_for_next_proof_over_same_field.Wrap).t
  -> 'max_local_max_proofs_verifieds
     Hlist.H1.T(Proof.Base.Messages_for_next_proof_over_same_field.Wrap).t

(** Interface for public statement types. Statements must be convertible
    to field elements for use as circuit public inputs. *)
module type Statement_intf = sig
  type field

  type t

  val to_field_elements : t -> field array
end

(** Statement interface for in-circuit (variable) values. *)
module type Statement_var_intf =
  Statement_intf with type field := Impls.Step.Field.t

(** Statement interface for out-of-circuit (constant) values. *)
module type Statement_value_intf =
  Statement_intf with type field := Impls.Step.field

(** Interface for generated proof modules. Provides verification key access
    and proof verification functions. *)
module type Proof_intf = sig
  type statement

  type t

  val verification_key_promise : Verification_key.t Promise.t Lazy.t

  val verification_key : Verification_key.t Deferred.t Lazy.t

  val id_promise : Cache.Wrap.Key.Verification.t Promise.t Lazy.t

  val id : Cache.Wrap.Key.Verification.t Deferred.t Lazy.t

  val verify : (statement * t) list -> unit Or_error.t Deferred.t

  val verify_promise : (statement * t) list -> unit Or_error.t Promise.t
end

(** Configuration for chunked polynomial evaluation. Used when circuits
    exceed the maximum supported degree and must be split into chunks. *)
type chunking_data = Verify.Instance.chunking_data =
  { num_chunks : int  (** Number of polynomial chunks *)
  ; domain_size : int (** Domain size for each chunk *)
  ; zk_rows : int     (** Number of zero-knowledge rows *)
  }

(** [verify_promise ?chunking_data nat_module statement_module vk proofs]
    verifies a list of statement-proof pairs against a verification key.

    @param chunking_data Optional chunking configuration for large circuits
    @param nat_module Witness for the max_proofs_verified type-level natural
    @param statement_module Statement type with field conversion
    @param vk The verification key to verify against
    @param proofs List of (statement, proof) pairs to verify
    @return [Ok ()] if all proofs verify, [Error _] otherwise
*)
val verify_promise :
     ?chunking_data:chunking_data
  -> (module Nat.Intf with type n = 'n)
  -> (module Statement_value_intf with type t = 'a)
  -> Verification_key.t
  -> ('a * 'n Proof.t) list
  -> unit Or_error.t Promise.t

(** The prover function type generated by compilation.

    Each inductive rule produces a prover that takes:
    - An optional handler for snarky requests (witness generation)
    - The public input value
    - And returns the proof along with any auxiliary outputs

    The type parameters encode predecessor proof information at the type level.
*)
module Prover : sig
  type ('prev_values, 'local_widths, 'local_heights, 'a_value, 'proof) t =
       ?handler:
         (   Snarky_backendless.Request.request
          -> Snarky_backendless.Request.response )
    -> 'a_value
    -> 'proof
end

(** {2 Side-Loaded Verification Keys}

    Side-loaded proofs allow verification with a dynamically-provided
    verification key, rather than one fixed at compile time. This enables:

    - Verifying proofs from multiple different proof systems
    - Updating verification keys without recompiling
    - Generic proof aggregation across different circuits

    {3 Usage}

    1. Create a side-loaded tag with {!create}
    2. In the circuit, call {!in_circuit} with the verification key
    3. Before proving, call {!in_prover} with the verification key
    4. The step circuit will verify against the provided key
*)
module Side_loaded : sig
  (** A verification key that can be provided at proving time rather than
      being fixed at compilation. Supports serialization for storage. *)
  module Verification_key : sig
    [%%versioned:
    module Stable : sig
      module V2 : sig
        type t [@@deriving sexp, equal, compare, hash, yojson]
      end
    end]

    include Codable.Base58_check_intf with type t := t

    include Codable.Base64_intf with type t := t

    val dummy : t

    open Impls.Step

    val to_input : t -> Field.Constant.t Random_oracle_input.Chunked.t

    module Checked : sig
      type t

      val to_input : t -> Field.t Random_oracle_input.Chunked.t
    end

    val typ : (Checked.t, t) Impls.Step.Typ.t

    val of_compiled_promise : _ Tag.t -> t Promise.t

    val of_compiled : _ Tag.t -> t Deferred.t

    module Max_width = Nat.N2
  end

  module Proof : sig
    [%%versioned:
    module Stable : sig
      module V2 : sig
        (* TODO: This should really be able to be any width up to the max width... *)
        type t = Verification_key.Max_width.n Proof.t
        [@@deriving sexp, equal, yojson, hash, compare]

        val to_base64 : t -> string

        val of_base64 : string -> (t, string) Result.t
      end
    end]

    val of_proof : _ Proof.t -> t

    val to_base64 : t -> string

    val of_base64 : string -> (t, string) Result.t
  end

  val create :
       name:string
    -> max_proofs_verified:(module Nat.Add.Intf with type n = 'n1)
    -> feature_flags:Opt.Flag.t Plonk_types.Features.t
    -> typ:('var, 'value) Impls.Step.Typ.t
    -> ('var, 'value, 'n1, Nat.N8.n) Tag.t

  val verify_promise :
       typ:('var, 'value) Impls.Step.Typ.t
    -> (Verification_key.t * 'value * Proof.t) list
    -> unit Or_error.t Promise.t

  val verify :
       typ:('var, 'value) Impls.Step.Typ.t
    -> (Verification_key.t * 'value * Proof.t) list
    -> unit Or_error.t Deferred.t

  (* Must be called in the inductive rule snarky function defining a
     rule for which this tag is used as a predecessor. *)
  val in_circuit :
    ('var, 'value, 'n1, 'n2) Tag.t -> Verification_key.Checked.t -> unit

  (* Must be called immediately before calling the prover for the inductive rule
     for which this tag is used as a predecessor. *)
  val in_prover : ('var, 'value, 'n1, 'n2) Tag.t -> Verification_key.t -> unit

  val srs_precomputation : unit -> unit
end

type ('max_proofs_verified, 'branches, 'prev_varss) wrap_main_generic =
  { wrap_main :
      'max_local_max_proofs_verifieds.
         Import.Domains.t
      -> ( 'max_proofs_verified
         , 'branches
         , 'max_local_max_proofs_verifieds )
         Full_signature.t
      -> ('prev_varss, 'branches) Hlist.Length.t
      -> ( ( Wrap_main_inputs.Inner_curve.Constant.t array
           , Wrap_main_inputs.Inner_curve.Constant.t array option )
           Wrap_verifier.index'
         , 'branches )
         Vector.t
         Promise.t
         Lazy.t
      -> (int, 'branches) Pickles_types.Vector.t
      -> (Import.Domains.t, 'branches) Pickles_types.Vector.t Promise.t
      -> (module Pickles_types.Nat.Add.Intf with type n = 'max_proofs_verified)
      -> ('max_proofs_verified, 'max_local_max_proofs_verifieds) Requests.Wrap.t
         * (   ( ( Impls.Wrap.Field.t
                 , Wrap_verifier.Challenge.t Kimchi_types.scalar_challenge
                 , Wrap_verifier.Other_field.Packed.t Shifted_value.Type1.t
                 , ( Wrap_verifier.Other_field.Packed.t Shifted_value.Type1.t
                   , Impls.Wrap.Boolean.var )
                   Opt.t
                 , ( Impls.Wrap.Impl.Field.t Composition_types.Scalar_challenge.t
                   , Impls.Wrap.Boolean.var )
                   Plonkish_prelude.Opt.t
                 , Impls.Wrap.Boolean.var )
                 Composition_types.Wrap.Proof_state.Deferred_values.Plonk
                 .In_circuit
                 .t
               , Wrap_verifier.Challenge.t Kimchi_types.scalar_challenge
               , Wrap_verifier.Other_field.Packed.t
                 Plonkish_prelude.Shifted_value.Type1.t
               , Impls.Wrap.Field.t
               , Impls.Wrap.Field.t
               , Impls.Wrap.Field.t
               , ( Impls.Wrap.Field.t Import.Scalar_challenge.t
                   Import.Types.Bulletproof_challenge.t
                 , Backend.Tick.Rounds.n )
                 Vector.T.t
               , Impls.Wrap.Field.t )
               Composition_types.Wrap.Statement.t
            -> unit )
           Promise.t
           Lazy.t
        (** An override for wrap_main, which allows for adversarial testing
              with an 'invalid' pickles statement by passing a dummy proof.
          *)
  ; tweak_statement :
      'actual_proofs_verified 'b 'e.
         ( Import.Challenge.Constant.t
         , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
         , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
         , ( Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
           , bool )
           Import.Types.Opt.t
         , ( Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
           , bool )
           Import.Types.Opt.t
         , bool
         , 'max_proofs_verified
           Proof.Base.Messages_for_next_proof_over_same_field.Wrap.t
         , Import.Types.Digest.Constant.t
         , ( 'b
           , ( Kimchi_pasta.Pallas_based_plonk.Proof.G.Affine.t
             , 'actual_proofs_verified )
             Pickles_types.Vector.t
           , ( ( Import.Challenge.Constant.t Import.Scalar_challenge.t
                 Import.Bulletproof_challenge.t
               , 'e )
               Pickles_types.Vector.t
             , 'actual_proofs_verified )
             Pickles_types.Vector.t )
           Proof.Base.Messages_for_next_proof_over_same_field.Step.t
         , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
           Import.Types.Bulletproof_challenge.t
           Import.Types.Step_bp_vec.t
         , Import.Types.Branch_data.t )
         Import.Types.Wrap.Statement.In_circuit.t
      -> ( Import.Challenge.Constant.t
         , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
         , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
         , ( Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
           , bool )
           Import.Types.Opt.t
         , ( Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
           , bool )
           Import.Types.Opt.t
         , bool
         , 'max_proofs_verified
           Proof.Base.Messages_for_next_proof_over_same_field.Wrap.t
         , Import.Types.Digest.Constant.t
         , ( 'b
           , ( Kimchi_pasta.Pallas_based_plonk.Proof.G.Affine.t
             , 'actual_proofs_verified )
             Pickles_types.Vector.t
           , ( ( Import.Challenge.Constant.t Import.Scalar_challenge.t
                 Import.Bulletproof_challenge.t
               , 'e )
               Pickles_types.Vector.t
             , 'actual_proofs_verified )
             Pickles_types.Vector.t )
           Proof.Base.Messages_for_next_proof_over_same_field.Step.t
         , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
           Import.Types.Bulletproof_challenge.t
           Import.Types.Step_bp_vec.t
         , Import.Types.Branch_data.t )
         Import.Types.Wrap.Statement.In_circuit.t
        (** A function to modify the statement passed into the wrap proof,
              which will be later passed to recursion pickles rules.

              This function can be used to modify the pickles statement in an
              adversarial way, along with [wrap_main] above that allows that
              statement to be accepted.
          *)
  }

module Storables : sig
  type t =
    { step_storable : Cache.Step.storable
    ; step_vk_storable : Cache.Step.vk_storable
    ; wrap_storable : Cache.Wrap.storable
    ; wrap_vk_storable : Cache.Wrap.vk_storable
    }

  val default : t
end

(** [compile_with_wrap_main_override_promise] compiles inductive rules into
    a complete recursive proof system.

    This is the main entry point for creating Pickles circuits. It transforms
    a set of inductive rules into step circuits, a wrap circuit, provers,
    and verification infrastructure.

    {3 Parameters}

    @param self Optional pre-existing tag for the proof system
    @param cache Key cache specification for persistent storage
    @param storables Storage configuration for keys
    @param proof_cache Cache for generated proofs
    @param disk_keys Pre-computed keys to load from disk
    @param override_wrap_domain Override the wrap circuit domain size
    @param override_wrap_main Override wrap circuit for testing
    @param num_chunks Number of polynomial chunks for large circuits
    @param lazy_mode If true, defer circuit generation until first use
    @param public_input Specification of the public input/output types
    @param auxiliary_typ Type for auxiliary prover-only data
    @param max_proofs_verified Maximum proofs verified by any rule (N0/N1/N2)
    @param name Unique name for this proof system
    @param constraint_constants SNARK constraint configuration
    @param choices Function returning the list of inductive rules

    {3 Return Value}

    Returns a 4-tuple:
    - {b Tag}: Unique identifier for referencing this proof system
    - {b Cache_handle}: Handle for managing cached keys
    - {b Proof module}: Module with verification functions
    - {b Provers}: Heterogeneous list of prover functions, one per rule

    {3 Type Parameters}

    The complex type signature encodes at the type level:
    - ['var], ['value]: Public input circuit/constant types
    - ['max_proofs_verified]: Maximum predecessor proofs (Nat.N0/N1/N2)
    - ['branches]: Number of inductive rules
    - ['prev_varss], ['prev_valuess]: Predecessor input types per rule
    - ['widthss], ['heightss]: Predecessor proof configuration per rule
*)
val compile_with_wrap_main_override_promise :
     ?self:('var, 'value, 'max_proofs_verified, 'branches) Tag.t
  -> ?cache:Key_cache.Spec.t list
  -> ?storables:Storables.t
  -> ?proof_cache:Proof_cache.t
  -> ?disk_keys:
       (Cache.Step.Key.Verification.t, 'branches) Vector.t
       * Cache.Wrap.Key.Verification.t
  -> ?override_wrap_domain:Pickles_base.Proofs_verified.t
  -> ?override_wrap_main:
       ('max_proofs_verified, 'branches, 'prev_varss) wrap_main_generic
  -> ?num_chunks:int
  -> ?lazy_mode:bool
  -> public_input:
       ( 'var
       , 'value
       , 'a_var
       , 'a_value
       , 'ret_var
       , 'ret_value )
       Inductive_rule.Kimchi.public_input
  -> auxiliary_typ:('auxiliary_var, 'auxiliary_value) Impls.Step.Typ.t
  -> max_proofs_verified:(module Nat.Add.Intf with type n = 'max_proofs_verified)
  -> name:string
  -> ?constraint_constants:Snark_keys_header.Constraint_constants.t
  -> choices:
       (   self:('var, 'value, 'max_proofs_verified, 'branches) Tag.t
        -> ( 'branches
           , 'prev_varss
           , 'prev_valuess
           , 'widthss
           , 'heightss
           , 'a_var
           , 'a_value
           , 'ret_var
           , 'ret_value
           , 'auxiliary_var
           , 'auxiliary_value )
           H4_6_with_length.T(Inductive_rule.Kimchi.Promise).t )
  -> unit
  -> ('var, 'value, 'max_proofs_verified, 'branches) Tag.t
     * Cache_handle.t
     * (module Proof_intf
          with type t = 'max_proofs_verified Proof.t
           and type statement = 'value )
     * ( 'prev_valuess
       , 'widthss
       , 'heightss
       , 'a_value
       , ('ret_value * 'auxiliary_value * 'max_proofs_verified Proof.t)
         Promise.t )
       H3_2.T(Prover).t

val wrap_main_dummy_override :
     Import.Domains.t
  -> ( 'max_proofs_verified
     , 'branches
     , 'max_local_max_proofs_verifieds )
     Full_signature.t
  -> ('prev_varss, 'branches) Hlist.Length.t
  -> ( ( Wrap_main_inputs.Inner_curve.Constant.t
       , Wrap_main_inputs.Inner_curve.Constant.t option )
       Wrap_verifier.index'
     , 'branches )
     Vector.t
     Promise.t
     Lazy.t
  -> (int, 'branches) Pickles_types.Vector.t
  -> (Import.Domains.t Promise.t, 'branches) Pickles_types.Vector.t
  -> (module Pickles_types.Nat.Add.Intf with type n = 'max_proofs_verified)
  -> ('max_proofs_verified, 'max_local_max_proofs_verifieds) Requests.Wrap.t
     * (   ( ( Impls.Wrap.Field.t
             , Wrap_verifier.Challenge.t Kimchi_types.scalar_challenge
             , Wrap_verifier.Other_field.Packed.t Shifted_value.Type1.t
             , ( Wrap_verifier.Other_field.Packed.t Shifted_value.Type1.t
               , Impls.Wrap.Boolean.var )
               Opt.t
             , ( Impls.Wrap.Impl.Field.t Composition_types.Scalar_challenge.t
               , Impls.Wrap.Boolean.var )
               Plonkish_prelude.Opt.t
             , Impls.Wrap.Boolean.var )
             Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit
             .t
           , Wrap_verifier.Challenge.t Kimchi_types.scalar_challenge
           , Wrap_verifier.Other_field.Packed.t
             Plonkish_prelude.Shifted_value.Type1.t
           , Impls.Wrap.Field.t
           , Impls.Wrap.Field.t
           , Impls.Wrap.Field.t
           , ( Impls.Wrap.Field.t Import.Scalar_challenge.t
               Import.Types.Bulletproof_challenge.t
             , Backend.Tick.Rounds.n )
             Vector.T.t
           , Impls.Wrap.Field.t )
           Composition_types.Wrap.Statement.t
        -> unit )
       Promise.t
       Lazy.t

module Make_adversarial_test : functor
  (_ : sig
     val tweak_statement :
          ( Import.Challenge.Constant.t
          , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
          , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
          , ( Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
            , bool )
            Import.Types.Opt.t
          , ( Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
            , bool )
            Import.Types.Opt.t
          , bool
          , 'max_proofs_verified
            Proof.Base.Messages_for_next_proof_over_same_field.Wrap.t
          , Import.Types.Digest.Constant.t
          , ( 'b
            , ( Kimchi_pasta.Pallas_based_plonk.Proof.G.Affine.t
              , 'actual_proofs_verified )
              Pickles_types.Vector.t
            , ( ( Import.Challenge.Constant.t Import.Scalar_challenge.t
                  Import.Bulletproof_challenge.t
                , 'e )
                Pickles_types.Vector.t
              , 'actual_proofs_verified )
              Pickles_types.Vector.t )
            Proof.Base.Messages_for_next_proof_over_same_field.Step.t
          , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
            Import.Types.Bulletproof_challenge.t
            Import.Types.Step_bp_vec.t
          , Import.Types.Branch_data.t )
          Import.Types.Wrap.Statement.In_circuit.t
       -> ( Import.Challenge.Constant.t
          , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
          , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
          , ( Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
            , bool )
            Import.Types.Opt.t
          , ( Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
            , bool )
            Import.Types.Opt.t
          , bool
          , 'max_proofs_verified
            Proof.Base.Messages_for_next_proof_over_same_field.Wrap.t
          , Import.Types.Digest.Constant.t
          , ( 'b
            , ( Kimchi_pasta.Pallas_based_plonk.Proof.G.Affine.t
              , 'actual_proofs_verified )
              Pickles_types.Vector.t
            , ( ( Import.Challenge.Constant.t Import.Scalar_challenge.t
                  Import.Bulletproof_challenge.t
                , 'e )
                Pickles_types.Vector.t
              , 'actual_proofs_verified )
              Pickles_types.Vector.t )
            Proof.Base.Messages_for_next_proof_over_same_field.Step.t
          , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
            Import.Types.Bulletproof_challenge.t
            Import.Types.Step_bp_vec.t
          , Import.Types.Branch_data.t )
          Import.Types.Wrap.Statement.In_circuit.t

     val check_verifier_error : Error.t -> unit
   end)
  -> sig end
