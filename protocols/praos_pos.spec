


global: {
  coinbase
  epoch_slots (*R=24k*)
  forkable_slots (*8k*)
}

chain_state: {
  state
  next_epoch_seed
  next_epoch_ledger
  epoch_seed
  epoch_ledger
  length
  slot
  epoch
  ancestors
  prev_chain_state
}

transition: {
  slot
  epoch
  vrf
  key
  state_transition (* note this includes coinbase *)
}

apply_transition 
  chain_state 
  transition
  =
    let get_next_epoch_seed prev =
      if    transition.slot > forkable_slots
        and transition.slot < 2*forkable_slots
      then hash(prev, transition.vrf)
      else prev
    new = 
      if transition.epoch > chain_state.epoch
      then  
          { epoch_seed = chain_state.next_epoch_seed;
            next_epoch_seed = get_next_epoch_seed (empty_hash ());
            next_epoch_ledger = get_ledger(chain_state.state);
            epoch_ledger = chain_state.next_epoch_ledger; }
      else 
           { epoch_seed = epoch_seed;
             next_epoch_seed = get_next_epoch_seed chain_state.next_epoch_seed;
             next_epoch_ledger = chain_state.next_ledger;
             epoch_ledger = chain_state.epoch_ledger; }
    assert(
      check_vrf(
        transition.slot
        transition.epoch
        transition.key
        new.epoch_ledger[transition.key].amount
        new.epoch_seed
        transition.vrf
      )
    )
    ancestors = chain_state.ancestors
    ancestors.push_back(hash(chain_state))
    if len(ancestors) > forkable_slots:
      ancestors.pop_front(hash(chain_state))
    return {
      state = apply_transition(chain_state.state, transition.state_transition)
      next_epoch_seed = new.next_epoch_seed
      next_epoch_ledger = new.next_epoch_ledger
      epoch_seed = new.epoch_seed
      epoch_ledger = new.epoch_ledger
      length = chain_state.length + 1
      slot = transition.slot
      epoch = transition.epoch
      ancestors
      prev_chain_state = hash(chain_state)
    }

select 
  curr
  cand
  =
    cand_fork_before_checkpoint = none of cand.ancestors in curr.ancestors
    cand_valid =
         verify(cand.proof)
      && slot_start_time(cand.slot, cand.epoch) < time of receipt
      && slot_end_time(cand.slot, cand.epoch) >= time of receipt (* TODO is it okay to drop this, and accept chains terminating at past slots? *)
      && check(cand.state)
    if cand_fork_before_checkpoint || !cand_valid
    then curr
    else argmax_{chain in [cand, curr]}(len(chain))

step t = function
  | Found transition ->
    apply_transition current_chain_state transition
  | Candidate_chain_state candidate_chain_state ->
    select current_chain_state candidate_chain_state

Assumptions:
  at all times, at least half of stakers are participating and honest
    
Invariant:
  for all slots s:
    for all honest parties:
      locked_slot = s - forkable_slots
      chain = the chain selected by the party at slot s
      locked_block = the most recent block in chain at least as old as locked_slot
      for all slots l > s
        chain = the chain selected by the party at slot l
        the locked block is a prefix of chain
