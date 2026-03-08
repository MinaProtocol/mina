# Mina Node Network Traffic Documentation

## Summary

[summary]: #summary

This document catalogs all inbound and outbound network traffic of a Mina node. It covers:

- All data exchange patterns between nodes and between node processes
- The communication rails (protocols and transports) used for each pattern
- Quantitative size and latency characteristics of each data stream
- An overview of the existing networking setup
- Runtime metrics available for monitoring each stream
- Guidance for future networking decisions

## Motivation

[motivation]: #motivation

As the Mina network grows and its networking requirements evolve, a clear picture of every traffic pattern is essential:

- To reason about bandwidth budgets for operators running nodes
- To identify which data streams are on the critical path for consensus participation
- To guide ongoing decisions such as the move from gossip-only delivery to Bitswap (RFC 0062) and IPC refactoring (RFC 0060)
- To determine the right monitoring metrics that signal whether the networking layer is healthy
- To prepare a reference that developers can consult when introducing new network interactions

## Architecture Overview

[architecture-overview]: #architecture-overview

A running Mina node consists of two co-operating OS processes:

1. **The OCaml daemon** (`mina`) – implements all business logic (consensus, ledger management, transaction pool, SNARK coordination, GraphQL/REST API, etc.).
2. **The Go libp2p helper** (`libp2p_helper`) – manages all peer-to-peer networking (connection management, gossip pub/sub, stream-based RPCs, peer discovery).

These two processes communicate over a local IPC channel using the Cap'N Proto binary serialization format (since RFC 0060 / PR #8725).

```
  ┌──────────────────────────────────────────────────────┐
  │                 Mina Daemon (OCaml)                  │
  │                                                      │
  │  ┌─────────────┐  ┌────────────┐  ┌───────────────┐ │
  │  │ Block Logic │  │  Tx Pool   │  │  SNARK Pool   │ │
  │  └──────┬──────┘  └─────┬──────┘  └───────┬───────┘ │
  │         │               │                 │          │
  │  ┌──────▼───────────────▼─────────────────▼───────┐  │
  │  │           Gossip Net / RPC Layer                │  │
  │  └────────────────────────┬────────────────────────┘  │
  │                           │ IPC (Cap'N Proto, pipes)   │
  └───────────────────────────┼──────────────────────────┘
                              │
  ┌───────────────────────────▼──────────────────────────┐
  │            libp2p Helper (Go)                        │
  │                                                      │
  │  ┌─────────────┐  ┌───────────┐  ┌───────────────┐  │
  │  │  GossipSub  │  │    DHT    │  │ Stream (RPC)  │  │
  │  └──────┬──────┘  └─────┬─────┘  └───────┬───────┘  │
  └─────────┼───────────────┼────────────────┼──────────┘
            │               │                │
            └───────────────┴────────────────┘
                        P2P Network (TCP/libp2p)
```

### External Interfaces

In addition to the P2P channel, the daemon exposes several local interfaces:

| Interface | Default Port | Protocol | Direction |
|-----------|-------------|----------|-----------|
| P2P / libp2p | 8302 | TCP (libp2p) | Inbound + Outbound |
| Client RPC | 8301 | TCP (Async RPC) | Inbound (local) |
| REST / GraphQL | 3085 | HTTP | Inbound (local or trusted) |
| Prometheus metrics | configurable | HTTP | Inbound (local or trusted) |
| Archive node | configurable | TCP (Async RPC) | Outbound (local or trusted) |
| Node status telemetry | configurable URL | HTTPS | Outbound |
| Node error reports | configurable URL | HTTPS | Outbound |

---

## Part 1 – P2P Traffic (Port 8302)

All peer-to-peer traffic uses a single external port handled by the libp2p helper. Within that port, libp2p multiplexes two classes of communication:

- **GossipSub pub/sub** for broadcasts (blocks, transactions, SNARK work)
- **Stream-based request/response RPC** for targeted queries between peers

### 1.1 Gossip Broadcast Messages (GossipSub)

Gossip pub/sub is used for high-fanout data that every node needs to receive. Nodes subscribe to one or more topics and the GossipSub protocol fans messages out to all subscribers through a mesh of peers. Messages are deduplicated by a content hash.

#### Topics

| Topic | Protocol version | Data type |
|-------|-----------------|-----------|
| `mina/block/1.0.0` | v1 | Block header (future: reference CID) |
| `mina/tx/1.0.0` | v1 | Transaction pool diff |
| `mina/snark-work/1.0.0` | v1 | SNARK pool diff |
| `coda/consensus-messages/0.0.1` | v0 | Legacy combined message (all three above) |

**Note:** Nodes can be configured to run in RO (read-only), RW (read-write), or N (no participation) mode per topic, via the `--pubsub-v1` / `--pubsub-v0` flags. During the v0→v1 migration, nodes typically participate in both topic sets simultaneously.

#### 1.1.1 New Block (`mina/block/1.0.0`)

**Direction:** Inbound and outbound

**Inbound:** The node receives new blocks produced by other block producers on the network.

**Outbound:** The node broadcasts newly produced blocks. Only block-producing nodes emit outbound block gossip (approximately once every 3 minutes per slot on mainnet).

**Data type:** `Mina_block.Header.t` (v1 topic) or `Mina_block.Stable.Latest.t` (v0 topic)

**Size characteristics:**
- A typical block header (v1) is on the order of a few kilobytes.
- A full block (v0 gossip) includes the staged ledger diff and can reach **1–3 MB** for a full block on mainnet. This large message size is the primary motivation for the Bitswap migration (RFC 0062).
- After the Bitswap migration (RFC 0062), v1 block gossip will carry only a small content identifier (CID) and header, with the full block body served on-demand via Bitswap.

**Latency requirements:**
- **Critical path.** Blocks must propagate to all nodes before the next slot boundary (3 minutes on mainnet, 20 seconds on lightnet). Slow propagation leads to missed slots and chain forks.
- Observed typical propagation times: a few seconds across the global network under normal conditions.

**Rebroadcast policy:** A node forwards a block gossip only after validating it (header signature, protocol version compatibility). Invalid messages are rejected (not forwarded), and the originating peer's trust score is decreased.

**Metrics:**
- `Mina_Network_new_state_received` (gauge) – rate of incoming block gossips
- `Mina_Network_new_state_broadcasted` (gauge) – rate of outgoing block gossips
- `Pipe_Drop_on_overflow_router_valid_transitions` (counter) – back-pressure signals

---

#### 1.1.2 Transaction Pool Diff (`mina/tx/1.0.0`)

**Direction:** Inbound and outbound

**Inbound:** The node receives new user transactions submitted by other nodes.

**Outbound:** The node rebroadcasts locally submitted transactions at intervals for a configurable broadcast period after submission. It also rebroadcasts received transactions if they were accepted into its own mempool.

**Data type:** `Transaction_pool.Resource_pool.Diff.t Network_pool.With_nonce.t`

**Size characteristics:**
- A diff contains 1–N transactions. Individual transactions vary from a few hundred bytes (simple payments) to tens of kilobytes (complex zkApp transactions).
- Typical diff sizes: **1 KB – 512 KB** depending on the number and type of transactions.

**Latency requirements:**
- **Non-critical path** relative to block propagation, but timely propagation improves block fullness and fee revenue for block producers.
- Transactions must reach a block producer's mempool before the block production window.

**Rebroadcast policy:** Accepted only if the diff passes mempool validation. Nonce tracking prevents replay.

**Metrics:**
- `Mina_Network_transaction_pool_diff_received` (gauge)
- `Mina_Network_transaction_pool_diff_broadcasted` (gauge)
- `Pipe_Drop_on_overflow_verified_network_pool_diffs` (counter)

---

#### 1.1.3 SNARK Pool Diff (`mina/snark-work/1.0.0`)

**Direction:** Inbound and outbound

**Inbound:** The node receives SNARK proofs produced by SNARK workers for pending scan state slots.

**Outbound:** SNARK coordinators broadcast locally produced SNARK work. All nodes rebroadcast received SNARK work if it was accepted into the SNARK pool.

**Data type:** `Snark_pool.Resource_pool.Diff.t Network_pool.With_nonce.t`

**Size characteristics:**
- Each SNARK work unit contains 1–2 proofs. A single SNARK proof is roughly **8–20 KB** (depending on the proof system and compression).
- Typical diff sizes: **10–40 KB**.

**Latency requirements:**
- **Moderately important.** SNARK work must arrive at block producers before they need to include it in a block, but there is slack of multiple block intervals.

**Metrics:**
- `Mina_Network_snark_pool_diff_received` (gauge)
- `Mina_Network_snark_pool_diff_broadcasted` (gauge)
- `Mina_Snark_work_completed_snark_work_received_rpc` (counter)

---

### 1.2 Peer-to-Peer RPC Messages (Stream-based)

Direct RPCs are point-to-point request/response calls made over libp2p streams using the protocol identifier `coda/rpcs/0.0.1`. These are used for data that is too large or too targeted for broadcast.

All RPCs are versioned using the `[%%versioned_rpc]` mechanism (see RFC 0013). Size and latency metrics for each RPC are exposed via Prometheus histograms.

**Global RPC metrics:**
- `Mina_Network_rpc_latency_ms` (histogram per RPC name)
- `Mina_Network_rpc_size_bytes` (histogram per RPC name)
- `Mina_Network_rpc_max_bytes` (histogram per RPC name)
- `Mina_Network_rpc_avg_bytes` (histogram per RPC name)
- `Mina_Network_rpc_latency_ms_summary` (summary)
- `Mina_Network_rpc_connections_failed` (counter)

The following subsections describe each RPC individually. Each has its own sent/received counters and failed-request/failed-response counters in the `Mina_Network_*` namespace.

---

#### 1.2.1 `get_some_initial_peers`

**Direction:** Outbound (query) / Inbound (response)

**Purpose:** Bootstrap peer discovery. A newly-started node requests a list of known peers from a seed node or other peer.

**Query:** `unit`

**Response:** `Peer.t list` (list of peer host, port, peer-id triples)

**Size:** Small. A response with 50 peers is approximately **2–5 KB**.

**Latency:** Non-critical. Called once at startup.

**Note:** This RPC is a candidate for deprecation as modern libp2p peer exchange (via DHT) makes it redundant.

**Metrics:**
- `Mina_Network_get_some_initial_peers_rpcs_sent`
- `Mina_Network_get_some_initial_peers_rpcs_received`
- `Mina_Network_get_some_initial_peers_rpc_requests_failed`
- `Mina_Network_get_some_initial_peers_rpc_responses_failed`

---

#### 1.2.2 `get_staged_ledger_aux_and_pending_coinbases_at_hash`

**Direction:** Outbound (query) / Inbound (response, serves peers)

**Purpose:** Bootstrap. A node starting up (or catching up after a long absence) must reconstruct the staged ledger at the frontier root from a peer that has it.

**Query:** `state_hash` – identifies the block whose staged ledger is needed

**Response:** `optional (staged_ledger, ledger_hash, pending_coinbase, protocol_state list)` – the full staged ledger auxiliary data, the snarked ledger hash, pending coinbase state, and the protocol states between the root and the target.

**Size:** This is the **largest single RPC payload** in the protocol. The staged ledger stores all in-flight (unproofed) transactions and can be tens to hundreds of megabytes. Observed sizes: **5 MB – 200 MB** depending on scan state utilization and block body sizes.

**Latency:** Non-critical for live participation; called only during bootstrap. However, slow responses (or no response) can block a bootstrapping node. A timeout triggers a retry with a different peer.

**Note:** This RPC is a future candidate for Bitswap (RFC 0062) to avoid single large RPC payloads.

**Metrics:**
- `Mina_Network_get_staged_ledger_aux_rpcs_sent`
- `Mina_Network_get_staged_ledger_aux_rpcs_received`
- `Mina_Network_get_staged_ledger_aux_rpc_requests_failed`
- `Mina_Network_get_staged_ledger_aux_rpc_responses_failed`

---

#### 1.2.3 `answer_sync_ledger_query`

**Direction:** Outbound (query) / Inbound (response, serves peers)

**Purpose:** Ledger sync (bootstrap). A bootstrapping node uses the sync ledger protocol to download an account ledger (Merkle tree) from peers, transferring only the subtrees that differ from the node's existing state.

**Query:** `(ledger_hash, sync_ledger_query)` – identifies the target ledger and the portion needed.

**Response:** `result sync_ledger_response error` – the requested hashes or leaf data, or an error.

**Size:** Individual queries and responses are small (**100 B – 50 KB** per query). However, a full ledger sync involves many round-trips (O(accounts) in the worst case).

**Latency:** Throughput matters more than per-query latency. Requests are spread across multiple peers to parallelize the download.

**Note:** This RPC is a future candidate for Bitswap (RFC 0062).

**Metrics:**
- `Mina_Network_answer_sync_ledger_query_rpcs_sent`
- `Mina_Network_answer_sync_ledger_query_rpcs_received`
- `Mina_Network_answer_sync_ledger_query_rpc_requests_failed`
- `Mina_Network_answer_sync_ledger_query_rpc_responses_failed`

---

#### 1.2.4 `get_transition_chain`

**Direction:** Outbound (query) / Inbound (response, serves peers)

**Purpose:** Block catchup. When a node learns of a fork or detects missing blocks, it downloads those blocks from peers.

**Query:** `state_hash list` – up to 20 block hashes to fetch in a single call.

**Response:** `optional (block list)` – the corresponding blocks.

**Size:** Blocks can be **100 KB – 3 MB** each. A batch of 20 blocks could be up to **60 MB**. In practice, catchup batches are typically 1–5 blocks at a time.

**Latency:** Moderately time-sensitive. Slow catchup causes a node to fall behind the frontier.

**Note:** Maximum batch size is 20 blocks; requesting more results in a null response.

**Metrics:**
- `Mina_Network_get_transition_chain_rpcs_sent`
- `Mina_Network_get_transition_chain_rpcs_received`
- `Mina_Network_get_transition_chain_rpc_requests_failed`
- `Mina_Network_get_transition_chain_rpc_responses_failed`

---

#### 1.2.5 `get_transition_chain_proof`

**Direction:** Outbound (query) / Inbound (response, serves peers)

**Purpose:** Proves that two blocks are connected via the canonical chain. Used during catchup to verify that a target block is within `k` blocks of a known root.

**Query:** `state_hash` – the target block

**Response:** `optional (state_hash, state_body_hash list)` – the root block hash and a Merkle proof of state body hashes connecting root to target.

**Size:** The proof list has at most `k` entries (currently `k = 290` on mainnet). Each `state_body_hash` is 32 bytes, so the response is at most ~**10 KB**.

**Latency:** Low latency required during active catchup. Typically completes within a few hundred milliseconds.

**Metrics:**
- `Mina_Network_get_transition_chain_proof_rpcs_sent`
- `Mina_Network_get_transition_chain_proof_rpcs_received`
- `Mina_Network_get_transition_chain_proof_rpc_requests_failed`
- `Mina_Network_get_transition_chain_proof_rpc_responses_failed`

---

#### 1.2.6 `get_transition_knowledge`

**Direction:** Outbound (query) / Inbound (response, serves peers)

**Purpose:** Returns the list of state hashes from the frontier root to the best tip. Used by a catching-up node to understand what a peer knows.

**Query:** `unit`

**Response:** `state_hash list` (up to `k` hashes)

**Size:** Up to `k` × 32 bytes ≈ **9 KB** on mainnet.

**Latency:** Low. Called once per peer sampled during catchup.

**Metrics:**
- `Mina_Network_get_transition_knowledge_rpcs_sent`
- `Mina_Network_get_transition_knowledge_rpcs_received`
- `Mina_Network_get_transition_knowledge_rpc_requests_failed`
- `Mina_Network_get_transition_knowledge_rpc_responses_failed`

---

#### 1.2.7 `get_ancestry`

**Direction:** Outbound (query) / Inbound (response, serves peers)

**Purpose:** Returns the root block of the peer's transition frontier and a Merkle proof connecting the requested block to that root. Used during long-range catchup.

**Query:** `(consensus_state, state_hash)` – a description of what the requester already knows and the target block.

**Response:** `optional (block, state_body_hash list, block)` – the target block, the Merkle proof, and the frontier root block.

**Size:** Two full blocks plus a proof of up to `k` state body hashes. In the worst case: **2× block size + 10 KB proof** ≈ **5 MB** or more.

**Latency:** Moderately time-sensitive; called during active sync.

**Metrics:**
- `Mina_Network_get_ancestry_rpcs_sent`
- `Mina_Network_get_ancestry_rpcs_received`
- `Mina_Network_get_ancestry_rpc_requests_failed`
- `Mina_Network_get_ancestry_rpc_responses_failed`

---

#### 1.2.8 `ban_notify`

**Direction:** Outbound

**Purpose:** Notifies a peer that the local node has banned them, including the time of the ban decision.

**Query:** `time` – the timestamp at which the ban was decided.

**Response:** `unit`

**Size:** Negligible (< 50 bytes).

**Latency:** Best-effort; the peer connection is closed immediately after sending.

**Note:** This RPC is a candidate for removal in favor of a direct libp2p notification mechanism before disconnect (RFC 0060).

**Metrics:**
- `Mina_Network_ban_notify_rpcs_sent`
- `Mina_Network_ban_notify_rpcs_received`
- `Mina_Network_ban_notify_rpc_requests_failed`
- `Mina_Network_ban_notify_rpc_responses_failed`

---

#### 1.2.9 `get_best_tip`

**Direction:** Outbound (query) / Inbound (response, serves peers)

**Purpose:** Returns the peer's current best tip along with a Merkle proof of its connection to the frontier root. Used by nodes starting up or reconnecting to quickly determine the current chain state.

**Query:** `unit`

**Response:** `optional (block, state_body_hash list, block)` – the best tip block, connectivity proof, and the frontier root block.

**Size:** Similar to `get_ancestry`: **2× block size + 10 KB proof** ≈ up to **5 MB**.

**Latency:** Low to moderate. Called infrequently (during sync or on operator request via the `best_tip` GraphQL query).

**Metrics:**
- `Mina_Network_get_best_tip_rpcs_sent`
- `Mina_Network_get_best_tip_rpcs_received`
- `Mina_Network_get_best_tip_rpc_requests_failed`
- `Mina_Network_get_best_tip_rpc_responses_failed`

---

#### 1.2.10 `get_node_status`

**Direction:** Outbound (query) / Inbound (response, optional)

**Purpose:** Telemetry. Collects status information from a peer: sync state, best tip height, peer count, uptime, etc. The node status payload is set via the libp2p helper's native `SetNodeStatus` IPC call and retrieved from a peer via `GetPeerNodeStatus`. Node operators may opt out of responding via a CLI flag.

**Implementation note:** Unlike other RPCs in this section, `get_node_status` is not served over the `coda/rpcs/0.0.1` stream. Instead, it uses a libp2p-native mechanism analogous to the `identify` protocol, where each node advertises its current status blob and peers can query it directly via the libp2p helper's IPC interface.

**Data:** JSON-serialized `node_status` (peer ID, chain ID, sync status, best tip height, catchup state, uptime, public key)

**Size:** Small (< 5 KB).

**Latency:** Best-effort; used for monitoring, not consensus.

**Metrics:**
- `Mina_Network_get_node_status_rpcs_sent`
- `Mina_Network_get_node_status_rpcs_received`
- `Mina_Network_get_node_status_rpc_requests_failed`
- `Mina_Network_get_node_status_rpc_responses_failed`

---

#### 1.2.11 `get_completed_snarks`

**Direction:** Outbound (query) / Inbound (response, serves peers)

**Purpose:** Allows a SNARK coordinator or block producer to obtain available completed SNARK work from a peer's SNARK pool.

**Query:** `unit`

**Response:** `optional (Transaction_snark_work.t list)` – a list of available SNARK work.

**Size:** Depends on SNARK pool size. Each SNARK work unit is roughly **10–20 KB**. A full pool can be several megabytes.

**Latency:** Low to moderate; called on-demand by SNARK coordinators.

**Metrics:**
- `Mina_Network_get_completed_snarks_rpcs_sent`
- `Mina_Network_get_completed_snarks_rpcs_received`
- `Mina_Network_get_completed_snarks_rpc_requests_failed`
- `Mina_Network_get_completed_snarks_rpc_responses_failed`

---

## Part 2 – IPC Traffic (Daemon ↔ libp2p Helper)

The OCaml daemon communicates with the Go libp2p helper via a local IPC channel. Since RFC 0060, this uses **Cap'N Proto** binary serialization (no base64 overhead). The channel uses Unix pipes.

**Key design properties:**
- O(1) IPC messages per network message (no fan-out at the IPC layer)
- Binary Cap'N Proto encoding eliminates encoding/decoding overhead
- The helper process owns all stream state; the daemon operates at a request/response abstraction

### 2.1 Daemon → Helper Messages

| Message | Purpose |
|---------|---------|
| `Configure` | Initial network configuration (ports, chain ID, seed peers, gating config) |
| `SetGatingConfig` | Update banned/trusted IPs and peer IDs at runtime |
| `Listen` | Listen on a new multiaddr |
| `AddPeer` | Add a peer (seed or direct) |
| `Publish` | Publish a message to a pubsub topic |
| `Subscribe` / `Unsubscribe` | Join or leave a pubsub topic |
| `OpenStream` | Open a stream to a specific peer for an RPC |
| `SendStream` | Send data on an existing stream |
| `CloseStream` | Signal that a stream has been written completely |
| `SetNodeStatus` | Update node telemetry visible to peers |
| `GenerateKeypair` | Request a new libp2p keypair |
| `Validate` | Return a validation result (accept/reject/ignore) for a gossip message |

**IPC latency:**
- `Mina_Network_ipc_latency_ns_summary` (histogram in nanoseconds)
- `Mina_Network_ipc_logs_received_total` (counter)

### 2.2 Helper → Daemon Messages

| Message | Purpose |
|---------|---------|
| `GossipReceived` | Incoming gossip message (includes sender peer info, timestamp, validation handle, raw data) |
| `PeerConnected` | A new peer connected |
| `PeerDisconnected` | A peer disconnected |
| `IncomingStream` | A peer opened a new stream (RPC request) |
| `StreamMessageReceived` | Data chunk received on a stream |
| `StreamComplete` / `StreamReset` | Stream closed normally or with an error |
| `ResourceUpdate` | Bitswap resource availability update |
| `Stats` | Periodic helper statistics (connection count, peer table, etc.) |

---

## Part 3 – Local API Traffic

### 3.1 Client Port (Default: 8301)

The daemon listens on a local TCP port for client RPC calls from the `mina client` CLI tool. This uses the same Async RPC mechanism as P2P RPCs but is restricted to local processes by default.

**Common operations over this channel:**
- Submit transactions
- Query the node's sync status, best tip, and blockchain state
- Start/stop block production
- Read daemon configuration and logs

**Direction:** Inbound (from local operator tools)

**Security:** This port should be firewalled from external access. It grants administrative control over the daemon.

### 3.2 GraphQL / REST API (Default: 3085)

The daemon exposes a GraphQL API over HTTP. This is used by wallets, block explorers, and monitoring tools.

**Direction:** Inbound

**Common query patterns:**
- Block status queries (best tip, finalized height)
- Account balance and nonce lookups
- Transaction submission
- Node status and sync state

**Security:** Should be restricted to trusted networks. Wide-open exposure allows anyone to read chain state and submit transactions on behalf of local accounts.

### 3.3 Prometheus Metrics (Configurable Port)

Both the OCaml daemon and the Go libp2p helper expose Prometheus-format metrics over HTTP. These are scraped by a Prometheus server for monitoring.

**Direction:** Inbound (Prometheus scraping)

**Key metric namespaces:**
- `Mina_Network_*` – all P2P networking metrics described above
- `Mina_Block_latency_*` – block gossip propagation latency
- `Mina_Snark_work_*` – SNARK pool and worker metrics
- `Mina_Transaction_pool_*` – mempool metrics
- `Mina_libp2p_connections_total` – active P2P connection count (from helper)
- `Mina_libp2p_validation_timeout_counter` – gossip validation timeouts

---

## Part 4 – Outbound External Traffic

### 4.1 Archive Node Connection

When `--archive-process-location` is specified, the daemon sends all confirmed blocks and transaction data to an archive node via Async RPC over TCP.

**Direction:** Outbound

**Data sent:**
- Full blocks (including body and scan state diffs) for archival
- Transaction status updates

**Size:** Proportional to block production rate. Roughly **100 KB – 3 MB** per block on mainnet.

**Latency:** Non-critical for consensus; the archive node is for historical record-keeping. However, a lagging archive can cause gaps in historical data.

### 4.2 Node Status Telemetry (`node_status_url`)

When `--node-status-url` is configured (default: O1Labs telemetry endpoint), the daemon sends a JSON payload every 5 slots containing:

- Peer ID and external IP
- Chain ID
- Sync status
- Best tip block height
- Catchup job status
- Uptime

**Direction:** Outbound (HTTPS POST)

**Size:** Small (< 5 KB per report)

**Frequency:** Every 5 slots (approximately every 15 minutes on mainnet)

**Privacy:** Contains the node's external IP address and public key (if configured). Operators can opt out by not setting `--node-status-url`.

**Reference:** RFC 0042.

### 4.3 Node Error Reporting (`node-error-url`)

When `--node-error-url` is configured, the daemon sends error reports with diagnostic information (hardware info, crash details) to a remote endpoint.

**Direction:** Outbound (HTTPS POST)

**Size:** Small to moderate (< 100 KB per report, depending on crash context)

**Frequency:** Event-driven (on error or crash)

**Privacy:** May contain system hardware information. Operators can opt out by not setting `--node-error-url`.

### 4.4 Seed Peer List Download (`--seed-peer-list-url`)

When `--seed-peer-list-url` is configured, the daemon fetches a list of seed node multiaddresses from a remote URL at startup.

**Direction:** Outbound (HTTP/HTTPS GET)

**Size:** Small (< 10 KB)

**Frequency:** Once at startup

---

## Part 5 – Networking Setup Overview

### Existing Setup

The existing setup uses:

| Layer | Technology | Notes |
|-------|-----------|-------|
| Transport | TCP via libp2p | All P2P traffic |
| P2P multiplexing | yamux / mplex (libp2p) | Multiple streams per connection |
| Gossip broadcast | GossipSub | Blocks, transactions, SNARK work |
| Peer discovery | Kademlia DHT + seed peers | |
| RPC | Async RPC over libp2p streams | Direct peer queries |
| Daemon↔helper IPC | Cap'N Proto over Unix pipes | Since RFC 0060 |
| External APIs | HTTP (GraphQL, Prometheus) | Local interfaces |

**Connection parameters (defaults):**

| Parameter | Value | CLI Flag |
|-----------|-------|---------|
| Min connections | 20 | `--min-connections` |
| Max connections | 50 | `--max-connections` |
| Validation queue size | 150 | `--validation-queue-size` |
| Gossip flooding | disabled | `--flooding` |

### Ideal Setup (Future Direction)

The networking evolution toward an "ideal" setup is guided by two key RFCs:

1. **RFC 0060 (Networking Refactor):** Separates message routing into prioritized data streams, allowing block gossip to be processed with higher priority than mempool gossip, and preventing IPC from becoming a bottleneck.

2. **RFC 0062 (Bitswap):** Reduces gossip pub/sub message size from 1–3 MB (full blocks) to a few kilobytes (CID + header), with full block bodies served on-demand via Bitswap. This substantially reduces bandwidth for non-block-producers and eliminates the redundant retransmission of block bodies.

**Target architecture data streams (from RFC 0060):**

```
Daemon ← Helper:
  block_gossip_in      ← HIGH priority (critical path)
  response_in          ← MEDIUM-HIGH priority
  request_in           ← MEDIUM priority
  mempool_gossip_in    ← MEDIUM-LOW priority (must not starve)
  stats_in             ← LOW priority (periodic)

Daemon → Helper:
  broadcast_out        → Block/tx/snark broadcasts
  response_out         → RPC responses
  validation_out       → Gossip validation results
```

---

## Part 6 – Networking Diagrams

### 6.1 Complete Node Traffic Map

```
                    ╔═══════════════════════════════════════════╗
                    ║         Internet / P2P Network            ║
                    ║                                           ║
  Other Nodes ◄────►║ libp2p TCP port 8302                      ║
                    ║                                           ║
                    ║   GossipSub Topics:                       ║
                    ║     mina/block/1.0.0       (1-3 MB/block) ║
                    ║     mina/tx/1.0.0          (1-512 KB)     ║
                    ║     mina/snark-work/1.0.0  (10-40 KB)     ║
                    ║                                           ║
                    ║   Peer RPC (coda/rpcs/0.0.1):             ║
                    ║     get_staged_ledger_aux  (5-200 MB)     ║
                    ║     answer_sync_ledger     (100B-50KB)    ║
                    ║     get_transition_chain   (up to 60 MB)  ║
                    ║     get_best_tip            (up to 5 MB)  ║
                    ║     get_ancestry            (up to 5 MB)  ║
                    ║     get_completed_snarks   (variable)     ║
                    ║     get_transition_chain_proof  (~10 KB)  ║
                    ║     get_transition_knowledge    (~9 KB)   ║
                    ║     get_some_initial_peers  (~2-5 KB)     ║
                    ║     get_node_status         (<5 KB)       ║
                    ║     ban_notify              (<50 B)       ║
                    ╚═════════════════╤═════════════════════════╝
                                      │
                              ┌───────▼────────┐
                              │  libp2p Helper │ (Go process)
                              │   port 8302    │
                              │                │
                              │  Prometheus    │◄── Monitoring
                              │  metrics port  │
                              └───────┬────────┘
                                      │ IPC (Cap'N Proto / Unix pipes)
                              ┌───────▼────────────────────────────┐
                              │        Mina Daemon (OCaml)         │
                              │                                     │
                              │  ┌─────────────────────────────┐   │
                              │  │   Block / Consensus Logic   │   │
                              │  └─────────────────────────────┘   │
                              │  ┌─────────────────────────────┐   │
                              │  │      Transaction Pool       │   │
                              │  └─────────────────────────────┘   │
                              │  ┌─────────────────────────────┐   │
                              │  │        SNARK Pool           │   │
                              │  └─────────────────────────────┘   │
                              │  ┌─────────────────────────────┐   │
                              │  │   Prometheus metrics port   │◄──┼── Monitoring
                              │  └─────────────────────────────┘   │
                              │  ┌─────────────────────────────┐   │
                              │  │  GraphQL/REST port 3085     │◄──┼── Wallets/
                              │  └─────────────────────────────┘   │   Explorers
                              │  ┌─────────────────────────────┐   │
                              │  │  Client RPC port 8301       │◄──┼── mina client
                              │  └─────────────────────────────┘   │   CLI
                              └──────────────┬──────────────────────┘
                                             │
                    ┌────────────────────────┼──────────────────────┐
                    │                        │                       │
           ┌────────▼────────┐    ┌──────────▼──────┐   ┌──────────▼──────┐
           │  Archive Node   │    │ Telemetry URL    │   │  Error Report   │
           │  (local RPC)    │    │ (HTTPS POST)     │   │  URL (HTTPS)    │
           │  ~100KB-3MB/blk │    │ <5KB / 5 slots   │   │  event-driven   │
           └─────────────────┘    └─────────────────┘   └─────────────────┘
```

### 6.2 Bootstrap / Sync Traffic Pattern

When a node starts from scratch or falls far behind:

```
New Node                    Seed/Peer Nodes
    │                              │
    │─── get_some_initial_peers ──►│
    │◄── peer list ────────────────│
    │                              │
    │─── get_best_tip ────────────►│ (multiple peers)
    │◄── best tip + proof ─────────│
    │                              │
    │─── answer_sync_ledger_query ►│ (many queries, spread across peers)
    │◄── ledger chunks ────────────│
    │                              │
    │─── get_staged_ledger_aux ───►│
    │◄── staged ledger (5-200MB) ──│
    │                              │
    │─── get_transition_chain ────►│ (fill frontier)
    │◄── blocks ───────────────────│
    │                              │
    │  [subscribes to gossip]      │
    │◄═══ block gossip ════════════╪══ (ongoing)
    │◄═══ tx gossip ═══════════════╪══ (ongoing)
    │◄═══ snark gossip ════════════╪══ (ongoing)
```

### 6.3 Ongoing Steady-State Traffic Pattern

Once synced and participating in consensus:

```
All Nodes                    This Node                  This Node (Block Producer)
     │                           │                                │
     │══ block gossip ══════════►│                                │
     │◄═ block gossip ═══════════│(after validation + forward)    │
     │══ tx gossip ═════════════►│                                │
     │◄═ tx gossip ══════════════│(if tx accepted to pool)        │
     │══ snark gossip ══════════►│                                │
     │◄═ snark gossip ═══════════│(if snark accepted)             │
     │                           │                                │
     │◄── get_transition_chain ──│(serve peers catching up)       │
     │─── get_best_tip ─────────►│(check sync occasionally)       │
     │                           │                                │
     │                           │ (at slot boundary)             │
     │                           │◄─────── block produced ────────│
     │◄══════ block gossip ══════│════════════════════════════════│
```

---

## Part 7 – Monitoring Recommendations

### Critical Metrics to Track

| Metric | Alert Condition | Meaning |
|--------|----------------|---------|
| `Mina_libp2p_connections_total` | < 5 | Node has too few peers, likely isolated |
| `Mina_Network_new_state_received` | 0 for > 2 slots | Node not receiving blocks (network issue) |
| `Mina_Network_rpc_connections_failed` | High rate | Peer connectivity issues |
| `Mina_libp2p_validation_timeout_counter` | Rising | Daemon falling behind on processing |
| `Pipe_Drop_on_overflow_router_valid_transitions` | Non-zero | Block processing backlog |
| `Mina_Block_latency_gossip_time_ms` | > 60,000 ms | Block propagation too slow |
| `Mina_Network_ipc_latency_ns_summary` | p99 > 10ms | IPC becoming a bottleneck |

### Bandwidth Estimation

For a typical mainnet node in steady state (not a block producer):

| Traffic | Direction | Rate |
|---------|-----------|------|
| Block gossip receive | Inbound | ~1-3 MB / slot (every 3 min) ≈ 10-30 KB/s |
| Block gossip relay | Outbound | Proportional to fanout degree (typically 4-8 peers) |
| Tx gossip | Inbound + Outbound | Highly variable; bursty |
| SNARK gossip | Inbound + Outbound | ~10-40 KB per SNARK work unit received |
| Catchup RPCs (when synced) | Outbound | Occasional; serving peers |
| Telemetry | Outbound | < 1 KB/min |

For a **block producer**, add approximately **one 1-3 MB outbound block broadcast per slot** that the node wins.

During **bootstrap**, inbound bandwidth can spike to hundreds of megabytes for ledger and frontier download.

---

## Unresolved Questions

[unresolved-questions]: #unresolved-questions

- **Actual on-chain message size measurements:** The sizes listed in this document are estimates or ranges from observed mainnet behavior. A systematic measurement of each RPC payload size (collected from production metrics) should be done to get precise p50/p95/p99 distributions for each data stream.

- **Bandwidth per gossip fanout degree:** The relationship between `max-connections`, gossip mesh parameters (D, D_low, D_high, D_lazy in GossipSub), and actual outbound bandwidth is not fully characterized. This affects operator bandwidth budgeting.

- **IPC prioritization post-RFC 0060:** Once the RFC 0060 multi-pipe IPC is fully implemented, the monitoring recommendations should be updated to reflect the new pipe-level metrics.

- **Bitswap bandwidth impact:** When RFC 0062 is complete, the gossip message sizes will change dramatically. Block gossip will shrink to a small CID (< 1 KB), but new Bitswap fetch traffic will emerge. The net bandwidth impact needs measurement.

- **Rate limiting:** The per-peer rate limiting implemented in the trust system is not fully documented here. A follow-up document should characterize the rate limit budget for each RPC to help operators understand how many concurrent peers they can safely serve.
