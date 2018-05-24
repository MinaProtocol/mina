Coda PoW

requirements:
  - shouldn't be possible to separate work and fee in work snark
  - transaction queue should always have work available
  - transaction queue should have merkle root to transactions (by account) available

Blockchain_snark
  ~old ~nonce ~ledger_snark ~ledger_hash ~timestamp ~new_hash
  - assert(Blockchain_snark.verify(old.snark, old))
  - new = update_with_asserts(old, nonce, timestamp, ledger_hash)
  - assert(hash(new) = new_hash)
  - assert(Work_snark.verify(new.ledger_snark, genesis_ledger, new.ledger_hash))
  - # should also assert old.ledger_hash is a "prefix" of new.ledger_hash
  - assert(new.timestamp > old.timestamp)
  - assert(hash(concat hash(new) nonce) < target(old.next_difficulty))

Work_snark:
  ~A ~B ~type:(Bundle transactions | Merge proofs)
  match type with
  | Bundle transactions
    -> assert transactions are valid, and applying them takes A -> B
  | Merge proofAC proofCB
    -> 
      - assert proofAC verifies A -> C
      - assert proofCB verifies C -> B

global: {
  max_transaction_queue_constraints
}

blockchain: {
  transaction_queue_hash
  ledger_hash
  timestamp
  previous_blockchain_hash
  strength
  next_difficulty
  snark
}

transaction_queue_transition: {
  new_transactions
  work_snarks
}

transaction_queue: {
  transaction_queue
  work_tree
}

blockchain_transition: {
  nonce
  transaction_queue_transition
  timestamp
}

work_snark: {
  fee
  work
}

step' blockchain transition
  =
    transaction_queue = get(blockchain.transaction_queue_hash)
    new_transaction_queue, maybe_new_ledger_snark_hash = apply transaction_queue transaction_queue_transition
    new_ledger_snark, new_ledger_hash = 
      Option.value_default maybe_new_ledger_snark
                           (old.ledger_snark, old.ledger_hash)
    next_difficulty = 
      Difficulty.next
        blockchain.next_difficulty
        state.timestamp
        transition.timestamp
    new_blockchain = {
      next_difficulty
      previous_blockchain_hash = hash(blockchain)
      transaction_queue_hash = blockchain.transaction_queue_hash
      strength = blockchain.strength + blockchain.next_difficulty
      timestamp = transition.timestamp
      ledger_hash = new_ledger_hash
    }
    proof = 
      Blockchain_snark.prove
        ~old:blockchain
        ~nonce:blockchain_transition.nonce
        ~ledger_snark:new_ledger_snark
        ~ledger_hash:new_ledger_hash
        ~timestamp:new_blockchain.timestamp
        ~new_hash:hash(new_blockchain)
    new_blockchain.snark = proof
    new_blockchain, transition.transaction_queue_transition

update_blockchain old new transaction_queue_transition
  =
    old_transaction_queue = get(old.transaction_queue_hash)
    new_transaction_queue, maybe_new_ledger_snark_hash = apply(old_transaction_queue, transaction_queue_transition)
    queue_constraints_remaining = max_transaction_queue_constraints - constraints(new_transaction_queue.queue)
    work_constraints_remaining = constraints(new_transaction_queue.work_tree)
    new_ledger_snark, new_ledger_hash = 
      Option.value_default(maybe_new_ledger_snark,
                           (old.ledger_snark, old.ledger_hash))
    transaction_queue_transition_valid = 
         hash(new_transaction_queue) = new.transaction_queue_hash
      && queue_constraints_remaining >= work_constraints_remaining
      && has_work_fees(transaction_queue_transition.work_snarks, transaction_queue_transition.new_transactions)
      && verify_work(work_snark, old_transaction_queue.work_tree, transaction_queue_transition.work_snarks)
      && new_ledger_hash = new.ledger_hash
    if   new.strength > old.strength
      && Time_close(new.timestamp)
      && Blockchain_snark.verify(new)
      && transaction_queue_transition_valid
    then new
    else old

step transition
  =
    match transition with
    | Received received_blockchain, transaction_queue_transition ->
      blockchain := strongest_blockchain blockchain received_blockchain, transaction_queue_transition
      if blockchain = received_blockchain
      then broadcast (Blockchain blockchain, transaction_queue_transition)
    | Transition transition ->
      blockchain, transaction_queue_transition := step' blockchain transition
      broadcast (Blockchain blockchain, transaction_queue_transition)
