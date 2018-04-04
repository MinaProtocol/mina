

state: {
  byzantine_state = {
    balances: map from identity -> balance
    claimed_work: map from work -> claimed identity
    blacklisted_identities: []
    permissioned_identities: []
  }
  locally_permissioned_identities = []
}

consensus_block: {
  ledger_transactions
    ledger_transaction (payment | coinbase) list
    new_unsealed_hash
    new_unsealed_hash_signatures
    new_ledger_hash
    new_ledger_hash_signature
  new_permissioned_identities Option
  claim_work: (work_id, identity) list
  submit_work: (work_id, work) list
}

propose state
  =

apply state block
  =
    ledger_transactions ->
      Transaction_transition
      Seal
    new_permissioned_identities ->
      Identity_transition
    claim_work ->
      update claimed_work
      start round based timer to blacklist identity
    submit_work ->
      update claimed_work
      update balances
      Work_tree_progress

on_event event
  | Become_notary state identity (happens after notary added to permissioned identities)
    update(state.locally_permissioned_identities)
    add_transaction_to_next_consensus(claim_transaction_buffer_work)
  | Initial_work_claim_accepted state identity
    add_transaction_to_next_consensus(submit_transaction_buffer_work)
  | Consensus_propose state
    byzantine_consensus(propose state)
  | Apply_Consensus state block
    apply state block
  | New_notary state identity
    update(state.locally_permissioned_identities)
  | Add_coinbase state identity
    if full notary
      add_transaction_to_next_consensus(coinbase(identity))
  | Add_transaction state transaction
    if full notary
      add_transaction_to_next_consensus(transaction)
