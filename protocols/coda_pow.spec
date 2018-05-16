Coda PoW

requirements:
  - shouldn't be possible to separate work and fee in work snark
  - transaction queue should always have work available
  - transaction queue should have merkle root to transactions (by account) available

Blockchain_snark
  ~old ~nonce ~ledger_snark ~new
  - verify old.snark for old
  - verify ledger_snark verifies old.ledger_hash -> new.ledger_hash
  - verify new.timestamp > old.timestamp
  - verify new.(strength, previous_blockchain_hash, next_difficulty) computed as expected
  - verify hash (concat new nonce) meets old.next_difficulty

Work_snark:
  ~A ~B ~type:(Bundle transactions | Merge proofs)
  match type with
  | Bundle transactions
    -> verify transactions are valid, and applying them takes A -> B
  | Merge proofs
    -> verify proofs are valid (A -> C -> B), and applying them takes A -> B

global: {
  max_transaction_queue_constraints
}

blockchain: {
  processing_pool_hash
  ledger_hash
  timestamp
  previous_blockchain_hash
  strength
  next_difficulty
  snark
}

processing_pool_transition: {
  new_transactions
  work_snarks
}

processing_pool: {
  transaction_queue
  work_tree
}

blockchain_transition: {
  nonce
  processing_pool_transition
  timestamp
}

work_snark: {
  fee
  work
}

apply_transition blockchain transition
  =
    processing_pool = get(blockchain.processing_pool)
    new_processing_pool, maybe_new_ledger_snark_hash = apply processing_pool processing_pool_transition
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
      processing_pool_hash = blockchain.processing_pool_hash
      strength = blockchain.strength + blockchain.next_difficulty
      timestamp = transition.timestamp
      ledger_hash = new_ledger_hash
    }
    proof = 
      Blockchain_snark.prove
        ~old:blockchain
        ~nonce:blockchain_transition.nonce
        ~ledger_snark:new_ledger_snark
        ~new:new_blockchain
    new_blockchain.snark = proof
    new_blockchain
  snark:
    check hash
    check block snark validity
    check T validity
      verify that constraints more than in T_queue less than constraints in T_work
      verify Snark work applied to T Snark
      verify that fees for Snark work are in T_queue 

update_blockchain old new processing_pool_transition
  =
    old_processing_pool = get(old.processing_pool_hash)
    new_processing_pool, maybe_new_ledger_snark_hash = apply(old_processing_pool, processing_pool_transition)
    queue_constraints_remaining = max_transaction_queue_constraints - constraints(new_processing_pool.queue)
    work_constraints_remaining = constraints(new_processing_pool.work_tree)
    new_ledger_snark, new_ledger_hash = 
      Option.value_default(maybe_new_ledger_snark,
                           (old.ledger_snark, old.ledger_hash))
    processing_pool_transition_valid = 
         hash(new_processing_pool) = new.processing_pool_hash
      && queue_constraints_remaining >= work_constraints_remaining
      && has_work_fees(processing_pool_transition.work_snarks, processing_pool_transition.new_transactions)
      && verify_work(work_snark, old_processing_pool.work_tree, processing_pool_transition.work_snarks)
      && new_ledger_hash = new.ledger_hash
    if   new.strength > old.strength
      && Time_close(new.timestamp)
      && Blockchain_snark.verify(new)
      && processing_pool_transition_valid
    then new
    else old

on_event event
  =
    match event with
    | Received received_blockchain, processing_pool_transition ->
      blockchain := strongest_blockchain blockchain received_blockchain, processing_pool_transition
      if blockchain = received_blockchain
      then broadcast (Blockchain blockchain)
    | Transition transition ->
      blockchain := apply_transition blockchain transition
      broadcast (Blockchain blockchain)
