# Care and feeding of your Coda daemon

Right now the default config directory is hardcoded to `~/.mina-config`.
This will be fixed eventually. In the meantime, you can pass `-config-directory`
to the daemon to look there.

## How ports are used

## CLI args

The daemon has many options. If you run `mina daemon -h`, it will explain what
they are.

## Config file

The daemon will look for a `$CONF_DIR/daemon.json` on startup. That file should
be a single JSON object containing the field `daemon: {...}`. These settings
are overridden by their corresponding command-line flags. See `mina daemon -h`
for more information about them.
These flags are supported in the `daemon` object of the config file:

- `client-port` int
- `libp2p-port` int
- `rest-port` int
- `block-producer-key` private-key-file
- `block-producer-pubkey` public-key-string
- `block-producer-password` string
- `coinbase-receiver` public-key-string
- `run-snark-worker` public-key-string
- `snark-worker-fee` int
- `peers` string list. This does not get overridden by `-peer` arguments.
  Instead, `-peer` arguments are added to this list.
- `work-selection` seq|rand Choose work sequentially (seq) or randomly (rand) \
            (default: seq)
- `work-reassignment-wait` int
- `log-received-blocks` bool
- `log-txn-pool-gossip` bool
- `log-snark-work-gossip` bool
- `log-block-creation` bool

## Environment variables

The daemon will read some environment variables on startup.

`MINA_CLIENT_TRUSTLIST` is a comma-separated list of CIDR masks, for example `10.0.0.0/8,172.16.0.0/12,192.168.0.0/16` would allow any client on an RFC1918 private network to control the daemon. This list can be edited with `mina advanced client-trustlist` commands.

There are other environment variables, but they aren't documented yet.

## Client/Daemon interface

### Overview

The Mina CLI client communicates with the running daemon through a local RPC
interface. The daemon exposes an [Async.Rpc](https://ocaml.janestreet.com/ocaml-core/latest/doc/async_rpc_kernel/Async_rpc_kernel/Rpc/index.html)
server over TCP, and the client connects to it each time a command is run.
This design keeps the CLI stateless while the long-running daemon manages all
node state.

```
┌─────────────────┐     Async.Rpc / TCP     ┌──────────────────┐
│   mina client   │ ──────────────────────► │   mina daemon    │
│   (CLI tool)    │ ◄────────────────────── │  (RPC server)    │
└─────────────────┘    (client-port)        └──────────────────┘
```

### Transport

The daemon listens for client connections on the **client port** (default
`8301`, configurable with `--client-port`). The client locates this port via
the `--daemon-port` flag on every `mina client` sub-command.

Each RPC call goes through the following steps:

1. The client opens a TCP connection to `localhost:<client-port>`.
2. An `Async.Rpc` handshake is performed (with a 60-second handshake timeout
   and periodic heartbeats).
3. The client dispatches a typed RPC request and waits for the response.
4. The TCP connection is closed when the response is received.

The implementation lives in `src/lib/daemon_rpcs/client.ml`
(`Daemon_rpcs.Client.dispatch`).

### Security – client trustlist

The daemon only accepts RPC connections from IP addresses that appear in its
**client trustlist**. By default, only `localhost` (`127.0.0.0/8`) is trusted.

Additional CIDR ranges can be added in three ways:

- **Environment variable** – set `MINA_CLIENT_TRUSTLIST` to a comma-separated
  list of CIDR masks before starting the daemon, e.g.
  `MINA_CLIENT_TRUSTLIST=10.0.0.0/8,192.168.0.0/16`.
- **Runtime commands** – use `mina advanced client-trustlist add <cidr>` /
  `mina advanced client-trustlist remove <cidr>` / `mina advanced client-trustlist list`
  while the daemon is running.
- **RPC** – the `Add_trustlist`, `Remove_trustlist`, and `Get_trustlist` RPCs
  (used internally by the commands above).

### Client-side connection helper

`src/lib/cli_lib/background_daemon.ml` provides the `rpc_init` helper used by
every `mina client` sub-command. Before dispatching the real RPC it:

1. Checks whether the daemon is reachable on the configured port.
2. If the daemon is not reachable, prints an informative error message and
   exits with code 15 so the calling process can detect the failure.
3. If the daemon is reachable, invokes the provided callback with the
   `Host_and_port.t` value for the daemon.

### RPC catalogue

All RPCs are defined in `src/lib/daemon_rpcs/daemon_rpcs.ml`. Each module
exposes a `query` type, a `response` type (serialized with `bin_io`), and an
`rpc` value of type `(query, response) Rpc.Rpc.t`.

| RPC module | Query | Response | Description |
|---|---|---|---|
| `Get_status` | `` [`Performance \| `None] `` | `Types.Status.t` | Returns the current status of the daemon, optionally including performance histograms. |
| `Clear_hist_status` | `` [`Performance \| `None] `` | `Types.Status.t` | Returns daemon status and resets the performance histograms. |
| `Get_balance` | `Account_id.t` | `Currency.Balance.t option Or_error.t` | Returns the balance of the given account. |
| `Get_nonce` | `Account_id.t` | `Account.Nonce.t option Or_error.t` | Returns the committed nonce for the given account (from the best-tip ledger). |
| `Get_inferred_nonce` | `Account_id.t` | `Account.Nonce.t option Or_error.t` | Returns the inferred nonce (committed nonce + pending transactions in the pool). |
| `Send_user_commands` | `User_command_input.t list` | `([`Broadcasted \| `Not_broadcasted] * pool_diff * rejected) Or_error.t` | Adds one or more signed payment or delegation commands to the transaction pool and broadcasts them. |
| `Send_zkapp_commands` | `Zkapp_command.t list` | `Zkapp_command.t list Or_error.t` | Adds one or more zkApp commands to the transaction pool and broadcasts them. |
| `Get_transaction_status` | `Signed_command.t` | `Transaction_inclusion_status.State.t Or_error.t` | Returns whether a given signed command is in the transaction pool, included in a block, or unknown. |
| `Get_ledger` | `State_hash.t option` | `Account.t list Or_error.t` | Returns all accounts in the staged ledger for the given state hash (or the best tip if `None`). |
| `Get_snarked_ledger` | `State_hash.t option` | `Account.t list Or_error.t` | Returns all accounts in the snarked ledger for the given state hash (or the best tip if `None`). |
| `Get_staking_ledger` | `Current \| Next` | `Account.t list Or_error.t` | Returns all accounts in the current or next epoch's staking ledger. |
| `Get_public_keys` | `unit` | `string list Or_error.t` | Returns the public keys of all accounts tracked by the daemon's wallets. |
| `Get_public_keys_with_details` | `unit` | `(string * int * int) list Or_error.t` | Returns public keys with their balance and nonce. |
| `Verify_proof` | `(Account_id.t * User_command.t * receipt_proof)` | `unit Or_error.t` | Verifies a payment receipt proof. |
| `Chain_id_inputs` | `unit` | `(State_hash.t * Genesis_constants.t * string list * int * int)` | Returns the inputs used to compute the chain ID (genesis hash, constants, constraint digests, protocol versions). |
| `Get_trust_status` | `Unix.Inet_addr.t` | `(Peer.t * Peer_status.t) list` | Returns the trust status for all peers at the given IP address. |
| `Get_trust_status_all` | `unit` | `(Peer.t * Peer_status.t) list` | Returns the trust status for every known peer. |
| `Reset_trust_status` | `Unix.Inet_addr.t` | `(Peer.t * Peer_status.t) list` | Resets the trust score for peers at the given IP address. |
| `Get_node_status` | `Multiaddr.t list option` | `Node_status.t Or_error.t list` | Returns status information about the specified peers (or the local node if `None`). |
| `Add_trustlist` | `Unix.Cidr.t` | `unit Or_error.t` | Adds a CIDR range to the client trustlist. |
| `Remove_trustlist` | `Unix.Cidr.t` | `unit Or_error.t` | Removes a CIDR range from the client trustlist. |
| `Get_trustlist` | `unit` | `Unix.Cidr.t list` | Returns the current client trustlist. |
| `Stop_daemon` | `unit` | `unit` | Requests the daemon to shut down gracefully. |
| `Start_tracing` | `unit` | `unit` | Enables async-profiling tracing. |
| `Stop_tracing` | `unit` | `unit` | Disables async-profiling tracing. |
| `Start_internal_tracing` | `unit` | `unit` | Enables internal structured tracing. |
| `Stop_internal_tracing` | `unit` | `unit` | Disables internal structured tracing. |
| `Snark_job_list` | `unit` | `string Or_error.t` | Returns a JSON list of outstanding SNARK work items. |
| `Snark_pool_list` | `unit` | `string` | Returns a JSON representation of completed SNARK work in the pool. |
| `Visualization.Frontier` | `string` (output path) | `` [`Active of unit \| `Bootstrapping] `` | Dumps a visualization of the transition frontier to a file. |
| `Visualization.Registered_masks` | `string` (output path) | `unit` | Dumps a visualization of the registered ledger masks to a file. |
| `Get_object_lifetime_statistics` | `unit` | `string` | Returns allocation statistics for long-lived objects (JSON). |
| `Generate_hardfork_config` | `{config_dir; generate_fork_validation}` | `unit Or_error.t` | Writes a hard-fork reference configuration to `config_dir`. |
| `Submit_internal_log` | `Itn_logger.remote_log` | `unit` | Submits an internal log entry from the prover/verifier process. |

### Adding a new RPC

1. Add a new module to `src/lib/daemon_rpcs/daemon_rpcs.ml` following the
   existing pattern (define `query`, `response`, and `rpc`).
2. Implement the RPC handler in `src/app/cli/src/init/mina_run.ml` inside
   `setup_local_server` using the `implement` helper.
3. Dispatch the RPC from the relevant `mina client` sub-command in
   `src/app/cli/src/init/client.ml` via `Daemon_rpcs.Client.dispatch` (or one
   of its convenience wrappers such as `dispatch_with_message`, `dispatch_pretty_message`, or
   `dispatch_join_errors`).
