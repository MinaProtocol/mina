(** Settle the pending blocks of a hard fork boundary.

    At a hard fork the canonical watermark is about k blocks behind the fork
    block, so the archive does not mark the last blocks of the ended chain
    canonical or orphaned. This module settles that boundary: the chain leading
    to the fork block becomes canonical, and every other block of the ended
    chain is orphaned ({!settle_fork}). Pending blocks outside the ended chain
    of a fork are not changed.

    A fork genesis is the first block of the new chain: global slot since hard
    fork 0, above the first genesis (global slot since genesis above 0). It is
    inserted as canonical; one that is not is refused, nothing is changed
    ({!Fork_genesis_not_canonical}). Its parent is the fork block. The chain is read
    through parent links only, so a fork that keeps the protocol version is
    handled like any other. *)

open Core
open Async

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
  | Fork_genesis_not_canonical
      (** The fork genesis is not canonical, which the archive never stores:
          the database is not what a settle builds on, so nothing changes. *)
[@@deriving yojson, sexp, equal]

(** Settle the boundary of the fork that [genesis_id] starts. One statement;
    the caller decides the transaction. *)
let settle_fork (module Conn : Mina_caqti.CONNECTION) ~genesis_id =
  let open Deferred.Result.Let_syntax in
  match%bind
    Conn.find_opt Settle_pending_blocks_sql.fork_genesis genesis_id
  with
  | None | Some (true, None) ->
      return No_fork_block
  | Some (false, _) ->
      return Fork_genesis_not_canonical
  | Some (true, Some fork_block_id) ->
      let%map canonicalized, orphaned, anchored =
        Conn.find Settle_pending_blocks_sql.settle_fork
          (genesis_id, fork_block_id)
      in
      if anchored then Settled { canonicalized; orphaned }
      else No_canonical_ancestor

(** The fork geneses whose fork block has [fork_state_hash]: the genesis of
    the config that names that fork block. *)
let fork_geneses_of_fork_block (module Conn : Mina_caqti.CONNECTION)
    ~fork_state_hash =
  Conn.collect_list Settle_pending_blocks_sql.fork_geneses_of_fork_block
    fork_state_hash

(** The outcome of {!run}. *)
type t =
  { genesis_id : int option  (** The fork genesis whose boundary was used. *)
  ; boundary : boundary option  (** [None] without a fork genesis. *)
  }
[@@deriving yojson, sexp, equal]

(** Settle the boundary of [genesis_id] (by default the newest fork genesis) in
    one transaction. With [~dry_run:true] the transaction is rolled back: the
    result is what a run would change. *)
let run ?(dry_run = false) ?genesis_id (module Conn : Mina_caqti.CONNECTION) =
  let open Deferred.Result.Let_syntax in
  let settle genesis_id =
    let%map boundary = settle_fork (module Conn) ~genesis_id in
    { genesis_id = Some genesis_id; boundary = Some boundary }
  in
  let in_transaction () =
    match genesis_id with
    | Some genesis_id ->
        settle genesis_id
    | None -> (
        match%bind
          Conn.find_opt Settle_pending_blocks_sql.newest_fork_genesis ()
        with
        | None ->
            return { genesis_id = None; boundary = None }
        | Some genesis_id ->
            settle genesis_id )
  in
  let%bind () = Conn.start () in
  match%bind.Deferred in_transaction () with
  | Error e ->
      let%bind.Deferred (_ : (unit, _) Result.t) = Conn.rollback () in
      Deferred.Result.fail e
  | Ok t ->
      let%map () = if dry_run then Conn.rollback () else Conn.commit () in
      t
