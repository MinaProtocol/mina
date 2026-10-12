(** Settle the pending blocks that can no longer stay pending.

    The archive marks a block canonical once it is deep enough under the best
    tip, and orphans its competitors at the same height. Two kinds of blocks
    miss that pass and stay pending for ever:

    - At a hard fork the canonical watermark is about k blocks behind the
      fork block. The chain leading to the fork block is history and becomes
      canonical; every other block of the ended chain -- including blocks the
      archive made canonical past the fork point -- is orphaned
      ({!settle_fork}).
    - A pending block at a height that has a canonical block lost
      ({!orphan_decided}).

    A fork genesis is a block with global slot since hard fork 0 after the
    chain's first genesis (global slot since genesis above 0); its parent is
    the fork block. The chain is read through parent links only, so a fork
    that keeps the protocol version is handled like any other. *)

open Core
open Async
open Caqti_request.Infix

(** What became of a fork boundary. *)
type boundary =
  | Settled of { canonicalized : int; orphaned : int }
      (** [canonicalized] ancestors of the fork block were made canonical,
          [orphaned] blocks of the ended chain were orphaned. *)
  | No_fork_block
      (** The fork block is not in the archive: nothing to anchor to. *)
  | No_canonical_ancestor
      (** The fork block's ancestry reaches no canonical block, so the
          boundary is left as it is. *)
[@@deriving yojson, sexp, equal]

let fork_genesis_req =
  (Caqti_type.int ->? Caqti_type.int)
    {sql| SELECT id FROM blocks
          WHERE id = $1
            AND global_slot_since_hard_fork = 0
            AND global_slot_since_genesis > 0
    |sql}

(** Whether [block_id] is a fork genesis. *)
let is_fork_genesis (module Conn : Mina_caqti.CONNECTION) ~block_id =
  Conn.find_opt fork_genesis_req block_id
  |> Deferred.Result.map ~f:Option.is_some

let newest_fork_genesis_req =
  (Caqti_type.unit ->? Caqti_type.int)
    {sql| SELECT id FROM blocks
          WHERE global_slot_since_hard_fork = 0
            AND global_slot_since_genesis > 0
          ORDER BY height DESC
          LIMIT 1
    |sql}

(** The newest fork genesis in the archive, if any. *)
let newest_fork_genesis (module Conn : Mina_caqti.CONNECTION) =
  Conn.find_opt newest_fork_genesis_req ()

(* The parent link, or, when it is not set yet, the block whose state hash is
   the genesis's parent hash. *)
let fork_block_req =
  (Caqti_type.int ->? Caqti_type.int)
    {sql| SELECT COALESCE(g.parent_id, p.id)
          FROM blocks g
          LEFT JOIN blocks p ON p.state_hash = g.parent_hash
          WHERE g.id = $1
            AND COALESCE(g.parent_id, p.id) IS NOT NULL
    |sql}

(* $1: the fork genesis, $2: the fork block. [walk] climbs from the fork block
   to the first canonical ancestor [anchor]; [ended] is everything below the
   anchor except the fork genesis and its descendants. Without an anchor
   nothing changes. *)
let settle_fork_req =
  (Caqti_type.(t2 int int) ->! Caqti_type.(t3 int int bool))
    {sql|
      WITH RECURSIVE walk (id, parent_id, chain_status) AS (
        SELECT id, parent_id, chain_status FROM blocks WHERE id = $2
        UNION ALL
        SELECT b.id, b.parent_id, b.chain_status
        FROM blocks b
        JOIN walk w ON b.id = w.parent_id
        WHERE w.chain_status <> 'canonical'
      ), anchor AS (
        SELECT id FROM walk WHERE chain_status = 'canonical'
      ), ended (id) AS (
        SELECT b.id FROM blocks b JOIN anchor a ON b.parent_id = a.id
        WHERE b.id <> $1
        UNION
        SELECT b.id FROM blocks b JOIN ended e ON b.parent_id = e.id
        WHERE b.id <> $1
      ), healed AS (
        UPDATE blocks SET chain_status = 'canonical'::chain_status_type
        WHERE id IN (SELECT id FROM walk WHERE chain_status <> 'canonical')
          AND EXISTS (SELECT 1 FROM anchor)
        RETURNING id
      ), cut AS (
        UPDATE blocks SET chain_status = 'orphaned'::chain_status_type
        WHERE id IN (SELECT id FROM ended)
          AND id NOT IN (SELECT id FROM walk)
          AND chain_status <> 'orphaned'
        RETURNING id
      )
      SELECT (SELECT count(*) FROM healed)::int,
             (SELECT count(*) FROM cut)::int,
             EXISTS (SELECT 1 FROM anchor)
    |sql}

(** Settle the boundary of the fork that [genesis_id] starts: the chain to
    the fork block becomes canonical, the rest of the ended chain is
    orphaned. One statement; the caller decides the transaction. *)
let settle_fork (module Conn : Mina_caqti.CONNECTION) ~genesis_id =
  let open Deferred.Result.Let_syntax in
  match%bind Conn.find_opt fork_block_req genesis_id with
  | None ->
      return No_fork_block
  | Some fork_block_id ->
      let%map canonicalized, orphaned, anchored =
        Conn.find settle_fork_req (genesis_id, fork_block_id)
      in
      if anchored then Settled { canonicalized; orphaned }
      else No_canonical_ancestor

let orphan_decided_req =
  (Caqti_type.unit ->! Caqti_type.int)
    {sql|
      WITH orphaned AS (
        UPDATE blocks p SET chain_status = 'orphaned'::chain_status_type
        WHERE p.chain_status = 'pending'
          AND EXISTS (
            SELECT 1 FROM blocks c
            WHERE c.height = p.height AND c.chain_status = 'canonical' )
        RETURNING p.id
      )
      SELECT count(*)::int FROM orphaned
    |sql}

(** Orphan the pending blocks at heights that have a canonical block. Returns
    how many. *)
let orphan_decided (module Conn : Mina_caqti.CONNECTION) =
  Conn.find orphan_decided_req ()

(** The outcome of {!run}. *)
type t =
  { genesis_id : int option  (** The fork genesis whose boundary was used. *)
  ; boundary : boundary option  (** [None] without a fork genesis. *)
  ; orphaned_decided : int
  }
[@@deriving yojson, sexp, equal]

(** Settle the boundary of [genesis_id] (by default the newest fork genesis)
    and orphan the pending blocks at decided heights, in one transaction.
    With [~dry_run:true] the transaction is rolled back: the result is what a
    run would change. *)
let run ?(dry_run = false) ?genesis_id (module Conn : Mina_caqti.CONNECTION) =
  let open Deferred.Result.Let_syntax in
  let in_transaction () =
    let%bind genesis_id =
      match genesis_id with
      | Some _ ->
          return genesis_id
      | None ->
          newest_fork_genesis (module Conn)
    in
    let%bind boundary =
      match genesis_id with
      | None ->
          return None
      | Some genesis_id ->
          settle_fork (module Conn) ~genesis_id >>| Option.some
    in
    let%map orphaned_decided = orphan_decided (module Conn) in
    { genesis_id; boundary; orphaned_decided }
  in
  let%bind () = Conn.start () in
  match%bind.Deferred in_transaction () with
  | Error e ->
      let%bind.Deferred (_ : (unit, _) Result.t) = Conn.rollback () in
      Deferred.Result.fail e
  | Ok t ->
      let%map () = if dry_run then Conn.rollback () else Conn.commit () in
      t

let completed_fork_geneses_req =
  (Caqti_type.int ->* Caqti_type.int)
    {sql| SELECT id FROM blocks
          WHERE (id = $1 OR parent_id = $1)
            AND global_slot_since_hard_fork = 0
            AND global_slot_since_genesis > 0
    |sql}

(** For the archive, after it adds [block_id] and links the blocks waiting for
    it as their parent: settle the boundary of every fork genesis this block
    completes -- the block itself, or a fork genesis whose parent it is. The
    caller's transaction holds the block and the settle together. *)
let on_block_added ~logger (module Conn : Mina_caqti.CONNECTION) ~block_id =
  let open Deferred.Result.Let_syntax in
  let%bind geneses = Conn.collect_list completed_fork_geneses_req block_id in
  Mina_caqti.deferred_result_list_fold geneses ~init:() ~f:(fun () genesis_id ->
      let%map boundary = settle_fork (module Conn) ~genesis_id in
      let metadata =
        [ ("genesis_id", `Int genesis_id)
        ; ("boundary", boundary_to_yojson boundary)
        ]
      in
      match boundary with
      | Settled _ ->
          [%log info]
            "Settled the hard fork boundary at fork genesis $genesis_id: \
             $boundary"
            ~metadata
      | No_fork_block ->
          [%log info]
            "Fork genesis $genesis_id: its fork block is not in the archive \
             yet; the boundary is settled when it arrives"
            ~metadata
      | No_canonical_ancestor ->
          [%log warn]
            "Fork genesis $genesis_id: the fork block's ancestry reaches no \
             canonical block, so the boundary is left as it is"
            ~metadata )
