open Core_kernel
open Frontier_base
module Work = Transaction_snark_work.Statement

module T = struct
  type view =
    { removed: int
    ; refcount_table: int Work.Table.t
    ; inclusion_table: int Work.Table.t }
  [@@deriving sexp]

  type t = {refcount_table: int Work.Table.t; inclusion_table: int Work.Table.t}

  let get_work = Staged_ledger.Scan_state.all_work_statements_exn

  (** Returns true if this update changed which elements are in the table
      (but not if the same elements exist with a different reference count) *)
  let add_to_table ~get_work ~get_statement table t : bool =
    let res = ref false in
    List.iter (get_work t) ~f:(fun work ->
        Work.Table.update table (get_statement work) ~f:(function
          | Some count ->
              count + 1
          | None ->
              res := true ;
              1 ) ) ;
    !res

  (** Returns true if this update changed which elements are in the table
      (but not if the same elements exist with a different reference count) *)
  let remove_from_table ~get_work ~get_statement table t : bool =
    let res = ref false in
    List.iter (get_work t) ~f:(fun work ->
        Work.Table.change table (get_statement work) ~f:(function
          | Some 1 ->
              res := true ;
              None
          | Some count ->
              Some (count - 1)
          | None ->
              failwith "Removed a breadcrumb we didn't know about" ) ) ;
    !res

  let add_scan_state_to_ref_table table scan_state : bool =
    add_to_table ~get_work ~get_statement:Fn.id table scan_state

  let add_transition_to_inclusion_table table transition : bool =
    add_to_table
      ~get_work:Mina_transition.External_transition.Validated.completed_works
      ~get_statement:Transaction_snark_work.statement table transition

  let remove_scan_state_from_ref_table table scan_state : bool =
    remove_from_table ~get_work ~get_statement:Fn.id table scan_state

  let remove_transition_from_inclusion_table table transition : bool =
    remove_from_table
      ~get_work:Mina_transition.External_transition.Validated.completed_works
      ~get_statement:Transaction_snark_work.statement table transition

  let create ~logger:_ frontier =
    let t =
      { refcount_table= Work.Table.create ()
      ; inclusion_table= Work.Table.create () }
    in
    let () =
      let breadcrumb = Full_frontier.root frontier in
      let scan_state =
        Breadcrumb.staged_ledger breadcrumb |> Staged_ledger.scan_state
      in
      let transition = Breadcrumb.validated_transition breadcrumb in
      ignore (add_scan_state_to_ref_table t.refcount_table scan_state : bool) ;
      ignore
        (add_transition_to_inclusion_table t.inclusion_table transition : bool)
    in
    ( t
    , { removed= 0
      ; refcount_table= t.refcount_table
      ; inclusion_table= t.inclusion_table } )

  type diff_update = {num_removed: int; is_added: bool}

  let handle_diffs t _frontier diffs_with_mutants =
    let open Diff.Full.With_mutant in
    let {num_removed; is_added} =
      List.fold diffs_with_mutants ~init:{num_removed= 0; is_added= false}
        ~f:(fun ({num_removed; is_added} as init) -> function
        | E (New_node (Full breadcrumb), _) ->
            let scan_state =
              Breadcrumb.staged_ledger breadcrumb |> Staged_ledger.scan_state
            in
            let transition = Breadcrumb.validated_transition breadcrumb in
            let added_scan_state =
              add_scan_state_to_ref_table t.refcount_table scan_state
            in
            let added_transition =
              add_transition_to_inclusion_table t.inclusion_table transition
            in
            { num_removed
            ; is_added= is_added || added_scan_state || added_transition }
        | E (Root_transitioned {new_root= _; garbage= Full garbage_nodes}, _)
          ->
            let open Diff.Node_list in
            let extra_num_removed =
              List.fold garbage_nodes ~init:0 ~f:(fun acc node ->
                  let delta =
                    if
                      remove_scan_state_from_ref_table t.refcount_table
                        node.scan_state
                    then 1
                    else 0
                  in
                  ignore
                  @@ remove_transition_from_inclusion_table t.inclusion_table
                       node.transition ;
                  acc + delta )
            in
            {num_removed= num_removed + extra_num_removed; is_added}
        | E (Best_tip_changed _, _) ->
            init )
    in
    if num_removed > 0 || is_added then
      Some
        { removed= num_removed
        ; refcount_table= t.refcount_table
        ; inclusion_table= t.inclusion_table }
    else None
end

include T
module Broadcasted = Functor.Make_broadcasted (T)
