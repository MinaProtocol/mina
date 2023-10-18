(** Compile the inductive rules *)

open Core_kernel
open Async_kernel
open Pickles_types
open Hlist

exception Return_digest of Md5.t

val pad_messages_for_next_wrap_proof :
     (module Pickles_types.Hlist.Maxes.S
        with type length = 'max_proofs_verified
         and type ns = 'max_local_max_proofs_verifieds )
  -> 'local_max_proofs_verifieds
     Hlist.H1.T(Proof.Base.Messages_for_next_proof_over_same_field.Wrap).t
  -> 'max_local_max_proofs_verifieds
     Hlist.H1.T(Proof.Base.Messages_for_next_proof_over_same_field.Wrap).t

module type Statement_intf = sig
  type field

  type t

  val to_field_elements : t -> field array
end

module type Statement_var_intf =
  Statement_intf with type field := Impls.Step.Field.t

module type Statement_value_intf =
  Statement_intf with type field := Impls.Step.field

module type Proof_intf = sig
  type statement

  type t

  val verification_key : Verification_key.t Lazy.t

  val id : Cache.Wrap.Key.Verification.t Lazy.t

  val verify : (statement * t) list -> unit Or_error.t Deferred.t

  val verify_promise : (statement * t) list -> unit Or_error.t Promise.t
end

val verify_promise :
     (module Nat.Intf with type n = 'n)
  -> (module Statement_value_intf with type t = 'a)
  -> Verification_key.t
  -> ('a * ('n, 'n) Proof.t) list
  -> unit Or_error.t Promise.t

module Prover : sig
  type ('prev_values, 'local_widths, 'local_heights, 'a_value, 'proof) t =
       ?handler:
         (   Snarky_backendless.Request.request
          -> Snarky_backendless.Request.response )
    -> 'a_value
    -> 'proof
end

module Side_loaded : sig
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

    val of_compiled : _ Tag.t -> t

    module Max_branches : Nat.Add.Intf

    module Max_width = Nat.N2
  end

  module Proof : sig
    [%%versioned:
    module Stable : sig
      module V2 : sig
        (* TODO: This should really be able to be any width up to the max width... *)
        type t =
          (Verification_key.Max_width.n, Verification_key.Max_width.n) Proof.t
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
    -> ('var, 'value, 'n1, Verification_key.Max_branches.n) Tag.t

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
         Lazy.t
      -> (int, 'branches) Pickles_types.Vector.t
      -> (Import.Domains.t, 'branches) Pickles_types.Vector.t
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
                   Pickles_types__Opt.t
                 , Impls.Wrap.Boolean.var )
                 Composition_types.Wrap.Proof_state.Deferred_values.Plonk
                 .In_circuit
                 .t
               , Wrap_verifier.Challenge.t Kimchi_types.scalar_challenge
               , Wrap_verifier.Other_field.Packed.t
                 Pickles_types__Shifted_value.Type1.t
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
         , (int64, Composition_types.Digest.Limbs.n) Pickles_types.Vector.vec
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
         , ( Limb_vector.Constant.Hex64.t
           , Composition_types.Digest.Limbs.n )
           Pickles_types.Vector.vec
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

(** This compiles a series of inductive rules defining a set into a proof
      system for proving membership in that set, with a prover corresponding
      to each inductive rule. *)
val compile_with_wrap_main_override_promise :
     ?self:('var, 'value, 'max_proofs_verified, 'branches) Tag.t
  -> ?cache:_ Cache.Spec.t
  -> ?proof_cache:Proof_cache.t
  -> ?disk_keys:
       (Cache.Step.Key.Verification.t, 'branches) Vector.t
       * Cache.Wrap.Key.Verification.t
  -> ?return_early_digest_exception:bool
  -> ?override_wrap_domain:Pickles_base.Proofs_verified.t
  -> ?override_wrap_main:
       ('max_proofs_verified, 'branches, 'prev_varss) wrap_main_generic
  -> public_input:
       ( 'var
       , 'value
       , 'a_var
       , 'a_value
       , 'ret_var
       , 'ret_value )
       Inductive_rule.public_input
  -> auxiliary_typ:('auxiliary_var, 'auxiliary_value) Impls.Step.Typ.t
  -> branches:(module Nat.Intf with type n = 'branches)
  -> max_proofs_verified:(module Nat.Add.Intf with type n = 'max_proofs_verified)
  -> name:string
  -> constraint_constants:Snark_keys_header.Constraint_constants.t
  -> choices:
       (   self:('var, 'value, 'max_proofs_verified, 'branches) Tag.t
        -> ( 'prev_varss
           , 'prev_valuess
           , 'widthss
           , 'heightss
           , 'a_var
           , 'a_value
           , 'ret_var
           , 'ret_value
           , 'auxiliary_var
           , 'auxiliary_value )
           H4_6.T(Inductive_rule).t )
  -> unit
  -> ('var, 'value, 'max_proofs_verified, 'branches) Tag.t
     * Cache_handle.t
     * (module Proof_intf
          with type t = ('max_proofs_verified, 'max_proofs_verified) Proof.t
           and type statement = 'value )
     * ( 'prev_valuess
       , 'widthss
       , 'heightss
       , 'a_value
       , ( 'ret_value
         * 'auxiliary_value
         * ('max_proofs_verified, 'max_proofs_verified) Proof.t )
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
     Lazy.t
  -> (int, 'branches) Pickles_types.Vector.t
  -> (Import.Domains.t, 'branches) Pickles_types.Vector.t
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
               Pickles_types__Opt.t
             , Impls.Wrap.Boolean.var )
             Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit
             .t
           , Wrap_verifier.Challenge.t Kimchi_types.scalar_challenge
           , Wrap_verifier.Other_field.Packed.t
             Pickles_types__Shifted_value.Type1.t
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
          , (int64, Composition_types.Digest.Limbs.n) Pickles_types.Vector.vec
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
          , ( Limb_vector.Constant.Hex64.t
            , Composition_types.Digest.Limbs.n )
            Pickles_types.Vector.vec
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
