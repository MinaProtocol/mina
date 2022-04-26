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
  constraint 'time_received = [ `Time_received ] * (unit, _) Truth.t
  constraint 'genesis_state = [ `Genesis_state ] * (unit, _) Truth.t
  constraint 'proof = [ `Proof ] * (unit, _) Truth.t
  (* TODO: This type seems wrong... we sometimes have a proof if it was received
     via gossip, but sometimes we do not and just stick a dummy proof here.
     It seems that the better thing to do would be to mark this accordingly instead
     of having a dummy (though I wonder why we need to cache this in the first
     place). *)
  constraint
    'delta_block_chain =
    [ `Delta_block_chain ] * (State_hash.t Non_empty_list.t, _) Truth.t
  constraint
    'frontier_dependencies =
    [ `Frontier_dependencies ] * (unit, _) Truth.t
  constraint 'staged_ledger_diff = [ `Staged_ledger_diff ] * (unit, _) Truth.t
  constraint 'protocol_versions = [ `Protocol_versions ] * (unit, _) Truth.t

type fully_invalid =
  ( [ `Time_received ] * unit Truth.false_t
  , [ `Genesis_state ] * unit Truth.false_t
  , [ `Proof ] * unit Truth.false_t
  , [ `Delta_block_chain ] * State_hash.t Non_empty_list.t Truth.false_t
  , [ `Frontier_dependencies ] * unit Truth.false_t
  , [ `Staged_ledger_diff ] * unit Truth.false_t
  , [ `Protocol_versions ] * unit Truth.false_t )
  t

type initial_valid =
  ( [ `Time_received ] * unit Truth.true_t
  , [ `Genesis_state ] * unit Truth.true_t
  , [ `Proof ] * unit Truth.true_t
  , [ `Delta_block_chain ] * State_hash.t Non_empty_list.t Truth.true_t
  , [ `Frontier_dependencies ] * unit Truth.false_t
  , [ `Staged_ledger_diff ] * unit Truth.false_t
  , [ `Protocol_versions ] * unit Truth.true_t )
  t

type almost_valid =
  ( [ `Time_received ] * unit Truth.true_t
  , [ `Genesis_state ] * unit Truth.true_t
  , [ `Proof ] * unit Truth.true_t
  , [ `Delta_block_chain ] * State_hash.t Non_empty_list.t Truth.true_t
  , [ `Frontier_dependencies ] * unit Truth.true_t
  , [ `Staged_ledger_diff ] * unit Truth.false_t
  , [ `Protocol_versions ] * unit Truth.true_t )
  t

type fully_valid =
  ( [ `Time_received ] * unit Truth.true_t
  , [ `Genesis_state ] * unit Truth.true_t
  , [ `Proof ] * unit Truth.true_t
  , [ `Delta_block_chain ] * State_hash.t Non_empty_list.t Truth.true_t
  , [ `Frontier_dependencies ] * unit Truth.true_t
  , [ `Staged_ledger_diff ] * unit Truth.true_t
  , [ `Protocol_versions ] * unit Truth.true_t )
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
  ( [ `Time_received ] * unit Truth.false_t
  , [ `Genesis_state ] * unit Truth.false_t
  , [ `Proof ] * unit Truth.false_t
  , [ `Delta_block_chain ] * State_hash.t Non_empty_list.t Truth.false_t
  , [ `Frontier_dependencies ] * unit Truth.false_t
  , [ `Staged_ledger_diff ] * unit Truth.false_t
  , [ `Protocol_versions ] * unit Truth.false_t )
  with_block

type initial_valid_with_block =
  ( [ `Time_received ] * unit Truth.true_t
  , [ `Genesis_state ] * unit Truth.true_t
  , [ `Proof ] * unit Truth.true_t
  , [ `Delta_block_chain ] * State_hash.t Non_empty_list.t Truth.true_t
  , [ `Frontier_dependencies ] * unit Truth.false_t
  , [ `Staged_ledger_diff ] * unit Truth.false_t
  , [ `Protocol_versions ] * unit Truth.true_t )
  with_block

type almost_valid_with_block =
  ( [ `Time_received ] * unit Truth.true_t
  , [ `Genesis_state ] * unit Truth.true_t
  , [ `Proof ] * unit Truth.true_t
  , [ `Delta_block_chain ] * State_hash.t Non_empty_list.t Truth.true_t
  , [ `Frontier_dependencies ] * unit Truth.true_t
  , [ `Staged_ledger_diff ] * unit Truth.false_t
  , [ `Protocol_versions ] * unit Truth.true_t )
  with_block

type fully_valid_with_block = Block.with_hash * fully_valid

let fully_invalid : fully_invalid =
  ( (`Time_received, Truth.False)
  , (`Genesis_state, Truth.False)
  , (`Proof, Truth.False)
  , (`Delta_block_chain, Truth.False)
  , (`Frontier_dependencies, Truth.False)
  , (`Staged_ledger_diff, Truth.False)
  , (`Protocol_versions, Truth.False) )
