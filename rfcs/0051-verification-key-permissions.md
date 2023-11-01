# Verification Key Permissions

This RFC describes the permission scheme for zkApps account verification keys that will be supported at the launch of the Berkeley network.

## Summary

Verification keys control the proofs that can be used when interacting with a zkApp account on-chain. Mina's zkApps allow for specifying permissions when updating various account fields, including the verification key. Updating the verification key is analagous to updating the code of a smart contract on other chains.

In this RFC, we describe a configuration for the verification key permissions that allows developers to make contracts immutable while protecting such contracts from deadlocking upon future upgrades of the protocol.

## Motivation

At the launch of the Berkeley network, the Mina Protocol does not yet guarantee backwards compatability of zkApps in future upgrades. Due to this, it is possible for an immutable contract to break -- any interactions with it that require proofs to be verified against it's verification key will no longer be accepted by the chain. Similarly, the on-chain features that the contract relied on may have been removed or modified.

We wish for zkApps developers to be able to make their contract immutable without putting their contract at risk to breaking upon a future release, rendering any funds locked up in the contract inaccessible.

## Detailed design

NB: This RFC relies on the [protocol versioning RFC](TODO).

In order to prevent a zkApp from breaking upon a future incompatible upgrade of the protocol, we will put special rules in place for the `Impossible` and `Proof` permissions on the verification key. The verification key permission will be represented as a tuple `(Control.t * txn_version)`, and `Proof`/`Impossible` controllers will be reinterpreted as `Signature` if the specified `txn_version` differs from the current protocol's transaction version. User interfaces may provide a less-detailed representation for `None` and `Either`, but the snark and over-the-wire protocol must accept a tuple for all variants.

To ensure that contracts do not become soft-locked, both the transaction logic and the snark must only accept transactions with verification key permission `txn_version`s equal to the current version. Any other versions must be rejected by the transaction pool, block validation logic, and by the snark. We will accomplish this by adding a `txn_version` check to the set of well-formedness checks we do against transactions.

Because setting the verification key permission requires specifying the `txn_version`, the `txn_version` will be included in the transactions hash, ensuring that the update cannot be replayed to 're-lock' the account to a newer, incompatible version.

When the `txn_version` stored in the account's verification key permission matches the current hard fork version of the protocol, the `Impossible` and `Proof` permissions act exactly like their normal counterparts (`Proof` fields can only be updated with a valid proof, `Impossible` fields can never be updated). When the `txn_version` stored within an account's verification key permission is older than (less than) the current hard fork version, then both of these permissions fallback to the `Signature` case, so that the now broken zkApps can be updated for the new hard fork.

The details for updating an old version account to a new version account are elided in this proposal and will be determined on a per upgrade basis. As such, we will keep the existing `zkapp_version` on accounts, storing both the `zkapp_version` of an account and the verificatin key permission `txn_version` separately. This separation means that the migration of an account's format happens separately from the account's smart contract migration. The migration of the account format can flexibly be done either on-chain, upon first interaction with an account, or off-chain, during the hard fork package generation step (but the decision of which route to take is left until we know what we are upgrading to).

## Test plan and functional requirements

Unit tests will be written to test these new permission rules, and a new test case will be added to the hard fork integration test.

The unit tests are to be written against the transaction snark, testing various account updates as inputs. The tests are broken into categories by the expected result: that the statement is unprovable, that the statement was proven to be failed, or that the statement was proven to be successful.

* Unprovable account updates
    * updates which set the `verification_key` permission to `Proof` or `Impossible` with a `txn_version` other than the current hard fork version
* Failed account updates
    * updates which modify the `verification_key` permission in a way that violates the `set_permission` setting while the account's verification key permission's `txn_version` is equal to the current hard fork version
    * updates which modify the `verification_key` using `Signature` or `None` authorizations when the `verification_key` permission is set to `Proof` or `Impossible` while the account's verification key permission's `txn_version` is equal to the current hard fork version
    * updates which modify the `verification_key` using a `Proof` authorization when the `verification_key` permission is set to `Impossible` while the account's verification key permission's `txn_version` is equal to the current hard fork version
* Successful account updates
    * updates which set the `verification_key` permission to `Proof` or `Impossible` with a `txn_version` equal to the current hard fork version, given `set_permission` allows it
    * updates that modify the `verification_key` using a `Proof` authorization when the `verification_key` permission is set to `Proof` while the account's verification key permission's `txn_version` is equal to the current hard fork version
    * updates that modify the `verification_key` using a `Signature` authorization when the `verification_key` permission is set to `Proof` or `Impossible` while the account's verification key permission's `txn_version` is less than the current hard fork version
    * updates that modify the `verification_key` permission using a `Signature` authorization whenever the `verification_key` permission is set to `Proof` or `Impossible` while the account's verification key permission's `txn_version` is less than the current hard fork version (even if `set_permission` disagrees)

The new test cases in the hard fork integration tests will utilize 2 accounts in the ledger which we will name A and B. The new test cases are as follows:

* Before the hard fork
    * Attempt to set any account's `verification_key` permission to `Proof` for the wrong hard fork
    * Attempt to set any account's `verification_key` permission to `Impossible` for the wrong hard fork
    * Set A's `verification_key` permission to `Proof` for the current hard fork
    * Set B's `verification_key` permission to `Impossible` for the current hard fork
    * Check that you can still update A's `verification_key` using the `Proof` authorization
    * Check that neither A nor B can have their `verification_key` updated using the `Signature` authorization
* After the hard fork
    * Check that you can update both A's and B's `verification_key` field using the `Signature` authorization
    * Check that you can update both A's and B's `verification_key` permission using the `Signature` authorization

## Drawbacks
[drawbacks]: #drawbacks

## Rationale and alternatives

## Unresolved questions

* Should we require that any outdated permissions must be reset by the first account update sent to it?
    * At a glance, this seems to make sense, but it also seems unnecessarily restrictive.
    * DECISION: it is unnecessary to enforce this, especially given we are tracking the verification key permission's `txn_version` separately from the `zkapp_version` of the underlying account
