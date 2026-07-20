# Known issues

Things visible in a hardfork test run that are **not** test failures, and that
are deliberately not fixed in the test harness. Each entry records what the
symptom looks like in the log, what actually causes it, and why it was left
alone — so the next person to read a CI log can tell known noise from a new
problem without re-deriving any of it.

Some noise seen in these runs originates in the network launcher (mln), not this
harness — those entries here are short pointers into
`scripts/mina-local-network/KNOWN_ISSUES.md`, where the cause and the reason it is
left alone live with the software that owns them.

The symptom observations below (log excerpts, counts) come from the `hard fork
test - mixed mode` job in `mina-single-job` build 224; file references are kept
current with the code.

## Daemons log a fatal crash on every teardown

Every shutdown — of both the main and the fork network, on success as well as
failure — produces this from each daemon:

```
[Fatal] libp2p_helper process died unexpectedly: "died after receiving sigterm (signal number 15)"
[Error] verifier terminated unexpectedly; the verifier process will be restarted automatically
[Fatal] Unhandled top-level exception: $exn
Generating crash report
  exn: { "sexp": [ "monitor.ml.Error", [ "exn.ml.Reraised", "Mina_net2 raised an exception",
         [ "monitor.ml.Error", [ "Mina_net2__Libp2p_helper.Libp2p_helper_died_unexpectedly" ], ...
```

This is normal shutdown, not a crash: the daemon's `libp2p_helper` receives
SIGTERM at the same instant the daemon does, because mln tears the whole process
group down at once. The cause and the reason it is left as-is belong to the
spawner, not this harness — see **"Teardown signals the whole process group"** in
`scripts/mina-local-network/KNOWN_ISSUES.md`.

## Block production runs late under load

A single run shows 14 × `1 slots too late`, 20 × block rejections for reason
`"invalid time"` (32 of 34 in the main phase), 4 × `validation callback timed
out` / `libp2p_helper: validation timed out :(`, and:

```
[Error] Error when increasing coinbase: $error
  "Could not increment coinbase transaction count because of insufficient work"
```

The chain still advances and the test's assertions still pass, so this is
cosmetic today. It reflects the environment rather than a defect: `proof_level:
full` with 30-second slots on a shared CI agent means block production
occasionally misses its slot and snark work does not always keep up. Worth
remembering as the most likely source of future flake on a slower agent — if
this test starts failing intermittently for timing reasons, start here.

## `--block-producer-key` is deprecated

Each block producer logs, on both the pre-fork and post-fork binaries:

```
[Warn] `block-producer-key` is deprecated. Please set `MINA_BP_PRIVKEY` environment variable instead.
```

Benign. mln passes the deprecated flag deliberately — the replacement
`MINA_BP_PRIVKEY` is not a drop-in (encrypted key file vs. raw base58 key, plus a
`/proc/<pid>/environ` exposure tradeoff). Full reasoning is a spawner concern —
see **"`--block-producer-key` is deprecated"** in
`scripts/mina-local-network/KNOWN_ISSUES.md`.

## The fork plan carries `slot_tx_end` / `slot_chain_end` that mean nothing

`baseOverlay` (`src/app/hardfork_test/src/internal/hardfork/network.go`) stamps
`slot_tx_end`, `slot_chain_end` and `hard_fork_genesis_slot_delta` into *both*
networks' plans, so the fork plan contains e.g. `slot_tx_end: 98` while the fork
chain starts at global slot 136 — a slot at which that setting, if honoured,
would reject every post-fork transaction with `After_slot_tx_end` and make the
phase-4 "blocks contain user commands" assertion unsatisfiable.

It is inert only because of a chain of two facts:

1. Phase 3 strips the `daemon` section out of `daemon.json` ("Removed .daemon
   from daemon.json").
2. `patch topology` deliberately never regenerates `daemon.json` — see
   **"`patch topology` never regenerates `daemon.json`"** in
   `scripts/mina-local-network/KNOWN_ISSUES.md`.

So the value lives in the plan JSON and never reaches a daemon. This works, but
it rests on that mln invariant: anything that makes `patch` re-materialize
`daemon.json` silently breaks the fork network's transaction flow. The clean fix
is on this side — stop setting these in the fork overlay (`baseOverlay` in
`src/app/hardfork_test/src/internal/hardfork/network.go`) rather than relying on
the mln behavior to neutralize them.

## Disk artifacts

`scripts/hardfork/build-and-test.sh` now removes its network root on every exit
path (`HARDFORK_KEEP_NETWORK_ROOT=1` retains it for local debugging), and the
test removes its own temp topology files. Some artifacts are still left behind
by design or by omission:

- **Nix out-links** — `prefork-devnet`, `postfork-devnet` and `hardfork_test`
  are created with `nix build --out-link` in the repo toplevel
  (`build-and-test.sh:170,175,195`). These are **GC roots**: they pin three
  full mina builds in the nix store against `nix-collect-garbage` for as long as
  the symlinks exist. Buildkite's `git clean -ffxdq` removes them at the start
  of the *next* build on that agent, so they persist between builds. If agent
  disk is the concern, this is a far larger footprint than anything the test
  writes, and it is the first place to look.
- **`/tmp/nix-cache-secret`** — `build-and-test.sh:78` writes
  `$NIX_CACHE_NAR_SECRET` to a world-readable path and never removes it.
- **`/tmp/nix-paths`** — appended to (`>>`) by the post-build hook on every run
  (`build-and-test.sh:92`), never truncated.

These were left alone because they belong to the nix build plumbing rather than
the test, and because the CI job runs in a `--rm` container, which makes the
blast radius of each depend on agent configuration this repo does not describe.

A caveat on all of the above, recorded so nobody mistakes it for a measured
result: the CI job runs via `Cmd.runInDocker` with `--rm` and mounts only
`/var/storagebox`, `/var/secrets`, `/shared` and the checkout at `/workdir`
(`buildkite/src/Lib/Cmds.dhall:81`). The network root is created under the
container's own `/tmp`, which that `--rm` should already reclaim on exit. So
removing the root bounds peak disk *during* a run and fixes non-container and
local runs outright, but it has not been shown to be what fills a shared agent
disk. The out-links, which persist in `/workdir` on the agent between builds,
are the better suspect. Confirming that needs knowledge of the agents' docker
data-root and `/var/storagebox` layout, which lives outside this repo.

## Benign noise

Seen every run; none indicate a problem.

| Message | Why |
| --- | --- |
| `GCLOUD_KEYFILE environment variable not set` (×6) | Block upload to GCS is not configured for local networks. |
| `Environment variable "MINA_TIME_OFFSET" not found, using default of 0` (×6) | No time offset is wanted. |
| `Could not read configuration from $config_file: <node>/daemon.json` (×3) | The daemon probes its config *directory* for a `daemon.json`; the real config arrives via `--config-file`. |
| `Need S3 hash specified in runtime config to verify download for "genesis_ledger"` (×3) | The ledger is local; there is nothing to download or verify. |
| `Could not send error report: Node_error_service was not configured` | No error-reporting service for a local network. |
| `libp2p_helper: failed to routing advertise: failed to find any peer in table`, `starting libp2p up failed` | The seed is the first node up and has no peers yet; it resolves once others join. |
| `Different version of Mina detected in config directory, removing existing configuration` (×2) | Expected: the fork network reuses the main network's config directories with a different binary. |
| `Node started before genesis: waiting N milliseconds` | Both networks are started ahead of their genesis timestamp by design. |
