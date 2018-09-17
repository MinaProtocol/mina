

global: {
  incremental_checkpoint_slots
  num_checkpoints
  checkpoint_slots = incremental_checkpoint_slots * num_checkpoints
  checkpoint_slots_inflation
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
  prev_chain_state
  checkpoints
  post_epoch_lock_hash
  next_post_epoch_lock_hash
  last_epoch_start_hash
  next_last_epoch_start_hash
  last_epoch_length
  unique_participants
  unique_participation
  last_epoch_participation
}

transition: {
  slot
  epoch
  vrf
  key
  delegation_key (* snark must prove delegation_key.delegator == key *)
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
        { epoch_seed = chain_state.next_epoch_seed;
          epoch_ledger = chain_state.next_epoch_ledger;
          post_epoch_lock_hash = chain_state.next_post_epoch_lock_hash;
          last_epoch_start_hash = chain_state.next_last_epoch_start_hash;
          next_epoch_seed = get_next_epoch_seed (empty_hash ());
          next_epoch_ledger = get_ledger(chain_state.state);
          next_last_epoch_start_hash = hash(chain_state);
          last_epoch_length = chain_state.length;
          last_epoch_participation = chain_state.unique_participation;
          unique_participants = empty_set();
          unique_participation = 0;
        }
      else
        { epoch_seed = chain_state.epoch_seed;
          epoch_ledger = chain_state.epoch_ledger;
          post_epoch_lock_hash = chain_state.post_epoch_lock_hash;
          last_epoch_start_hash = chain_state.last_epoch_start_hash;
          next_epoch_seed = get_next_epoch_seed (chain_state.next_epoch_seed);
          next_epoch_ledger = chain_state.next_ledger;
          next_last_epoch_start_hash = chain_state.next_last_epoch_start_hash;
          last_epoch_length = chain_state.last_epoch_length;
          last_epoch_participation = chain_state.last_epoch_participation;
          unique_participants = chain_state.unique_participants + key;
          unique_participation =
            if key not in chain_state.unique_participants
            then chain_state.unique_participation + epoch_ledger[key].amount
            else chain_state.unique_participation;
        }
    let next_post_epoch_lock_hash =
      if transition.slot > forkable_slots*2 && chain_state.slot <= forkable_slots*2
      then hash(chain_state)
      else chain_state.next_post_epoch_lock_hash
    assert(
      check_vrf(
        transition.slot
        transition.epoch
        key
        epoch_ledger[transition.delegation_key].amount
        epoch_seed
        transition.vrf
      )
    )
    checkpoints = chain_state.checkpoints
    last_pos = chain_state.slot % incremental_checkpoint_slots
    new_pos = transition.slot % incremental_checkpoint_slots
    if new_pos < last_pos
    then 
      checkpoints.push_back(hash(chain_state))
      if len(checkpoints) > num_checkpoints
      then checkpoints.pop_front()
    return {
      epoch_seed
      next_epoch_seed
      state = apply_transition(chain_state.state, transition.state_transition)
      length = chain_state.length + 1
      slot = transition.slot
      epoch = transition.epoch
      prev_chain_state = hash(chain_state)
      checkpoints = checkpoints

      new.post_epoch_lock_hash
      next_post_epoch_lock_hash
      new.last_epoch_start_hash
      new.next_last_epoch_start_hash
      new.last_epoch_length
      new.unique_participants
      new.unique_participation
      new.last_epoch_participation
    }

select 
  curr
  cand
  =
    cand_fork_before_checkpoint = none of cand.checkpoints in curr.checkpoints
    cand_valid =
         verify(cand.proof)
      && slot_start_time(cand.slot, cand.epoch) < time of receipt
      && slot_end_time(cand.slot, cand.epoch) >= time of receipt (* TODO is it okay to drop this, and accept chains terminating at past slots? *)
      && check(cand.state)
    if !cand_fork_before_checkpoint || !cand_valid
    then curr
    else 
      if cand.post_epoch_lock_hash = curr.post_epoch_lock_hash
      then argmax_{chain in [cand, curr]}(len(chain))
      else 
        if cand.last_epoch_start_hash = curr.last_epoch_start_hash
        then argmax_{chain in [cand, curr]}(len(chain.last_epoch_length))
        else argmax_{chain in [cand, curr]}(len(chain.last_epoch_participation))

step t = function
  | Found transition ->
    apply_transition current_chain_state transition
  | Candidate_chain_state candidate_chain_state ->
    select current_chain_state candidate_chain_state

Assumptions:
  at all times, at least (50 + checkpoint_slots_inflation)% of stakers are participating and honest
  checkpoints are at most checkpoint_slots slots from the tip
  the maximum inflation in checkpoint_slots slots is checkpoint_slots_inflation
    
Invariant:
  for all slots s:
    for all honest parties:
      locked_slot = s - 8k
      chain = if the party was online at slot s, the chain that would have been selected
      locked_block = the most recent block in chain at least as old as locked_slot
      for all slots l > s
        chain = if the party was online at slot l, the chain that would have been selected
        the locked block is a prefix of chain


