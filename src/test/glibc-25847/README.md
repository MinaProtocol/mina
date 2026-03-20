# glibc #25847 Reproducer: Async TCP Connection Churn

A reproducer for [glibc bug #25847](https://sourceware.org/bugzilla/show_bug.cgi?id=25847),
which causes `pthread_cond_signal()` to silently fail to wake a waiting thread. This bug
caused a Mina daemon to permanently deadlock and remain unresponsive for 6+ days. The test
triggers the same deadlock through TCP connection churn that mimics the daemon's real
workload pattern.

## Quick Start

```bash
# At the project root
./src/test/glibc-25847/run.sh

# Or in this working directory
./run.sh
```

You can also build the binaries directly without running the test:

```bash
nix build                    # glibc 2.40 (affected)
nix build .#fixed            # glibc 2.42 (fixed)
ls ./result/bin/             # async_tcp_server, async_tcp_client
ldd ./result/bin/async_tcp_server | grep libc  # confirm glibc version
```

### Running with Fixed glibc

To confirm the glibc upgrade resolves the issue, run against glibc 2.42 (from
nixos-unstable, the first nixpkgs channel with the fix — nixpkgs skipped 2.41):

```bash
./run.sh --fixed                # glibc 2.42 (fixed)
./run.sh --fixed -n 10 -t 600  # longer run for confidence
```

Expected outcome: no instances deadlock. Compare with `./run.sh` (glibc 2.40), where
~1 in 5 instances typically deadlocks within the first 5 minutes.

### Options

| Flag | Default | Description |
|---|---|---|
| `--fixed` | off | Use the "fixed" nix shell (glibc 2.42) instead of default (glibc 2.40) |
| `-n`, `--instances` | 3 | Number of parallel test instances |
| `-t`, `--timeout` | 600 | Per-instance timeout in seconds |
| `--client-fibers` | 8 | TCP client fibers per client process |
| `--client-procs` | 1 | Client processes per server (more churn) |
| `--bg-fibers` | 0 | Extra background `In_thread.run` fibers |
| `--pause-on-deadlock` | off | Keep deadlocked server process alive for gdb attachment |

Example with custom settings:

```bash
./run.sh -n 10 -t 600
./run.sh -n 7 -t 1200 --pause-on-deadlock
```

### Interpreting Results

Each server prints a line per second:
```
alive: cycle=237 connections=451045(+1946/s ~7784 in_thread_ops/s) bg_in_thread=0(+0/s)
```

The `in_thread_ops/s` estimate is `conn_rate * 4` (the 4 server-side `In_thread` ops per
connection: 2x `fcntl_getfl` + `shutdown` + `close`).

- **Output stops**: The server has deadlocked. glibc #25847 triggered.
- **Output continues until timeout**: No deadlock in that instance.
- The script analyzes logs after all instances finish and reports which ones deadlocked
  (cycle number much lower than the timeout).

### Expected Results

On glibc 2.40 (provided by the nix flake): ~1 in 5 instances typically deadlocks within
the first 5 minutes at default settings. On glibc 2.41+: the bug is fixed and no instance
should deadlock.

### Tuning

There are two throughput metrics to consider when tuning the test:

- **Per-server condvar ops/s**: How many `In_thread` blocking section transitions each
  individual server performs per second. Higher means each server's condvar is exercised
  more intensely, which may increase the probability of triggering the race per server.
- **Aggregate condvar ops/s**: Total ops/s across all servers. More instances means more
  independent condvars being exercised in parallel — more rolls of the dice, even if each
  individual server is slower.

These are in tension: more instances compete for CPU, reducing per-server throughput. On an
8-core machine, rough numbers are:

| Config | Per-server ops/s | Aggregate ops/s |
|---|---|---|
| 1 server | ~18,000 | ~18,000 |
| 3 servers (default) | ~14,000 | ~42,000 |
| 7 servers | ~7,500 | ~52,500 |

The default of 3 instances balances these: each server still runs at ~80% of single-server
throughput while tripling the number of independent condvar targets.

The `--client-procs` option launches multiple client processes per server, which can
increase per-server connection rates slightly (separate processes avoid client-side Async
scheduler overhead). However, in the original incident the daemon had just one "client"
driving traffic — the verifier child process making ITN logging callbacks over TCP — so
`--client-procs 1` (the default) is the more realistic configuration.

## What the Test Does

The test consists of two binaries — a server (`async_tcp_server.ml`) and a client
(`async_tcp_client.ml`) — that run as separate processes. This matches the real daemon
incident, where the verifier child process opened TCP connections *to* the daemon.

The **server** runs a TCP echo handler: accept a connection, read one line, write it back,
close. It also runs a monitor loop that prints throughput every second. Each accepted
connection generates 4 `In_thread` operations on the server side (2x `fcntl_getfl` +
`shutdown` + `close`), each involving a blocking section transition (release master lock
condvar -> syscall -> reacquire master lock condvar).

The **client** runs 8 fibers (configurable via `--client-fibers`) that each repeatedly connect
to the server on localhost, send "ping", read the echo response, and disconnect as fast as
possible. It exists solely to drive connection churn.

`run.sh` launches a server for each instance, waits for it to print its listening port,
then launches a client connecting to that port. Only the server is monitored for deadlock
— it is the server's master lock condvar that deadlocks. Server logs go to
`logs/instance_N.log`, client logs to `logs/client_N.log`.

At ~2,000 connections/sec, the server's Async scheduler is simultaneously driving
`epoll_wait` cycles for TCP accept events, creating the mixed condvar signal pattern
(signal-inside-mutex from `Thread.yield`, signal-outside-mutex from blocking sections)
that triggers the glibc bug.

## Background: The Frozen Mina Daemon

### The Incident

In March 2026, a Mina daemon running in a Kubernetes pod
(`itn-standard-plain-2-5784c549b9-l8hr8`) was discovered to be completely unresponsive. The
pod was running image
`mina-daemon:3.3.0-martyall-martyall-inc-rxs-per-zkapp-develop-9f82ebf-bullseye-devnet`
(commit `9f82ebf`, branch `martyall/martyall/inc-rxs-per-zkapp-develop`) on Debian bullseye
(glibc 2.31) with OCaml 4.14.2. Investigation revealed:

- The daemon had been frozen for **over 6 days** without being restarted.
- The freeze occurred on **March 12 at ~19:29 UTC**, in a 34-second window between the
  last log line (19:28:49.694517, a successful SNARK verification) and the first failed
  health check (19:29:23).
- There was **no gradual degradation** — the daemon went from fully functional (processing
  blocks, verifying SNARKs) to completely silent in an instant.
- The Kubernetes liveness probe checked the libp2p port (10005), which `libp2p_helper`
  (a separate Go process) kept open independently. So k8s never restarted the pod. The
  readiness probe (checking GraphQL on port 3085) was failing — **3,581 consecutive
  failures over 6 days** — but readiness failures only remove a pod from service
  endpoints, they don't trigger a restart.

### Process State at Discovery

| PID | State | Description |
|---|---|---|
| 16 | tl (traced/stopped, sleeping) | **Mina daemon** — alive but frozen, 269h CPU time |
| 121, 146, 157, 162 | Z (zombie) | Prover, verifier, VRF evaluator, +1 — all exited cleanly (status 0) |
| 175 | Rl (running) | **libp2p_helper** — still alive, 628h CPU time |

The 4 child processes exited cleanly due to RPC heartbeat timeout (heartbeat send every
10s, timeout after 15 minutes). They are spawned with `shutdown_on:Connection_closed`,
so when the daemon stopped responding to heartbeats, they shut down intentionally. This
is by design — it prevents orphaned children from consuming resources after a parent
freeze.

`libp2p_helper` communicates via stdin/stdout pipes (not RPC heartbeats), so it stayed
alive as long as the daemon process existed. Its stdout pipe buffer was full (a Go thread
was blocked trying to write 7,976 bytes), and its stdin reader was blocked waiting for
commands from the daemon. It was a passive victim of the freeze, not a cause.

### GDB Analysis: The Deadlock

We attached `gdb` to the frozen daemon via a `kubectl debug` ephemeral container. The
daemon had 34 OS threads. Of these, only 4 are relevant to the deadlock:

| Thread | Role | State |
|---|---|---|
| Thread 1 (LWP 16) | Async scheduler | `st_thread_yield` -> `pthread_cond_wait` on `caml_master_lock` |
| Thread 2 (LWP 18) | Thread pool worker ("shutdown") | `st_masterlock_acquire` -> `pthread_cond_wait` on `caml_master_lock` |
| Thread 4 (LWP 20) | Thread pool worker ("fcntl_getfl") | `st_masterlock_acquire` -> `pthread_cond_wait` on `caml_master_lock` |
| Thread 3 (LWP 19) | Tick thread | `select()` — does **not** interact with the master lock |

Thread names like "shutdown" and "fcntl_getfl" reflect the last syscall each worker ran
via `In_thread.syscall_exn`, not what the daemon was doing when it froze.

All other threads were idle: thread pool workers waiting for work, RocksDB background
threads, and Rayon (Rust) worker threads. None interact with the OCaml master lock.

### The Lost Wakeup

Direct memory inspection of the `caml_master_lock` structure revealed:

```
busy    = 0   (lock is FREE — nobody holds it)
waiters = 3   (all three threads are waiting)
```

This is a **lost wakeup**: the condition all threads are waiting for (`busy == 0`) is
already satisfied, but they are stuck in `pthread_cond_wait` needing a signal to wake up
and check it. No thread will ever send that signal because no thread is running.

The condvar's internal `__wrefs` field confirmed 3 active waiters at the futex level,
consistent with the 3 stuck threads. The kernel's `/proc/16/stack` showed `futex_wait` for
the main thread, and `/proc/16/syscall` confirmed syscall 202 (`futex`).

**Breakpoint confirmation**: We set breakpoints at three points *after* `Thread.yield()`
in the scheduler loop — the `epoll_wait` call (line 771), the `post_check` (line 788), and
`have_lock_do_cycle` (line 862). After resuming execution and waiting 10+ seconds, **none
fired**. The scheduler runs on a 50ms `epoll_wait` timeout, so any of these should hit
almost immediately if the scheduler were cycling. The scheduler is permanently stuck at
`Thread.yield()` and never reaches `epoll_wait`.

### Core Dump Corroboration

A ~14 GB core dump was extracted and analyzed. Walking the OCaml heap from the
`camlAsync_unix__Raw_scheduler__the_one_and_only` symbol to the kernel scheduler state
revealed:

- `cycle_count`: 41,008,989 total scheduler cycles
- `cycle_start`: **2026-03-12T19:28:49.695910Z** — 1.4ms after the last log line
- `last_cycle_num_jobs`: 9 (last completed cycle ran 9 jobs — completely normal)
- `in_cycle`: false (scheduler between cycles, stuck at the yield/epoll transition)
- Normal and low priority job queues: both empty
- fd 64 (libp2p_helper stdout pipe): registered as `Watch_once` with an **unfilled Ivar**

The unfilled `Watch_once` Ivar for fd 64 is the smoking gun. libp2p_helper's pipe buffer
was full, so fd 64 was readable. The fd was registered in the kernel's epoll interest set
(confirmed via `/proc/16/fdinfo/6`). But the Ivar was never filled because `epoll_wait` was
never called — because the scheduler was permanently stuck at `Thread.yield()`.

## The glibc Bug

### Mechanism

glibc 2.27 (2018) introduced a new `pthread_cond_t` implementation using a two-group
waiter management scheme. This implementation has a bug
([sourceware #25847](https://sourceware.org/bugzilla/show_bug.cgi?id=25847)) where
`pthread_cond_signal()` can silently fail to wake any thread.

The root cause: when a waiter thread consumes a signal and is then preempted before reading
`__g1_start`, multiple group rotations can occur. When the thread resumes, it sees a new
`__g1_start`, incorrectly detects "signal stealing", and posts a replacement signal to the
current group without properly updating `__g_size`. This creates a mismatch in the
condvar's internal bookkeeping. Eventually, a signal is posted to a group with no actual
futex waiters, and no thread wakes up.

There is also a [second failure mode](https://probablydance.com/2022/09/17/finding-the-second-bug-in-glibcs-condition-variable/)
discovered by Malte Skarupke: `pthread_cond_broadcast()` can exit early without making
state changes when no waiters are in `pthread_cond_wait()`, leaving corrupted condvar state
unrepaired. This means even a `pthread_cond_broadcast` watchdog is not 100% reliable on
affected glibc versions.

**Affected versions**: glibc 2.27 through 2.40.
**Fixed**: glibc 2.41 (January 2025). Ubuntu 20.04 received a
[backport](https://bugs.launchpad.net/ubuntu/+source/glibc/+bug/1899800) in glibc
2.31-0ubuntu9.9 (April 2022); no other affected distribution has backported the fix.

### How It Hits OCaml

OCaml's `st_thread_yield` (in `otherlibs/systhreads/st_posix.h`) implements cooperative
thread scheduling using `pthread_cond_signal` and `pthread_cond_wait`:

```c
// Simplified from st_thread_yield in OCaml 4.14.2
pthread_mutex_lock(&m->lock);
m->busy = 0;
pthread_cond_signal(&m->is_free);   // Wake a competitor
m->waiters++;
do {
    pthread_cond_wait(&m->is_free, &m->lock);  // Wait to be re-woken
} while (m->busy);
m->busy = 1;
m->waiters--;
pthread_mutex_unlock(&m->lock);
```

The `do-while` loop always enters `pthread_cond_wait` before checking `busy`, even if
`busy` is already 0. The thread *must* receive a condvar signal to wake up. When glibc
#25847 causes `pthread_cond_signal` to silently fail, the competitor never wakes, and the
yielding thread enters `pthread_cond_wait` with no one left to signal it.

The `do-while` pattern was deliberately introduced in
[OCaml PR #2112](https://github.com/ocaml/ocaml/pull/2112) (Feb 2019) to fix yield
fairness. The code is correct per POSIX — reviewed by Xavier Leroy and Jacques-Henri
Jourdan. The bug is entirely in glibc's violation of the POSIX guarantee that
`pthread_cond_signal` will wake at least one waiting thread.

### Independent Confirmation

The OCaml community independently reported the same deadlock:

- **[OCaml Discuss thread](https://discuss.ocaml.org/t/is-there-a-known-recent-linux-locking-bug-that-affects-the-ocaml-runtime/6542)**:
  A user reported the exact same pattern — multiple threads stuck on the master lock
  condvar. Xavier Leroy identified the cause as `pthread_cond_signal` being silently
  ignored. The reporter confirmed:
  - Deadlocks on Ubuntu 18.04 (glibc 2.27) and 20.04 (glibc 2.31) but **not** on
    Ubuntu 16.04 (glibc 2.23, predating the buggy rewrite)
  - A one-line glibc patch eliminated deadlocks after 1+ days of stress testing
  - Unpatched systems deadlocked within hours under load
- **[Debian bug #986724](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=986724)**
  explicitly lists the OCaml runtime as an affected program
- **Ubuntu bugs [#1888857](https://bugs.launchpad.net/ubuntu/+source/glibc/+bug/1888857)
  and [#1899800](https://bugs.launchpad.net/ubuntu/+source/glibc/+bug/1899800)** document
  the same pattern

## Why TCP Connection Churn

The test uses TCP connections because that's what the frozen daemon was actually doing.

### The ITN Logger Pattern

The daemon had `ITN_FEATURES` enabled, which activates internal tracing. When the verifier
child process generates `[%log internal]` entries during SNARK verification (~18
entries/sec), each entry dispatches via `Rpc.Connection.with_client` — opening a **new TCP
connection** to the daemon's RPC server on `127.0.0.1:client_port`.

On the daemon side, each connection triggers:
1. TCP accept
2. Reader + Writer creation: 2x `fcntl_getfl` via `In_thread.syscall_exn`
3. RPC dispatch and handling
4. Connection close: `shutdown` + `close` via `In_thread.syscall_exn`

That's **4 `In_thread` operations per connection**, each involving a blocking section
transition (release master lock condvar -> syscall -> reacquire master lock condvar). At
~10-18 connections/sec, this generates ~40-70 condvar operations/sec of real syscall work.

Meanwhile, the Async scheduler is driving `epoll_wait` cycles for TCP socket events,
creating the mixed condvar signal pattern:
- `Thread.yield()`: signal condvar **inside** mutex
- `epoll_wait` enter/leave: signal condvar **outside** mutex (blocking section)
- `In_thread` worker completion: signal condvar **outside** mutex (blocking section)

This mixed pattern — signal-inside-mutex interleaved with signal-outside-mutex — is what
creates the condvar group rotation activity that triggers the glibc bug.

### Evidence from the Frozen Daemon

The stuck thread pool workers were named `"shutdown"` and `"fcntl_getfl"` — these are
fd lifecycle operations from `In_thread.syscall_exn` in async_unix's `fd.ml` and
`unix_syscalls.ml`. These are exactly the operations generated by TCP connection
lifecycle. The test replicates this cross-process pattern directly: a separate client
process opens connections to the server, just as the verifier child opened connections to
the daemon.

## Risk in ITN vs Non-ITN Environments

The deadlock is probabilistic — it requires specific thread preemption timing during
condvar group rotation. The probability of triggering it depends on the rate of condvar
operations: more operations per second means more chances for the race condition per unit
time. ITN environments dramatically increase this rate.

### ITN Environments (Elevated Risk)

With `ITN_FEATURES` enabled, every `[%log internal]` entry from a child process dispatches
via `Rpc.Connection.with_client` — a **new TCP connection per message** (see
[The ITN Logger Pattern](#the-itn-logger-pattern) above). During active SNARK
verification, the verifier generates ~10-18 log messages/sec, each producing 4
`In_thread` blocking section transitions on the daemon side (~40-72 condvar ops/sec of
real syscall work).

This is the workload that was running when the frozen daemon deadlocked. The stuck thread
pool workers were named `"shutdown"` and `"fcntl_getfl"` — TCP connection lifecycle
operations from this exact pattern (see
[Evidence from the Frozen Daemon](#evidence-from-the-frozen-daemon) above).

### Non-ITN Environments (Lower but Non-Zero Risk)

Without `ITN_FEATURES`, the per-message TCP connection churn disappears:

- **Child process communication**: Rpc_parallel maintains a single long-lived TCP
  connection per child process (verifier, prover, VRF evaluator). These don't generate
  per-message connection churn — one connection setup at spawn time, then multiplexed RPC
  calls over the existing connection.
- **libp2p_helper**: Communicates via stdin/stdout pipes, not TCP. No `In_thread`
  operations for libp2p I/O.
- **Remaining `In_thread` sources**: fd operations for new peer connections, GraphQL
  HTTP requests (including the k8s readiness probe every ~2 minutes), and occasional
  file I/O still generate `In_thread` blocking section transitions, but at much lower
  frequency than the ITN logger's per-message pattern.
- **No baseline condvar activity without `In_thread` work**: The condvar is effectively
  dormant when no thread pool workers are contending for the master lock.
  `Thread.yield()` checks `waiters == 0` and [returns immediately](https://github.com/ocaml/ocaml/blob/4.14.2/otherlibs/systhreads/st_posix.h#L175-L178)
  without calling `pthread_cond_signal` or `pthread_cond_wait`. The `epoll_wait`
  blocking section calls `pthread_cond_signal` in `st_masterlock_release`, but with
  zero waiters this is a no-op at the futex level — it does not drive the group
  rotations that the glibc bug requires. The condvar's internal state only becomes
  active when `In_thread` operations create real contention.

A non-ITN daemon is not immune — the condvar race can trigger on any `In_thread`
operation. But without the ITN logger's per-message TCP connection churn, `In_thread`
activity is sporadic (peer connections, occasional file I/O, GraphQL probes) rather than
sustained. The expected time to deadlock stretches from days (as observed in the ITN
incident after ~2 days of sustained operation) to potentially weeks or months.

### Why the Test Triggers Quickly

This reproducer generates ~14,000 condvar ops/sec per server — roughly 200x the ITN
daemon's ~70 ops/sec. This compresses the expected time to deadlock from days to minutes.
The C reproducers for glibc #25847 trigger even faster (<1 minute) because they use
synchronized concurrent condvar bursts from multiple threads, whereas OCaml's serialized
master lock means only one signal/wait pair proceeds at a time.

Pure OCaml reproducers (yield loops, blocking section bursts) didn't trigger in 5-minute
runs during investigation. The per-message TCP connection pattern — creating real fd
lifecycle `In_thread` work interleaved with the scheduler's `epoll_wait` cycles — is what
generates enough mixed-signal condvar activity to trigger the bug reliably.

## Affected Distributions

| Distribution | glibc | Affected? |
|---|---|---|
| Debian 11 (bullseye) | 2.31 | **Yes** (confirmed by source inspection, see note) |
| Debian 12 (bookworm) | 2.36 | **Yes** (confirmed by source inspection, see note) |
| Ubuntu 18.04 | 2.27 | **Yes** |
| Ubuntu 20.04 | 2.31 | [Backport applied](https://bugs.launchpad.net/ubuntu/+source/glibc/+bug/1899800) in 2.31-0ubuntu9.9 |
| Ubuntu 22.04 | 2.35 | **Likely** (predates fix, no backport found in [changelog](https://www.ubuntuupdates.org/package/core/jammy/main/updates/glibc)) |
| Ubuntu 24.04 | 2.39 | **Likely** (predates fix, no backport found in [changelog](https://launchpad.net/ubuntu/+source/glibc/+changelog)) |
| [Debian 13 (trixie)](https://packages.debian.org/source/trixie/glibc) | 2.41 | **No** (fixed) |
| Any with glibc 2.41+ | 2.41+ | **No** (fixed) |
| Ubuntu 16.04 | 2.23 | No (predates buggy rewrite) |

Note on Debian 11/12: Direct inspection of the glibc source shipped with
[Debian 11 (2.31-13+deb11u11)](https://sources.debian.org/src/glibc/2.31-13+deb11u11/nptl/pthread_cond_signal.c/)
and
[Debian 12 (2.36-9+deb12u13)](https://sources.debian.org/src/glibc/2.36-9+deb12u13/nptl/pthread_cond_signal.c/)
confirms both contain the vulnerable code. Specifically:

- `pthread_cond_signal.c` uses
  [`__condvar_quiesce_and_switch_g1`](https://sources.debian.org/src/glibc/2.31-13+deb11u11/nptl/pthread_cond_common.c/)
  and the old `+2` signal encoding (`atomic_fetch_add_relaxed(..., 2)`).
- `pthread_cond_wait.c` contains the broken signal-stealing recovery path that re-posts
  signals via `atomic_compare_exchange_weak_relaxed(..., s + 2)` — this is the code path
  where the bug manifests (re-posting a signal to a group with no actual futex waiters).
- Neither Debian release's
  [patch series](https://sources.debian.org/src/glibc/2.31-13+deb11u11/debian/patches/series/)
  includes any patch addressing bug #25847, and the
  [Debian bug report](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=986724) does not
  mention backporting — the fix was only applied in glibc 2.41-1 for trixie.

For comparison, the
[fixed version in Debian 13](https://sources.debian.org/src/glibc/2.41-12+deb13u2/nptl/pthread_cond_signal.c/)
replaces `__condvar_quiesce_and_switch_g1` with a rewritten `__condvar_switch_g1`, changes
the signal encoding from `+2` to `+1`, and eliminates the signal-stealing recovery
entirely.

Additionally, the Mina daemon freeze that motivated this reproducer occurred in a Docker
image running Debian 11 (glibc 2.31), and the observed deadlock pattern (all threads stuck
on `caml_master_lock` with `busy=0`) matches the bug and the
[OCaml community reports](https://discuss.ocaml.org/t/is-there-a-known-recent-linux-locking-bug-that-affects-the-ocaml-runtime/6542)
exactly.

Note on Ubuntu 20.04: The OCaml community
[confirmed](https://discuss.ocaml.org/t/is-there-a-known-recent-linux-locking-bug-that-affects-the-ocaml-runtime/6542)
deadlocks within seconds on stock glibc 2.31, resolved by a one-line patch. Ubuntu later
applied an official backport in 2.31-0ubuntu9.9 (April 2022).

## Nix Flake

The `flake.nix` provides packages and dev shells for both affected and fixed glibc
versions. Binaries link against a pinned glibc via nix rpath, so they reproduce the bug
(or confirm the fix) regardless of the host's glibc.

### Packages

| Output | glibc | Description |
|---|---|---|
| `packages.x86_64-linux.default` | 2.40 (affected) | `async_tcp_server`, `async_tcp_client`, `allow_ptrace.so` |
| `packages.x86_64-linux.fixed` | 2.42 (fixed) | Same binaries, linked against fixed glibc |

```bash
nix build              # → ./result/bin/{async_tcp_server,async_tcp_client}, ./result/lib/allow_ptrace.so
nix build .#fixed      # same layout, glibc 2.42
```

### Dev Shells

| Output | Contents |
|---|---|
| `devShells.x86_64-linux.default` | Built binaries on PATH + gdb (glibc 2.40) |
| `devShells.x86_64-linux.fixed` | Built binaries on PATH + gdb (glibc 2.42) |

```bash
nix develop            # shell with async_tcp_server, async_tcp_client, gdb
nix develop .#fixed    # same, with glibc 2.42
```

The nixpkgs inputs:
- **`nixpkgs`** — nixos-24.11, glibc 2.40 (last affected version).
- **`nixpkgs-fixed`** — nixos-unstable pinned commit, glibc 2.42 (first nixpkgs channel
  with the fix; nixpkgs skipped 2.41).

## References

- [glibc bug #25847](https://sourceware.org/bugzilla/show_bug.cgi?id=25847) — the root cause
- [Debian bug #986724](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=986724) — Debian tracker
- [Ubuntu bug #1899800](https://bugs.launchpad.net/ubuntu/+source/glibc/+bug/1899800) — Ubuntu tracker
- [OCaml community confirmation](https://discuss.ocaml.org/t/is-there-a-known-recent-linux-locking-bug-that-affects-the-ocaml-runtime/6542) — discuss.ocaml.org thread
- [OCaml PR #2112](https://github.com/ocaml/ocaml/pull/2112) — introduced the do-while yield pattern
- ["Finding the Second Bug"](https://probablydance.com/2022/09/17/finding-the-second-bug-in-glibcs-condition-variable/) — secondary broadcast failure mode
- OCaml source: `otherlibs/systhreads/st_posix.h` (4.14 branch) — `st_thread_yield`, `st_masterlock_acquire`
