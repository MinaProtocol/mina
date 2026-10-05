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
*)

open Pickles_types

(** Functor to create a step prover for a given inductive rule.

    @param Inductive_rule The interface defining the rule's structure including
      predecessor proof tags, main function, and public input/output types.
      The rule specifies which proofs to verify and the application logic.

    @param A The type of the circuit statement variable (used inside the circuit).

    @param A_value The type of the circuit statement value (concrete values
      outside the circuit).

    @param Max_proofs_verified Type-level natural number representing the maximum
      number of predecessor proofs this rule verifies. This determines the
      fixed-size vectors used for proof data. *)
module Make
    (Inductive_rule : Inductive_rule.Intf with type 'a proof = 'a Proof.t)
    (A : Pickles_types.Poly_types.T0) (A_value : sig
      type t
    end)
    (Max_proofs_verified : Pickles_types.Nat.Add.Intf_transparent) : sig
  (** Compiled step branch data containing the circuit, domains, and requests
      for this rule. Created by {!Step_branch_data.create}. *)
  module Step_branch_data : module type of Step_branch_data.Make (Inductive_rule)

  (** [f ?handler ~proof_cache branch_data statement ~maxes ~prevs_length
        ~self ~step_domains ~feature_flags ~self_dlog_plonk_index
        ~public_input ~auxiliary_typ pk wrap_vk]

      Generate a step proof by executing the inductive rule.

      @param handler Optional request handler for providing witness values
        during proving. Used to supply prover-only data like predecessor proofs.

      @param proof_cache Optional cache to store/retrieve proving artifacts,
        avoiding redundant computation when proving similar statements.

      @param branch_data Compiled circuit data for this rule branch, containing
        the constraint system, domain configuration, and request types.

      @param statement The public statement value to prove (e.g., blockchain
        state hash).

      @param maxes Module encoding the maximum proof counts for each predecessor
        proof system. Used for padding vectors to fixed sizes.

      @param prevs_length Type-level witness for the number of predecessor proofs.

      @param self Tag identifying this proof system, used for self-references
        in recursive rules.

      @param step_domains Domain configurations for all step circuit branches,
        needed for computing verification key hashes.

      @param feature_flags Circuit feature flags (lookups, runtime tables, etc.)
        that affect the proof structure.

      @param self_dlog_plonk_index Verification key polynomial evaluations for
        this proof system, used in the recursive verifier.

      @param public_input Specification of the public input structure (input only,
        output only, or both).

      @param auxiliary_typ Type for auxiliary prover-only values returned by
        the rule's main function.

      @param pk The step circuit proving key (Vesta-based).

      @param wrap_vk The wrap circuit verification key, needed for verifying
        that predecessor proofs will pass wrap verification.

      @return A promise of:
        - The step proof containing the statement and kimchi proof
        - The return value from the rule's main function
        - The auxiliary value (prover-only data)
        - Vector of predecessor proof widths (number of proofs each verified) *)
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
