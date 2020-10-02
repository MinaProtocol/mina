open Core_kernel
open Frontier_base

module T = struct
  type t = {logger: Logger.t}

  type view = Breadcrumb.t list

  let create ~logger frontier = ({logger}, [Full_frontier.root frontier])

  let handle_diffs t _frontier diffs_with_mutants =
    let open Diff.Full.With_mutant in
    let new_nodes =
      List.filter_map diffs_with_mutants ~f:(function
        | E (New_node (Full breadcrumb), _) ->
            let staged_ledger_hash =
              Breadcrumb.staged_ledger breadcrumb |> Staged_ledger.hash
            in
            let ledger_hash =
              Coda_base.Staged_ledger_hash.ledger_hash staged_ledger_hash
            in
            [%log' info t.logger]
              "Ledger hash of staged ledger in new breadcrumb"
              ~metadata:
                [ ( "staged_ledger_hash"
                  , `String
                      (Yojson.Safe.to_string
                         (Coda_base.Ledger_hash.to_yojson ledger_hash)) ) ] ;
            Some breadcrumb
        | _ ->
            None )
    in
    Option.some_if (not @@ List.is_empty new_nodes) new_nodes
end

include T
module Broadcasted = Functor.Make_broadcasted (T)
