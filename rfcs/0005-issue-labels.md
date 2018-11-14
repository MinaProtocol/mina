# Summary
[summary]: #summary

Currently, our issue labels are ad-hoc and somewhat confusing. This defines
several categories of label, and how to use them.

# Detailed design
[detailed-design]: #detailed-design

Here are the categories of issue label. Each label is composed of the category
name and the label name. For example, `area-snark` or `priority-critical`.

- `area-`. This narrows general area of the codebase or feature that this
  issue impacts.

  - `build`
  - `catchup`
  - `client`
  - `consensus`
  - `daemon`
  - `docs`
  - `gossip`
  - `kademlia`
  - `monitoring`
  - `proposer`
  - `protocol`
  - `sdk`
  - `snark`
  - `snarker`
  - `testnet`
  - `tests`
  - `ux`
  - `website`

- `impact-`. This describes the general impact of the issue.

  - `bandwidth`: uses too much bandwidth
  - `crash`: there's a crash
  - `disk`: uses too much disk space
  - `dos`: liable to a remote denial of service attack
  - `insecure`: an attacker can exploit this for nefarious ends
  - `latency`: takes too long
  - `memory`: uses too much memory
  - `slow`: our code is slower than it could be

- `effort-`. This estimates how much experience (with OCaml/the
  codebase/whatever) is necessary to resolve an issue.

  - `easy`: not much experience necessary
  - `hard`: a lot of experience necessary, will be challenging
  - `medium`: some experience necessary

- `category-`. General, broad-stroke categories useful for filtering the issue
  list.

  - `bug`
  - `duplicate`
  - `enhancement`: not necessarily a feature, and might fix some bugs, but improves some aspect of the codebase.
  - `feature-request`
  - `mentored`: this issue has someone who can mentor contributors through fixing it
  - `quick-fix`: the necessary change has already been identified, and it will take someone already familiar with the codebase less than around half an hour to implement it.
  - `refactor`
  - `regression`: this issue was previously already fixed.
  - `rfc`

- `priority-`. How urgent it is to fix the issue.

  - `critical`
  - `high`
  - `low`

- `status-`. This indicates something about the current status of the issue.

  - `cannot-repro`: reproduction attempts failed
  - `needs-info`: issue isn't detailed enough to act on
  - `needs-repro`: needs to be reproduced
  - `needs-rfc`: this change needs nontrivial design work that should be done in an RFC.

- `planning-`. When we plan on doing this

  - `after-testnet`: after the public testnet is released
  - `for-testnet`: before the public testnet is released

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

The idea with most of these categories is to partition the issues along various
axes to make it easy to filter and track them. The labels within most categories
aren't intended to be mutually exclusive. The main exception is "Priority".

Keep in mind that only repo collaborators can add/remove issues. Maintainers
should apply labels to new issues as appropriate.

# Prior art
[prior-art]: #prior-art

- Rust: https://github.com/rust-lang/rust/labels
- geth: https://github.com/ethereum/go-ethereum/labels
- aleth: https://github.com/ethereum/aleth/labels
- Electron: https://github.com/electron/electron/labels
- Tezos: https://gitlab.com/tezos/tezos/labels
- ZCash: https://github.com/zcash/zcash/labels
