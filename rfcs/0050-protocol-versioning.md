# Protocol Versioning

Protocol versioning is the system by which we identify different versions of the blockchain protocol and the software the operates it.

## Summary

There are multiple dimensions of compatability between software operating a decentralized protocol. In this RFC, we concretely breakdown those dimensions of compatability into a hierarchy, and then propose a semver-inspired verisioning scheme that utilizes that hierarchy.

## Motivation

The motivation for this comes from a few angles. Firstly, having a versioning scheme for the protocol itself allows developers in the ecosystem to more accurately discuss compatability of different software. For instance, if any 2 separate implementations of the daemon exist, then the protocol version can identify if those 2 implementations are compatible. Tools that process data from the network can also identify the versions of the protocol they are compatible with, or even dynamically support multiple versions of the protocol via configuration.

Besides this, we also want a way to programatically reason about different versions of the protocol from within our software, including having the ability to be aware of protocol versions within the snark proofs that Mina uses.

The solution in this RFC is optimizing for simplicity and clarity.

## Detailed design

At a protocol level, there are 2 important dimensions of compatibility: compatibility of the transaction system, and compatibility of the networking protocol. Transaction system compatibility determines support for the transaction format and the logical details of how transactions are processed. Compatibility of the networking protocol determines the participation rules (consensus et al) and wire format.

Compatibility of the transaction system can be thought of as the mapping of ledger states into sets of all valid applicable transactions for each ledger state. This ensures that, if we have any 2 different implementations of the transaction logic, that those 2 implementations are only considered compatible if they will always accept, reject, or fail transactions in an equivalent way.

Compatibility of the networking protocol can be thought of as the set of all RPC messages, wires types, gossip topics, p2p feature set, and participation rules. Participation rules include any rule in the protocol that regards certain behavior as malicious or otherwise not permitted. This ranges from consensus details to bannable offenses and even verification logic for gossip messages. It's important the capture all of this under the umbrella of networking protocol compatibility since divergences in these details can lead to unintended forks on the chain.

To label versions of our daemon software, we will use the following versioning convention, inspired by semver: `<txn_version>.<net_version>.<impl_version>`. In this setup, the version of the transaction system is the most dominant version, since any updates to it necessitate a hardfork, and when reasoning about the logic of the chain state, it is the most significant version number. The prefix of the `<txn_version>.<net_version>` uniquely identifies a particular hard fork version, since the pair of those 2 versions determines the full compatability of an implementation. The leftover `<impl_version>` is retained for the usage of individual daemon implementations to use however they see fit. We leave this detail to each implementor of the daemon, as the meaning of these versions is intended to be specific to the implementation.

For the existing daemon implementation in OCaml, which is maintained in the `MinaProtocol/mina` repository, we will use the following versioning convention for the `<impl_version>`: `<api_version>-<patch_version>`. Here, the `<api_version>` will be used to denotate any breaking API changes for user-facing APIs the daemon supports (CLI, GraphQL, Archive Format). Whenever we add, remove, deprecate, or modify the interface of existing APIs, this version must be incremented. The `<patch_version>` is used in the same way the patch version is utilized in semver: to signify that there are new backwards compatible bug fixes or improvements. We may also add an additional suffix to the `<impl_version>` if there is a different variant of the artifact for that version. For instance, if we were testing some optimizations behind a feature flag, but weren't ready to ship it to the stable version of the software (or didn't want to for some reason), then we could maintain a variant build for that artifact by appending a `-opt` prefix to the version.

## Drawbacks
[drawbacks]: #drawbacks

The main drawback of this plan is that it requires additional review when tagging the version for a new release of the software. However, this appears to be a necessary and an important step in the process, and hopefully will lead us to a world where we are developing the protocol separately from the implementation, rather than assigning a protocol version to an implementation retroactively upon release.
 
## Rationale and alternatives

One alternative to this is following semver directly, and not specifying more specific meanings behind the version number. This would make the versioning scheme more standard, but it would no longer allow us to use the `<txn_version>` and the `<net_version>` as separate values when reasoning about their relative compatibility in tooling (and in the snarks). 

## Prior art

The daemon already supports a semver protocol version, but does not specify how it should be set over time. This Berkeley hard fork is an opportunity to set the rules for it in place.

## Unresolved questions
