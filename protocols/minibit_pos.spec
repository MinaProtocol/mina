Minibit PoS, dynamic stake, injected randomness

global: {
  epoch_seed
  epoch_slots
  epoch_ledger_hash_cutoff
}

state: {
  ledger_hash
  length
  epoch_ledger_hash
  epoch_commitments
  randomness_fallback_counter
  next_epoch_ledger_hash
  epoch_randomnes
  next_epoch_randomness maybe
  slot#
  epoch#
  prev_state_hash
}

transition: {
  new_ledger_hash
  ledger_proof
  signed_randomness maybe
  epoch_commitments maybe
  slot#
  epoch#
}

apply_transition state transition
  =
    incr_epoch = (transition.epoch# > state.epoch#)
    epoch_ledger_hash = 
      if incr_epoch 
      then state.next_epoch_ledger_hash
      else state.epoch_ledger_hash
    next_epoch_ledger_hash = 
      if transition.slot# <= global.epoch_ledger_hash_cutoff
      then ledger_hash
      else state.next_epoch_ledger_hash
    epoch_randomness =
      if incr_epoch
      then if state.next_epoch_randomness is Some
           then state.next_epoch_randomness
           else fixed_randomness     
      else state.epoch_randomness
    randomness_fallback_counter =
      if incr_epoch
      then if state.next_epoch_randomness is Some
           then state.randomness_fallback_counter
           else state.randomness_fallback_counter + 1
      else state.randomness_fallback_counter
    next_epoch_randomness =
      if incr_epoch
      then
        None
      else if 
           transition.slot# > global.epoch_ledger_hash_cutoff 
        && state.header.next_epoch_randomness = None 
        && transition.signed_randomness != None
        transition.signed_randomness
      else 
        state.header.next_epoch_randomness
    epoch_commitments =
      if incr_epoch
      then
        None
      else if 
           transition.slot# <= global.epoch_ledger_hash_cutoff 
        && state.epoch_commitments = None 
        && transition.epoch_commitments != None
        transition.epoch_commitments
      else 
        state.epoch_commitments
    new_state = {
      ledger_hash = transition.new_ledger_hash
      length = state.length + 1
      epoch_commitments
      randomness_fallback_counter
      epoch_ledger_hash
      next_epoch_ledger_hash
      epoch_randomness
      next_epoch_randomness
      slot# = transition.slot#
      epoch# = transition.epoch#
      prev_state_hash = hash(state)
    }
    signature = sign(new_state)
    proof = 
      SNARK "zk_state_valid" proving that, for new_state:
        - all old values came from a state with valid proof
        - ledger_proof proves a valid sequence of transactions moved the ledger from state.body.ledger_hash to new_ledger_hash
        - next_epoch_randomness computed correctly per epoch_commitments
        - signed by the winner as computed with slot#, epoch# under global.epoch_seed, state.epoch_ledger_hash, and state.epoch_randomness
        - all fields in new_state computed exactly as above
    (state, signature, proof)

check_state old_state new_state
  = 
    new_state.proof zk_state_valid verifies new_state
      &&
    (new_state.fallbacks < old_state.fallbacks || new_state.length > old_state.length)
      &&
    is_time_for_slot(new_state.slot#, new_state.epoch#)
      &&
    if_could_have_randomness_has_randomness(new_state)
      &&
    if_could_have_commitments_has_commitments(new_state)
    
on_event event
  = 
    match event with
    | Received_New_Epoch -> broadcast signed randomness commitment
    | Reached slot# global.epoch_ledger_hash_cutoff -> broadcast signed randomness openings
    | Reached slot# (global.epoch_ledger_hash_cutoff + opening time) -> broadcast signed randomness recoveries
    | Time_for_slot_transition transition -> 
      try
        state := apply_transition state transition
        broadcast State state
    | State new_state ->
      if check_state state new_state
      then state := new_state
