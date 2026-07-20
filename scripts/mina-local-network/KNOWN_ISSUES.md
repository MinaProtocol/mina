# Known issues — mina-local-network (mln)

Deliberate limitations and non-obvious invariants of the `mln` tool itself:
behaviors that are correct-by-choice, not bugs, but that will surprise a user or
a log reader who hits them. Each entry records the symptom, the cause with a
current file reference, and why it is the way it is — so the next person can tell
a design decision from a defect without re-deriving it.

Issues that belong to a *consumer* of mln (e.g. the hardfork test harness, its CI
job, or the mina daemon under load) live with that software instead — see
`src/app/hardfork_test/KNOWN_ISSUES.md`.

## Teardown signals the whole process group, so daemons log a fatal crash on shutdown

Every daemon mln tears down — on success as well as failure — logs a fatal-looking
crash report as it exits:

```
[Fatal] libp2p_helper process died unexpectedly: "died after receiving sigterm (signal number 15)"
[Error] verifier terminated unexpectedly; the verifier process will be restarted automatically
[Fatal] Unhandled top-level exception: $exn
  exn: [ "monitor.ml.Error", ... "Mina_net2__Libp2p_helper.Libp2p_helper_died_unexpectedly" ...
```

This is normal shutdown, not a crash. The helper's own message is the tell: it
received SIGTERM *directly*, rather than being torn down by its parent daemon.

Cause: each process is spawned with `start_new_session=True`
(`mln/process.py:71`), so the daemon is a session leader whose process group
contains its own children — `libp2p_helper`, the verifier, the prover. Teardown
then signals the whole group with `os.killpg` (the group-kill helper at
`mln/process.py:97`, called from `teardown_process` at `mln/process.py:106`). The
helper therefore dies at the same instant as the daemon, and the daemon — which
cannot know a shutdown is in progress — correctly reports its helper vanishing as
a fatal condition.

A fix belongs in the spawner: signal `proc.pid` alone, give the daemon time to
stop its own children, and only then escalate to `killpg(SIGTERM)` and
`killpg(SIGKILL)` for stragglers. Two things make this more than a one-line
change, which is why it is documented rather than done:

- Group signalling is what currently guarantees no orphaned helpers or snark
  workers survive the run. Signalling only the daemon trades that guarantee for
  the daemon's own cleanup being correct and prompt.
- The teardown timeout is 3 seconds (`mln/spawn/main.py:448`), which is already
  aggressive for a daemon that has to flush RocksDB; a daemon-first teardown
  would need a longer, separately-chosen budget.

Both need a real network to validate, so this should be its own change with its
own CI run.

## `patch topology` never regenerates `daemon.json` or `genesis_ledger.json`

`patch topology` replans an already-materialized state root in place, reusing the
existing key material. It **deliberately does not** regenerate `daemon.json` or
`genesis_ledger.json` (`mln/cli.py`, `do_patch_topology` — see its docstring at
`mln/cli.py:283`). Only key material is verified; everything ledger- or
daemon-config-affecting in the patched plan lives in the plan JSON and never
reaches a daemon.

The consequence is a silent no-op trap: patching a value that flows through those
files — account balances, `proof.level`, genesis timestamp, `slot_tx_end`, and so
on — leaves the on-disk config describing the *pre-patch* network, and the daemon
loads that. The patched value is real in `plan.json` and inert everywhere else.

This is intentional: regenerating the ledger would rewrite keys and defeat the
whole point of `patch` (replanning without disturbing a materialized network).
Callers that change ledger-affecting config are responsible for regenerating
those files themselves. The daemon is the only party that knows which config it
actually loaded, which is why `mln.graphql.daemon_genesis_timestamp`
(`mln/graphql.py:242`) reads the genesis back from the daemon rather than trusting
any file mln may or may not have written. Anything that makes `patch`
re-materialize `daemon.json` silently changes this contract — treat it as
load-bearing.

## `--block-producer-key` is deprecated, but the replacement is not a drop-in

Every block producer mln spawns logs:

```
[Warn] `block-producer-key` is deprecated. Please set `MINA_BP_PRIVKEY` environment variable instead.
```

The spawner passes the flag at `mln/topology.py:496`. Switching is not the
mechanical swap the warning implies, because the two carry *different forms of the
key*:

- `--block-producer-key` takes a path to an **encrypted private key file**, read
  via `Secrets.Keypair.Terminal_stdin.read_exn` with the password from
  `MINA_PRIVKEY_PASS`.
- `MINA_BP_PRIVKEY` takes a **raw base58-encoded private key**, passed straight to
  `Private_key.of_base58_check_exn`.

So the spawner would have to decrypt each keypair file itself and place the raw
private key into a child's environment, where it is readable via
`/proc/<pid>/environ`. That is a meaningful change in both implementation and
exposure for the sake of silencing a warning, and it is not obviously an
improvement for a throwaway local network. Left as-is deliberately.

## ITN max-cost workloads require openssl ≥ 1.1.1 (Ed25519)

An `itn_max_cost` workload that is not `start='manual'` needs mln to generate an
Ed25519 auth key via `openssl genpkey -algorithm ed25519`. If that command fails
(older openssl, or none on PATH) mln raises `ED25519_UNSUPPORTED` at spawn
(`mln/spawn/itn.py:101`) rather than degrading silently. Install openssl ≥ 1.1.1,
or set the workload to `start='manual'` and inject the key yourself. Networks
without ITN workloads are unaffected.

## An unpinned v2 (constraint) topology samples a fresh layout every run

Lowering a v2 topology (`plan lower`, or any spawn that resolves one) runs the
sampler, and placement is **random unless `requirements.seed` is pinned**. So the
same v2 file lowers to a different concrete node set — count, names, and which
capabilities share a node — on each run. This is by design: it is how the CI
presets exercise layout diversity.

The trap is for a consumer that must lower a topology and then act on *that same*
layout more than once: it must lower **once** and reuse the result, never re-lower
and assume agreement. The hardfork harness does exactly this — it lowers a preset
a single time and renders both the main and fork networks from that one concrete
layout, so they always agree without pinning a seed. A consumer that re-lowers
between steps will silently get two different networks.
