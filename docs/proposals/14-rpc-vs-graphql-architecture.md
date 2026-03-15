# Architecture Note: RPC vs GraphQL in Mina --- Analysis and Recommendations

## Overview

Mina daemon exposes two communication interfaces. This document analyzes both, explains why `mina_graphql` (server) can never be lightweight, why it doesn't matter, and establishes guidelines for which interface new tooling should use.

## The Two Interfaces

### RPC (Async RPC / bin_prot)

- **Transport**: TCP socket, localhost only
- **Port**: Client port (default 8301), always enabled
- **Serialization**: OCaml `bin_prot` --- compact binary format, **OCaml-specific**
- **Authentication**: None, but bound to localhost
- **Connection**: `Rpc.Connection.client` from Jane Street's Async library
- **Source**: `src/lib/daemon_rpcs/daemon_rpcs.ml`

**Available RPCs:**

| RPC | Purpose |
|-----|---------|
| `Get_status` | Full daemon status (sync, peers, block production) |
| `Get_trust_status` / `Get_trust_status_all` | Peer trust scores |
| `Reset_trust_status` | Unban a peer |
| `Get_public_keys` / `Get_public_keys_with_details` | Wallet public keys |
| `Stop_daemon` | Graceful shutdown |
| `Start_tracing` / `Stop_tracing` | Performance tracing |
| `Start_internal_tracing` / `Stop_internal_tracing` | Internal tracing |
| `Snark_pool_list` / `Snark_job_list` | SNARK pool inspection |
| `Get_balance` | Account balance |
| `Get_nonce` / `Get_inferred_nonce` | Account nonce |
| `Get_ledger` / `Get_snarked_ledger` / `Get_staking_ledger` | Ledger export |
| `Send_user_commands` / `Send_zkapp_commands` | Submit transactions |
| `Get_transaction_status` | Transaction inclusion status |
| `Verify_proof` | Receipt chain verification |
| `Add_trustlist` / `Remove_trustlist` / `Get_trustlist` | Connection gating |
| `Get_node_status` | Query peer node status |
| `Get_object_lifetime_statistics` | Internal debugging |
| `Generate_hardfork_config` | Hard fork preparation |
| `Clear_hist_status` | Clear performance histograms |
| `Visualization.Frontier` / `Visualization.Registered_masks` | Debug visualizations |

### GraphQL (HTTP + WebSocket)

- **Transport**: HTTP POST (queries/mutations) + WebSocket (subscriptions)
- **Port**: REST port (default 3085), always enabled
- **Serialization**: JSON --- language-agnostic
- **Authentication**: None by default, localhost-bound
  - `--insecure-rest-server`: binds to all interfaces (warned against)
  - `--open-limited-graphql-port PORT`: opens a second port with read-only subset
- **Schema**: 495KB introspection schema, covers nearly all daemon functionality
- **Source**: `src/lib/graphql/mina_graphql/mina_graphql.ml`, `types.ml`

**Subscriptions** (WebSocket, real-time):
- `newSyncUpdate` --- sync status changes
- `newBlock` --- new blocks added to best chain
- `chainReorganization` --- chain reorganization events

## Comparison

### Accessibility

| | RPC | GraphQL |
|---|---|---|
| From OCaml | Native, typed | Via HTTP client or typed PPX queries |
| From Python/JS/Go/Rust | Impossible (bin_prot is OCaml-specific) | Any HTTP client |
| From curl | Binary protocol | `curl -X POST -d '{"query":"{ syncStatus }"}' localhost:3085/graphql` |
| From browser | No | GraphiQL interactive explorer |
| Schema discovery | Read OCaml source | Introspection query or `graphql_schema.json` |
| Self-documenting | No | Yes --- field descriptions in schema |

### Availability

Both interfaces are **always enabled**. Neither requires a special flag:
- RPC: always listens on client port (default 8301)
- GraphQL: always listens on REST port (default 3085)

There is no advantage to either in terms of availability.

### Security

| | RPC | GraphQL (default) | GraphQL (limited port) |
|---|---|---|---|
| Bind address | localhost only, always | localhost only | Configurable (any interface) |
| Read access | Full | Full | Restricted read-only subset |
| Write access | stop-daemon, send txns, tracing | All mutations | None (read-only) |
| Remote access | Never | Only with `--insecure-rest-server` | Designed for it |

The **limited GraphQL port** is the only mechanism designed for semi-trusted external access. RPC has no equivalent.

### Performance

| | RPC | GraphQL |
|---|---|---|
| Serialization overhead | Minimal (binary bin_prot) | Higher (JSON text encoding) |
| Typical latency | ~microseconds (local) | ~milliseconds (HTTP round-trip) |
| Bandwidth | Compact | 5-10x larger for equivalent data |

**This difference is irrelevant for operator tooling.** Both are sub-millisecond on localhost. The performance gap only matters for high-frequency internal communication (which neither health checks nor CLI commands are).

### Version Coupling

| | RPC | GraphQL |
|---|---|---|
| Client-server coupling | **Tight** --- bin_prot format must match exactly | **Loose** --- additive schema changes don't break clients |
| Schema evolution | Breaking on any type change | Additive by convention |
| Cross-version compatibility | None | Possible (if fields only added) |

### How the CLI Currently Uses Each

Looking at `src/app/cli/src/init/client.ml`:

**RPC (`rpc_init` via `background_daemon.ml`):**
- `mina client status` --- `Get_status` RPC
- `mina client stop-daemon` --- `Stop_daemon` RPC
- `mina advanced start-tracing` / `stop-tracing` --- tracing RPCs
- Trust/trustlist management commands

**GraphQL (`graphql_init`):**
- `mina client get-balance` --- GraphQL query
- `mina client send-payment` --- GraphQL mutation
- `mina client delegate-stake` --- GraphQL mutation
- `mina client set-snark-worker` / `set-snark-work-fee` --- GraphQL mutations
- `mina client export-logs` --- GraphQL mutation
- `mina client batch-send-payments` --- GraphQL mutations
- Most `mina advanced` account/transaction commands

**Pattern**: RPC for low-level daemon control (stop, status, tracing). GraphQL for everything else (accounts, transactions, configuration).

## Dependency Weight of Each Interface

### RPC: `daemon_rpcs` library

```
daemon_rpcs (25+ Mina-internal deps)
  ├── consensus
  ├── transition_frontier
  ├── mina_networking
  ├── network_pool
  ├── trust_system
  ├── mina_net2
  ├── mina_base
  ├── sync_status
  ├── user_command_input
  └── ... 15+ more
```

**Heavy.** Every RPC's query/response type uses `[@@deriving bin_io_unversioned]` with Mina-specific stable types. You cannot use `daemon_rpcs` without pulling in `consensus`, `transition_frontier`, etc.

### GraphQL: `mina_graphql` library (server-side)

```
mina_graphql (100+ deps)
  ├── mina_lib (entire daemon)
  ├── pickles, kimchi_backend (SNARK/crypto)
  ├── transaction_snark, blockchain_snark
  ├── block_producer, consensus
  ├── staged_ledger, transition_frontier
  └── ... 90+ more
```

**Extremely heavy --- but this is unavoidable and correct.** See next section.

### GraphQL: `mina_graphql_client` library (client-side)

Currently heavy because of a dependency leak (see Proposal 13). After the fix:

```
mina_graphql_client (after Proposal 13)
  ├── generated_graphql_queries (PPX-generated from schema JSON)
  ├── mina_graphql_input_types (3 input constructors, ~5 deps)
  ├── mina_base, currency, signature_lib
  └── cohttp-async (HTTP client)
```

**Lightweight.** No SNARK code, no daemon internals.

### Raw GraphQL (no library)

```
Any HTTP client (e.g., cohttp-async)
  └── Just send POST with JSON query string, parse JSON response
```

**Zero Mina deps.** This is always possible with GraphQL, never possible with RPC.

## Why `mina_graphql` (Server) Can Never Be Dependency-Free

A natural question: can we refactor the GraphQL server to be independent of daemon internals?

**No.** In OCaml's `graphql-async` library, type definitions and resolvers are the same construct. Every GraphQL object type is parameterized with the server context type:

```ocaml
(* From src/lib/graphql/mina_graphql/types.ml, line 12 *)
let private_key : (Mina_lib.t, Scalars.PrivateKey.t option) typ = ...

(* Line 64 --- types and resolvers are one definition *)
let account_id : (Mina_lib.t, Account_id.t option) typ =
  obj "AccountId" ~fields:(fun _ ->
    [ field "publicKey" ~typ:(non_null public_key)
        ~args:Arg.[]
        ~resolve:(fun _ id -> Mina_base.Account_id.public_key id)  (* resolver inline *)
    ])
```

The `~resolve` functions need `Mina_lib.t` to fetch live data from the running daemon. Unlike JavaScript GraphQL frameworks (Apollo, etc.) where schema and resolvers are separate files, OCaml's graphql library merges them. You cannot define "what an Account looks like" without also defining "how to fetch its fields."

**This is correct and does not need fixing.** The server IS the daemon --- it should depend on daemon internals.

## Why It Doesn't Matter (The Architecture Is Already 95% Right)

The client-server boundary is already clean:

```
┌─────────────────────────────────────────────────────────┐
│                    graphql_schema.json                    │
│                  (495KB, shared contract)                 │
│                                                          │
│  Generated at build time via introspection query against │
│  the server-side schema. Checked into repo.              │
└──────────────────┬───────────────────┬───────────────────┘
                   │                   │
          (compile time)         (compile time)
                   │                   │
                   ▼                   ▼
    ┌──────────────────────┐  ┌─────────────────────────┐
    │ generated_graphql_   │  │      mina_graphql        │
    │ queries              │  │    (server-side)          │
    │                      │  │                           │
    │ PPX reads schema     │  │ Types + resolvers         │
    │ JSON → generates     │  │ (Mina_lib.t context)      │
    │ typed OCaml client   │  │ Must be heavy --- correct │
    │ code                 │  │                           │
    │                      │  │ Deps: mina_lib, pickles,  │
    │ Deps: cohttp,        │  │ kimchi, consensus, ...    │
    │ mina_base, graphql-  │  │ (100+ libs)               │
    │ async (lightweight!) │  │                           │
    └──────────┬───────────┘  └───────────────────────────┘
               │
               ▼
    ┌──────────────────────┐
    │  mina_graphql_client │
    │                      │
    │  Uses generated      │
    │  queries + HTTP      │
    │                      │
    │  PROBLEM: also deps  │
    │  on mina_graphql for │◄──── This is the only leak
    │  3 input constructors│      (Proposal 13 fixes it)
    └──────────────────────┘
```

The `graphql_schema.json` is the shared contract. The `graphql_ppx` preprocessor generates typed client code from it at compile time --- **without importing any server-side code**. This is already the right pattern.

The only leak is 3 calls to `Mina_graphql.Types.Input.SendPaymentInput.make_input` and `SendDelegationInput.make_input` in `client.ml`. Proposal 13 extracts these into a tiny `mina_graphql_input_types` library.

## Guidelines for New Tooling

### Use GraphQL (not RPC) for new operator tools

| Reason | Detail |
|--------|--------|
| Language-agnostic | External tools in Python, Go, JS can use GraphQL. RPC is OCaml-only. |
| Lightweight client | After Proposal 13, `mina_graphql_client` is lightweight. `daemon_rpcs` will always be heavy. |
| Raw HTTP fallback | Can always bypass typed client with `cohttp-async` + JSON. Impossible with RPC's bin_prot. |
| Remote monitoring | GraphQL supports remote access via limited port. RPC is localhost-only, always. |
| Schema evolution | GraphQL schema changes are additive/non-breaking. bin_prot changes are breaking. |
| Discoverability | GraphQL has introspection, GraphiQL UI, schema docs. RPC requires reading OCaml source. |

### When RPC is still appropriate

- **Internal daemon-to-daemon communication**: bin_prot's compact binary format matters for high-throughput internal messaging
- **Operations that have no GraphQL equivalent**: Currently only `Start/Stop_tracing`, `Start/Stop_internal_tracing`, `Visualization.*`, and `Generate_hardfork_config` --- these are developer-internal operations

### For the health check app specifically

**Use GraphQL.** Either:
1. **After Proposal 13**: Use `mina_graphql_client` (typed, with retry logic, lightweight)
2. **Before Proposal 13**: Use raw `cohttp-async` with hardcoded query strings (zero Mina deps)

Both approaches work. RPC would force a dependency on `daemon_rpcs` (25+ deps including `consensus`, `transition_frontier`) with no benefit.

## Why a Lightweight RPC Client Is Not Feasible

### The question

Given that we're making `mina_graphql_client` lightweight (Proposal 13), should we do the same for RPC --- create a standalone lightweight RPC client library that doesn't pull in heavy daemon dependencies?

### The answer: No

The RPC and GraphQL architectures are fundamentally different in a way that makes this asymmetric.

### GraphQL has a language-independent schema contract

```
graphql_schema.json (495KB, checked into repo)
       |
       +---> graphql_ppx reads it at compile time
              +---> generates lightweight typed OCaml client code
                    (no server-side imports needed)
```

The `graphql_ppx` preprocessor generates client types from the JSON schema without importing any server code. The schema JSON is the clean boundary. That's why Proposal 13 only needs to extract 3 input constructors --- everything else is already decoupled.

### RPC has no schema --- the OCaml types ARE the protocol

The RPC response type `Status.t` (in `src/lib/daemon_rpcs/types.ml`, lines 462-494) contains:

```ocaml
type t = {
  sync_status       : Sync_status.Stable.Latest.t
  catchup_status    : (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int) list option
  consensus_time_best_tip : Consensus.Data.Consensus_time.Stable.Latest.t option
  consensus_time_now      : Consensus.Data.Consensus_time.Stable.Latest.t
  consensus_configuration : Consensus.Configuration.Stable.Latest.t
  peers             : Network_peer.Peer.Display.Stable.Latest.t list
  addrs_and_ports   : Node_addrs_and_ports.Display.Stable.Latest.t
  next_block_production   : Next_producer_timing.t option
  histograms        : Histograms.t option
  metrics           : Metrics.t
  ...
} [@@deriving bin_io_unversioned]
```

`bin_prot` serialization requires **the exact same OCaml type definition** on both client and server to deserialize. You cannot parse a `Consensus.Data.Consensus_time.Stable.Latest.t` without importing the `consensus` library. You cannot parse `Transition_frontier.Full_catchup_tree.Node.State.Enum.t` without importing `transition_frontier`.

### What extraction would require

To create a lightweight RPC client, you would need to duplicate every type referenced in every RPC's query and response:

| RPC response type field | Source library | That library's deps |
|------------------------|----------------|---------------------|
| `Sync_status.Stable.Latest.t` | `sync_status` | lightweight |
| `Consensus.Data.Consensus_time.Stable.Latest.t` | `consensus` | `mina_base`, `signature_lib`, `snark_params`, `genesis_constants`, ... |
| `Consensus.Configuration.Stable.Latest.t` | `consensus` | same as above |
| `Transition_frontier.Full_catchup_tree.Node.State.Enum.t` | `transition_frontier` | `consensus`, `staged_ledger`, `mina_block`, `verifier`, ... |
| `Network_peer.Peer.Display.Stable.Latest.t` | `network_peer` | lightweight |
| `Node_addrs_and_ports.Display.Stable.Latest.t` | `node_addrs_and_ports` | `network_peer` |
| `Trust_system.Peer_status.Stable.Latest.t` | `trust_system` | `network_peer`, `logger` |
| `Network_pool.Transaction_pool.Diff_versioned.Stable.Latest.t` | `network_pool` | `mina_base`, `transaction_snark_work`, ... |
| `Mina_networking.Node_status.Stable.Latest.t` | `mina_networking` | `consensus`, `transition_frontier`, `network_pool`, ... |

You would need to:

1. **Duplicate all these types** into a new `daemon_rpcs_types_lightweight` library
2. **Keep them in perfect sync** --- `bin_prot` derives serialization format from the OCaml type structure. Same field names, same field order, same variant constructors, same nesting. One mismatch -> silent data corruption or crash.
3. **Track changes across 10+ libraries** --- any change to `Consensus.Configuration.t` or `Transition_frontier.Node.State.Enum.t` in the source library must be immediately mirrored in the duplicate.
4. **No tooling exists** to verify the duplicates match --- unlike Protocol Buffers or FlatBuffers, `bin_prot` has no schema validation tool. The only check is runtime deserialization.

### The fundamental asymmetry

| | GraphQL | RPC |
|---|---|---|
| Shared contract | `graphql_schema.json` (language-independent) | OCaml types with `bin_io` (OCaml-only) |
| Client code generation | `graphql_ppx` generates from JSON schema | None --- must import actual type definitions |
| Can decouple client from server? | Yes, already done via PPX + schema JSON | No --- types ARE the coupling |
| Effort to make lightweight | Extract 3 input constructors (1-2 days) | Duplicate entire type ecosystem (weeks, fragile, ongoing maintenance) |
| Cross-language support | Yes, any HTTP client | No, bin_prot is OCaml-only |

### Conclusion

The right strategy is to **invest in GraphQL for all external/operator tooling** and accept that RPC is --- and should remain --- an internal OCaml-to-OCaml mechanism. Attempting to make RPC lightweight would be high effort, fragile, and provide no benefit over the GraphQL path.

Any functionality currently only available via RPC (tracing, visualizations) that operators need should be exposed via GraphQL as well, rather than trying to make the RPC interface externally accessible.

## Action Items

1. **Proposal 13** --- Extract 3 input constructors to fix the `mina_graphql_client` dependency leak. This unblocks lightweight typed GraphQL clients. (1-2 days)
2. **New tools should use GraphQL** --- Establish this as a project convention.
3. **Consider deprecating overlapping RPCs** --- Several RPCs duplicate GraphQL queries (`Get_balance`, `Get_nonce`, `Send_user_commands`). Long-term, the CLI could migrate these to GraphQL and simplify `daemon_rpcs`.
4. **Document the limited GraphQL port** --- Operators running remote monitoring need to know about `--open-limited-graphql-port` and what it exposes.
