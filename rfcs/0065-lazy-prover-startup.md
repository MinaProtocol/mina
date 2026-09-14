## Summary
[summary]: #summary

The Mina daemon starts a *prover subprocess* (a separate operating system process that builds
blockchain SNARK proofs) every time it starts, even on nodes that never produce a block. The prover
subprocess uses approximately 1.43 GB of resident memory and approximately 10 minutes of multi-core
CPU time at start. This RFC proposes to remove the prover from the start sequence and to start it
only when a proof is first requested. It also proposes to start the *VRF evaluator* (the subprocess
that evaluates the Verifiable Random Function to find won slots) only when block production keys are
configured.

The change has one hard precondition: the verifier subprocess currently takes its verification keys
from the prover. This RFC describes how to remove that dependency, and it treats the memory saving
as a value to measure, not a value to assume.

## Motivation
[motivation]: #motivation

Most Mina daemons on the network do not produce blocks. Seed nodes, archive nodes, block feeders,
RPC nodes and Rosetta nodes only follow the chain. These nodes pay the full cost of the prover
subprocess and get no benefit from it.

The following table gives the resident set size (RSS, the physical memory a process holds) measured
on 2026-08-17 for a keyless `mina daemon --seed`, mainnet image, release 3.5.0, commit `fe759fe99`.

| Process | RSS |
| --- | --- |
| prover worker | 1.43 GB |
| daemon (steady state) | 636 MB (peak 1.8 GB) |
| verifier worker | 0.6–0.8 GB |
| VRF evaluator | 122 MB |
| libp2p helper | 125 MB |
| **Total** | **≈ 2.9 GB** |

On such a node the prover and the VRF evaluator together hold approximately 1.55 GB. That is more
than 50 % of the footprint of a fresh node, and it does no work.

The start cost is also large. `Prover.create` calls `Pickles.Cache_handle.generate_or_load` on the
blockchain SNARK cache handle (`src/lib/prover/prover.ml:117-119`). On a node without a warm proving
key cache this step needs approximately 10 minutes of multi-core CPU. Until it completes, the
verifier cannot start, so the node cannot validate any block. Operators see this as a long period
in which GraphQL does not answer.

The expected outcome is:

* approximately 1.5 GB less RSS on every passive node;
* a shorter time from process start to a serving node;
* no change of behaviour for block producers.

This RFC continues the direction of [RFC 0063](0063-reducing-daemon-memory-usage.md), which moved
proofs and verification keys out of RAM and onto disk. RFC 0063 reduced the *variable* part of the
footprint. This RFC reduces the *baseline* part, which RFC 0063 lists as approximately 3.06 GB and
does not address.

## Detailed design
[detailed-design]: #detailed-design

### Current start sequence

In `src/lib/mina_lib/mina_lib.ml` the start sequence is:

1. `Prover.create` inside the `manage_prover_subprocess` thread (line 1818-1829). This call is
   **unconditional**. It does not look at `config.block_production_keypairs`.
2. `set_itn_data (module Prover) prover` (line 1828).
3. `Prover.get_blockchain_verification_key prover` and `Prover.get_transaction_verification_key
   prover` inside the `manage_verifier_subprocess` thread (lines 1845 and 1849).
4. `Verifier.create` with those two keys (line 1853).
5. `Internal_tracing.register_toggle_callback` for the prover (line 1877).
6. `Vrf_evaluator.create` with `~keypairs:config.block_production_keypairs` (line 1894-1897). This
   call is also unconditional, and it passes an empty set on a keyless node.

Block production itself is already gated. `Block_producer.run` is called only when
`block_production_keypairs` is not empty (`mina_lib.ml:1430-1441`). All real proving is reachable
only through that call: `Prover.create_genesis_block` at `block_producer.ml:669` and `Prover.prove`
at `block_producer.ml:864`. Therefore the prover on a passive node is idle for its whole life.

The prover has exactly three other consumers:

* the two verification key fetches at daemon start (step 3 above);
* the GraphQL field `blockchainVerificationKey`
  (`src/lib/graphql/mina_graphql/mina_graphql.ml:2733`);
* the internal-tracing toggle and the ITN logger data hookup.

### Step 1 — take the verification keys from a source other than the prover

This is the precondition. It must be merged and measured before step 2.

The prover worker's key accessors do no proving work. In `src/lib/prover/prover.ml` they are:

```ocaml
let get_blockchain_verification_key () = Lazy.force B.Proof.verification_key

let get_transaction_verification_key () = Lazy.force T.verification_key
```

The daemon already contains a function that produces the same two values without any subprocess.
`Verifier.get_verification_keys_eagerly` (`src/lib/verifier/verifier.ml:22-41`, exported at
`src/lib/verifier/verifier.mli:11`) applies the same two functors and forces the same two lazy
values. `Verifier.For_tests.default` already uses it, and
`src/app/cli/src/init/test_submit_to_archive.ml:624-639` builds a working verifier from it.

The change in `mina_lib.ml` is therefore small: replace the two `Prover.get_*_verification_key`
calls with one call to `Verifier.get_verification_keys_eagerly ~signature_kind
~constraint_constants ~proof_level`.

**Corner case — proof level.** The two sources are not equal for all proof levels. The prover
returns `Lazy.force Pickles.Verification_key.dummy` when the proof level is `Check` or `No_check`
(`prover.ml:224-230` and `prover.ml:249-255`). `Verifier.get_verification_keys_eagerly` always
computes the real keys. A direct swap would make a `dev` or `lightnet` daemon compile the full
circuits, which is a large regression. The replacement must keep the per-proof-level behaviour:
return the dummy key for `Check` and `No_check`, and compute the real key only for `Full`.

**Corner case — cost of the functor application.** `Blockchain_snark_state.Make` calls
`Pickles.compile ()` at functor application time (`blockchain_snark_state.ml:493-501`), not inside a
lazy value. Compiling the constraint system is the expensive part. Forcing
`B.Proof.verification_key` then also forces `Cache.Wrap.read_or_generate`
(`src/lib/crypto/pickles/pickles.ml:762-770`), which reads or generates the *wrap* keys. It does
**not** force `Pickles.Cache_handle.generate_or_load`, which holds the much larger *step* proving
keys and which only the prover calls.

The consequence is important and is the main risk of this RFC: calling
`get_verification_keys_eagerly` in the daemon process moves circuit compilation **into the daemon
process**, where the resulting modules stay reachable for the life of the process. Without
measurement we cannot claim a saving; we could move memory from the prover process into the daemon
process and gain nothing. See [Impact analysis](#impact-analysis) for the measurement that decides
this.

If the measurement is bad, step 1 has two fallbacks, described in
[Rationale and alternatives](#rationale-and-alternatives): a build-time baked verification key, or a
short-lived prover that is killed after the keys are read.

### Step 2 — start the prover on first demand

Replace the `Prover.t` field of the process record with a value that starts the subprocess on first
use:

```ocaml
(* src/lib/mina_lib/mina_lib.ml, processes record, line 54 *)
type processes =
  { prover : Prover.t Deferred.t Lazy.t
  ; ...
  }
```

`Lazy.t` gives "at most once" semantics, and `Deferred.t` lets every later caller wait for the same
start. Concurrent callers therefore share one subprocess; there is no race that could start two
provers.

Call sites change as follows:

* `Block_producer.run` (`mina_lib.ml:1441`) — it is already inside the keypair guard. It receives
  the lazy value and forces it. Because `Block_producer.run` is called during
  `start`, the prover starts at the same point in time as today for a block producer, so a producer
  sees no regression.
* GraphQL `blockchainVerificationKey` (`mina_graphql.ml:2733`) — this field must **not** force the
  prover. It must read the same value the verifier was built from. This removes the last accidental
  reason for a passive node to start a prover.
* `Internal_tracing.register_toggle_callback` (`mina_lib.ml:1877`) and `set_itn_data`
  (`mina_lib.ml:1828`) — these must apply to the prover only if it is already started. If the lazy
  value is not yet forced, the callback does nothing, and the current tracing state is applied when
  the prover later starts. Toggling tracing must never start a prover.

**Corner case — proof level `Check` and `No_check`.** In these levels `Prover.create` is
`Deferred.return` of a module with no cost. Laziness is harmless but also pointless. Behaviour is
unchanged.

**Corner case — late keys.** In the current tree `block_production_keypairs` is set once, in
`Mina_lib.Config.t` (`src/lib/mina_lib/config.ml:25`), and there is no GraphQL mutation that adds a
block production key at run time. Laziness is still the preferred design over a `--no-prover` flag,
because it derives the behaviour from real use and stays correct if such a mutation is added later.

**Corner case — first block after a long wait.** If the prover starts only when the node first wins
a slot, the node would need approximately 10 minutes of proving key loading inside the slot, and it
would miss the block. This is why `Block_producer.run` forces the lazy value at start-up, not at the
first won slot. Laziness gates on *"is this node a producer"*, not on *"has this node won a slot"*.

### Step 3 — gate the VRF evaluator

`Vrf_evaluator.create` (`mina_lib.ml:1894-1897`) receives `config.block_production_keypairs` and is
called even when that set is empty. Wrap it in the same emptiness test that already guards
`Block_producer.run`, and make the field an option. This is independent of steps 1 and 2 and can be
merged first. It saves 122 MB and carries almost no risk.

### Summary of the code change

| File | Change |
| --- | --- |
| `src/lib/mina_lib/mina_lib.ml` | verifier keys from `Verifier`, prover field becomes lazy, VRF evaluator gated |
| `src/lib/verifier/verifier.ml` / `.mli` | `get_verification_keys_eagerly` returns dummy keys for `Check` / `No_check` |
| `src/lib/graphql/mina_graphql/mina_graphql.ml` | `blockchainVerificationKey` reads the stored key, does not force the prover |
| `src/lib/block_producer/block_producer.ml` | accepts the lazy prover and forces it in `run` |

## Impact analysis
[impact-analysis]: #impact-analysis

### Memory

Target for a keyless `daemon --seed`, mainnet, proof level `Full`:

| | today | after step 3 | after steps 1-3 |
| --- | --- | --- | --- |
| prover worker | 1.43 GB | 1.43 GB | 0 |
| VRF evaluator | 122 MB | 0 | 0 |
| daemon | 636 MB | 636 MB | to be measured |
| verifier worker | 0.6–0.8 GB | 0.6–0.8 GB | 0.6–0.8 GB |
| libp2p helper | 125 MB | 125 MB | 125 MB |
| **total** | **≈ 2.9 GB** | **≈ 2.8 GB** | **target ≈ 1.4 GB** |

The "to be measured" cell is the whole risk of this RFC. It must be filled with a real measurement
before steps 1 and 2 are merged. Acceptance rule: the change is accepted only if the total RSS of
all processes of a keyless node falls by at least 1 GB. If the daemon process grows by nearly the
amount the prover process loses, the design must move to one of the alternatives below.

### Start time

The prover start step disappears from the critical path of a passive node. The expected saving is
approximately 10 minutes of multi-core CPU on a node without a warm proving key cache, and the time
from process start to a responding GraphQL endpoint falls by the same amount. A block producer sees
no change, because it still starts the prover during `start`.

### Node roles

| Role | Effect |
| --- | --- |
| block producer | none; prover starts at the same point as today |
| snark worker | none; the snark worker uses its own `Transaction_snark` instance (`src/lib/snark_worker/prod.ml:32`), not the prover |
| seed / archive / block feeder / RPC | ≈ 1.5 GB less RSS, ≈ 10 minutes faster start |
| Rosetta | as above; Rosetta runs a passive daemon |
| integration tests (`test_executive`) | none expected; the tests use proof level `Full` block producers |

### Consensus and protocol

None. No proof, no verification key, no serialized type and no wire format changes. The change is
limited to *when* a subprocess starts. The verification keys used by the verifier are the same
values as today; only their source changes. This is verifiable, see the test plan.

### Operational

* Process trees change. Monitoring, alerting and `pidof`-style scripts that assume a prover process
  is always present will need an update. This must be in the release notes.
* Prometheus process metrics for the prover will be absent on passive nodes.
* A block producer that is misconfigured (no keys) previously still held a prover. After this change
  it will not. The failure mode does not change, but the memory profile does.

## Test plan
[test-plan]: #test-plan

### 1. Verification key equality (unit, blocking)

The strongest possible guard. The keys the verifier receives must not change.

* A new unit test asserts that `Verifier.get_verification_keys_eagerly` returns exactly the keys
  that `Prover.get_blockchain_verification_key` and `Prover.get_transaction_verification_key`
  return, for the same `signature_kind`, `constraint_constants` and `proof_level`, for each of
  `Full`, `Check` and `No_check`.
* The repository already contains committed reference keys per profile:
  `src/lib/blockchain_snark/tests/print_blockchain_snark_vk/{dev,devnet,mainnet}_blockchain_snark_vk.json`
  and the matching files under `src/lib/transaction_snark/test/print_transaction_snark_vk/`. Their
  `dune` rules already diff a computed key against the committed key under the `runtest` alias.
  Extend that comparison to the key the daemon actually passes to `Verifier.create`.

### 2. Laziness (unit)

* Assert that building a `Mina_lib.t` with an empty `block_production_keypairs` set never forces the
  prover lazy value.
* Assert that a GraphQL `blockchainVerificationKey` query does not force it either.
* Assert that toggling internal tracing does not force it.
* Assert that `Block_producer.run` does force it, exactly once, and that two concurrent forces
  produce one subprocess.

### 3. VRF evaluator gating (unit)

* Assert `vrf_evaluator` is `None` for an empty keypair set and `Some` otherwise.

### 4. Memory and start-time measurement (manual, blocking)

Run the same measurement that produced the table in [Motivation](#motivation), before and after, on
the same machine and the same image:

* keyless `mina daemon --seed`, mainnet config, proof level `Full`, cold proving key cache;
* the same, with a warm cache at `/tmp/coda_cache_dir`;
* a block producer with one key.

Record for each process: RSS at start, RSS at peak, RSS at steady state after the node reaches
`Synced`, and wall-clock time from process start to the first successful GraphQL query. The
acceptance rule from [Impact analysis](#impact-analysis) applies.

### 5. Integration tests (CI)

* `block_production_priority`, `block_reward_test` and `slot_end_test` prove that a producer still
  produces. These exercise the forced path.
* `medium_bootstrap`, `peers_reliability_test` and `chain_reliability_test` prove that a passive
  node still bootstraps and validates blocks with a verifier that was built without a prover.
* `zkapps`, `zkapps_timing`, `zkapps_nonce_test` and `verification_key_update` prove that zkApp
  proof verification is unaffected. These are the tests most sensitive to a wrong verification key.
* `post_hard_fork` proves that the fork path still works, which matters because a fork uses a
  runtime configuration that can override constraint constants.

### 6. Runtime configuration override (targeted)

`Runtime_config.Proof` can override `ledger_depth`, `work_delay`, `sub_windows_per_window` and the
proof level (`src/lib/runtime_config/runtime_config.ml:430-432`). Any of these changes the
constraint system, and therefore the verification key. Start a daemon with a configuration file that
overrides `ledger_depth`, and assert that the verifier still receives a key that matches the running
constraint constants. This test is mandatory for the baked-key alternative and is a useful guard for
the in-process alternative.

### 7. Soak

Run a passive node for 24 hours and confirm that the prover is never started, that RSS is stable,
and that no block is rejected.

## Drawbacks
[drawbacks]: #drawbacks

* **The saving is not proven.** Circuit compilation moves from the prover process into the daemon
  process. Until step 1 is measured, the net saving could be much smaller than 1.43 GB. This is the
  reason the RFC makes the measurement a merge gate.
* **A new failure point at a late time.** Today a prover that fails to start fails the daemon at
  start, which is loud. With laziness, a producer that fails to start its prover fails later. The
  design reduces this by forcing the lazy value inside `Block_producer.run` at start-up, but the
  failure is still one step further from the process start.
* **More states to reason about.** `prover` becomes a three-state value: not started, starting,
  started. Internal tracing, ITN data and metrics must all handle the "not started" state.
* **Process trees change.** Operator tooling that assumes a fixed process list will need an update.
* **The `Check` and `No_check` behaviour must be preserved by hand.** The dummy-key behaviour lives
  in the prover today. Moving it creates a chance to lose it silently, which is why test 1 covers
  all three proof levels.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

**Why laziness and not a `--no-prover` flag.** A flag makes the operator responsible for a decision
the daemon can make from facts it already holds. A wrong flag on a block producer is a silent
missed-block fault. There is no `--no-prover`, `MINA_PROVER` or `dummy_prover` in the tree today,
and this RFC recommends that none is added. Laziness derives the behaviour from real use and stays
correct if a run-time key injection mutation is added later.

**Alternative A — bake the verification key at build time.** The repository already generates and
commits per-profile verification keys (`{dev,devnet,mainnet}_blockchain_snark_vk.json` and the
transaction equivalents), and `Pickles.Verification_key` derives `of_yojson`
(`src/lib/crypto/pickles/verification_key.mli:22`). The daemon could load the key for its profile
and never compile a circuit. This gives the largest saving and the fastest start.
Its cost is the runtime configuration corner case: if the configuration overrides `ledger_depth`,
`work_delay`, `sub_windows_per_window` or the proof level, the baked key is wrong. The mitigation is
to compare the effective constraint constants against the compiled constants and fall back to
computing the key when they differ. This alternative is the recommended fallback if the step 1
measurement is bad, and it may be worth doing directly.

**Alternative B — a short-lived prover.** Start the prover, read the two keys, then kill it. This
keeps one source of truth and needs almost no new code. It saves the steady-state 1.43 GB but keeps
the approximately 10 minute start cost, so it fixes memory and not start time. It is the safest
fallback.

**Alternative C — do nothing.** Passive operators keep paying for approximately 1.5 GB and
approximately 10 minutes that give them nothing. Since most of the network is passive, this is a
large aggregate cost and a barrier to running an archive or Rosetta node on a small machine.

**Out of scope, but related.** The daemon, the prover and the verifier each compile Pickles circuits
in their own process, so the same compilation can run up to three times per node. Sharing that work
is a larger change and belongs in its own RFC. This RFC only removes one of the three on passive
nodes.

## Prior art
[prior-art]: #prior-art

* [RFC 0063](0063-reducing-daemon-memory-usage.md) reduced the variable memory of the daemon by
  moving proofs and verification keys to an LMDB on-disk cache. It measured a baseline of
  approximately 3.06 GB and did not address it. This RFC addresses part of that baseline.
* `src/app/cli/src/init/test_submit_to_archive.ml` has built a verifier without a prover subprocess
  for a long time. It is the working proof that the dependency is removable.
* `Verifier.For_tests.default` already uses `get_verification_keys_eagerly`, so the code path is
  exercised today, although only in tests.
* The `print_blockchain_snark_vk` and `print_transaction_snark_vk` executables, with their committed
  per-profile JSON files and `runtest` diff rules, are working prior art for build-time baked
  verification keys (alternative A).
* Lazy subprocess start is a common pattern in the daemon already: the snark worker is started from
  an `Option` on the configured key (`mina_lib.ml:1900-1908`), and the uptime snark worker is
  likewise optional.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

* **How much memory does in-process verification key computation cost the daemon?** This must be
  measured before steps 1 and 2 are merged. It decides between the in-process design and
  alternatives A and B. It is the single blocking question of this RFC.
* Does forcing the wrap key through `Cache.Wrap.read_or_generate` have a meaningful cost on a node
  with a cold `Cache_dir` cache, or is the cost fully in the step keys behind `Cache_handle`?
* Should alternative A (baked keys) be adopted directly instead of the in-process computation, given
  that the reference key files and their tests already exist?
* Should `blockchainVerificationKey` in GraphQL keep its current semantics, or should it be
  documented as "the key this node validates with" rather than "the key this node's prover holds"?
  The two are equal today, and this RFC keeps them equal, but the wording matters for API
  consumers.
* Is a metric or a log line needed to tell an operator that the prover has not been started, so that
  a misconfigured producer is still noticed?
* Should the same treatment be applied to the verifier on nodes that never validate — for example a
  pure archive node fed from a trusted source? This RFC does not propose it, because all following
  nodes validate blocks, but it is the natural next question.
