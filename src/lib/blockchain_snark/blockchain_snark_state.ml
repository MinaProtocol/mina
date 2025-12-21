(** {0 Blockchain SNARK State}

    This module implements the blockchain SNARK circuit for Mina Protocol.
    The blockchain SNARK is a recursive proof that verifies the validity of
    blockchain state transitions.

    {1 Architecture Overview}

    The blockchain SNARK uses the Pickles recursive proving system to create
    succinct proofs that chain together. Each blockchain SNARK proof:
    - Verifies the previous blockchain SNARK proof (recursion)
    - Verifies a transaction SNARK proof (if ledger changed)
    - Validates consensus state transitions
    - Manages pending coinbase operations
*)

open Core_kernel
open Snark_params
open Tick
open Mina_base
open Mina_state
open Pickles_types

(** {1 Request Types for Witness Provision}

    The blockchain SNARK uses Snarky's request/response mechanism to obtain
    witness values during proof generation. These request types define what
    data the prover needs to provide.

    The handler (see [blockchain_handler] below) responds to these requests
    with the actual witness values from [Witness.t].
*)
include struct
  open Snarky_backendless.Request

  (** Request types for witness data during proving *)
  type _ t +=
    | Prev_state : Protocol_state.Value.t t
        (** Request the previous protocol state value *)
    | Prev_state_proof : Nat.N2.n Pickles.Proof.t t
        (** Request the proof of the previous blockchain state *)
    | Transition : Snark_transition.Value.t t
        (** Request the snark transition data *)
    | Txn_snark : Transaction_snark.Statement.With_sok.t t
        (** Request the transaction SNARK statement *)
    | Txn_snark_proof : Nat.N2.n Pickles.Proof.t t
        (** Request the transaction SNARK proof *)
end

(** {1 Witness Type}

    The witness contains all private inputs needed to generate a blockchain
    SNARK proof. These values are provided by the block producer but are not
    included in the public proof statement.
*)
module Witness = struct
  (** The complete witness for blockchain SNARK proof generation.

      @param prev_state The previous protocol state (full value, not just hash)
      @param prev_state_proof Proof that prev_state is valid (N2 = verifies 2 proofs)
      @param transition The snark transition containing new state data
      @param txn_snark The transaction SNARK statement (ledger transition)
      @param txn_snark_proof Proof of the transaction SNARK (N2 proof)
  *)
  type t =
    { prev_state : Protocol_state.Value.t
    ; prev_state_proof : Nat.N2.n Pickles.Proof.t
    ; transition : Snark_transition.Value.t
    ; txn_snark : Transaction_snark.Statement.With_sok.t
    ; txn_snark_proof : Nat.N2.n Pickles.Proof.t
    }
end

(** {1 Request Handlers}

    These functions create Snarky request handlers that provide witness
    values during proof generation. The handler pattern allows the circuit
    to request values on-demand as constraints are being constructed.
*)

(** Create a request handler for blockchain SNARK witness values.

    @param on_unhandled Fallback handler for unrecognized requests
    @param witness The witness containing all required values
    @return A handler function that responds to witness requests
*)
let blockchain_handler on_unhandled
    { Witness.prev_state
    ; prev_state_proof
    ; transition
    ; txn_snark
    ; txn_snark_proof
    } =
  let open Snarky_backendless.Request in
  fun (With { request; respond } as r) ->
    let k x = respond (Provide x) in
    match request with
    | Prev_state ->
        k prev_state
    | Prev_state_proof ->
        k prev_state_proof
    | Transition ->
        k transition
    | Txn_snark ->
        k txn_snark
    | Txn_snark_proof ->
        k txn_snark_proof
    | _ ->
        on_unhandled r

(** Wrap an optional user-provided handler with the blockchain handler.

    This allows composing the blockchain SNARK's handler with additional
    handlers for custom extensions.
*)
let wrap_handler h w =
  match h with
  | None ->
      blockchain_handler
        (fun (Snarky_backendless.Request.With { respond; _ }) ->
          respond Unhandled )
        w
  | Some h ->
      (* TODO: Clean up the handler composition interface. *)
      fun r -> blockchain_handler h w r

(** Helper to run a checked computation with the blockchain handler installed. *)
let with_handler k w ?handler =
  let h = wrap_handler handler w in
  k ?handler:(Some h)

(** {1 Helper Functions for Statement Comparison}

    These functions compare transaction SNARK statements to determine
    whether ledger state has changed. They are used to decide if a new
    ledger proof was created.
*)

(** Pickles Step implementation - uses Pallas curve (Tick) *)
module Impl = Pickles.Impls.Step

(** Compare two register sets for equality, EXCLUDING pending_coinbase_stack.

    Registers contain:
    - first_pass_ledger: Ledger hash after first pass transactions
    - second_pass_ledger: Ledger hash after second pass transactions
    - pending_coinbase_stack: (ignored in this comparison)
    - local_state: Zkapp local state (stack, call stack, etc.)

    @return Boolean.var that is true if all compared fields are equal
*)
let non_pc_registers_equal_var t1 t2 =
  Impl.make_checked (fun () ->
      let module F = Core_kernel.Field in
      let ( ! ) eq x1 x2 = Impl.run_checked (eq x1 x2) in
      let f eq acc field = eq (F.get field t1) (F.get field t2) :: acc in
      Registers.Fields.fold ~init:[]
        ~first_pass_ledger:(f !Frozen_ledger_hash.equal_var)
        ~second_pass_ledger:(f !Frozen_ledger_hash.equal_var)
        ~pending_coinbase_stack:(fun acc f ->
          (* Skip pending_coinbase_stack - handled separately *)
          let () = F.get f t1 and () = F.get f t2 in
          acc )
        ~local_state:(fun acc f ->
          Local_state.Checked.equal' (F.get f t1) (F.get f t2) @ acc )
      |> Impl.Boolean.all )

(** Compare two transaction SNARK statements for ledger hash equality.

    This function determines if the ledger state has changed between
    the previous and current statements. It compares:
    - source registers (excluding pending_coinbase_stack)
    - target registers (excluding pending_coinbase_stack)
    - connecting_ledger_left
    - connecting_ledger_right
    - supply_increase

    Note: pending_coinbase_stack is intentionally excluded because it
    is handled separately in the coinbase verification logic.

    @param s1 First statement (typically from previous blockchain state)
    @param s2 Second statement (typically the new transaction SNARK statement)
    @return Boolean.var that is true if all ledger hashes are equal
            (meaning no new ledger transition occurred)
*)
let txn_statement_ledger_hashes_equal
    (s1 : Transaction_snark.Statement.Checked.t)
    (s2 : Transaction_snark.Statement.Checked.t) =
  Impl.make_checked (fun () ->
      let module F = Core_kernel.Field in
      let ( ! ) x = Impl.run_checked x in
      (* Compare source registers (excluding pending_coinbase_stack) *)
      let source_eq =
        !(non_pc_registers_equal_var
            { s1.source with pending_coinbase_stack = () }
            { s2.source with pending_coinbase_stack = () } )
      in
      (* Compare target registers (excluding pending_coinbase_stack) *)
      let target_eq =
        !(non_pc_registers_equal_var
            { s1.target with pending_coinbase_stack = () }
            { s2.target with pending_coinbase_stack = () } )
      in
      (* Compare connecting ledger hashes *)
      let left_ledger_eq =
        !(Frozen_ledger_hash.equal_var s1.connecting_ledger_left
            s2.connecting_ledger_left )
      in
      let right_ledger_eq =
        !(Frozen_ledger_hash.equal_var s1.connecting_ledger_right
            s2.connecting_ledger_right )
      in
      (* Compare supply increase *)
      let supply_increase_eq =
        !(Currency.Amount.Signed.Checked.equal s1.supply_increase
            s2.supply_increase )
      in
      Impl.Boolean.all
        [ source_eq
        ; target_eq
        ; left_ledger_eq
        ; right_ledger_eq
        ; supply_increase_eq
        ] )

(** {1 Blockchain SNARK - Main Circuit Definition}

    The blockchain SNARK is the core recursive proof that validates the entire
    Mina blockchain. It proves that a new protocol state is a valid transition
    from a previous protocol state.

    {2 Overview of What This SNARK Verifies}

    The blockchain SNARK circuit enforces the following invariants:

    1. {b State Hash Integrity}: The hash of the new protocol state matches
       the public input (new_state_hash).

    2. {b Previous State Linkage}: The new state correctly references the
       previous state's hash, maintaining blockchain continuity.

    3. {b Consensus State Transition}: The transition from the previous
       consensus state to the new one follows the consensus rules
       (via [Consensus_state_hooks.next_state_checked]).

    4. {b Ledger State Validity}: Either:
       - A new ledger proof was created (transaction snark input is correct), OR
       - No ledger transition occurred (ledger hashes unchanged)

    5. {b Pending Coinbase Management}: Coinbases are correctly added/removed
       from the pending coinbase stack based on whether a new ledger proof
       was emitted.

    6. {b Recursive Proof Verification}: Two proofs are recursively verified:
       - The previous blockchain proof (unless this is the genesis block)
       - The transaction snark proof (if a new ledger proof was emitted)

    {2 Inputs and Witness Structure}

    {b Public Input:}
    - [new_state]: The new protocol state (hashed via [Data_as_hash])

    {b Witness (private inputs):}
    - [prev_state]: The previous protocol state value
    - [prev_state_proof]: Proof that the previous state was valid (N2 proof)
    - [transition]: The snark transition containing new blockchain state and
      consensus transition data
    - [txn_snark]: The transaction snark statement with ledger source/target
    - [txn_snark_proof]: Proof of the transaction snark (N2 proof)

    {2 Success Condition}

    The circuit succeeds when:
    {[
      (is_base_case OR success) AND
      (txn_snark_input_correct OR nothing_changed) AND
      updated_consensus_state AND
      correct_coinbase_status
    ]}
*)

(* Legacy comment preserved for reference:
   Blockchain_snark ~old ~nonce ~ledger_snark ~ledger_hash ~timestamp ~new_hash
      Input:
        old : Blockchain.t
        old_snark : proof
        nonce : int
        work_snark : proof
        ledger_hash : Ledger_hash.t
        timestamp : Time.t
        new_hash : State_hash.t
      Witness:
        transition : Transition.t
      such that
        the old_snark verifies against old
        new = update_with_asserts(old, nonce, timestamp, ledger_hash)
        hash(new) = new_hash
        the work_snark verifies against the old.ledger_hash and new_ledger_hash
        new.timestamp > old.timestamp
        transition consensus data is valid
        new consensus state is a function of the old consensus state
*)
let%snarkydef_ step ~(logger : Logger.t)
    ~(proof_level : Genesis_constants.Proof_level.t)
    ~(constraint_constants : Genesis_constants.Constraint_constants.t) new_state
    : _ Tick.Checked.t =
  (* ========================================================================
     VERIFICATION STEP 1: Extract Public Input Hash
     ========================================================================
     The public input to this SNARK is the new protocol state, passed as a
     [Data_as_hash.t]. We extract its hash to use for verification later.
     This hash will be compared against the computed hash of the new state
     to ensure integrity.

     Type: [new_state_hash : State_hash.var]
     Constraint: None yet - just extracting the hash from the public input
  *)
  let new_state_hash =
    State_hash.var_of_hash_packed (Data_as_hash.hash new_state)
  in
  (* ========================================================================
     WITNESS LOADING: Snark Transition
     ========================================================================
     Load the snark transition from the witness. Contains:
     - blockchain_state: The new blockchain state (ledger hashes, timestamp)
     - consensus_transition: Data for consensus state transition
     - pending_coinbase_update: How to update the pending coinbase stack

     Type: [transition : Snark_transition.var]
  *)
  let%bind transition =
    with_label __LOC__ (fun () ->
        exists Snark_transition.typ ~request:(As_prover.return Transition) )
  in
  (* ========================================================================
     WITNESS LOADING: Transaction SNARK Statement
     ========================================================================
     Load the transaction SNARK statement from the witness. This statement
     describes the ledger transition that was proven by the transaction SNARK:
     - source: Starting ledger state (registers + pending coinbase)
     - target: Ending ledger state
     - connecting_ledger_left/right: Intermediate ledger hashes
     - supply_increase: Net change in total currency supply
     - fee_excess: Must be zero for valid blockchain transitions

     Type: [txn_snark : Transaction_snark.Statement.Checked.t]
  *)
  let%bind txn_snark =
    with_label __LOC__ (fun () ->
        exists Transaction_snark.Statement.With_sok.typ
          ~request:(As_prover.return Txn_snark) )
  in
  (* ========================================================================
     VERIFICATION STEP 2: Load and Hash Previous State
     ========================================================================
     Load the previous protocol state from the witness and compute its hash.
     This establishes the chain linkage - we verify that:
     1. The previous state exists and is well-formed
     2. Its hash matches what we'll reference in the new state

     The hash is computed using [Protocol_state.hash_checked] which applies
     the Poseidon hash function to the state structure.

     Outputs:
     - previous_state: The full previous protocol state (for reading fields)
     - previous_state_hash: Hash of previous state (for chain linkage)
     - previous_blockchain_proof_input: Wrapped hash for recursive proof
     - previous_state_body_hash: Hash of the body (for coinbase operations)

     Constraint: Computes Poseidon hash of previous_state
  *)
  let%bind ( previous_state
           , previous_state_hash
           , previous_blockchain_proof_input
           , previous_state_body_hash ) =
    let%bind prev_state_ref =
      with_label __LOC__ (fun () ->
          exists (Typ.prover_value ()) ~request:(As_prover.return Prev_state) )
    in
    let%bind t =
      with_label __LOC__ (fun () ->
          exists
            (Protocol_state.typ ~constraint_constants)
            ~compute:(As_prover.read (Typ.prover_value ()) prev_state_ref) )
    in
    let%map previous_state_hash, body = Protocol_state.hash_checked t in
    let previous_blockchain_proof_input =
      Data_as_hash.make_unsafe
        (State_hash.var_to_field previous_state_hash)
        prev_state_ref
    in
    (t, previous_state_hash, previous_blockchain_proof_input, body)
  in
  (* ========================================================================
     VERIFICATION STEP 3: Check if Ledger State Changed
     ========================================================================
     Compare the transaction SNARK statement's ledger hashes against the
     previous blockchain state's ledger proof statement. This determines
     whether a new ledger proof was created in this block.

     The comparison checks (via [txn_statement_ledger_hashes_equal]):
     - source registers (first_pass_ledger, second_pass_ledger, local_state)
     - target registers (first_pass_ledger, second_pass_ledger, local_state)
     - connecting_ledger_left and connecting_ledger_right
     - supply_increase

     Note: pending_coinbase_stack is NOT compared here (handled separately)

     Result: [txn_stmt_ledger_hashes_didn't_change : Boolean.var]
     - true = no new ledger proof (reusing previous statement)
     - false = new ledger proof was created

     Constraint: Multiple equality checks on ledger hash fields
  *)
  let%bind txn_stmt_ledger_hashes_didn't_change =
    txn_statement_ledger_hashes_equal
      (previous_state |> Protocol_state.blockchain_state).ledger_proof_statement
      { txn_snark with sok_digest = () }
  in
  (* ========================================================================
     VERIFICATION STEP 4: Compute Supply Increase
     ========================================================================
     The supply increase is only applied if a new ledger proof was created.
     If the ledger hashes didn't change, supply_increase = 0.

     This prevents double-counting supply increases when blocks don't
     include new transaction proofs.

     Constraint: Conditional selection based on txn_stmt_ledger_hashes_didn't_change
  *)
  let%bind supply_increase =
    Currency.Amount.(
      Signed.Checked.if_ txn_stmt_ledger_hashes_didn't_change
        ~then_:
          (Signed.create_var ~magnitude:(var_of_t zero) ~sgn:Sgn.Checked.pos)
        ~else_:txn_snark.supply_increase)
  in
  (* ========================================================================
     VERIFICATION STEP 5: Validate Consensus State Transition
     ========================================================================
     This is a CRITICAL verification step. It validates that the transition
     from the previous consensus state to the new one follows all consensus
     rules. Implemented in [Consensus_state_hooks.next_state_checked].

     What gets verified (in Ouroboros Samasika / Mina consensus):
     - Slot number progression
     - Epoch transitions
     - VRF output validity (for block producer selection)
     - Staking epoch ledger references
     - Total currency and supply increase accounting
     - Min window density (for chain selection)
     - Sub-window densities

     Inputs:
     - prev_state: The previous protocol state
     - prev_state_hash: Hash of previous state
     - transition: The snark transition with consensus transition data
     - supply_increase: Net change in currency supply

     Outputs:
     - updated_consensus_state: Boolean indicating success
     - consensus_state: The new consensus state

     Constraint: Extensive consensus rule checks (see consensus library)
  *)
  let%bind `Success updated_consensus_state, consensus_state =
    with_label __LOC__ (fun () ->
        Consensus_state_hooks.next_state_checked ~constraint_constants
          ~prev_state:previous_state ~prev_state_hash:previous_state_hash
          transition supply_increase )
  in
  (* Extract consensus-derived values needed for coinbase operations *)
  let global_slot =
    Consensus.Data.Consensus_state.global_slot_since_genesis_var consensus_state
  in
  let supercharge_coinbase =
    Consensus.Data.Consensus_state.supercharge_coinbase_var consensus_state
  in
  (* ========================================================================
     VERIFICATION STEP 6: Get Previous Pending Coinbase Root
     ========================================================================
     Extract the pending coinbase Merkle root from the previous state's
     staged ledger hash. This root will be used to verify coinbase
     pop/add operations.

     The pending coinbase is a data structure that tracks coinbase rewards
     that haven't yet been included in a ledger proof.
  *)
  let prev_pending_coinbase_root =
    previous_state |> Protocol_state.blockchain_state
    |> Blockchain_state.staged_ledger_hash
    |> Staged_ledger_hash.pending_coinbase_hash_var
  in
  (* ========================================================================
     VERIFICATION STEP 7: Determine Genesis State Hash
     ========================================================================
     Get the genesis state hash. Special handling for forks:
     - If previous state IS the genesis state, use its own hash
     - Otherwise, inherit from previous state's genesis_state_hash field

     This enables hard forks to maintain correct genesis references.
  *)
  let%bind genesis_state_hash =
    Protocol_state.genesis_state_hash_checked ~state_hash:previous_state_hash
      previous_state
  in
  (* ========================================================================
     VERIFICATION STEP 8: Construct and Verify New State Hash
     ========================================================================
     This is a CRITICAL verification step that ensures state hash integrity.

     We construct the new protocol state from its components and verify
     that its hash matches the public input (new_state_hash).

     Steps:
     1. Create new protocol state from:
        - previous_state_hash (chain linkage)
        - genesis_state_hash (fork handling)
        - blockchain_state (from transition)
        - consensus_state (from step 5)
        - constants (inherited from previous state)

     2. Check if this is the genesis/base case (first block after genesis)

     3. Handle fork scenarios: if at a fork point, use the fork's
        previous state hash instead of the computed one

     4. ASSERT: Hash of constructed state == public input hash
        This is the core integrity check of the blockchain SNARK!

     Constraint: State_hash.assert_equal (computed hash, public input hash)
  *)
  let%bind new_state, is_base_case =
    let t =
      Protocol_state.create_var ~previous_state_hash ~genesis_state_hash
        ~blockchain_state:(Snark_transition.blockchain_state transition)
        ~consensus_state
        ~constants:(Protocol_state.constants previous_state)
    in
    let%bind is_base_case =
      Protocol_state.consensus_state t
      |> Consensus.Data.Consensus_state.is_genesis_state_var
    in
    (* Handle hard fork: at fork point, use fork's previous state hash *)
    let%bind previous_state_hash =
      match constraint_constants.fork with
      | Some { state_hash = fork_prev; _ } ->
          State_hash.if_ is_base_case
            ~then_:(State_hash.var_of_t fork_prev)
            ~else_:t.previous_state_hash
      | None ->
          Checked.return t.previous_state_hash
    in
    let t = { t with previous_state_hash } in
    (* CRITICAL CONSTRAINT: Verify computed hash matches public input *)
    let%map () =
      let%bind h, _ = Protocol_state.hash_checked t in
      with_label __LOC__ (fun () -> State_hash.assert_equal h new_state_hash)
    in
    (t, is_base_case)
  in
  (* ========================================================================
     VERIFICATION STEP 9: Pending Coinbase and Transaction SNARK Verification
     ========================================================================
     This is a complex verification block that handles:
     A. Pending coinbase stack management (pop and add operations)
     B. Transaction SNARK statement validity
     C. Overall success condition computation

     The pending coinbase is a Merkle tree that tracks coinbase rewards.
     When a ledger proof is emitted, coinbases are "popped" (finalized).
     Each block adds new coinbases to the stack.
  *)
  let%bind txn_snark_must_verify, success =
    (* ----------------------------------------------------------------------
       STEP 9A: Pending Coinbase Pop Operation
       ----------------------------------------------------------------------
       When a new ledger proof is emitted (proof_emitted = true), we must
       pop coinbases from the pending coinbase stack. These are the coinbases
       that were included in the transactions proven by the ledger proof.

       - proof_emitted = NOT txn_stmt_ledger_hashes_didn't_change
       - If no new proof, this should be a no-op (root unchanged)

       Outputs:
       - root_after_delete: New pending coinbase root after popping
       - deleted_stack: The stack that was popped (for verification)
       - no_coinbases_popped: Boolean, true if pop was a no-op
    *)
    let%bind new_pending_coinbase_hash, deleted_stack, no_coinbases_popped =
      let coinbase_receiver =
        Consensus.Data.Consensus_state.coinbase_receiver_var consensus_state
      in
      let%bind root_after_delete, deleted_stack =
        Pending_coinbase.Checked.pop_coinbases ~constraint_constants
          prev_pending_coinbase_root
          ~proof_emitted:(Boolean.not txn_stmt_ledger_hashes_didn't_change)
      in
      (* Verify: if no new ledger proof, pop should be no-op *)
      let%bind no_coinbases_popped =
        Pending_coinbase.Hash.equal_var root_after_delete
          prev_pending_coinbase_root
      in
      (* ----------------------------------------------------------------------
         STEP 9B: Pending Coinbase Add Operation
         ----------------------------------------------------------------------
         Add the new block's coinbase to the pending coinbase stack.
         The coinbase includes:
         - coinbase_receiver: Who receives the block reward
         - supercharge_coinbase: Whether this is a supercharged coinbase
         - previous_state_body_hash: For coinbase memo/reference
         - global_slot: Current slot number

         The pending_coinbase_update from the transition specifies how to
         update the stack (which coinbase action to take).
      *)
      let%map new_root =
        with_label __LOC__ (fun () ->
            Pending_coinbase.Checked.add_coinbase ~constraint_constants
              root_after_delete
              (Snark_transition.pending_coinbase_update transition)
              ~coinbase_receiver ~supercharge_coinbase previous_state_body_hash
              global_slot )
      in
      (new_root, deleted_stack, no_coinbases_popped)
    in
    (* Get the current ledger statement from the new state *)
    let current_ledger_statement =
      (Protocol_state.blockchain_state new_state).ledger_proof_statement
    in
    (* Create the expected source stack from the deleted stack *)
    let pending_coinbase_source_stack =
      Pending_coinbase.Stack.Checked.create_with deleted_stack
    in
    (* ----------------------------------------------------------------------
       STEP 9C: Verify Transaction SNARK Input Correctness
       ----------------------------------------------------------------------
       This verifies that the transaction SNARK statement is valid when a
       new ledger proof was created. Checks include:

       1. Fee excess must be zero
          - All fees in the transactions must balance out
          - Prevents fee manipulation attacks

       2. Ledger statement connectivity (valid_ledgers_at_merge_checked)
          - Previous statement's target == current statement's source
          - Ensures ledger proofs chain together correctly
          - See [Snarked_ledger_state.valid_ledgers_at_merge_checked]

       3. Pending coinbase stack consistency
          - txn_snark.source.pending_coinbase_stack == expected source stack
          - txn_snark.target.pending_coinbase_stack == deleted_stack
          - Ensures coinbase handling is consistent between blockchain
            and transaction SNARKs

       Result: [txn_snark_input_correct : Boolean.var]
    *)
    let%bind txn_snark_input_correct =
      let open Checked in
      (* CONSTRAINT: Fee excess must be zero *)
      let%bind () =
        Fee_excess.(assert_equal_checked (var_of_t zero) txn_snark.fee_excess)
      in
      let previous_ledger_statement =
        (Protocol_state.blockchain_state previous_state).ledger_proof_statement
      in
      (* Check ledger connectivity between previous and current statements *)
      let ledger_statement_valid =
        Impl.make_checked (fun () ->
            Snarked_ledger_state.(
              valid_ledgers_at_merge_checked
                (Statement_ledgers.of_statement previous_ledger_statement)
                (Statement_ledgers.of_statement current_ledger_statement)) )
      in
      (*TODO: Any assertion about the local state and sok digest
         in the statement required?*)
      all
        [ ledger_statement_valid
        (* Check: txn_snark source coinbase stack matches expected *)
        ; Pending_coinbase.Stack.equal_var
            txn_snark.source.pending_coinbase_stack
            pending_coinbase_source_stack
        (* Check: txn_snark target coinbase stack matches deleted stack *)
        ; Pending_coinbase.Stack.equal_var
            txn_snark.target.pending_coinbase_stack deleted_stack
        ]
      >>= Boolean.all
    in
    (* ----------------------------------------------------------------------
       STEP 9D: Check "Nothing Changed" Condition
       ----------------------------------------------------------------------
       If no new ledger proof was created, we expect:
       - Ledger hashes unchanged (txn_stmt_ledger_hashes_didn't_change = true)
       - No coinbases were popped (no_coinbases_popped = true)

       This is the alternative valid state when no transaction work was done.
    *)
    let%bind nothing_changed =
      Boolean.all [ txn_stmt_ledger_hashes_didn't_change; no_coinbases_popped ]
    in
    (* ----------------------------------------------------------------------
       STEP 9E: Verify Coinbase Status
       ----------------------------------------------------------------------
       Verify that the new pending coinbase hash in the transition matches
       what we computed after pop + add operations.

       This ensures the staged ledger hash in the new state correctly
       reflects the pending coinbase updates.
    *)
    let%bind correct_coinbase_status =
      let new_root =
        transition |> Snark_transition.blockchain_state
        |> Blockchain_state.staged_ledger_hash
        |> Staged_ledger_hash.pending_coinbase_hash_var
      in
      Pending_coinbase.Hash.equal_var new_pending_coinbase_hash new_root
    in
    (* ----------------------------------------------------------------------
       STEP 9F: Main Validity Assertion
       ----------------------------------------------------------------------
       CRITICAL CONSTRAINT: At least one of these must be true:
       - txn_snark_input_correct: A valid new ledger proof was created
       - nothing_changed: No ledger transition occurred (valid idle state)

       This is an OR condition - the blockchain can advance either by
       including transaction work OR by producing an empty block.
    *)
    let%bind () =
      with_label __LOC__ (fun () ->
          Boolean.Assert.any [ txn_snark_input_correct; nothing_changed ] )
    in
    (* Determine if transaction SNARK proof needs verification *)
    let transaction_snark_should_verifiy = Boolean.not nothing_changed in
    (* ----------------------------------------------------------------------
       STEP 9G: Compute Overall Success
       ----------------------------------------------------------------------
       The step succeeds when:
       - updated_consensus_state = true (consensus rules satisfied)
       - correct_coinbase_status = true (coinbase handling correct)

       Note: The txn_snark_input_correct OR nothing_changed assertion
       was already enforced above, so we don't include it in result.
    *)
    let%bind result =
      Boolean.all [ updated_consensus_state; correct_coinbase_status ]
    in
    let%map () =
      as_prover
        As_prover.(
          Let_syntax.(
            let%map txn_snark_input_correct =
              read Boolean.typ txn_snark_input_correct
            and nothing_changed = read Boolean.typ nothing_changed
            and no_coinbases_popped = read Boolean.typ no_coinbases_popped
            and updated_consensus_state =
              read Boolean.typ updated_consensus_state
            and correct_coinbase_status =
              read Boolean.typ correct_coinbase_status
            and result = read Boolean.typ result in
            [%log trace]
              "blockchain snark update success: $result = \
               (transaction_snark_input_correct=$transaction_snark_input_correct \
               ∨ nothing_changed \
               (no_coinbases_popped=$no_coinbases_popped)=$nothing_changed) ∧ \
               updated_consensus_state=$updated_consensus_state ∧ \
               correct_coinbase_status=$correct_coinbase_status"
              ~metadata:
                [ ( "transaction_snark_input_correct"
                  , `Bool txn_snark_input_correct )
                ; ("nothing_changed", `Bool nothing_changed)
                ; ("updated_consensus_state", `Bool updated_consensus_state)
                ; ("correct_coinbase_status", `Bool correct_coinbase_status)
                ; ("result", `Bool result)
                ; ("no_coinbases_popped", `Bool no_coinbases_popped)
                ]))
    in
    (transaction_snark_should_verifiy, result)
  in
  (* ========================================================================
     VERIFICATION STEP 10: Determine Proof Verification Requirements
     ========================================================================
     Based on the proof_level configuration, determine whether the recursive
     proofs actually need to be verified.

     Proof levels:
     - Full: Production mode, all proofs must verify
     - Check: Development mode, proofs are not verified (faster testing)
     - No_check: Same as Check, no verification

     Transaction SNARK verification:
     - Only required if a new ledger proof was created (nothing_changed = false)
     - AND we're in Full proof level

     Previous blockchain proof verification:
     - Only required if this is NOT the base case (not genesis block)
     - AND we're in Full proof level
  *)
  let txn_snark_must_verify =
    match proof_level with
    | Check | No_check ->
        Boolean.false_
    | Full ->
        txn_snark_must_verify
  in
  let prev_must_verify =
    match proof_level with
    | Check | No_check ->
        Boolean.false_
    | Full ->
        Boolean.not is_base_case
  in
  (* ========================================================================
     VERIFICATION STEP 11: Final Success Assertion
     ========================================================================
     CRITICAL CONSTRAINT: Either we're at the base case (genesis) OR
     the step succeeded. This is the final gate that determines if the
     entire blockchain SNARK circuit is satisfied.

     Constraint: is_base_case OR success
  *)
  let%bind () =
    with_label __LOC__ (fun () -> Boolean.Assert.any [ is_base_case; success ])
  in
  (* ========================================================================
     STEP 12: Load Proofs and Return Previous Proof Statements
     ========================================================================
     Load the actual proof witnesses and construct the return value.
     This function returns two [Previous_proof_statement] records that
     Pickles uses for recursive verification:

     1. Previous blockchain proof:
        - public_input: Hash of previous state (for recursive verification)
        - proof: The actual N2 proof from the witness
        - proof_must_verify: true unless base case or non-Full mode

     2. Transaction SNARK proof:
        - public_input: The transaction snark statement
        - proof: The actual N2 proof from the witness
        - proof_must_verify: true if new ledger proof AND Full mode

     These proofs are verified by Pickles during the wrap phase,
     creating the recursive proof chain that secures the blockchain.
  *)
  let%bind previous_blockchain_proof =
    exists (Typ.prover_value ()) ~request:(As_prover.return Prev_state_proof)
  in
  let%map txn_snark_proof =
    exists (Typ.prover_value ()) ~request:(As_prover.return Txn_snark_proof)
  in
  (* Return the two previous proof statements for Pickles recursive verification *)
  ( { Pickles.Inductive_rule.Previous_proof_statement.public_input =
        previous_blockchain_proof_input
    ; proof = previous_blockchain_proof
    ; proof_must_verify = prev_must_verify
    }
  , { Pickles.Inductive_rule.Previous_proof_statement.public_input = txn_snark
    ; proof = txn_snark_proof
    ; proof_must_verify = txn_snark_must_verify
    } )

(** {1 Statement Module}

    The Statement module defines the public input type for the blockchain SNARK.
    The public input is the protocol state, represented as a hash.
*)
module Statement = struct
  (** The statement type is the full protocol state value.
      However, it's passed to the circuit as [Data_as_hash.t], meaning only
      the hash is constrained in the circuit, while the full value is
      available in the prover for witness generation.
  *)
  type t = Protocol_state.Value.t

  (** Type descriptor for the statement.
      Uses [Data_as_hash.typ] which hashes the protocol state to create
      the actual public input (a single field element = the state hash).
  *)
  let typ =
    Data_as_hash.typ ~hash:(fun t -> (Protocol_state.hashes t).state_hash)

  (** Convert statement to field elements (for public input extraction) *)
  let to_field_elements =
    let (Typ { value_to_fields; _ }) = typ in
    Fn.compose fst value_to_fields
end

(** {1 Pickles Tag Type}

    The tag type uniquely identifies this SNARK in the Pickles compilation.
    It encodes:
    - Public input type: [Protocol_state.Value.t Data_as_hash.t]
    - Statement type: [Protocol_state.Value.t]
    - Max proofs verified: N2 (this SNARK verifies up to 2 previous proofs)
    - Branches: N1 (there is 1 branch/rule in this SNARK)
*)
type tag =
  ( Protocol_state.Value.t Data_as_hash.t
  , Statement.t
  , Nat.N2.n
  , Nat.N1.n )
  Pickles.Tag.t

(** {1 Utility Functions} *)

(** Check the constraint system without generating a full proof.

    This is useful for testing and debugging - it verifies that the
    constraints are satisfiable with the given witness, but doesn't
    produce a proof.

    @param w Witness values
    @param handler Optional additional request handler
    @param proof_level Proof level configuration
    @param constraint_constants Constraint constants
    @param new_state_hash The new protocol state to verify
    @return [Ok ()] if constraints are satisfied, [Error] otherwise
*)
let check w ?handler ~proof_level ~constraint_constants new_state_hash :
    unit Or_error.t =
  let open Tick in
  check
    (Fn.flip handle (wrap_handler handler w) (fun () ->
         let%bind curr =
           exists Statement.typ ~compute:(As_prover.return new_state_hash)
         in
         step ~proof_level ~constraint_constants ~logger:(Logger.create ()) curr )
    )

(** Create the Pickles inductive rule for the blockchain SNARK.

    The rule specifies:
    - identifier: "step" (name for debugging)
    - prevs: [self, transaction_snark] (the two proofs this rule verifies)
    - main: The circuit function that returns previous proof statements
    - feature_flags: None (no optional features enabled)

    @param proof_level Proof level configuration
    @param constraint_constants Genesis constraint constants
    @param transaction_snark Tag for the transaction SNARK (for linking)
    @param self Tag for this blockchain SNARK (for recursion)
    @return A Pickles inductive rule
*)
let rule ~proof_level ~constraint_constants transaction_snark self :
    _ Pickles.Inductive_rule.t =
  { identifier = "step"
  ; prevs = [ self; transaction_snark ]
  ; main =
      (fun { public_input = x } ->
        let b1, b2 =
          Run.run_checked
            (step ~proof_level ~constraint_constants ~logger:(Logger.create ())
               x )
        in
        { previous_proof_statements = [ b1; b2 ]
        ; public_output = ()
        ; auxiliary_output = ()
        } )
  ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
  }

(** {1 Module Signature}

    Signature for compiled blockchain SNARK modules.
*)
module type S = sig
  (** Proof type - an N2 Pickles proof with protocol state as statement *)
  module Proof :
    Pickles.Proof_intf
      with type t = Nat.N2.n Pickles.Proof.t
       and type statement = Protocol_state.Value.t

  (** The Pickles tag for this SNARK *)
  val tag : tag

  (** Handle to cached proving/verification keys *)
  val cache_handle : Pickles.Cache_handle.t

  open Nat

  (** The prover function.

      Takes a witness and returns a Pickles prover that produces
      a blockchain SNARK proof.

      Type parameters encode:
      - Public inputs: (Protocol_state, Transaction_snark.Statement, unit)
      - Proofs verified: (N2, N2, unit) - up to 2 proofs each
      - Branches: (N1, N5, unit) - 1 blockchain rule, 5 transaction rules
      - Statement: Protocol_state.Value.t
      - Output: Deferred proof
  *)
  val step :
       Witness.t
    -> ( Protocol_state.Value.t * (Transaction_snark.Statement.With_sok.t * unit)
       , N2.n * (N2.n * unit)
       , N1.n * (N5.n * unit)
       , Protocol_state.Value.t
       , (unit * unit * Proof.t) Async.Deferred.t )
       Pickles.Prover.t

  (** Lazy constraint system digests for verification key stability *)
  val constraint_system_digests : (string * Md5_lib.t) list Lazy.t
end

(** Verify blockchain SNARK proofs.

    @param ts List of (statement, proof) pairs to verify
    @param key Verification key
    @return Async result indicating verification success/failure
*)
let verify ts ~key = Pickles.verify (module Nat.N2) (module Statement) key ts

(** Compute constraint system digests for the blockchain SNARK.

    The digest is an MD5 hash of the constraint system, used to detect
    when the circuit has changed (which would invalidate old proofs).

    @param proof_level Proof level configuration
    @param constraint_constants Genesis constraint constants
    @return List of (name, digest) pairs
*)
let constraint_system_digests ~proof_level ~constraint_constants () =
  let digest = Tick.R1CS_constraint_system.digest in
  [ ( "blockchain-step"
    , digest
        (let main x =
           let open Tick in
           let%map _ =
             step ~proof_level ~constraint_constants ~logger:(Logger.create ())
               x
           in
           ()
         in
         Tick.constraint_system ~input_typ:Statement.typ
           ~return_typ:Tick.Typ.unit main ) )
  ]

(** {1 Make Functor}

    Functor to compile the blockchain SNARK circuit into a concrete
    proving/verification system.

    Takes the transaction SNARK tag (to link the two SNARKs together)
    and configuration parameters. Returns a module with:
    - Compiled tag and cache handle
    - step function for proof generation
    - Proof module with serialization support
*)
module Make (T : sig
  (** Tag for the transaction SNARK (for recursive linking) *)
  val tag : Transaction_snark.tag

  (** Constraint constants (affects circuit structure) *)
  val constraint_constants : Genesis_constants.Constraint_constants.t

  (** Proof level: Full, Check, or No_check *)
  val proof_level : Genesis_constants.Proof_level.t
end) : S = struct
  open T

  (** Compile the blockchain SNARK using Pickles.

      Parameters:
      - cache: Directory for caching proving/verification keys
      - public_input: The statement type (protocol state hash)
      - override_wrap_domain: N1 (wrap with single proof verification)
      - auxiliary_typ: Unit (no auxiliary output)
      - max_proofs_verified: N2 (verifies up to 2 proofs)
      - name: "blockchain-snark" for debugging
      - choices: Single rule that calls the step function
  *)
  let tag, cache_handle, p, Pickles.Provers.[ step ] =
    Pickles.compile () ~cache:Cache_dir.cache
      ~public_input:(Input Statement.typ)
      ~override_wrap_domain:Pickles_base.Proofs_verified.N1
      ~auxiliary_typ:Typ.unit
      ~max_proofs_verified:(module Nat.N2)
      ~name:"blockchain-snark"
      ~choices:(fun ~self ->
        [ rule ~proof_level ~constraint_constants T.tag self ] )

  (** Wrap the step prover with the witness handler *)
  let step = with_handler step

  (** Lazy computation of constraint system digests *)
  let constraint_system_digests =
    lazy (constraint_system_digests ~proof_level ~constraint_constants ())

  (** Proof module from Pickles compilation *)
  module Proof = (val p)
end
