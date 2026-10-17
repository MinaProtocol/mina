(** Settle the pending blocks of a hard fork boundary.

    At a hard fork the canonical watermark is about k blocks behind the fork
    block, so the archive does not mark the last blocks of the ended chain
    canonical or orphaned. This module settles that boundary: the chain leading
    to the fork block becomes canonical, and every other block of the ended
    chain is orphaned ({!settle_fork}). Pending blocks outside the ended chain
    of a fork are not changed.

    A fork genesis is the first block of the new chain: global slot since hard
    fork 0, above the first genesis (global slot since genesis above 0). It is
    inserted as canonical. Its parent is the fork block. The chain is read
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
[@@deriving yojson, sexp, equal]

(** Settle the boundary of the fork that [genesis_id] starts. One statement;
    the caller decides the transaction. *)
let settle_fork (module Conn : Mina_caqti.CONNECTION) ~genesis_id =
  let open Deferred.Result.Let_syntax in
  match%bind Conn.find_opt Settle_pending_blocks_sql.fork_block genesis_id with
  | None ->
      return No_fork_block
  | Some fork_block_id ->
      let%map canonicalized, orphaned, anchored =
        Conn.find Settle_pending_blocks_sql.settle_fork
          (genesis_id, fork_block_id)
      in
      if anchored then Settled { canonicalized; orphaned }
      else No_canonical_ancestor

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

(** For the daemon stream, after it stored a fork genesis: settle the newest
    fork genesis, in its own transaction. The caller calls this only for a
    block that starts a hard fork. *)
let settle_stored_fork_genesis ~logger pool =
  Mina_caqti.Pool.use
    (fun (module Conn : Mina_caqti.CONNECTION) -> run (module Conn))
    pool
  |> Deferred.Result.map ~f:(fun result ->
         [%log info] "Settled the hard fork boundary"
           ~metadata:[ ("result", to_yojson result) ] )
