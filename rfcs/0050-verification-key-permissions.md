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

In order to prevent a zkApp from breaking upon a future incompatible upgrade of the protocol, we will not allow users to set the `Impossible` or `Proof` permissions on the verification key. Instead, we will add 2 new permissions, `Impossible_during_hard_fork` and `Proof_during_hard_fork`, each of which will carry a specific transaction logic version to represent the hard fork they in which they are valid. Thus, the total set of permissions allowed to be set on verification keys would be:

* `None`
* `Either`
* `Signature`
* `Proof_during_hard_fork of txn_version`
* `Impossible_during_hard_fork of txn_version`

There is a restriction enforced in the transaction snark when a user attempts to set the permission to either `Proof_during_hard_fork` or `Impossible_during_hard_fork`. For any hard fork version, the transaction snark will only accept attempts to set one of these permissions to the current hard fork version. Any attempt to set one of these permissions to a hard fork version other than the current one will result in a failure. This failure should be implemented as a well formed transaction error rather than failing on chain, since it is something that can be checked statically before accepting transactions into the transaction pool. Thus, the transaction snark will fail to prove any such transactions, rather than failing on-chain.

When the `txn_version` referenced by either of these new permissions matches the current hard fork version of the protocol, the permissions act exactly like their normal counterparts (`Proof` fields can only be updated with a valid proof, `Impossible` fields can never be updated). When the `txn_version` is older than (less than) the current hard fork version, then both of these permissions fallback to the `Signature` case, so that the now broken zkApps can be updated for the new hard fork.

An account permission that is set to either of these new permissions can be updated when the `txn_version` referenced is older than the current hard fork version. This scenario ignores restrictions by `set_permission`, and operates as if `set_permission` were `Signature`.

The transaction snark asserts that any `txn_version` referenced by any account permission cannot be newer than the current protocol version.

## Test plan and functional requirements

Unit tests will be written to test these new permissions, and a new test case will be added to the hard fork integration test.

The unit tests are to be written against the transaction snark, testing various account updates as inputs. The tests are broken into categories by the expected result: that the statement is unprovable, that the statement was proven to be failed, or that the statement was proven to be successful.

* Unprovable account updates
    * updates operating on an account in the ledger where the `verification_key` permission is set to `Proof` or `Impossible`
    * updates operating on an account in the ledger where the `verification_key` permission is set to `Proof_during_hard_fork` or `Impossible_during_hard_fork` that references a `txn_version` that is greater than the current hard fork version
    * updates which set the `verification_key` permission to `Proof` or `Impossible`
    * updates which set the `verification_key` permission to `Proof_during_hard_fork` or `Impossible_during_hard_fork` that references a `txn_version` other than the current hard fork version
* Failed account updates
    * updates which set the `verification_key` permission to `Proof_during_hard_fork` or `Impossible_during_hard_fork` that references a `txn_version` equal t the current hard fork version if `set_permission` does not allow it.
    * updates that modify the `verification_key` using a `Signature` authorization when the `verification_key` permission is set to `Proof_during_hard_fork` or `Impossible_during_hard_fork`.
    * updates that modify the `verification_key` when the `verification_key` permission is set to `Impossible_during_hard_fork` set to the current hard fork version.
    * updates that modify `verification_key` using a `Signature` authorization when the `verification_key` permission is set to `Proof_during_hard_fork` or `Impossible_during_hard_fork` set to the current hard fork version
    * updates that modify the `verification_key` permission using a `Signature` authorization whenever the `verification_key` permission is set to `Proof_during_hard_fork` or `Impossible_during_hard_fork` set to the current hard fork version when the `set_permission` is not `None`, `Either`, or `Signature`
* Successful account updates
    * updates which set the `verification_key` permission to `Proof_during_hard_fork` or `Impossible_during_hard_fork` that references a `txn_version` equal t the current hard fork version, given `set_permission` allows it.
    * updates that modify the `verification_key` using a `Proof` authorization when the `verification_key` permission is set to `Proof_during_hard_fork` set to the current hard fork version.
    * updates that modify the `verification_key` using a `Signature` authorization when the `verification_key` permission is set to `Proof_during_hard_fork` or `Impossible_during_hard_fork` set to an older hard fork version
    * updates that modify the `verification_key` permission using a `Signature` authorization whenever the `verification_key` permission is set to `Proof_during_hard_fork` or `Impossible_during_hard_fork` set to an older hard fork version (even if `set_permission` disagrees)

The new test cases in the hard fork integration tests will utilize 2 accounts in the ledger which we will name A and B. The new test cases are as follows:

* Before the hard fork
    * Attempt to set any account's `verification_key` permission to `Proof_during_hard_fork` for the wrong hard fork
    * Attempt to set any account's `verification_key` permission to `Impossible_during_hard_fork` for the wrong hard fork
    * Set A's `verification_key` permission to `Proof_during_hard_fork` for the current hard fork
    * Set B's `verification_key` permission to `Impossible_during_hard_fork` for the current hard fork
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
