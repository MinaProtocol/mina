

state: {
  byzantine_state = {
    balances: map from identity -> balance
    claimed_work: map from work -> claimed identity
    blacklisted_identities: []
    permissioned_identities: []
  }
  locally_permissioned_identities = []
}

verify_block state transactions
  =
    map all
      transactions
      ~f:(function
      | Transaction t -> 
      | Seal t -> 
      | Coinbase t -> 
      | Claim_work t -> 
      | Submit_work t -> add to balances
      | Identity t -> add to permissioned_identities if not there already (comes with work)
      )

apply_transactions state transactions
  =
    assemble transactions into
    - work_tree_progress
    - transaction_transition
    - seal_transition
    - identity_transition
    send off to transaction_chain


on_event event
  | Become_notary state identity (happens after notary added to permissioned identities)
    update(state.locally_permissioned_identities)
    add_transaction_to_next_consensus(claim_transaction_buffer_work)
  | Initial_work_claim_accepted state identity
    add_transaction_to_next_consensus(submit_transaction_buffer_work)
  | Consensus state transactions
    byzantine_consensus(state, transactions, verify_transactions, apply_transactions)
  | New_notary state identity
    update(state.locally_permissioned_identities)
  | Add_coinbase state identity
    if full notary
      add_transaction_to_next_consensus(coinbase(identity))
  | Add_transaction state transaction
    if full notary
      add_transaction_to_next_consensus(transaction)
