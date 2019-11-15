open Core_kernel
open Coda_base
open Frontier_base

module T = struct
  type t = Ledger.t Ledger_hash.Table.t

  type view = unit

  let create ~logger:_ frontier =
    (* populate ledger table from breadcrumbs *)
    let ledger_table = Ledger_hash.Table.create () in
    let breadcrumbs = Full_frontier.all_breadcrumbs frontier in
    List.iter breadcrumbs ~f:(fun bc ->
        let ledger = Staged_ledger.ledger @@ Breadcrumb.staged_ledger bc in
        let ledger_hash = Ledger.merkle_root ledger in
        ignore (Hashtbl.add ledger_table ~key:ledger_hash ~data:ledger) ) ;
    (ledger_table, ())

  let lookup t ledger_hash = Ledger_hash.Table.find t ledger_hash

  let handle_diffs ledger_table _frontier diffs =
    List.iter diffs ~f:(function
      | Diff.Full.E.E (New_node (Full breadcrumb)) ->
          let ledger =
            Staged_ledger.ledger @@ Breadcrumb.staged_ledger breadcrumb
          in
          let ledger_hash = Ledger.merkle_root ledger in
          ignore
            (Ledger_hash.Table.add ledger_table ~key:ledger_hash ~data:ledger)
      | _ ->
          () ) ;
    None
end

module Broadcasted = Functor.Make_broadcasted (T)
include T
