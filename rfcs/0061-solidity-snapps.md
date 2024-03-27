# Overview of solidity features for snapps

This document aims to examine the features of the solidity smart contract
language, to describe how they can be simulated by snapps, and proposing
changes to the snapp transaction model for those that it currently cannot
simulate.

This document refers to the features of v0.8.5 of the solidity language, and
makes reference to the snapp parties transaction RFC at MinaProtocol/mina#8068
(version 95e148b4eef01c6104de21e4c6c7c7465536b9d8 at time of writing).

## Basic features

### State variables

Solidity uses [state variables](https://docs.soliditylang.org/en/v0.8.5/structure-of-a-contract.html#state-variables)
to manage the internal state of a contract. We intend to simulate this state
with a 'snapp state' formed of [8 field elements](https://github.com/MinaProtocol/mina/blob/b137fbd750d9de1b5dfe009c12de134de0eb7200/src/lib/mina_base/snapp_state.ml#L17).
Where the state holds more data than will fit in 8 field elements, we can
simulate this larger storage by holding a hash of some of these variables in
place of their contents.

In solidity, 'public' variables can be referenced by other contracts via a
function. We propose using the same method for snapps; see the function section
below for details.

#### Off-chain storage and snapp state accessibility

When the variables do not fit within the field elements, the data for the snapp
will not be directly available on-chain, and must be computed or retrieved from
some off-chain source. It is important to provide primitives for revealing
the updated states, otherwise updating a snapp's state may only reveal a hash,
and the new underlying data may be rendered inaccessible.

To this end, it may be useful to add support for the poseidon hash used by mina
to IPFS, so that this data can be stored (ephemerally) in IPFS. We will also
discuss a proposal to expose data for state transitions as 'events' associated
with the parties; see the events section below for details.

### Functions

[Functions](https://docs.soliditylang.org/en/v0.8.5/structure-of-a-contract.html#functions)
are the primary interface of solidity contracts; in order to interact
with a smart contract, you submit a transaction that calls one of the functions
the contract exposes. These may call other functions from the same contract or
from other contracts.

We propose simulating functions with snark proofs, where each function call
corresponds to a single snark proof. Our current snark model uses a 'wrapping'
primitive, which allows a single 'verification key' to verify wrapped proofs
witnessing one (or more) of several different 'circuits' (here, function
declarations). Function calls against different snapps require separate
'parties', although multiple calls to functions in the same snapp may be merged
into a single proof and issued as a single 'party' (either by proof composition
or inlining, depending on the use case).

#### Arguments and returned values

In order to simulate calling functions with arguments, and returning values
from functions, snapp parties must be able to expose some 'witness' to these
values. The format is determined by the circuit statement, but usually this
will be `hash(arguments, returned_values)`.

*This is currently not supported by the snapp transaction model RFC.*

**Proposal:** add an additional field element (`aux_data`) that is passed as
part of the input to the snapp proof, which may be used to bind the function's
input and returned values.

#### Function calls between snapps

In order for a snapp to verify that function calls are executed, snapp proofs
must be able to interrogate the other parties included in a transaction. The
current RFC doesn't identify what the proof inputs should be, but describes a
stack of parties (`parties`) and the current state of the stack when a
transaction is reached in the stack (`remaining_parties`).

**Proposal:** pass `parties`, the stack of parties, as part of the snapp input.

We should also consider nested function calls, each of which may result in one
or more parties (e.g. to pay one or more receivers, or to make other further
function calls). We can make these conceptually simpler and more composable by
grouping the transactions nested below a party's snapp together, in a hierarchy
of snapps. This will be particularly helpful for snapps which make recursive
calls or deeply nested calls, by letting them avoid walking arbitrarily far
along the stack of parties to find the one they care about.

**Proposal:** use a stack of stacks for the parties involved in a transaction,
allowing each snapp to access its inner transactions by examining its stack.
For example, a snapp which calls other snapps might have a stack that looks
like
```ocaml
[ transfer_for_fee
; [ snapp1
  ; transfer1 (* Sent by snapp1 *)
  ; [ snapp2 (* Called by snapp1 *)
    ; transfer2 (* Sent by snapp2 *)
    ; [snapp3] ] (* Called by snapp2 *)
  ; transfer3 (* Sent by snapp1 *)
  ; [snapp4] ] ] (* Called by snapp1 *)
```
Concretely, this allows snapp1 to access `transfer3` and `snapp4` without
needing to know or care about the transfers and snapps executed by `snapp2`.
In the implementation, this could look something like:
```ocaml
let get_next_party
    current_stack (* The stack for the most recent snapp *)
    call_stack (* The partially-completed parent stacks *)
  =
  let next_stack, next_call_stack =
    if call_stack = empty_stack then
      empty_stack, empty_stack
    else
      call_stack.pop()
  in
  (* If the current stack is complete, 'return' to the previous
     partially-completed one.
  *)
  let current_stack, call_stack =
    if current_stack = empty_stack then
      next_stack, next_call_stack
    else
      stack, call_stack
  in
  let stack_or_party, next_stack = current_stack.pop() in
  let party, remaining_stack =
    let stack =
      if stack_or_party.is_party() then
        (* dummy value for circuit *)
        current_stack
      else
        stack_or_party.as_stack()
    in
    let popped_value, remaining_stack = stack.pop() in
    if stack_or_party.is_party() then
      stack_or_party.as_party(), empty_stack
    else
      popped_value, remaining_stack
  in
  let party, current_stack, next_stack =
    if remaining_stack = empty_stack then
      party, next_stack, empty_stack
    else
      party, remaining_stack, next_stack
  in
  let call_stack =
    if next_stack = empty_stack then call_stack
    else call_stack.push(next_stack)
  in
  party, current_stack, call_stack
```

This increases the number of stack operations per party from 1 to 4.

### Function modifiers

[Function modifiers](https://docs.soliditylang.org/en/v0.8.5/structure-of-a-contract.html#function-modifiers)
are a language level feature of solidity, and exist solely to avoid unnecessary
function calls. This requires no features at the transaction model level.

### Events

[Events](https://docs.soliditylang.org/en/v0.8.5/structure-of-a-contract.html#events)
in solidity are emitted by a smart contract, but are not available for use by
the contracts themselves. They are used to signal state transitions or other
information about the contract, and can be used to expose information without
the need to replay all past contract executions to discover the current state.

*This is currently not supported by the snapp transaction model RFC.*

**Proposal:** add an additional field to each party that contains a list of
events generated by executing a snapp, or none if it is a non-snapp party. This
event stack should be passed as part of the input to the snapp, as the output
of hash-consing the list in reverse order. (*TODO-protocol-team: decide on the
maximum number / how the number affects the txn fee / etc. to avoid abuse.*)

#### Exposing internal state variables

As mentioned in the 'state variables' section above, the contents of a snapp's
internal state becomes unavailable on-chain if that state is larger than the
available 8 field elements. Events give us the opportunity to re-expose this
data on chain, by e.g. emitting a `Set_x(1)` event when updating the value of
the internal variable `x` to `1`, so that the current state of the snapp can be
recovered without off-chain communication with the previous party sending the
snapp.

This is likely to be an important feature: it's not possible to execute a snapp
without knowing the internal state, and this appears to be the easiest and most
reliable way to ensure that it is available. Without such support, it's
possible and relatively likely for a snapp's state to become unknown /
unavailable, effectively locking the snapp.

### Errors

Solidity
[errors](https://docs.soliditylang.org/en/v0.8.5/structure-of-a-contract.html#errors)
are triggered by a `revert` statement, and are able to carry additional
metadata.

In the current snapp transaction RFC, this matches the behaviour of invalid
proofs, where the errors correspond to an unsatisfiable statement for a
circuit. In this model, we lose the ability to expose the additional metadata
on-chain; however, execution is not on-chain, so the relevant error metadata
can be exposed at proof-generation time instead.

### Struct and enum types

[Struct types](https://docs.soliditylang.org/en/v0.8.5/structure-of-a-contract.html#struct-types)
are a language feature of solidity, which is already supported by snarky.
[Enum types](https://docs.soliditylang.org/en/v0.8.5/structure-of-a-contract.html#enum-types)
have also had long-lived support in snarky, although have seen little use in
practice.

## Types

### Value types

All of the
[value types](https://docs.soliditylang.org/en/v0.8.5/types.html#value-types)
supported by solidity are also supported by snarky.

### Reference types

[Reference types](https://docs.soliditylang.org/en/v0.8.5/types.html#reference-types)
in solidity refer to blocks of memory. These don't have a direct analog in
snarks, but can be simulated -- albeit at a much higher computational cost --
by cryptographic primitives. Many of these primitives are already implemented
in snarky.

### Mapping types

[Mapping types](https://docs.soliditylang.org/en/v0.8.5/types.html#mapping-types)
are similar to reference types, but associate some 'key' value with each data
entry. This can be implemented naively on top of a primitive for
`[(key, value)]`, an array of key-value pairs, which is already available in
snarky.

We currently do not support a primitive for de-duplication: a key may appear
multiple times in a `[(key, value)]` implementation and the prover for a snapp
could choose any of the values associated with the given key in a particular
map. This will require some research into the efficiency of the different
primitives available for this, but has no impact upon the transaction model.

## Standard library

### Block / transaction properties

The
[block and transaction properties](https://docs.soliditylang.org/en/v0.8.5/units-and-global-variables.html#block-and-transaction-properties)
available in solidity are, at time of writing:
* `blockhash(uint blockNumber)`
  - Can be easily supported using the protocol state hash, although the timing
    is tight for successful execution (receive a block, create the snapp proof,
    send it, have it included in the next block).
  - **Proposal:** support the previous `protocol_state_hash` in snapp
    predicates.
* `block.chainid`
  - **Proposal:** expose the chain ID in the genesis constants, allow it to be
    used in the snapp predicate.
* `block.coinbase`
  - Snapp proofs are generated before the block producer is known. Not possible
    to support.
* `block.difficulty`
  - Not applicable, block difficulty is fixed.
* `block.gaslimit`
  - Not applicable, we don't have a gas model.
* `block.number`
  - Available by using `blockchain_length` in the snapp predicate.
* `block.timestamp`
  - Available by using `timestamp` in the snapp predicate.
* `gasleft()`
  - Not applicable, we don't have a gas model.
* `msg.data`
  - Available as part of the snapp input
* `msg.sender`
  - **Proposal:** Expose the party at the head of the parent stack as part of
    the snapp input.
* `msg.sig`
  - As above.
* `msg.value`
  - As above.
* `tx.gasprice`
  - Not applicable, we don't have a gas model.
* `tx.origin`
  - Can be retrieved from the `parties` stack of parties. May be one or more
    parties, depending on the structure of the transaction.

### Account look-ups

Solidity supports the following
[accessors on addresses](https://docs.soliditylang.org/en/v0.8.5/units-and-global-variables.html#members-of-address-types):
* `balance`
  - Could use the `staged_ledger_hash` snapp predicate (currently disabled) and
    perform a merkle lookup. However, this doesn't account for changes made by
    previous parties in the same transaction, or previous transactions in the
    block.
  - **Proposal:** Add a 'lookup' transaction kind that returns the state of an
    account using `aux_data`, with filters to select only the relevant data.
    Snapps can then 'call' this by including this party as one of their
    parties.
  - Note: using this will make the snapp transaction fail if the balance of the
    account differs from the one used to build the proof at proving time.
* `code`, `codehash`
  - Snapp equivalent is the `verification_key`.
  - Options are as above for `balance`. If this key is for one of the
    snapp-permissioned parties, the key can assumed to be statically known,
    since their snapp proof will be rejected and the transaction reverted if
    the key has changed.
* `transfer(uint256 amount)`
  - Executed by including a transfer to the party as part of the snapp's party
    stack.
* `call`, `delegatecall`, `staticcall`
  - Executed by including a snapp party as part of the snapp's party stack.

### Contract-specific functions

Solidity supports
[reference to `this` and a `selfdestruct` call](https://docs.soliditylang.org/en/v0.8.5/units-and-global-variables.html#members-of-address-types).

We can support `this` by checking the address of the party for a particular
snapp proof, or by otherwise including its address in the snapp input.

We currently do not support account deletion, so it is not possible to
implement an equivalent to `selfdestruct`.
