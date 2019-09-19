open Core_kernel
open Coda_transition
open Frontier_base
module Work = Transaction_snark_work.Statement

module T = struct
  type t = int Work.Table.t

  type view = int * int Work.Table.t

  let get_work (breadcrumb : Breadcrumb.t) : Work.t list =
    let staged_ledger = Breadcrumb.staged_ledger breadcrumb in
    let scan_state = Staged_ledger.scan_state staged_ledger in
    Staged_ledger.Scan_state.all_work_statements scan_state

  (** Returns true if this update changed which elements are in the table
      (but not if the same elements exist with a different reference count) *)
  let add_breadcrumb_to_ref_table table breadcrumb : bool =
    List.fold ~init:false (get_work breadcrumb) ~f:(fun acc work ->
        match Work.Table.find table work with
        | Some count ->
            Work.Table.set table ~key:work ~data:(count + 1) ;
            acc
        | None ->
            Work.Table.set table ~key:work ~data:1 ;
            true )

  (** Returns true if this update changed which elements are in the table
      (but not if the same elements exist with a different reference count) *)
  let remove_breadcrumb_from_ref_table table breadcrumb : bool =
    List.fold (get_work breadcrumb) ~init:false ~f:(fun acc work ->
        match Work.Table.find table work with
        | Some 1 ->
            Work.Table.remove table work ;
            true
        | Some v ->
            Work.Table.set table ~key:work ~data:(v - 1) ;
            acc
        | None ->
            failwith "Removed a breadcrumb we didn't know about" )

  let create ~logger:_ frontier =
    let t = Work.Table.create () in
    let (_ : bool) =
      add_breadcrumb_to_ref_table t (Full_frontier.root frontier)
    in
    (t, (0, t))

  type diff_update = {num_removed: int; is_added: bool}

  let handle_diffs (t : t) (frontier : Full_frontier.t) diffs =
    let open Diff in
    let {num_removed; is_added} =
      List.fold diffs ~init:{num_removed= 0; is_added= false}
        ~f:(fun ({num_removed; is_added} as init) -> function
        | Lite.E.E (New_node (Lite transition)) ->
            (* TODO: extensions need full diffs *)
            { num_removed
            ; is_added=
                is_added
                || add_breadcrumb_to_ref_table t
                     (Full_frontier.find_exn frontier
                        (External_transition.Validated.state_hash transition))
            }
        | Lite.E.E (Root_transitioned {new_root= _; garbage}) ->
            let extra_num_removed =
              List.fold ~init:0
                ~f:(fun acc hash ->
                  acc
                  +
                  if
                    remove_breadcrumb_from_ref_table t
                      (Full_frontier.find_exn frontier hash)
                  then 1
                  else 0 )
                garbage
            in
            {num_removed= num_removed + extra_num_removed; is_added}
        | Lite.E.E (Best_tip_changed _) ->
            init
        | Lite.E.E (New_node (Full _)) ->
            (* cannot refute despite impossibility *)
            failwith "impossible" )
    in
    if num_removed > 0 || is_added then Some (num_removed, t) else None
end

include T
module Broadcasted = Functor.Make_broadcasted (T)
