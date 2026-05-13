# Mina Glossary

This file is the **single canonical source** for definitions of Mina-specific
terminology. Other docs should link here rather than redefining terms inline.

Each entry has a `<!-- canonical: <slug> -->` HTML anchor immediately above
its heading, so AI agents and tools can grep deterministically for the
authoritative definition (e.g. `grep "canonical: scan_state"`).

## Conventions

- One canonical definition per term. If you find a term defined in two
  places, fold the second occurrence into a link to this file.
- Entries are alphabetized. Grouped entries (e.g. "Hard fork names",
  "Profiles") are filed under their group heading.
- Citations point to the most authoritative in-tree source. They are line
  ranges, not pinned shas — verify at read time.

## Index

- [Block, transition, breadcrumb](#block-transition-breadcrumb)
- [Branches: `compatible`, `develop`, `master`](#branches-compatible-develop-master)
- [Completed work](#completed-work)
- [Hard fork vs soft fork](#hard-fork-vs-soft-fork)
- [Hard fork names: Berkeley, Mesa, Izmir](#hard-fork-names-berkeley-mesa-izmir)
- [Ledger mask](#ledger-mask)
- [Ledger proof](#ledger-proof)
- [Pickles](#pickles)
- [Prefork](#prefork)
- [Profiles: `dev`, `devnet`, `mainnet`, `lightnet`](#profiles-dev-devnet-mainnet-lightnet)
- [Protocol state](#protocol-state)
- [Recursive proof](#recursive-proof)
- [Scan state](#scan-state)
- [Slot, epoch, k](#slot-epoch-k)
- [Snark work](#snark-work)
- [Snarked ledger](#snarked-ledger)
- [Staged ledger](#staged-ledger)
- [Transition frontier (full vs persistent)](#transition-frontier-full-vs-persistent)
- [VRF](#vrf)
- [Work statement](#work-statement)

---

<!-- canonical: block -->
<!-- canonical: transition -->
<!-- canonical: breadcrumb -->

## Block, transition, breadcrumb

These three words refer to overlapping concepts at different layers:

- **Block** — the wire-level data: header (with [protocol state](#protocol-state)
  and proof) plus a [staged ledger](#staged-ledger) diff. This is what gets
  gossiped between peers.
- **Transition** (a.k.a. *external transition*) — a block plus the
  validation tags accumulated as it moves through the pipeline (signature
  checked, proof verified, parent known, etc.). When code says "external
  transition" it almost always means a *validated* block.
- **Breadcrumb** — the fully-expanded in-memory representation in the
  [transition frontier](#transition-frontier-full-vs-persistent). A
  breadcrumb wraps a validated block together with the resulting
  [staged ledger](#staged-ledger) (including
  [scan state](#scan-state) and pending coinbase). Storing a breadcrumb
  costs a lot of RAM, which is why the persistent frontier stores blocks
  only.

*Source: [`src/lib/transition_frontier/frontier_base/breadcrumb.mli`](../src/lib/transition_frontier/frontier_base/breadcrumb.mli),
[`src/lib/transition_frontier/README.md`](../src/lib/transition_frontier/README.md).*

---

<!-- canonical: branch_compatible -->
<!-- canonical: branch_develop -->
<!-- canonical: branch_master -->

## Branches: `compatible`, `develop`, `master`

The three long-lived development branches:

- **`master`** — current stable mainnet release. Hotfixes only.
- **`compatible`** — soft-fork staging. Daemons built from `compatible`
  must still connect to mainnet.
- **`develop`** — breaking changes (incompatible with running mainnet),
  including features scoped for the next [hard fork](#hard-fork-vs-soft-fork).

`release/<name>` branches (`release/3.4.0`, `release/mesa`, …) are
**short-lived release-only** branches cut from a long-lived branch. They
are not contributor PR targets.

*Source: [`README-branching.md`](../README-branching.md) (canonical).*

---

<!-- canonical: completed_work -->

## Completed work

A bundle of at most two [ledger proofs](#ledger-proof) along with the
prover's public key and fee. This is what a snark worker returns when it
finishes a job; it's also the unit a block producer consumes when including
work in a [staged ledger](#staged-ledger) diff. "Completed work" and
"[snark work](#snark-work)" are used interchangeably in most parts of the
codebase.

*Source: [`src/lib/transaction_snark_work/transaction_snark_work.mli`](../src/lib/transaction_snark_work/transaction_snark_work.mli),
[`src/lib/staged_ledger/README.md`](../src/lib/staged_ledger/README.md).*

---

<!-- canonical: hard_fork -->
<!-- canonical: soft_fork -->

## Hard fork vs soft fork

- **Hard fork** — a protocol change that *breaks* compatibility: nodes
  running the old version cannot validate or follow the new chain.
  Coordinated via a fixed activation slot and a fresh genesis ledger
  ([prefork](#prefork) snapshot).
- **Soft fork** — a backwards-compatible protocol change. Old nodes still
  follow the chain; new rules only restrict what was previously allowed.
  Soft-fork-scoped work targets the [`compatible`](#branches-compatible-develop-master)
  branch.

For named hard fork events, see
[Hard fork names](#hard-fork-names-berkeley-mesa-izmir).

---

<!-- canonical: hardfork_berkeley -->
<!-- canonical: hardfork_mesa -->
<!-- canonical: hardfork_izmir -->

## Hard fork names: Berkeley, Mesa, Izmir

Mina hard forks are given non-numeric code names so internal references stay
stable as version numbers shift. Chronological order:

- **Berkeley** — the 2.X hard fork. Currently the active mainnet release.
- **Mesa** — the 3.X hard fork. Next scheduled hard fork; staged on the
  `release/mesa` branch and prepared via [prefork](#prefork) genesis ledgers.
- **Izmir** — historically reserved as the post-Berkeley name when Mesa was
  not yet planned. Treat references to "izmir" in older docs/RFCs as
  superseded by Mesa unless the context makes it clear the term was used
  for something else.

---

<!-- canonical: ledger_mask -->

## Ledger mask

A copy-on-write overlay over a parent ledger. Account updates land in the
mask without modifying the parent; if the underlying chain segment is
abandoned (a fork is dropped), the mask is discarded with no impact on the
parent. When a block is finalized along its branch, the mask is committed
("flushed") into its parent.

Masks are how the [transition frontier](#transition-frontier-full-vs-persistent)
keeps multiple competing chain tips cheap: each [breadcrumb](#block-transition-breadcrumb)
holds only a thin diff over its parent's ledger.

*Source: [`src/lib/mina_ledger/README.md`](../src/lib/mina_ledger/README.md).*

---

<!-- canonical: ledger_proof -->

## Ledger proof

A SNARK certifying a transition between two ledger states. Concretely, a
ledger proof attests "starting from snarked ledger A, applying transactions
T₁…Tₙ produces snarked ledger B." It is a special case of a transaction
SNARK that has been merged across all transactions in a [scan state](#scan-state)
tree, which is why one is emitted whenever a tree is fully proven.

Each [completed-work](#completed-work) bundle returned by a snark worker
contains at most two ledger proofs.

*Source: [`src/lib/ledger_proof/`](../src/lib/ledger_proof/),
[`src/lib/staged_ledger/README.md`](../src/lib/staged_ledger/README.md).*

---

<!-- canonical: pickles -->

## Pickles

Mina's [recursive-proof](#recursive-proof) system. Pickles takes proofs
about proofs, which is what lets the blockchain stay constant-size: instead
of growing with chain length, a single pickles proof certifies the validity
of all prior history.

Used to compose [transaction SNARKs](#ledger-proof) and the blockchain
SNARK that wraps each block.

*Source: [`src/lib/crypto/pickles/`](../src/lib/crypto/pickles/) and the
[`proof-systems`](../src/lib/crypto/proof-systems) submodule.*

---

<!-- canonical: prefork -->

## Prefork

The frozen snapshot of state captured *before* a [hard fork](#hard-fork-vs-soft-fork)
activates. Used as both (a) the input to fork validation (you must replay
post-prefork blocks deterministically) and (b) the genesis ledger of the
post-fork chain.

Prefork artifacts ship as Debian packages named e.g.
`mina-create-mesa-prefork-genesis-ledger`. Directory layout follows a
fork-validation convention so that downstream tools can discover the
ledger, runtime config, and replayer inputs as a unit.

---

<!-- canonical: profile_dev -->
<!-- canonical: profile_devnet -->
<!-- canonical: profile_mainnet -->
<!-- canonical: profile_lightnet -->

## Profiles: `dev`, `devnet`, `mainnet`, `lightnet`

Build profiles selected via dune's `--profile` flag. Each profile is a
configuration module under `src/lib/node_config/profiled/<name>.ml`
exposing constants such as `ledger_depth`, `k`, `slots_per_epoch`, and
`proof_level`.

| Profile | Ledger depth | `k` | Slots/epoch | Proof level | Use |
|---|---|---|---|---|---|
| `dev` | 10 | small | small | `check` | Local development; fast block times. |
| `devnet` | 35 | mainnet | mainnet | `full` | Public devnet; mainnet parameters with testnet signature kind. |
| `mainnet` | 35 | mainnet | mainnet | `full` | Production. |
| `lightnet` | 35 | 30 | 720 | `none` | Lightweight test network; no proofs. |

`dev` is the default if `--profile` is omitted. `devnet` and `mainnet`
differ only in [signature kind](../src/lib/signature_kind) — the underlying
parameters are identical.

*Source: [`src/lib/node_config/profiled/`](../src/lib/node_config/profiled/).*

---

<!-- canonical: protocol_state -->

## Protocol state

The consensus-critical state of the chain at a given block. Contains the
state hash, blockchain state (ledger hash, previous state hash, timestamp),
and consensus state (epoch data, [VRF](#vrf) outputs, etc.). The protocol
state is what pickles' blockchain SNARK proves valid.

*Source: [`src/lib/mina_state/protocol_state.mli`](../src/lib/mina_state/protocol_state.mli).*

---

<!-- canonical: recursive_proof -->

## Recursive proof

A SNARK proof whose statement asserts the validity of *another* SNARK
proof. Mina uses recursive proofs (via [Pickles](#pickles)) to keep
on-chain proof size constant regardless of chain length: each new block's
proof recursively certifies the previous block's proof.

---

<!-- canonical: scan_state -->

## Scan state

A queue of binary trees that holds the data required to prove sets of
transactions. Each node stores either a base statement (one transaction's
input/output) or a merge statement (two children combined).

A new tree is "rolled in" each time a block is applied; trees are filled
incrementally as snark workers return [completed work](#completed-work).
When a tree's root has a proof, a [ledger proof](#ledger-proof) is emitted
and the [snarked ledger](#snarked-ledger) advances. Two parameters control
its shape:

- `scan_state_transaction_capacity_log_2` — log₂ of transactions per tree
- `scan_state_work_delay` — how many trees may be partially-proven at once

*Source: [`src/lib/transaction_snark_scan_state/`](../src/lib/transaction_snark_scan_state/),
[`src/lib/staged_ledger/README.md`](../src/lib/staged_ledger/README.md).*

---

<!-- canonical: slot -->
<!-- canonical: epoch -->
<!-- canonical: k -->

## Slot, epoch, k

Three time/finality parameters of the consensus layer:

- **Slot** — the smallest discrete time unit. Block production is allocated
  per slot; at most one block per slot per producer. Slot length is set by
  `block_window_duration_ms` (3 minutes on mainnet, 2 seconds on `dev`).
- **Epoch** — a fixed number of slots (`slots_per_epoch`, 7140 on mainnet).
  Staking-ledger snapshots and [VRF](#vrf) inputs roll over at epoch
  boundaries.
- **`k`** — the consensus finality constant (290 on mainnet). Blocks more
  than `k` deep from the best tip are considered finalized; the
  [transition frontier](#transition-frontier-full-vs-persistent) is bounded
  to paths of length ≤ `k` from its root.

These three are the fundamental knobs of Ouroboros Samasika consensus and
appear with different values across [profiles](#profiles-dev-devnet-mainnet-lightnet).

*Source: [`src/lib/node_config/profiled/`](../src/lib/node_config/profiled/),
[`src/lib/consensus/`](../src/lib/consensus/).*

---

<!-- canonical: snark_work -->

## Snark work

A unit of off-chain proof generation: producing the SNARK proofs needed to
fill in pending statements in the [scan state](#scan-state). Snark workers
ask the daemon for work, compute the proofs, and return
[completed work](#completed-work) bundles back to the SNARK pool.

A block producer must include enough completed work in its block to keep
the scan state from falling behind, paying out the workers' fees from the
coinbase. "Snark work" and "completed work" are often used interchangeably;
when a distinction is drawn, "snark work" is the *job specification* and
"completed work" is the *result*.

*Source: [`src/lib/snark_work_lib/`](../src/lib/snark_work_lib/),
[`src/lib/snark_worker/`](../src/lib/snark_worker/).*

---

<!-- canonical: snarked_ledger -->

## Snarked ledger

A ledger state for which a [ledger proof](#ledger-proof) has been produced.
Every transaction that produced this state has been certified by a SNARK.
Contrast with [staged ledger](#staged-ledger), which contains transactions
that have *not yet* been proven.

The snarked ledger advances each time a [scan-state](#scan-state) tree
finishes proving its transactions.

*Source: [`src/lib/staged_ledger/README.md`](../src/lib/staged_ledger/README.md),
[`src/lib/mina_ledger/README.md`](../src/lib/mina_ledger/README.md).*

---

<!-- canonical: staged_ledger -->

## Staged ledger

The pipeline data structure that holds a ledger plus pending unproven work.
A staged ledger is a triple of:

1. A [ledger](../src/lib/mina_ledger/) (an account-state Merkle tree).
2. A [scan state](#scan-state) tracking which transactions still need proofs.
3. A pending-coinbase collection (block rewards waiting on their SNARK).

Applying a block to the parent staged ledger produces the child staged
ledger: the block's transactions advance the ledger, the block's
[completed work](#completed-work) fills in scan-state proofs, and any
emitted [ledger proof](#ledger-proof) advances the [snarked ledger](#snarked-ledger).

*Source: [`src/lib/staged_ledger/README.md`](../src/lib/staged_ledger/README.md)
(canonical and well-maintained — model for other library READMEs).*

---

<!-- canonical: transition_frontier -->
<!-- canonical: full_frontier -->
<!-- canonical: persistent_frontier -->

## Transition frontier (full vs persistent)

The set of recent blocks the daemon keeps live, organized as a rose tree
rooted at the most recent finalized block; paths from the root are at most
[`k`](#slot-epoch-k) long. The frontier has two synchronized
representations:

- **Full frontier** — the in-memory representation. Each node is a
  [breadcrumb](#block-transition-breadcrumb), so the full frontier holds
  every node's [staged ledger](#staged-ledger) (and thus its
  [scan state](#scan-state) and [ledger masks](#ledger-mask)).
- **Persistent frontier** — the on-disk RocksDB representation, updated
  asynchronously from the full frontier via a diff buffer. It stores
  *blocks* only, not breadcrumbs; on daemon restart the full frontier is
  reconstructed from this on-disk state.

The transition frontier is also where [snark work](#snark-work) is
discovered (via the scan state) and where the [snarked ledger](#snarked-ledger)
is advanced as proofs land.

*Source: [`src/lib/transition_frontier/README.md`](../src/lib/transition_frontier/README.md).*

---

<!-- canonical: vrf -->

## VRF

Verifiable Random Function. In Mina's Ouroboros Samasika consensus, the VRF
is what each potential block producer evaluates per [slot](#slot-epoch-k)
to determine whether they have the right to produce a block, weighted by
their stake in the staking-ledger snapshot for the current
[epoch](#slot-epoch-k). The VRF output is verifiable by other nodes from
the producer's public key.

*Source: [`src/lib/consensus/`](../src/lib/consensus/).*

---

<!-- canonical: work_statement -->

## Work statement

The input/output specification of a single SNARK proof job in the
[scan state](#scan-state) — i.e., "this proof must show that applying
transaction(s) X to ledger state A yields ledger state B." A snark worker
fetches an unproven work statement, generates the corresponding proof, and
returns it as part of a [completed-work](#completed-work) bundle.

*Source: [`src/lib/transaction_snark_scan_state/`](../src/lib/transaction_snark_scan_state/),
[`src/lib/staged_ledger/README.md`](../src/lib/staged_ledger/README.md).*
