open Core_kernel
open Frontier_base
module Work = Transaction_snark_work.Statement

(* TODO: best tip table should be a separate extension *)

module T = struct
  type view = { removed_work : Work.t list } [@@deriving sexp]

  type t =
    { mutable refcount_map : int Work.Map.t
          (** Tracks the number of blocks that have each work statement in
              their scan state.
              Work is included iff it is a member of some block scan state.
          *)
    ; mutable best_tip_table : Work.Set.t
          (** The set of all snark work statements present in the scan state
              for the last 10 blocks in the best chain.
          *)
    }

  let name = "snark_pool_refcount"

  let get_work = Staged_ledger.Scan_state.all_work_statements_exn

  let work_is_referenced t work = Map.mem t.refcount_map work

  let best_tip_table t = t.best_tip_table

  let add_to_table t scan_state =
    t.refcount_map <-
      List.fold (get_work scan_state) ~init:t.refcount_map
        ~f:(Work.Map.update ~f:(Option.value_map ~default:1 ~f:(( + ) 1)))

  (** Returns the elements that were removed from the table. *)
  let remove_from_table t scan_state : Work.t list =
    let res, refc =
      List.fold (get_work scan_state) ~init:([], t.refcount_map)
        ~f:(fun (res, refc) work ->
          match Work.Map.find refc work with
          | Some 1 ->
              (work :: res, Work.Map.remove refc work)
          | Some count ->
              (res, Work.Map.set refc ~key:work ~data:(count - 1))
          | None ->
              failwith "Removed a breadcrumb we didn't know about" )
    in
    t.refcount_map <- refc ;
    res

  let create ~logger:_ frontier =
    let t =
      { refcount_map = Work.Map.empty; best_tip_table = Work.Set.empty }
    in
    let breadcrumb = Full_frontier.root frontier in
    let scan_state =
      Breadcrumb.staged_ledger breadcrumb |> Staged_ledger.scan_state
    in
    add_to_table t scan_state ;
    (t, { removed_work = [] })

  let handle_diffs t frontier diffs_with_mutants =
    let open Diff.Full.With_mutant in
    let removals =
      List.fold diffs_with_mutants ~init:[] ~f:(fun removals -> function
        | E (New_node (Full breadcrumb), _) ->
            let scan_state =
              Breadcrumb.staged_ledger breadcrumb |> Staged_ledger.scan_state
            in
            add_to_table t scan_state ; removals
        | E
            ( Root_transitioned
                { garbage = Full garbage_nodes
                ; old_root_scan_state = Full old_root_scan_state
                ; _
                }
            , _ ) ->
            let removed_scan_states =
              old_root_scan_state
              :: List.map garbage_nodes ~f:(fun node -> node.scan_state)
            in
            let removed_works =
              List.bind removed_scan_states ~f:(remove_from_table t)
            in
            removed_works :: removals
        | E (Best_tip_changed new_best_tip_hash, _) ->
            let rec update_best_tip_table blocks_remaining state_hash =
              match Full_frontier.find frontier state_hash with
              | None ->
                  ()
              | Some breadcrumb ->
                  let statements =
                    try
                      Breadcrumb.staged_ledger breadcrumb
                      |> Staged_ledger.all_work_statements_exn
                    with _ -> []
                  in
                  t.best_tip_table <-
                    List.fold ~f:Set.add ~init:t.best_tip_table statements ;
                  if blocks_remaining > 0 then
                    update_best_tip_table (blocks_remaining - 1)
                      (Breadcrumb.parent_hash breadcrumb)
            in
            let num_blocks_to_include = 3 in
            t.best_tip_table <- Work.Set.empty ;
            update_best_tip_table num_blocks_to_include new_best_tip_hash ;
            removals )
    in
    let removed_work = List.concat removals in
    if not (List.is_empty removed_work) then Some { removed_work } else None
end

include T
module Broadcasted = Functor.Make_broadcasted (T)
