# archive_rpc

`archive_rpc` is the protocol between a Mina daemon and an archive node: the
RPCs the archive serves, and the types those RPCs carry. Use it to write a
program that sends blocks to an archive, or a program that receives them.

This library has no database code. A program that only talks to an archive
does not link caqti, postgres or the archive's processor. The archive itself
(`archive_lib`) depends on this library and re-exports its modules under the
old names (`Archive_lib.Diff`, `Archive_lib.Extensional`, ...).

## Modules

| Module         | Contents |
|----------------|----------|
| `Rpc`          | The three RPC definitions. Start here. |
| `Diff`         | The query of `Send_archive_diff`, and the builder the daemon uses to make it. |
| `Extensional`  | The archive's own representation of a block. Query of `Send_extensional_block`. |
| `Chain_status` | `Canonical`, `Orphaned` or `Pending`. Part of `Extensional.Block`. |
| `Timing`       | Performance log lines. |

The `.mli` files are the reference. Each type and value has its contract there.

## The RPCs

The archive listens on `--server-port` (default 3086). The RPCs are plain
`Async.Rpc` calls over TCP, encoded with bin_prot.

| RPC (name, version)          | Query                                   | Sent by |
|------------------------------|-----------------------------------------|---------|
| `Send_archive_diff`, 0       | `Diff.t`                                | the daemon (`--archive-address`), once per block added to its transition frontier |
| `Send_precomputed_block`, 0  | `Mina_block.Precomputed.Stable.Latest.t`| `mina advanced archive-blocks --precomputed`, GraphQL `archivePrecomputedBlock` |
| `Send_extensional_block`, 0  | `Extensional.Block.Stable.Latest.t`     | `mina advanced archive-blocks --extensional`, GraphQL `archiveExtensionalBlock` |

The response of each RPC is `unit`.

### What a reply means

- A successful reply means that the archive put the message on its internal
  queue. It does not mean that the block is in the database. The database
  write occurs after the reply, and it can fail.
- An RPC error means that the archive did not accept the message. Send it
  again. The daemon tries five times (`Mina_lib.Archive_client`).

### Delivery, duplicates, order

- A sender can send the same message more than once. The archive looks up a
  block by its state hash first, so a block it already has does not change
  anything. Sending again is safe.
- The archive does not need blocks in order. When a block arrives before its
  parent, the archive stores it without a parent link. It adds the link when
  the parent arrives.

## Compatibility rules

- All three RPCs are at version 0, and each carries the `Stable.Latest` form
  of its query. A sender and an archive must use the same protocol version.
  If a query type changes, the bytes on the wire change.
- `Diff` types are not versioned. They derive bin_prot directly. Every change
  to them is a wire change.
- `Extensional` types are versioned (`Stable.V2`, `Stable.V3`). Their JSON
  form is written by `mina-extract-blocks` and read by
  `mina-archive-blocks --extensional`. Old JSON files must stay readable.

### How to change the protocol

1. Do not change the query type of an existing RPC.
2. To send new data, add a new RPC with a new name, or a new version of an
   existing RPC. Then make the archive implement both until all senders are
   upgraded.
3. To change an `Extensional` type, add a new `Stable.Vn` module. Keep the
   older ones for the JSON files that already exist.
4. Keep this library free of database code. If a change needs caqti or the
   processor, the change belongs in `archive_lib`.

## Writing a client

Send a diff, a precomputed block or an extensional block with the RPC
definition and a host and port:

```ocaml
let send_block ~archive (block : Archive_rpc.Extensional.Block.t) =
  (* [archive] is a Host_and_port.t, for example 127.0.0.1:3086 *)
  Daemon_rpcs.Client.dispatch Archive_rpc.Rpc.extensional_block block archive
```

For retries and logging, use the helpers in `Mina_lib.Archive_client`
(`dispatch_precomputed_block`, `dispatch_extensional_block`). They are also
what the CLI and GraphQL use.

## Writing a server

Implement the RPCs that your service accepts. Reply only after you accepted
the message, because the sender reads a reply as "accepted":

```ocaml
open Async

let serve ~port ~on_diff =
  let implementations =
    Rpc.Implementations.create_exn ~on_unknown_rpc:`Close_connection
      ~implementations:
        [ Rpc.Rpc.implement Archive_rpc.Rpc.t (fun () diff -> on_diff diff) ]
  in
  Rpc.Connection.serve ~implementations
    ~initial_connection_state:(fun _ _ -> ())
    ~where_to_listen:(Tcp.Where_to_listen.of_port port)
    ()
```

To refuse a message, raise in the implementation. The sender receives an RPC
error and tries again.

A server for the archive's purpose must also accept duplicates, and blocks
that arrive before their parents (see above).

## Testing

To send blocks to a running archive by hand, use
`mina advanced archive-blocks --archive-address HOST:PORT --precomputed FILES`
(or `--extensional`). To make extensional block files from an existing
archive, use `mina-extract-blocks`.
