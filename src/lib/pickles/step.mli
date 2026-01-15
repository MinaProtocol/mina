(** {1 Step - Step Circuit Prover Generation}

    This module generates provers for step circuits. Step circuits run on
    the Tick (Vesta) curve and execute application logic while verifying
    predecessor wrap proofs.

    {2 Overview}

    The [Make] functor creates a step prover function [f] that:
    1. Executes the inductive rule's main function
    2. Verifies predecessor wrap proofs (if any)
    3. Produces a step proof ready for wrapping

    {2 Relationship to Wrap}

    {v
    Step Proof                   Wrap Proof
    ┌─────────────────┐         ┌─────────────────┐
    │ Application     │         │ Verifies step   │
    │ logic           │   ───►  │ proof           │
    │                 │         │                 │
    │ Verifies wrap   │         │ Uniform format  │
    │ proofs          │         │ for recursion   │
    └─────────────────┘         └─────────────────┘
    v}

    {2 Output Type}

    The step prover returns a tuple containing:
    - Base step proof with statement and underlying kimchi proof
    - Return value from the rule's main function
    - Auxiliary value (prover-only data)
    - Predecessor proof widths vector

    {2 Implementation Notes for Rust Port}

    - The [Make] functor is parameterized by the inductive rule interface
    - [A] and [A_value] are the circuit/constant public input types
    - [Max_proofs_verified] is a type-level natural (N0, N1, or N2)
    - The result is wrapped in [Promise.t] for async computation

    @see {!Step_main} for the step circuit logic
    @see {!Wrap} for wrapping step proofs
*)

open Pickles_types

(** [Make] creates a step prover from an inductive rule and type parameters. *)
module Make
    (Inductive_rule : Inductive_rule.Intf with type 'a proof = 'a Proof.t)
    (A : Pickles_types.Poly_types.T0) (A_value : sig
      type t
    end)
    (Max_proofs_verified : Pickles_types.Nat.Add.Intf_transparent) : sig
  module Step_branch_data : module type of Step_branch_data.Make (Inductive_rule)

  val f :
       ?handler:
         (   Snarky_backendless.Request.request
          -> Snarky_backendless.Request.response )
    -> proof_cache:Proof_cache.t option
    -> ( A.t
       , A_value.t
       , 'ret_var
       , 'ret_value
       , 'auxiliary_var
       , 'auxiliary_value
       , Max_proofs_verified.n
       , 'self_branches
       , 'prev_vars
       , 'prev_values
       , 'local_widths
       , 'local_heights )
       Step_branch_data.t
    -> A_value.t
    -> maxes:
         (module Pickles_types.Hlist.Maxes.S
            with type length = Max_proofs_verified.n
             and type ns = 'max_local_max_proof_verifieds )
    -> prevs_length:('prev_vars, 'prevs_length) Pickles_types.Hlist.Length.t
    -> self:('a, 'b, 'c, 'd) Tag.t
    -> step_domains:
         (Import.Domains.t, 'self_branches) Pickles_types.Vector.t Promise.t
    -> feature_flags:Opt.Flag.t Plonk_types.Features.Full.t
    -> self_dlog_plonk_index:
         Backend.Tick.Inner_curve.Affine.t array
         Pickles_types.Plonk_verification_key_evals.t
    -> public_input:
         ( 'var
         , 'value
         , A.t
         , A_value.t
         , 'ret_var
         , 'ret_value )
         Inductive_rule.public_input
    -> auxiliary_typ:('auxiliary_var, 'auxiliary_value) Impls.Step.Typ.t
    -> Kimchi_pasta.Vesta_based_plonk.Keypair.t
    -> Impls.Wrap.Verification_key.t
    -> ( ( 'value
         , ( Unfinalized.Constant.t
           , Max_proofs_verified.n )
           Pickles_types.Vector.t
         , (Backend.Tock.Curve.Affine.t, 'prevs_length) Pickles_types.Vector.t
         , ( Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
             Import.Types.Bulletproof_challenge.t
             Import.Types.Step_bp_vec.t
           , 'prevs_length )
           Pickles_types.Vector.t
         , 'local_widths
           Pickles_types.Hlist.H1.T
             (Proof.Base.Messages_for_next_proof_over_same_field.Wrap)
           .t
         , ( ( Backend.Tock.Field.t
             , Backend.Tock.Field.t array )
             Pickles_types.Plonk_types.All_evals.t
           , Max_proofs_verified.n )
           Pickles_types.Vector.t )
         Proof.Base.Step.t
       * 'ret_value
       * 'auxiliary_value
       * (int, 'prevs_length) Pickles_types.Vector.t )
       Promise.t
end
