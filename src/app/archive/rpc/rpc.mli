(** The RPCs an archive node serves.

    The archive listens on [--server-port] (default 3086) and implements all
    three; anything that wants a block archived dispatches one of them. They
    are plain [Async.Rpc] calls over TCP, encoded with bin_prot.

    {b Replies.} Every reply is [unit]. A successful reply means the archive
    has taken the message onto its internal queue, not that it is in the
    database: the write happens afterwards and may still fail there. An RPC
    error means the message was not accepted; senders retry (the daemon tries
    five times, see [Mina_lib.Archive_client]).

    {b Delivery.} Senders retry, so a message can arrive more than once. The
    archive treats a block it already holds as a no-op, keyed by state hash,
    so re-sending is safe. There is no ordering guarantee between messages;
    the archive links a block to its parent whenever the parent arrives.

    {b Compatibility.} Every RPC is at [~version:0] and carries the
    [Stable.Latest] form of its query. Sender and archive must therefore be
    built from the same protocol version: changing a query type changes the
    bytes on the wire. Add a new RPC (or a new version of one) rather than
    changing the type of an existing one. *)

open Async

(** [Send_archive_diff]: a change in the daemon's transition frontier.

    Sent by the daemon ([--archive-address]) for every block added to its
    transition frontier, as {!Diff.Transition_frontier.Breadcrumb_added}. The
    query type is not versioned: see {!Diff}. *)
val t : (Diff.t, Core_kernel.Unit.Stable.V1.t) Rpc.Rpc.t

(** [Send_precomputed_block]: a whole block in precomputed form, as written by
    a daemon's block logs and the precomputed-block buckets.

    Sent by [mina advanced archive-blocks --precomputed] and the
    [archivePrecomputedBlock] GraphQL mutation, to back-fill blocks the
    archive missed. *)
val precomputed_block :
  ( Mina_block.Precomputed.Stable.Latest.t
  , Core_kernel.Unit.Stable.V1.t )
  Rpc.Rpc.t

(** [Send_extensional_block]: a block in the archive's own representation, as
    produced by [mina-extract-blocks].

    Sent by [mina advanced archive-blocks --extensional] and the
    [archiveExtensionalBlock] GraphQL mutation, to copy blocks from one archive
    to another. *)
val extensional_block :
  (Extensional.Block.Stable.Latest.t, Core_kernel.Unit.Stable.V1.t) Rpc.Rpc.t
