

state: {
  byzantine_state = {
    balances: map from identity -> balance
    claimed_work: map from work -> claimed identity
    blacklisted_identities: []
    permissioned_identities: []
  }
  locally_permissioned_identities: []
  queued_transactions: []
}

byzantine_transition: {
  byzantine_state_hash
  ledger_transactions: Option
    transactions: (payment | coinbase) list
    new_unsealed_hash_signatures
    new_ledger_hash
    new_ledger_hash_signature
  new_permissioned_identities Option
  claim_work: (work_id, identity) set
  submit_work: (work_id, work) set
  newly_blacklisted: identity set
}

propose state
  =
    (transactions, peer_new_permissioned_identities, claims, submissions) = ask_peers_for_data(state.locally_permissioned_identities)
    new_unsealed_hash = hash(transactions, transaction_buffer.latest_unsealed_hash)
    new_unsealed_hash_signatures = ask_peers_to_sign(state.locally_permissioned_identities, new_unsealed_hash)
    new_ledger_hash = apply(transactions, latest_ledger)
    new_ledger_hash_signature = ask_peers_to_sign(state.locally_permissioned_identities, new_ledger_hash)
    new_permissioned_identities = biggest_update(peer_new_permissioned_identities)
    claims = prioritize by round and permissioned_identities_index (claims) (* how to make more robust? *)
    submissions = submissions
    blacklisted = any_expired_timers
    transition = (* build from above *)
    { state, transition }

verify state transition
  =
    - ensure transition.byzantine_state_hash matches
    - all transitions valid
    - unsealed_hash + new_ledger_hash as expected, signatures sufficient
    - new_permissioned_identities valid if there
    - claimed_work valid (* make more robust, ensure winner actually winner *)
    - submit_work valid
    - newly_blacklisted matches local timer view

apply state transition
  =
    unwrap ledger_transactions ->
      iter ledger_transactions.transactions ->
        Transaction_transition t -> emit Transaction_transition t
      emit Seal_transition ledger_transactions.new_unsealed_hash_signatures
    unwrap new_permissioned_identities ->
      emit Identity_transition new_permissioned_identities
    iter claim_work ->
      byzantine_state.claimed_work.set(work_id, identity)
      start_timer(work_id, blacklist identity, k rounds)
    iter submit_work ->
      byzantine_state.claimed_work.remove(work_id)
      byzantine_state.balances.increase(identity, work_constraints)
      cancel_timer(work_id, blacklist identity, k rounds)
      emit Work_tree_progress work
    state.byzantine_state.blacklisted_identities += transition.newly_blacklisted

on_event event
  | Consensus_propose state
    byzantine_consensus(propose state)
  | Apply_Consensus state transition
    apply state transition 
  | New_notary state identity
    update(state.locally_permissioned_identities)
  | Add_coinbase state
    state.queued_transactions.append(coinbase(self_identity))
  | Add_transaction state transaction
    state.queued_transactions.append(transaction)
  | Add_identity_change state new_permissioned_identities
    state.queued_transactions.append(new_permissioned_identities)
  | Claim_work state work_id
    state.queued_transactions.append(claim_work(work_id))
  | Submit_work state work_id work
    state.queued_transactions.append(submit_work(work_id, work))
