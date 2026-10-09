(** Settle the pending blocks that can no longer stay pending.

    The archive marks a block canonical once it is deep enough under the best
    tip, and orphans its competitors at the same height. Two kinds of blocks
    miss that pass and stay pending for ever:

    - At a hard fork the canonical watermark is about k blocks behind the
      fork block. The chain leading to the fork block is history and becomes
      canonical; every other block of the ended chain -- including blocks the
      archive wrongly made canonical past the fork point -- is orphaned.
    - A pending block at a height that has a canonical block lost.

    The newest fork genesis (global slot since hard fork 0, with its parent in
    the archive) marks the boundary; its parent is the fork block. The chain
    is read through parent links only, so a fork that keeps the protocol
    version is handled like any other. *)

open Core
open Async
open Caqti_request.Infix

type t =
  { canonicalized : int  (** Ancestors of the fork block, now canonical. *)
  ; orphaned_after_fork : int
        (** Blocks of the ended chain off the fork block's ancestry. *)
  ; orphaned_decided : int
        (** Pending blocks at a height that has a canonical block. *)
  ; fork_unresolved : bool
        (** A fork genesis was found, but its fork block's ancestry does not
            reach a canonical block, so the boundary was left as it is. *)
  }
[@@deriving yojson, sexp, equal]

(* The newest fork genesis and its fork block. *)
let fork_genesis_query =
  (Caqti_type.unit ->? Caqti_type.(t2 int int))
    {sql|
      SELECT id, parent_id
      FROM blocks
      WHERE global_slot_since_hard_fork = 0
        AND parent_id IS NOT NULL
      ORDER BY height DESC
      LIMIT 1
    |sql}

(* $1: the fork genesis, $2: the fork block. [walk] climbs from the fork block
   to the first canonical ancestor [anchor]; [ended] is everything below the
   anchor except the fork genesis and its descendants. Without an anchor
   nothing changes. *)
let settle_fork_query =
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

let orphan_decided_query =
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

let run_in_transaction (module Conn : Mina_caqti.CONNECTION) =
  let open Deferred.Result.Let_syntax in
  let%bind fork =
    match%bind Conn.find_opt fork_genesis_query () with
    | None ->
        return None
    | Some (genesis, fork_block) ->
        let%map healed, cut, anchored =
          Conn.find settle_fork_query (genesis, fork_block)
        in
        Some (healed, cut, anchored)
  in
  let%map orphaned_decided = Conn.find orphan_decided_query () in
  let canonicalized, orphaned_after_fork, fork_unresolved =
    match fork with
    | None ->
        (0, 0, false)
    | Some (healed, cut, anchored) ->
        (healed, cut, not anchored)
  in
  { canonicalized; orphaned_after_fork; orphaned_decided; fork_unresolved }

(** Settle the pending blocks in one transaction. With [~dry_run:true] the
    transaction is rolled back: the counts are what a run would change. *)
let run ?(dry_run = false) (module Conn : Mina_caqti.CONNECTION) =
  let open Deferred.Result.Let_syntax in
  let%bind () = Conn.start () in
  match%bind.Deferred run_in_transaction (module Conn) with
  | Error e ->
      let%bind.Deferred (_ : (unit, _) Result.t) = Conn.rollback () in
      Deferred.Result.fail e
  | Ok t ->
      let%map () = if dry_run then Conn.rollback () else Conn.commit () in
      t

let log ~logger ~dry_run t =
  let metadata =
    [ ("canonicalized", `Int t.canonicalized)
    ; ("orphaned_after_fork", `Int t.orphaned_after_fork)
    ; ("orphaned_decided", `Int t.orphaned_decided)
    ]
  in
  if t.fork_unresolved then
    [%log warn]
      "The newest fork block's ancestry does not reach a canonical block; the \
       fork boundary was left as it is" ;
  if dry_run then
    [%log info]
      "Settling pending blocks would make $canonicalized canonical, orphan \
       $orphaned_after_fork of the chain ended at the fork and \
       $orphaned_decided at decided heights"
      ~metadata
  else
    [%log info]
      "Settled pending blocks: $canonicalized made canonical, \
       $orphaned_after_fork of the chain ended at the fork and \
       $orphaned_decided at decided heights orphaned"
      ~metadata

(** [run] on its own connection to [postgres_uri], logged. *)
let run_uri ?(dry_run = false) ~logger postgres_uri =
  let open Deferred.Result.Let_syntax in
  let%bind (module Conn) = Mina_caqti.connect postgres_uri in
  let%bind.Deferred result = run ~dry_run (module Conn) in
  let%bind.Deferred () = Conn.disconnect () in
  let%map t = Deferred.return result in
  log ~logger ~dry_run t ; t
