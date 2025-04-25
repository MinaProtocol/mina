open Mina_base

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
