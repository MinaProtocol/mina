---
mip: <to be assigned>
title: Automatic hard fork hand-over for archive and Rosetta
description: The archive and Rosetta carry themselves across a hard fork, instead of an operator carrying them.
authors: Dariusz Kijania (@dkijania)
discussions-to: https://github.com/MinaProtocol/mina/issues/19245
status: Draft
type: Standards Track
category: Interface
created: 2026-08-28
---

## Abstract

A hard fork leaves the archive database in a state it cannot repair by itself: the
last blocks before the fork stay `pending` for ever, the post-fork chain is not
linked to the pre-fork one, and accounts that the new era's genesis created but no
block has touched report a balance of zero. Today an operator fixes each of these
by hand, in an order nobody has written down, while readers such as Rosetta may be
running against a schema that no longer belongs to the era they were compiled for.

This proposal specifies an automatic hand-over. A daemon tells the archive about
the fork over the existing archive RPC. The archive records it, stops, and a
dispatcher starts the runtime that matches. That runtime then performs one ordered
repair: it inserts the post-fork genesis block, settles the stranded boundary, and
loads the era's genesis accounts. Rosetta reads those accounts rather than
answering zero, and stands down when the schema underneath it moves to another
era.

## Motivation

Four separate problems, each of which is currently a manual step or a silent wrong
answer.

**The stranded band.** The archive promotes a block to `canonical` only when
another block arrives more than *k* heights above the highest canonical one. On
devnet *k* is 290. A hard fork stops the old chain, so no further block ever
arrives and the last *k* blocks — the fork block among them — stay `pending`
permanently. At the mesa fork on devnet this left 401 blocks undecided. Nothing
repairs that on its own, and no error is raised.

At the berkeley hard fork this was not felt, because the migration tooling of
the day carried the archive across and left the chain statuses settled. That
tooling was removed in July 2024 (`582abd4c1f`), and mesa has no equivalent:
today the boundary is an operator's job, done by hand, with no tool that owns
it and no record of having been done.

**The severed chain, when the genesis block does not arrive.** In the ordinary
case it does arrive. The archive subscribes to the daemon's `New_breadcrumbs`
view, that view is seeded with the frontier's *root*, and a broadcast pipe hands
a new reader the current value — so a post-fork daemon whose root is still its
genesis block delivers it as the first thing the archive hears. Integration
tests that run an archive across a fork exercise this, which is why the boundary
is normally linked without anyone doing anything.

It is delivery, though, not a guarantee. The daemon sends once and does not
replay: an archive that is down when the post-fork daemon starts loses it. So
does an archive that first connects after the frontier root has advanced past
the genesis, and one restored from a backup taken before the fork. In those
cases the first *produced* post-fork block, at `fork_len + 2`, is stored with
`parent_id` NULL: canonicalisation cannot walk across the boundary and the
missing-block metrics misread, with no error raised. The workaround today is to
restart the archive with `--config-file`, which builds the block and inserts it.

**Accounts that answer zero.** A balance query is a snapshot lookup: it finds the
most recent block at or below the requested height in which the account appears.
An account created by the new era's genesis and untouched since appears in no such
block, so the lookup misses and Rosetta reports a balance of zero — with a 200. A
confidently wrong number is worse for an exchange than an error.

**Readers on the wrong side of a migration.** Every process that opens the archive
database is compiled against era-specific types: `Max_state_size` is `Nat.N32` in
mesa where it was `N8` in berkeley. A reader that survives a schema migration
underneath it does not reliably fail — it may succeed and return wrong data.
Nothing checks. This hazard is independent of any automation: it applies to every
operator who upgrades their archive and their Rosetta at different times.

The daemon already has an automatic hard fork mode. This proposal gives the
archive and Rosetta the equivalent, so that the whole node stack crosses a fork
without a runbook.

## Specification

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be
interpreted as described in RFC 2119.

### 1. Announcing the fork

The pre-fork daemon, on generating its hard fork configuration, MUST send that
configuration to its archive over the existing archive RPC, as a new
`Transition_frontier` diff variant:

```
Hardfork_config of { config_json : string }
```

`config_json` MUST be the generated configuration verbatim. It is small — the
configuration devnet generated for the mesa fork is 698 bytes, because it names
its ledgers by hash rather than carrying their accounts.

The archive MUST NOT acknowledge this message until the record is durable. In
particular an implementation MUST NOT answer from a queue: a reply that means
"received" rather than "recorded" is worthless here, because the daemon exits
moments later and a failed write would leave nobody aware of it. Where the RPC
response type carries no error channel, the archive MUST signal failure by
raising, so that the daemon's dispatch reports it.

A post-fork daemon SHOULD re-send its own configuration on a slow heartbeat, so
that an archive restored from a backup taken before the fork learns about it.

### 2. Recording the fork

The archive MUST record the announcement in a single-row table:

```sql
CREATE TABLE hardfork_state
( id                     int             PRIMARY KEY DEFAULT 1 CHECK (id = 1)
, fork_state_hash        text            NOT NULL
, fork_blockchain_length bigint          NOT NULL
, fork_global_slot       bigint          NOT NULL
, config_json            text            NOT NULL
, source                 hardfork_source NOT NULL
, announced_at           timestamptz     NOT NULL DEFAULT now()
, finalized_at           timestamptz
);
```

`config_json` MUST be stored verbatim, byte for byte. Implementations MUST NOT
store it as `jsonb` or any other normalising representation: the configuration is
an artefact that may later be written back out or hashed, and a parsed
representation reorders keys and discards whitespace.

Recording MUST be idempotent — the configuration arrives on a heartbeat — and an
announcement naming a *different* fork block than one already recorded MUST be
refused rather than reconciled. Two daemons disagreeing about where the chain
forked is not a situation any automatic choice improves.

There is deliberately no column recording how far the hand-over has progressed.
`finalized_at` is that: NULL while the boundary is unsettled, a timestamp once it
is settled.

### 3. Standing down

The archive MUST accept a `--hardfork-handling` flag with three values, matching
the daemon's vocabulary:

| Value | Behaviour |
|---|---|
| `keep-running` | Record the fork and continue. **Default.** |
| `exit` | Record the fork, acknowledge, then exit. The schema belongs to the operator. |
| `migrate-exit` | Record the fork, acknowledge, run the schema upgrade, then exit. |

The default MUST be `keep-running`, so that upgrading the binary does not by
itself change when an archive stops.

The archive MUST acknowledge the announcement before exiting. Implementations
SHOULD allow a short grace period for the reply to reach the wire; this is a
courtesy and not a correctness measure, because the row is committed before the
reply is produced.

`migrate-exit` MUST run the schema upgrade from a script path, configurable and
defaulting to `/etc/mina/archive/upgrade_to_mesa.sql`. If the upgrade fails the
process MUST exit non-zero and MUST NOT leave a partially applied schema
unreported.

### 4. Choosing the runtime

A dispatcher MUST stand in front of every archive and Rosetta command, and MUST
decide which runtime to execute from **two** facts in the archive database:
whether a fork has been announced (`hardfork_state`), and which era the schema is
in (`migration_history`).

| Fork announced | Schema era | Runtime |
|---|---|---|
| no | pre-fork or absent | pre-fork |
| no | post-fork | **pre-fork** |
| yes | pre-fork | refuse, and say the schema must be upgraded |
| yes | post-fork | post-fork |

Neither signal is sufficient alone. Row two is the case that requires both: the
schema may legitimately be upgraded well before the fork, and during that window
the chain is still pre-fork.

An absent `migration_history` MUST be read as "never migrated" and MUST NOT be
treated as a failure to read the database. Every reader of that row MUST agree on
this.

The dispatcher SHOULD be compiled against neither era's types, so that it cannot
itself be the wrong binary.

### 5. The hand-over

The post-fork archive MUST perform three repairs, **in this order**, and MUST NOT
begin any of them until the genesis ledger named by the configuration is
available:

1. **Insert the post-fork genesis block, if it is not already there.** The
   daemon normally delivers it (see Motivation); this covers the cases where it
   did not. The archive MUST check for the block before building one, because
   building means resolving the genesis ledger and holding it open, which is
   neither free nor repeatable. After inserting it the archive MUST adopt any
   block already present whose `parent_hash` names it and whose `parent_id` is
   NULL — the delivery that failed is precisely the case where a child arrived
   first.
2. **Settle the boundary.** See §6.
3. **Load the genesis accounts.** See §7.

Only the first strictly requires the ledger. The other two are ordered behind it
deliberately; see Rationale.

Each step MUST be idempotent, so that a pass which stops early costs only that
pass. The archive MUST NOT stop retrying: an archive that quietly gave up would be
indistinguishable from one with nothing to do. Implementations SHOULD poll briskly
while the ledger is still expected and then less often, escalating the log level
rather than falling silent.

### 6. Settling the boundary

Settling means giving every block in the stranded band its final `chain_status`:
`canonical` for those on the line of descent to the fork block, `orphaned` for
those that are not. The archive MUST NOT settle unless **all** of the following
hold:

1. the fork block named by the configuration is present;
2. it is on the best chain;
3. at least *n* blocks stand above it, where *n* is configurable;
4. the era's genesis block is present;
5. the chain back to the highest canonical block is unbroken;
6. the post-fork genesis block is present;
7. that block's parent is the fork block.

Implementations MUST evaluate these in a defined order and MUST report the first
unmet condition, so that an operator reading logs can act on it.

The fork block's slot MUST be read from the block itself and MUST NOT be taken
from `Fork_config.global_slot_since_genesis`. That field is the *scheduled*
genesis slot, not the fork block's own: on devnet they are 161 apart. Comparing
the configuration's number against recorded block slots can never match.

The repair MUST be a single statement, so that it is all-or-nothing. It MUST NOT
express set membership as a scalar test against a large array — see Rationale.

Concurrent archives against one database MUST coordinate. An implementation using
a PostgreSQL advisory lock MUST report when it finds the lock held, because such a
lock belongs to a session rather than a process and can outlive the archive that
took it.

### 7. Genesis accounts

The archive MUST record the era's genesis accounts in a table of their own:

```sql
CREATE TABLE genesis_accounts
( genesis_height          bigint NOT NULL
, public_key              text   NOT NULL
, token                   text   NOT NULL
, balance                 text   NOT NULL
, nonce                   bigint NOT NULL
, initial_minimum_balance text
, cliff_time              bigint
, cliff_amount            text
, vesting_period          bigint
, vesting_increment       text
, PRIMARY KEY (genesis_height, public_key, token)
);
```

These accounts MUST NOT be recorded in `accounts_accessed`. They were accessed by
no transaction; they are initial conditions rather than block effects, and
conflating the two changes what that table means.

The table MUST be append-only across eras. A balance query at a pre-fork height
still needs the earlier era's genesis balance for an account untouched throughout
that era, so clearing a previous era's rows makes that question permanently
unanswerable.

The load MUST be atomic, so that a partial write cannot be mistaken for a
completed one.

**This step takes hours.** A genesis ledger holds hundreds of thousands of
accounts, and every one of them is a row. That is why it is last in the order,
why nothing else waits on it, and why its failure costs nothing else: by the
time it runs, everything else about the fork is already correct, and an archive
that never finishes it is in exactly the position every archive is in today.

Two consequences follow. Implementations SHOULD keep the destination flat rather
than normalised — the existing loader walks a cascade per account, which is why
raising its chunk size to 5000 once exhausted a 16 GiB PostgreSQL — and SHOULD
weigh atomicity against holding a transaction open for hours, which keeps a
snapshot alive and holds back vacuum for as long as it runs.

### 8. Rosetta

Rosetta MUST consult `genesis_accounts` as a second source when the block lookup
for a balance misses, and the **later** of the two sources MUST win — a genesis
row must not override a balance that a block has since changed.

Rosetta MUST offer a flag, off by default, that makes it stand down when the
schema belongs to another era. When enabled it MUST poll `migration_history` and,
on finding a protocol version it was not built for or a migration in progress,
MUST log the reason and exit cleanly so that a supervisor can start the matching
runtime.

That flag MUST default to off: a deployment that will never pass through a hard
fork should not pay for one. The automode package supplies it, because installing
that package is the statement that this deployment might.

Rosetta MUST NOT ship a dispatcher of its own. It routes through the archive's,
because the decision and the record are identical and two programs answering the
same question from the same row could only ever disagree.

### 9. Packaging

An automode installation MUST provide both runtimes side by side, under
per-era paths, with every archive and Rosetta command a symlink to the dispatcher.
The umbrella package MUST pin its pre-fork and post-fork dependencies to exact
versions, so that naming the umbrella pulls both eras and the pre-fork one at its
own version rather than the image's.

## Rationale

**Why the database rather than a marker file.** The daemon's automatic mode
records its state on disk. That does not work for an archive: an archive's
filesystem is typically ephemeral, so a marker written before a restart is gone
when the container is replaced, and the next start would route back to the
pre-fork binary. The archive's durable state is its database, so the database
decides.

**Why the archive must stop at all.** The work waiting on the other side of a fork
is post-fork work. The genesis block belongs to the new era, and a pre-fork binary
cannot build it — its constants and its types are the old era's. The process that
receives the configuration is therefore not the process that can act on it, and
the only way to reach the right binary is to exit and let the dispatcher choose
again.

**Why the whole hand-over waits for the ledger.** Only the genesis block insert
strictly needs it. The boundary repair needs nothing but the blocks already in the
database and could finish sooner. It deliberately does not. A database with its
`chain_status` rewritten, no genesis block and no genesis accounts is three
different half-states to recognise; one that has not started yet is one. The
blocks in question have been stranded since the fork, so a wait measured in
minutes buys that simplicity cheaply.

**Why two routing signals.** Operators upgrade the schema ahead of the fork. On
devnet the mesa schema was applied roughly six hours before the fork itself, and
for that entire window the schema read post-fork while the daemon was still
pre-fork and still speaking the old wire format. A dispatcher reading only the
schema would have started the post-fork archive against it.

**Why the boundary repair must not use `id = ANY(array)`.** The canonical set is a
quarter of a million ids, asked about once per row. Written as a scalar test
inside a `CASE` or an `OR` it cannot be an index condition, and PostgreSQL 13 and
older rescan the whole array for every row; 14 hashes it. Measured against the
real devnet fork on PostgreSQL 12 — the version this project's CI runs — the same
repair took **eleven minutes** written that way and **seventeen seconds** written
as a join. The outcome is identical.

**Why a separate table for genesis accounts.** Discussed in §7. The alternative,
`accounts_accessed`, also buys nothing: its loader walks a normalised cascade per
account, which is why a chunk size of 5000 once exhausted a 16 GiB PostgreSQL. A
flat table has no cascade.

**What the "post-fork genesis present" condition does and does not prove.** It was
introduced as corroboration: the chain confirming what one message asserted. Where
the archive builds that block itself from the same configuration, it is not
corroboration — the block cannot disagree with the configuration it was derived
from. It remains necessary for a different reason: it supplies the boundary slot
that bounds the orphaning, without which every same-version block off the
canonical chain is orphaned however far above the fork it sits. Implementations
wanting genuine corroboration SHOULD require a *produced* post-fork block, which
the network signed and the archive did not derive. This is left open.

**Alternatives considered for delivering the ledger.** Sending the full genesis
ledger inline over the RPC was rejected: the artefact is hundreds of megabytes.
Having the archive fetch it from object storage was chosen instead, which is why
the configuration carries `s3_data_hash` for each ledger — the hash verifies the
download rather than locating it, since the filename is derived from the ledger
hash. The daemon already delivers the genesis block itself in the ordinary case, as
the seeded `New_breadcrumbs` view, and where that delivery lands the archive
needs no ledger for step one at all. Making the delivery reliable — replaying it
on a heartbeat the way the configuration is replayed, so that an archive which
was down does not simply miss it — would shrink the ledger's role further. That
is worth doing and is not specified here.

**If automode is more than is wanted, most of this still is.** The proposal has
two halves that can be adopted separately, and only one of them is automatic.

The machinery that makes it *automatic* is §1's announcement over the RPC, §3's
stopping, §4's dispatcher and §9's packaging. That half is the expensive one: it
needs both runtimes installed side by side, a dispatcher in front of every
command, and a daemon that talks to the archive.

The repairs themselves — §5's ordering, §6's boundary settle, §7's genesis
accounts, §8's Rosetta changes — need none of it. They are things a post-fork
archive does to its own database, and they work in a deployment that has only
ever had one runtime. An operator supplies the fork configuration by hand --
`mina advanced send-hardfork-config <config.json> --archive-address host:port`
sends the same message the daemon would -- and everything downstream is the
same. Note that this is not a special build or a flag combination invented for
the purpose: `--hardfork-handling` already defaults to `keep-running`, which is
exactly "record the fork, repair the database, do not stop". The standalone mode
is the default, and automode is what you add.

So a smaller first step is available, and it is the one that carries most of the
value:

| Taken alone | What it fixes | Needs automode? |
|---|---|---|
| The relink (§5.1) | A boundary severed because the genesis block never arrived — including on the existing `--config-file` path, which has the same gap today | no |
| The boundary settle (§6) | The band *k* strands, which since the berkeley migration tooling was removed nothing owns | no |
| Genesis accounts, and Rosetta reading them (§7, §8) | Accounts answering zero with a 200 | no |
| Rosetta standing down (§8) | A reader misreading a schema from another era, which is a hazard for any operator who upgrades the two at different times | no |
| The dispatcher (§4) and stopping (§3) | Choosing the runtime without a human | **yes** |

Adopting the first four and none of the fifth leaves an operator doing one
thing by hand — deciding when to swap the binaries — instead of the five they do
today, and removes every silent wrong answer in the Motivation. It is a
reasonable place to stop, and nothing in it has to be undone to go further later.

## Backwards Compatibility

This proposal changes no consensus rule and no block format.

**Default behaviour is unchanged.** `--hardfork-handling` defaults to
`keep-running` and Rosetta's stand-down flag defaults to off. An existing archive
or Rosetta upgraded to a binary containing this work behaves exactly as before
until an operator opts in, or installs the automode package which opts in for
them.

**The schema changes are additive.** `hardfork_state` and `genesis_accounts` are
new tables. A pre-fork binary can write to a database carrying them, which matters
because operators upgrade the schema before the fork. The downgrade script removes
both.

**The archive RPC gains a variant.** A daemon carrying this change talking to an
archive without it will have the message rejected as unknown; a daemon without it
talking to an archive with it simply never sends one. Neither is fatal, and the
archive's behaviour without the message is what it is today.

**Rosetta's balance answers change** for accounts untouched since their era's
genesis: they will report their real balance where they previously reported zero.
This is the point of the change, but it is a visible difference for any consumer
that had come to rely on the zero.

## Test Cases

Four harnesses, all runnable without a network.

**The stranded band, on real data.** The published devnet archive dump taken three
hours before the mesa fork, used unmodified: 681,253 blocks, no post-fork blocks
at all, 401 stranded `pending` with the fork block among them. The test asserts
that the archive records the fork and rewrites **no block** while the ledger is
missing, and then that the band heals — 545,433 canonical in an unbroken chain to
the fork block, the abandoned pre-fork window orphaned, and the post-fork genesis
left alone.

**The relink.** Two passes: the archive inserts a genesis block, then a child
pointing at it with `parent_id` NULL is put in front of it and the genesis is
inserted again. The child's `parent_id` must end up as the genesis's id. Covers
both insert paths — the automatic one and the `--config-file` one. The
configuration carries its ledger as inline accounts, so the test fetches nothing.

**Dispatcher routing.** All four combinations of §4, asserted.

**Rosetta on both sides.** An account untouched since genesis must report its
balance rather than zero; a schema of the binary's own era must be served
straight through; a schema from another era must produce a clean stand-down. A
stub answering `query { networkID }` stands in for the daemon, which Rosetta wants
only to validate the network identifier.

Each of these was checked against a deliberately broken build, to confirm it can
fail.

## Reference Implementation

Implemented as a stack of pull requests against `feat/archive_automode` in
`MinaProtocol/mina`, tracked by issue #19245: the daemon's send, the archive's
record, the boundary repair, the genesis block, the genesis accounts, Rosetta's
two changes, the dispatcher, packaging, and the harnesses above.

## Security Considerations

**The archive acts on one message.** A single RPC from the daemon causes the
archive to rewrite the `chain_status` of hundreds of thousands of rows. That
message is not authenticated beyond the archive's existing RPC surface, which is
expected to be reachable only by its own daemon. Deployments MUST NOT expose the
archive RPC port beyond that trust boundary. This is not a new exposure — the same
port already accepts blocks — but the consequence of accepting a bad message is
larger than it was.

**The archive cannot currently detect a wrong fork block.** As noted in the
Rationale, where the archive derives the post-fork genesis from the same
configuration it is validating, the check is circular. A misconfigured or
compromised daemon naming the wrong fork block would have that accepted. Requiring
a produced post-fork block would close this, at the cost of waiting for the new
chain to produce one.

**Era mismatch is a silent misread, not a crash.** This is the most
security-relevant property in the proposal. A reader compiled for one era against
a schema from another may decode accounts incorrectly and return them with a 200.
The stand-down in §8 and the dispatcher in §4 exist for this, and both read the
same row precisely so that they cannot disagree.

**Credentials, if the ledger upload is automated.** Should a daemon be given write
access to the object store holding genesis ledgers, that access SHOULD be scoped
to a single prefix, write-only, without delete, and SHOULD prefer short-lived
credentials over static keys. Note that this does not move the trust boundary: the
archive already believes what its daemon tells it about the fork, and verifies the
tarball against a hash from that same configuration.

**A lock can outlive its process.** A PostgreSQL advisory lock belongs to a
session. An archive killed mid-repair leaves a backend still holding it, and a
restarted archive finds itself unable to proceed. Silence in that state is the
hazard; §6 requires that it be reported.

**Diagnostics must survive the failure they describe.** Two implementation
pitfalls are worth recording because both silently destroyed the information that
mattered: log messages whose interpolated values exceed the logger's length limit
are dropped, and error text from PostgreSQL contains `$1`-style placeholders that
a structured logger will read as interpolation and reject the whole message.
Implementations SHOULD format such text into the message and neutralise `$`.

## Copyright

Copyright and related rights waived via
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).
