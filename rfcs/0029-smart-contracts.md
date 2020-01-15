NB: This purposely glosses over the details of on-chain data storage. A
separate discussion probably needs to be had over how that storage should look,
what the cost model for storage is, when to delete stored data, etc.

## Witness generation + proving off chain: store verification keys in accounts
* Account should be updated to add a field for verification key(s).
  - This should likely be a dedicated field, separate from other data stored in
    the account, so that it can be addressed easily from within the snark.
  - If we want to allow multiple smart contracts to be active for an account,
    the keys should be stored in an addressible way -- probably a Merkle tree
    would be best -- so that the correct key can be recalled for a given proof.
* A new kind of 'transaction' containing the proof (and verification key
  address) -- should be added to trigger the contract.
  - The proof should accept the transaction as a 'public input'.
    + If the contract may also modify 'data' stored on-chain, the old and new
      state of the data need to be passed to the proof as part of this too
    + This should form part of the 'transaction' anyway, so as long as we
      encode these data changes as part of the transaction, this should work as
      intended.
  - The proof could provide 'input' addresses for references to other on-chain
    data.
    + It would be preferable to pass the top hash of the tree as an input
      instead, but the tree will vary as transactions are applied, which would
      make the proof invalid.
    + This makes it the responsibility of the transaction snark to read this
      data, pass it as public inputs, and verify the proof against it.
    + Doing this puts a hard limit on the number of on-chain data locations
      that the proof can be verified against: the maximum will be encoded in
      the constraint system of the transaction snark.
    + These addresses need to be passed as part of this message if they may
      vary accross different witnesses. (If not, this information could live in
      the account with the verification keys instead.)
  - We shouldn't need to allow any other public inputs: any other data should
    be verified by the proof cryptographically or against on-chain data anyway.
* The transaction snark should be updated to accept the path to the
  verification key and a proof for that key.
  - This requires generating constraints for verifying the proof in the
    constraint system.
    + Naturally, this will increase witness size and proving time.
  - The verification key should be 'looked up' by opening the account in the
    account Merkle tree and then opening the verification key (either directly,
    or via addressing in the keys tree).
  - If additional on-chain data may be referenced, the snark will need to be
    modified to prove that this data was read from the relevant addresses, and
    that the proof matches the data.
  - The account signing the 'transaction' should be verified as one of the
    accounts authorised to run the smart contract.
* The proofs need to be checked before being put into the snark worker's queue,
  to ensure that the blockchain snark can be built correctly.
  - This is equivalent to checking that a transaction is valid before applying
    it, and we can do this at the same stage.
* Nothing needs to be done for off-chain data. It should be related to on-chain
  data, verified cryptographically, etc. by the proof.
* Inclusion in a block is fixed size, so nothing needs to be done for gas etc.

## Witness generation + proving off chain: store WASM blob for generating the
## constraints
* Need to implement a universal snark verifier in Snarky, to be included in the
  transaction snark.
* Account should be updated to add a field for the WASM blob.
  - This can proceed approximately as for verification keys above.
  - Storage may be more of a consideration here: the data stored could be much
    larger than a verification key.
  - A hash of the expected constraint system should be stored with the blob, to
    ensure that the worker can't modify the constraint system when checking the
    proof.
* A WASM interpreter will need to be adapted or written.
  - In particular, the WASM interpreter will need to be integrated properly
    with functions for field operations on the relevant field, functions for
    adding constraints, etc. to give a consistent interface for any different
    surface languages that we want to support.
  - Constraints need to be integrated directly with the WASM interpreter (e.g.
    functions to incrementally add them), because WASM can currently only
    return a single value (int or float) which is too small to represent the
    constraints as a whole-program return value.
  - Example interpreter implementation (rust):
    https://github.com/paritytech/wasmi
* Need to create a restricted evaluation environment.
  - This should be 'easy' to build on top of existing WASM interpreters.
  - Must restrict RAM usage to avoid out-of-memory errors on nodes.
  - Must restrict system resource access to avoid exploits, stealing creds,
    etc.
* Need a gas model for execution of the WASM, with gas limits, prices, etc.
  associated with either the account or (better) the WASM blob itself in the
  account.
  - This needs a mechanism for the consensus nodes to decide collectively on
    how much gas per block can be used.
  - The amount of gas used should be added to the transaction before including
    it in the blockchain.
  - **The gas for the evaluation should be held by the sender account, not the
    account hosting the WASM, to ensure that a bad actor can't drain an account
    by triggering the predicate repeatedly.**
* The 'proof transaction' should be modified to include a 'proof accepted'
  flag, calculated by the worker.
  - This flag should be false if WASM evaluation fails.
    + E.g. If the gas limit is too low, or the the evaluation raises an
      exception.
  - This flag should also be false if the constraint system doesn't match the
    hash stored in the account.
  - This flag should also be false if the proof doesn't verify against the
    constraint system.
  - This flag should be false if the transaction cannot be applied after
    transferring the gas cost to the worker.
* The transaction snark should be modified to accept 'gas used' with each
  transaction.
  - This should be checked against the sender's gas limit, converted using the
    gas price, and transferred to the worker.
  - If the proof in a 'proof transaction' cannot be accepted (due to
    out-of-gas, invalid proof, etc.), then the state changes in the transaction
    should not be applied.
    + In practice, this means that updating the merkle tree should be
      conditional on the transaction's 'proof accepted' flag.
* Consensus nodes verify that the gas transaction was honest using an
  'everybody evaluates' consensus model:
  - Each node should repeat the evaluation of the WASM blob, tracking the gas
    used. If the gas spent differs from the gas used, reject the transaction.
  - At this stage, the gas should be transferred, to avoid a double-spend.
    + For example, if the sender and the WASM account are the same, we need to
      ensure that the evaluation cost isn't transferred out of the account by
      the transaction.
  - While evaluating, the node should check whether
    + the transaction is legal (e.g. there are sufficient funds);
    + evaluating the blob succeeds (vs. failing with out-of-gas, etc.);
    + the hash of the resulting constraint system matches the one associated
      with the blob;
    + the proof verifies against the constraint system.
  - If the checks above pass, the 'proof accepted' flag must be true;
    otherwise, it must be false. If the flag differs, the transaction should be
    rejected.
  - If the 'proof accepted' flag is true, apply the state change to the Merkle
    tree.

## Witness generation + proving on chain: store WASM blobs for generating
## constraints and witnesses in accounts
* Details for the constraints blob and for proof verification follow roughly
  the above.
* Account should be extended to include a field for the witness generation
  blob.
* A 'create-proof transaction' for evaluating the blobs should be added.
  - We likely want to include additional public inputs here to be passed to the
    proof.
    + This gives the sender (rather than the worker) control over any data that
      should be specific to this proof.
  - Otherwise, this can behave like the proof transactions for the other
    models.
* The transaction snark should be modified to accept the 'create-proof
  transaction' kind.
  - This runs essentially the same as the above, except the proof should be
    exposed as part of the witness instead of in the transaction in public
    input.
* Consensus nodes verify that the gas transaction was honest, similar to the
  above, except:
  - nodes should evaluate the witness WASM blob, confirming that it verifies
    against the constraint system, instead of generating or checking a proof;

## Witness generation + proving on chain: store snarky programs in accounts
* Need to decide on a representation for snarky programs.
  - Better not to use source code directly, compilation is hard to measure for
    gas.
    + Could still interpret via OCaml, javascript, etc., but gas measurement is
      still pretty unmanagable.
  - Could compile down to a dedicated bytecode, with specific instructions for
    snarky-specific operations (field ops, constraints, verification gadgets,
    etc.)
  - Could compile down to WASM and use the above.
    + Simplest would be to go via rust from Meja.
* Remaining details follow roughly the above, except for a slightly different
  evaluation model. In particular:
  - Earlier failure is possible: we can generate the constraints and the data
    simultaneously, so checking the constraints as they are added is far
    easier.
  - Need to create a VM to evaluate the code in.
    + This needs much the same restrictions as the WASM VM.
    + Memory usage guarantees are harder to make: may have to analyse programs
      and try to inline garbage collection behaviour to stay within reasonable
      memory limits.
    + Need to expose a restricted system model while compiling, in order to
      ensure that system access doesn't leak.
    + Possibility is to use docker with restricted memory -- but this makes it
      significantly harder to track gas usage, and more expensive to reset to a
      known-good environment.
