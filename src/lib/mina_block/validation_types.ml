open Mina_base

(** {1 Block Validation States}

    Mina blocks go through several validation stages as they move through the
    network. These types use OCaml's type system to track which validation
    checks have been completed, preventing bugs where unvalidated blocks are
    treated as valid.

    {2 The Validation Pipeline}

    When a block is received, it progresses through these states:
    1. {b Fully Invalid}: Just received, no checks done
    2. {b Initial Valid}: Basic checks passed (time, genesis, proof format)
    3. {b Almost Valid}: Most checks passed, but staged ledger diff not validated
    4. {b Fully Valid}: All validation complete, ready for consensus

    {2 What Gets Validated?}

    Each validation state tracks whether these components have been checked:
    - {b Time Received}: Block timestamp is reasonable
    - {b Genesis State}: Block is compatible with our genesis
    - {b Proof}: zkSNARK proof is well-formed and valid
    - {b Delta Block Chain}: Block correctly links to previous blocks
    - {b Frontier Dependencies}: Dependencies on other blocks are resolved
    - {b Staged Ledger Diff}: Transaction list produces the claimed state changes
    - {b Protocol Versions}: Block uses valid protocol versions

    {2 Why This Matters}

    This validation pipeline allows Mina to:
    - Process blocks incrementally without blocking the network
    - Reject invalid blocks early to save computation
    - Ensure consensus only considers fully validated blocks
    - Provide clear error messages about what validation failed

    {2 For Newcomers}

    Think of block validation like checking a document:
    1. First, check if it's the right format
    2. Then, verify the signature is valid
    3. Finally, confirm the content makes sense

    Mina does the same with blocks, checking basic properties first before
    doing expensive validation like verifying zkSNARK proofs.
*)

type ( 'time_received
     , 'genesis_state
     , 'proof
     , 'delta_block_chain
     , 'frontier_dependencies
     , 'staged_ledger_diff
     , 'protocol_versions )
     t =
  'time_received
  * 'genesis_state
  * 'proof
  * 'delta_block_chain
  * 'frontier_dependencies
  * 'staged_ledger_diff
  * 'protocol_versions

(* TODO commented out because of weird type errors *)
(* Types are constrained though in practice (e.g. all functions requiring fully validated
   block prescribe this requirement well) *)
(* constraint 'time_received = [ `Time_received ] * (unit, _) Mina_stdlib.Truth.t
   constraint 'genesis_state = [ `Genesis_state ] * (unit, _) Mina_stdlib.Truth.t
   constraint 'proof = [ `Proof ] * (unit, _) Mina_stdlib.Truth.t
   (* TODO: This type seems wrong... we sometimes have a proof if it was received
      via gossip, but sometimes we do not and just stick a dummy proof here.
      It seems that the better thing to do would be to mark this accordingly instead
      of having a dummy (though I wonder why we need to cache this in the first
      place). *)
   constraint
     'delta_block_chain =
     [ `Delta_block_chain ] * (State_hash.t Nonempty_list.t, _) Mina_stdlib.Truth.t
   constraint
     'frontier_dependencies =
     [ `Frontier_dependencies ] * (unit, _) Mina_stdlib.Truth.t
   constraint 'staged_ledger_diff = [ `Staged_ledger_diff ] * (unit, _) Mina_stdlib.Truth.t
   constraint 'protocol_versions = [ `Protocol_versions ] * (unit, _) Mina_stdlib.Truth.t *)

(** A block that has just been received and hasn't passed any validation checks.
    All validation flags are set to false. *)
type fully_invalid =
  ( [ `Time_received ] * unit Mina_stdlib.Truth.false_t
  , [ `Genesis_state ] * unit Mina_stdlib.Truth.false_t
  , [ `Proof ] * unit Mina_stdlib.Truth.false_t
  , [ `Delta_block_chain ]
    * State_hash.t Mina_stdlib.Nonempty_list.t Mina_stdlib.Truth.false_t
  , [ `Frontier_dependencies ] * unit Mina_stdlib.Truth.false_t
  , [ `Staged_ledger_diff ] * unit Mina_stdlib.Truth.false_t
  , [ `Protocol_versions ] * unit Mina_stdlib.Truth.false_t )
  t

(** A block that has passed initial validation checks:
    - Time received check passed
    - Genesis state compatibility verified
    - Proof format is valid
    - Delta block chain links correctly
    - Protocol versions are acceptable

    Still needs frontier dependencies and staged ledger diff validation. *)
type initial_valid =
  ( [ `Time_received ] * unit Mina_stdlib.Truth.true_t
  , [ `Genesis_state ] * unit Mina_stdlib.Truth.true_t
  , [ `Proof ] * unit Mina_stdlib.Truth.true_t
  , [ `Delta_block_chain ]
    * State_hash.t Mina_stdlib.Nonempty_list.t Mina_stdlib.Truth.true_t
  , [ `Frontier_dependencies ] * unit Mina_stdlib.Truth.false_t
  , [ `Staged_ledger_diff ] * unit Mina_stdlib.Truth.false_t
  , [ `Protocol_versions ] * unit Mina_stdlib.Truth.true_t )
  t

(** A block that has passed most validation checks:
    - All initial validation checks passed
    - Frontier dependencies resolved

    Only staged ledger diff validation remains. *)
type almost_valid =
  ( [ `Time_received ] * unit Mina_stdlib.Truth.true_t
  , [ `Genesis_state ] * unit Mina_stdlib.Truth.true_t
  , [ `Proof ] * unit Mina_stdlib.Truth.true_t
  , [ `Delta_block_chain ]
    * State_hash.t Mina_stdlib.Nonempty_list.t Mina_stdlib.Truth.true_t
  , [ `Frontier_dependencies ] * unit Mina_stdlib.Truth.true_t
  , [ `Staged_ledger_diff ] * unit Mina_stdlib.Truth.false_t
  , [ `Protocol_versions ] * unit Mina_stdlib.Truth.true_t )
  t

(** A block that has passed all validation checks and is ready for consensus.
    All validation flags are set to true. *)
type fully_valid =
  ( [ `Time_received ] * unit Mina_stdlib.Truth.true_t
  , [ `Genesis_state ] * unit Mina_stdlib.Truth.true_t
  , [ `Proof ] * unit Mina_stdlib.Truth.true_t
  , [ `Delta_block_chain ]
    * State_hash.t Mina_stdlib.Nonempty_list.t Mina_stdlib.Truth.true_t
  , [ `Frontier_dependencies ] * unit Mina_stdlib.Truth.true_t
  , [ `Staged_ledger_diff ] * unit Mina_stdlib.Truth.true_t
  , [ `Protocol_versions ] * unit Mina_stdlib.Truth.true_t )
  t

type ( 'time_received
     , 'genesis_state
     , 'proof
     , 'delta_block_chain
     , 'frontier_dependencies
     , 'staged_ledger_diff
     , 'protocol_versions )
     with_block =
  Block.with_hash
  * ( 'time_received
    , 'genesis_state
    , 'proof
    , 'delta_block_chain
    , 'frontier_dependencies
    , 'staged_ledger_diff
    , 'protocol_versions )
    t

type fully_invalid_with_block =
  ( [ `Time_received ] * unit Mina_stdlib.Truth.false_t
  , [ `Genesis_state ] * unit Mina_stdlib.Truth.false_t
  , [ `Proof ] * unit Mina_stdlib.Truth.false_t
  , [ `Delta_block_chain ]
    * State_hash.t Mina_stdlib.Nonempty_list.t Mina_stdlib.Truth.false_t
  , [ `Frontier_dependencies ] * unit Mina_stdlib.Truth.false_t
  , [ `Staged_ledger_diff ] * unit Mina_stdlib.Truth.false_t
  , [ `Protocol_versions ] * unit Mina_stdlib.Truth.false_t )
  with_block

type initial_valid_with_block =
  ( [ `Time_received ] * unit Mina_stdlib.Truth.true_t
  , [ `Genesis_state ] * unit Mina_stdlib.Truth.true_t
  , [ `Proof ] * unit Mina_stdlib.Truth.true_t
  , [ `Delta_block_chain ]
    * State_hash.t Mina_stdlib.Nonempty_list.t Mina_stdlib.Truth.true_t
  , [ `Frontier_dependencies ] * unit Mina_stdlib.Truth.false_t
  , [ `Staged_ledger_diff ] * unit Mina_stdlib.Truth.false_t
  , [ `Protocol_versions ] * unit Mina_stdlib.Truth.true_t )
  with_block

type almost_valid_with_block =
  ( [ `Time_received ] * unit Mina_stdlib.Truth.true_t
  , [ `Genesis_state ] * unit Mina_stdlib.Truth.true_t
  , [ `Proof ] * unit Mina_stdlib.Truth.true_t
  , [ `Delta_block_chain ]
    * State_hash.t Mina_stdlib.Nonempty_list.t Mina_stdlib.Truth.true_t
  , [ `Frontier_dependencies ] * unit Mina_stdlib.Truth.true_t
  , [ `Staged_ledger_diff ] * unit Mina_stdlib.Truth.false_t
  , [ `Protocol_versions ] * unit Mina_stdlib.Truth.true_t )
  with_block

type ( 'time_received
     , 'genesis_state
     , 'proof
     , 'delta_block_chain
     , 'frontier_dependencies
     , 'staged_ledger_diff
     , 'protocol_versions )
     with_header =
  Header.with_hash
  * ( 'time_received
    , 'genesis_state
    , 'proof
    , 'delta_block_chain
    , 'frontier_dependencies
    , 'staged_ledger_diff
    , 'protocol_versions )
    t

type fully_invalid_with_header =
  ( [ `Time_received ] * unit Mina_stdlib.Truth.false_t
  , [ `Genesis_state ] * unit Mina_stdlib.Truth.false_t
  , [ `Proof ] * unit Mina_stdlib.Truth.false_t
  , [ `Delta_block_chain ]
    * State_hash.t Mina_stdlib.Nonempty_list.t Mina_stdlib.Truth.false_t
  , [ `Frontier_dependencies ] * unit Mina_stdlib.Truth.false_t
  , [ `Staged_ledger_diff ] * unit Mina_stdlib.Truth.false_t
  , [ `Protocol_versions ] * unit Mina_stdlib.Truth.false_t )
  with_header

type initial_valid_with_header =
  ( [ `Time_received ] * unit Mina_stdlib.Truth.true_t
  , [ `Genesis_state ] * unit Mina_stdlib.Truth.true_t
  , [ `Proof ] * unit Mina_stdlib.Truth.true_t
  , [ `Delta_block_chain ]
    * State_hash.t Mina_stdlib.Nonempty_list.t Mina_stdlib.Truth.true_t
  , [ `Frontier_dependencies ] * unit Mina_stdlib.Truth.false_t
  , [ `Staged_ledger_diff ] * unit Mina_stdlib.Truth.false_t
  , [ `Protocol_versions ] * unit Mina_stdlib.Truth.true_t )
  with_header

type almost_valid_with_header =
  ( [ `Time_received ] * unit Mina_stdlib.Truth.true_t
  , [ `Genesis_state ] * unit Mina_stdlib.Truth.true_t
  , [ `Proof ] * unit Mina_stdlib.Truth.true_t
  , [ `Delta_block_chain ]
    * State_hash.t Mina_stdlib.Nonempty_list.t Mina_stdlib.Truth.true_t
  , [ `Frontier_dependencies ] * unit Mina_stdlib.Truth.true_t
  , [ `Staged_ledger_diff ] * unit Mina_stdlib.Truth.false_t
  , [ `Protocol_versions ] * unit Mina_stdlib.Truth.true_t )
  with_header

type fully_valid_with_block = Block.with_hash * fully_valid

let fully_invalid : fully_invalid =
  ( (`Time_received, Mina_stdlib.Truth.False)
  , (`Genesis_state, Mina_stdlib.Truth.False)
  , (`Proof, Mina_stdlib.Truth.False)
  , (`Delta_block_chain, Mina_stdlib.Truth.False)
  , (`Frontier_dependencies, Mina_stdlib.Truth.False)
  , (`Staged_ledger_diff, Mina_stdlib.Truth.False)
  , (`Protocol_versions, Mina_stdlib.Truth.False) )
