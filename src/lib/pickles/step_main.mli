(** {1 Step Main - Step Circuit Entry Point}

    This module defines the main SNARK function for "step" circuits in the
    Pickles recursive proof system.

    {2 Overview}

    A step circuit:
    1. Executes user application logic (the "inductive rule")
    2. Partially verifies predecessor wrap proofs (group operations only)
    3. Produces "unfinalized" proof data for the subsequent wrap circuit

    Step circuits operate over the {b Tick (Vesta)} curve. They verify wrap
    proofs that came from the {b Tock (Pallas)} curve.

    {2 Tick/Tock Cycle Context}

    The key insight of Pickles is that Tick's scalar field equals Tock's
    base field (and vice versa). This means:
    - Step circuits can efficiently do Tock base field arithmetic (native)
    - Step circuits {i cannot} efficiently do Tock scalar field arithmetic
    - Scalar field operations are "deferred" to the wrap circuit

    {2 Data Flow}

    {v
    Inputs:                              Outputs:
    ┌────────────────────────────┐      ┌─────────────────────────────────┐
    │ Previous wrap proofs       │      │ Types.Step.Statement containing:│
    │ Application state (input)  │  ──► │  - unfinalized_proofs (vector)  │
    │ Inductive rule logic       │      │  - messages_for_next_step_proof │
    │ Known wrap verification    │      │  - messages_for_next_wrap_proof │
    │   keys for predecessors    │      └─────────────────────────────────┘
    └────────────────────────────┘
    v}

    {2 Verification Process}

    For each predecessor wrap proof, the step circuit:
    1. Verifies all group operations (curve point additions, scalar mults)
    2. Defers scalar-field checks to {!Unfinalized.t}
    3. Extracts new bulletproof challenges for accumulation
    4. Hashes messages for the next step/wrap proofs

    {2 Implementation Notes for Rust Port}

    - The [Make] functor takes an inductive rule module; in Rust, use a
      trait bound or generic parameter
    - Heavy use of GADTs for type-level verification counts; use const
      generics in Rust
    - Promise-based async for prover computation; use async/await in Rust
    - The staged function return allows separating circuit construction
      from execution

    @see <../GLOSSARY.md> for terminology definitions
    @see {!Step_verifier} for the verification logic used within step
    @see {!Wrap_main} for the corresponding wrap circuit
*)

module Make (Inductive_rule : Inductive_rule.Intf) : sig
  (** [step_main] constructs the main circuit function for a step proof.

      This highly polymorphic function:
      1. Takes request handlers for prover witness data
      2. Runs the inductive rule's application logic
      3. Partially verifies each predecessor wrap proof
      4. Accumulates bulletproof challenges
      5. Produces the step statement for the wrap circuit

      {3 Type Parameters}

      - ['proofs_verified]: Number of proofs this branch actually verifies
      - ['max_proofs_verified]: Maximum proofs any branch in this system
        verifies
      - ['self_branches]: Number of branches in this proof system
      - ['prev_vars], ['prev_values]: Predecessor public input types
        (nested tuples)
      - ['local_signature]: Signature of predecessor proof systems
      - ['local_branches]: Branch counts of predecessor proof systems
      - ['var], ['value]: This rule's public input circuit/native types
      - ['a_var], ['a_value]: Application state types
      - ['ret_var], ['ret_value]: Return value types
      - ['auxiliary_var], ['auxiliary_value]: Private auxiliary data types

      {3 Key Parameters}

      @param requests Module providing handlers for witness data requests
      @param max_proofs_verified Witness that this is the maximum width
      @param self_branches Number of branches in this proof system
      @param local_signature Predecessor proof system signatures (as HList)
      @param proofs_verified Length witness for predecessor count
      @param lte Proof that proofs_verified <= max_proofs_verified
      @param public_input Configuration for public input/output types
      @param auxiliary_typ Type for private auxiliary circuit data
      @param basic Compiled data for this proof system (verification keys,
        etc.)
      @param known_wrap_keys Wrap verification keys for each predecessor
        branch
      @param self Tag identifying this proof system
      @param rule The inductive rule (Promise) to execute

      @return Staged function that, when called, produces the step statement

      {3 Example Flow}

      {[
        (* 1. Create the step_main function *)
        let step_fn = step_main (module Requests) ...

        (* 2. Unstage and execute in prover *)
        let statement_promise = Staged.unstage step_fn () in

        (* 3. Await the statement *)
        let statement = Promise.block_on_async_exn statement_promise
      ]}

      BEWARE: The returned function captures references to wrap keys that
      must remain valid during proving.
  *)
  val step_main :
    'proofs_verified 'self_branches 'prev_vars 'prev_values 'var 'value 'a_var
    'a_value 'ret_var 'ret_value 'auxiliary_var 'auxiliary_value
    'max_proofs_verified 'local_branches 'local_signature.
       (module Requests.Step(Inductive_rule).S
          with type auxiliary_value = 'auxiliary_value
           and type local_branches = 'local_branches
           and type local_signature = 'local_signature
           and type max_proofs_verified = 'max_proofs_verified
           and type prev_values = 'prev_values
           and type proofs_verified = 'proofs_verified
           and type return_value = 'ret_value
           and type statement = 'a_value )
    -> (module Pickles_types.Nat.Add.Intf with type n = 'max_proofs_verified)
    -> self_branches:'self_branches Pickles_types.Nat.t
    -> local_signature:
         'local_signature Pickles_types.Hlist.H1.T(Pickles_types.Nat).t
    -> local_signature_length:
         ('local_signature, 'proofs_verified) Pickles_types.Hlist.Length.t
    -> local_branches_length:
         ('local_branches, 'proofs_verified) Pickles_types.Hlist.Length.t
    -> proofs_verified:
         ('prev_vars, 'proofs_verified) Pickles_types.Hlist.Length.t
    -> lte:('proofs_verified, 'max_proofs_verified) Pickles_types.Nat.Lte.t
    -> public_input:
         ( 'var
         , 'value
         , 'a_var
         , 'a_value
         , 'ret_var
         , 'ret_value )
         Inductive_rule.public_input
    -> auxiliary_typ:('auxiliary_var, 'auxiliary_value) Impls.Step.Typ.t
    -> basic:
         ( 'var
         , 'value
         , 'max_proofs_verified
         , 'self_branches )
         Types_map.Compiled.basic
    -> known_wrap_keys:
         'local_branches
         Pickles_types.Hlist.H1.T(Types_map.For_step.Optional_wrap_key).t
    -> self:('var, 'value, 'max_proofs_verified, 'self_branches) Tag.t
    -> ( 'prev_vars
       , 'prev_values
       , 'local_signature
       , 'local_branches
       , 'a_var
       , 'a_value
       , 'ret_var
       , 'ret_value
       , 'auxiliary_var
       , 'auxiliary_value )
       Inductive_rule.Promise.t
    -> (   unit
        -> ( (Unfinalized.t, 'max_proofs_verified) Pickles_types.Vector.t
           , Impls.Step.Field.t
           , (Impls.Step.Field.t, 'max_proofs_verified) Pickles_types.Vector.t
           )
           Import.Types.Step.Statement.t
           Promise.t )
       Core_kernel.Staged.t
end
