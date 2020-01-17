## Summary
[summary]: #summary

This document outlines implementation proposals for several versions of smart
contracts that could be implemented on top of the coda blockchain.

## Motivation
[motivation]: #motivation

These proposals are intended to extend the permissions model of accounts, so
that transactions (or other state-change requests) may be allowed to apply to
an account that the sender would usually not have permission to modify. These
extended permissions are implemented as 'predicates', which the transaction
must satisfy in order to be accepted and applied to the blockchain.

#### Simple motivating example: transaction itermediary

Alice wants to send a transaction to Bob, but has asked Claire to be her
intermediary. Alice wants to ensure that
- Claire is the only account that may issue a transaction on her account
- Bob is the only account that Claire may issue transactions to
- Claire may only issue a transaction up to some limit, or in some fixed
  amount

In this case, Alice should be able to add a predicate that guarantees these
conditions, so that only transactions matching these may be accepted into the
blockchain.

## Detailed design
[detailed-design]: #detailed-design

NB: For the purposes of this description, the implementation and economics of
on-chain data storage is treated as abstract. The assumptions are only that:
* the data is associated with an account, which may be addressed through the
  accounts Merkle tree
* the data is stored in some cryptographically verifiable, addressible form.

These proposals are approximately incremental: each proposal may be built out
upon the foundation of the previous proposal.

### Witness generation + proving off chain: store verification keys in accounts

* Account should be updated to add a field for verification key(s).
  - This should likely be a dedicated field, separate from other data stored in
    the account, so that it can be addressed easily and efficiently from within
    the snark.
  - If we want to allow multiple smart contracts to be active for an account,
    the keys should be stored in an addressible way -- probably a Merkle tree
    would be best -- so that the correct key can be recalled for a given proof.
* Transactions should be extended with an optional field containing the proof
  and verification key address.
  - The presence of this field should trigger the predicate from the contract,
    overruling the existing permissions model.
  - The proof should accept the transaction as a 'public input', so that the
    proof can witness the validity of the transaction.
  - If the contract may also modify data stored on-chain, the old and new state
    of the data need to be passed to the proof.
    + This data may be large and cause the size of the public input to vary
      significantly.
    + To avoid this, a cryptographic encoding (e.g. a Merkle tree) should be
      used to store the address and data for each state change, and only the
      cryptographic encoding should be passed to the proof.
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
    + In particular, any data that is not verified in this way comes from the
      same source as the proof, so the data could have been internalised in the
      proof with no loss of capabilities.
    + This also gives us far more stability in the size of the public input,
      which must have stable limits in order to be encoded in the transaction
      snark.
* The transaction snark should be updated to accept the path to the
  verification key and a proof for that key.
  - This requires generating constraints for verifying the proof in the
    constraint system.
    + Naturally, this will increase witness size and proving time for all
      transactions.
    + The constraints added will present hard limits for the number of public
      inputs, number of on-chain data accesses, etc. that proofs may require.
  - The verification key should be 'looked up' by opening the account in the
    account Merkle tree and then opening the verification key (either directly,
    or via addressing in the keys tree).
  - If additional on-chain data may be referenced, the snark will need to be
    modified to prove that this data was read from the relevant addresses, and
    that the proof matches the data.
    + The cost of this may be reduced by only allowing accesses within the
      account's own data (to avoid an account look-up), but this may prevent
      certain applications from being viable.
    + There will be a strict upper bound on the number of these accesses that
      may be perfored.
* The proofs need to be checked before being put into the snark worker's queue,
  to ensure that the blockchain snark can be built correctly.
  - This is equivalent to checking that a transaction is valid before applying
    it, and we can do this at the same stage.
* Nothing needs to be done for off-chain data. It should be related to on-chain
  data, verified cryptographically, etc. by the proof.
* Inclusion in a block, proof verification, etc. are fixed size, so nothing
  needs to be done for gas etc.

### Witness generation + proving off chain: store WASM blob for generating the constraints

* Need to implement a universal snark verifier in Snarky, to be included in the
  transaction snark.
  - This is necessary to verify proofs based solely on their constraint system.
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
  - Exposing constraints needs to be integrated directly with the WASM
    interpreter (e.g.  functions to incrementally add them), because WASM can
    currently only return a single value (int or float) which is too small to
    represent the constraints as a whole-program return value.
  - Example interpreter implementation (rust):
    https://github.com/paritytech/wasmi
* Need to create a restricted evaluation environment.
  - This should be 'easy' to build on top of existing WASM interpreters.
  - Must restrict RAM usage to avoid out-of-memory errors on nodes.
  - Must restrict system resource access to avoid exploits, stealing creds,
    etc.
  - Needs to be orchestrated to measure gas usage.
* Need a gas model for execution of the WASM, with gas limits, prices, etc.
  associated with either the account or (better) the WASM blob itself in the
  account.
  - This needs a mechanism for the consensus nodes to decide collectively on
    how much gas per block can be used.
  - The amount of gas used should be added to the transaction before including
    it in the blockchain.
  - The gas for the evaluation should be held by the sender account, not the
    account hosting the WASM, to ensure that a bad actor can't drain an account
    by triggering the predicate repeatedly.
  - The gas price and limit should be set in the transaction, so that the
    sender can control their spend.
  - The WASM evaluation should be deterministic (i.e. always produce the same
    valid output). This makes failure easier to deal with.
    + If the evaluation fails, it might make sense to remove the contract.
    + Could also penalise the account hosting the contract by charging it for
      the gas used if there is a failure or the hash doesn't match.
      (NB: This would require that the contract is removed on failure,
      otherwise a bad WASM blob could be used to drain an account.)
* Transactions should be extended with an optional field containing the proof
  and the path to the WASM blob + hash.
  - This is approximately equivalent to the verification key case above.
* The transaction snark should be modified to include a 'proof accepted' flag,
  calculated by the worker.
  - This flag should be false if WASM evaluation fails.
    + E.g. If the gas limit is too low, or the the evaluation raises an
      exception, uses too much memory, etc.
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
* The transaction snark should otherwise be modified in line with the changes
  for off-chain key-based verification above.
* Consensus nodes verify that the gas transaction was honest using an
  'everybody evaluates' consensus model:
  - Each node should repeat the evaluation of the WASM blob, tracking the gas
    used. If the gas spent differs from the gas used, reject the transaction.
  - At this stage, the gas should be transferred, to avoid a potential
    double-spend.
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

### Witness generation + proving on chain: store WASM blobs for generating constraints and witnesses in accounts

* Details for the constraints blob and for proof verification follow roughly
  the above.
* Account should be extended to include a field for the witness generation
  blob.
* The proof and WASM blob optional field in the transaction should be extended
  to add support for public inputs and 'auxiliary inputs'.
  - This gives the sender (rather than the worker) control over any data that
    should be specific to this proof.
  - The auxiliary inputs will used to create the witness, but will not be
    exposed as part of the public input.
    + The public input should be used to verify that these are correct, e.g.
      computing their hash and comparing it to one given as a public input.
  - Otherwise, this can behave like the proof transactions for the other
    models.
* The WASM evaluator needs to be modified to provide access to the public and
  auxiliary inputs.
  - This shouldn't affect the rest of the evaluator, which may remain the same.
* The transaction snark should be modified to accept this modified field in
  transactions.
  - This runs essentially the same as the above.
  - The proof should now be included as part of the witness (instead of the
    public input), as it doesn't need to be distributed to the other nodes.
  - The verification needs to be modified to accept the public input provided
    in the transaction, as well as the transaction itself.
* Consensus nodes verify that the gas transaction was honest, similar to the
  above, except:
  - nodes should evaluate the witness WASM blob, confirming that it verifies
    against the constraint system, instead of generating or checking a proof;

### Witness generation + proving on chain: store snarky programs in accounts

* Need to decide on a representation for snarky programs.
  - Better not to use source code directly, compilation is hard to measure for
    gas.
    + Could still interpret via a scripting language (eg. OCaml, javascript).
    + Evaluation is hard to make deterministic, would have to modify garbage
      collection, etc. to not depend on system load.
    + Modifications to ensure that memory usage is bounded, system access is
      restricted etc. could amount to a large rewrite of the interpreter.
    + Could write our own interpreter, but it will need to be implemented a
      very low level (ie. C, Rust, etc.) if we want to ensure that evaluation
      has a fairly consistent cost and can't be abused.
  - Could compile down to a dedicated bytecode, with specific instructions for
    snarky-specific operations (field ops, constraints, verification gadgets,
    etc.), and store that on-chain instead.
    + This is much simpler to write an interpreter for (but still complex).
  - Could compile down to WASM (or another existing bytecode) and use the
    above.
    + Simplest would be to go via rust from Meja.
    + This also lets developers write programs in their preferred language, if
      they don't want to use our tooling.
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

## Drawbacks and benefits
[drawbacks-and-benefits]: #drawbacks-and-benefits

### Witness generation + proving off chain: store verification keys in accounts

#### Drawbacks

* Proofs need to be generated by the sender of the transaction.
  - This can be expensive, and may restrict the type of devices that can
    send transactions that are verified by smart contracts.
* Keys need to be generated by the contract author.
  - This is also expensive, which will restrict the type of devices that can
    set up a smart contract.
* The smart contract is opaque.
  - The verification key doesn't provide any insight into the constraint system
    that the transaction must satisfy.
  - The contents of the smart contract must be communicated to authorised
    senders off-chain.
    + This also involves transmitting the proving key, which can be large.
* Keys should be regenerated per-account, reuse should be avoided.
  - Re-using keys would allow the original key generator to generate false
    proofs, if they had stored the 'toxic waste' randomness used when
    generating them.

#### Benefits

* Least amount of work to implement.
  - Most of the complex parts (the snarky verifier, account look-ups, etc.) are
    already implemented and used elsewhere.
* Verification keys will be fairly small, so storage costs can be lower.
* Developers are not restricted to any particular language for generating their
  keys and proofs.
* The size of the constraint system is unrestricted.

### Witness generation + proving off chain: store WASM blob for generating the constraints

#### Drawbacks
[constraints-only-wasm-drawbacks]: #drawbacks-1

* Proofs need to be generated by the sender of the transaction.
  - This can be expensive, and may restrict the type of devices that can
    send transactions that are verified by smart contracts.
* The contract author needs to compute the constraint system to generate the
  appropriate hash.
  - This should be fairly cheap, but may still require a local WASM
    interpreter if the hash is not already known.
* Need to implement a universal snark.
* Need to implement a gas model.
  - It is also not possible to verify the gas usage in the snark, so more trust
    is placed in consensus.
* Need to implement or integrate a WASM interpreter.
  - Gas metering may require wide-reaching changes if we adapt an existing
    interpreter.
* Consensus nodes need to do an amount of unpaid work to verify the gas usage.
* Constraint system programs must be written in a language that compiles down
  to WASM.
  - This usually means that the language relies on manual memory management,
    which will make it hard to use for some developers.
* Will need to write WASM backends for our current snark langauge tooling, if
  we want it to be usable for smart contracts.
* The size of the constraint system is restricted by the transaction snark.
* Verification of universal snarks is (generally) more expensive.
* The smart contract author needs to communicate the program to generate
  witnesses off-chain.

#### Benefits
[constraints-only-wasm-benefits]: #benefits-1

* Far more insight into the predicate's behaviour.
* Less snark-specific knowledge is necessary for developers.
* The smart contract author doesn't need to generate keys.
  - This reduces computational costs and data transfer costs (for the large
    proving keys).
* Smart contracts may be copied directly between accounts.
* There is a good amount of WASM tooling under active development.
* Existing WASM interpreters generally provide good sandboxing.

### Witness generation + proving on chain: store WASM blobs for generating constraints and witnesses in accounts

#### Drawbacks

* All of the drawbacks of constraints-only WASM (see
  [above][constraints-only-wasm-drawbacks]). Exceptions:
  - The sender of the transaction no longer needs to generate a proof.
  - The smart contract author does not need to participate in off-chain
    communications.
* The proof model is more complicated.
  - Additional public input need to be available, to give the sender control
    over the proof.
* Consensus nodes need to do more unpaid work to verify the gas usage.
* More failure cases to handle in the gas model.

#### Benefits

* All of the benefits for constraints-only WASM (see
  [above][constraints-only-wasm-benefits]).
* Transaction sender does not need to perform an expensive computation
  (proving).
  - This allows low-power devices to trigger smart contracts.
* All information needed for evaluating the contract is on-chain.
* User experience is better.
  - Smart contract authors only send the minimum necessary information: the
    constraint system generator and the witness generator.
  - Transation senders only send the transaction and any other necessary
    information. No extra computation or data is needed.

### Witness generation + proving on chain: store snarky programs in accounts

#### Drawbacks

* Ill-defined: it isn't clear how snarky programs should be encoded when stored
  on the chain.
* Evaluation model is far more complex. In particular:
  - it may be harder to meter for gas usage;
  - it may be harder to sandbox;
  - it may be harder to regulate memory usage.
* Restricts developer choice of languages and tooling.
* All of the drawbacks of WASM for constraints and witnesses, except those
  specific to WASM.

#### Benefits

* Smart contracts will be much more human-readable.
  - Program style is less data-oriented and more logic-oriented.
* All of the benefits of WASM for constraints and witnesses, except those
  specific to WASM.

## Time estimates
[time-estimates]: #time-estimates

### Storage model

* Economics/business logic decisions.
  - No estimate (@es92 to advise).
* Storage design decisions.
  - No estimate (crypto and protocol teams to advise).
* On-chain storage model.
  - Estimate 2-5 days (to check with protocol team).
* Storage expiry logic.
  - Estimate 1-2 days (to check with protocol team).
* Data storage transactions (consensus and transaction snark).
  - Estimate 5-10 days (to check with protocol team).
* Further testing and initial optimisations.
  - Estimate 2-6 days (to check with protocol team).

### Proof verification

* Universal snark implementations.
  - No estimate (@ihm to advise).
  - Not necessary for verification key model.
* Verification of transactions using proofs (consensus and transaction snark).
  - Estimate 5-10 days (to check with crypto team).
* Integration for reading additional on-chain storage.
  - Estimate 2-4 days.
  - This is a 'good to have', could be omitted.
* Integration with additional public/auxiliary inputs.
  - Estimate 3-4 days.
  - Not necessary for off-chain proof generation models.
* Further testing and initial optimisations.
  - Estimate 4-7 days (to check with crypto team).

### WASM Evaluation

* Economics/business logic decisions for gas.
  - No estimate (@es92 to advise).
* Evaluation using reference interpreter (written in OCaml).
  - https://github.com/WebAssembly/spec
    + Runs slower, easier to integrate.
  - Integration with daemon.
    + Estimate 2-4 days.
  - Orchestration for gas measurement.
    + Estimate 3-5 days.
  - Memory limiting / sandboxing.
    + Estimate 1-4 days.
  - Integration of snark-specific built-ins.
    + Estimate 5-8 days.
* Evaluation using WASM3 interpreter (written in C).
  - https://github.com/wasm3/wasm3
    + Runs faster, harder to integrate.
  - Integration with daemon.
    + Estimate 5-10 days.
  - Orchestration for gas measurement.
    + Estimate 4-8 days.
  - Memory limiting / sandboxing.
    + Estimate 2-5 days.
  - Integration of snark-specific built-ins.
    + Estimate 7-12 days.
- Gas costs per instruction and built-in operation.
  + Estimate 2-4 days.
* Further testing and initial optimisations.
  - Estimate 2-6 days.

Estimates should run roughly the same for other VMs, the main factors will be
the language that the VM is implemented in, instruction complexity and the VM's
data-flow model.

### Snarky implementation in rust

Since rust has strong support for WASM, and is similar enough to OCaml that we
could closely follow snarky's implementation/libraries, this could form a
viable option for a good smart contract language, and allow us to use a WASM
backend.

* Duplicate snarky core implementation in rust.
  - Estimate 1-2 weeks.
* Convert snarky libraries to rust snarky libraries.
  - Estimate 1-2 weeks.
* Set up for easy WASM compilation and special-casing for our snark-specific
  built-ins.
  - 3-5 days.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

##### Storage

* How should the specific storage for each model be implemented?
* How should each model interface with other existing or proposed on-chain storage?

##### Metering

* What should the economics of the gas model be?
* How will block gas limits be decided?
* How will we decide the gas cost of various instructions in each model?

##### Encodings:

* What encoding or encodings should be supported for snarky programs?
* What specific encodings should we recommend for public inputs in the
  on-chain-proving models.
