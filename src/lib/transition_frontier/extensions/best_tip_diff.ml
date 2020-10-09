open Core_kernel
open Coda_base
open Frontier_base

module T = struct
  type t = {logger: Logger.t}

  type view =
    { new_commands: User_command.Valid.t With_status.t list
    ; removed_commands: User_command.Valid.t With_status.t list
    ; reorg_best_tip: bool }

  let create ~logger frontier =
    ( {logger}
    , { new_commands= Breadcrumb.commands (Full_frontier.root frontier)
      ; removed_commands= []
      ; reorg_best_tip= false } )

  (* Get the breadcrumbs that are on bc1's path but not bc2's, and vice versa.
     Ordered oldest to newest. *)
  let get_path_diff t frontier (bc1 : Breadcrumb.t) (bc2 : Breadcrumb.t) :
      Breadcrumb.t list * Breadcrumb.t list =
    let ancestor = Full_frontier.common_ancestor frontier bc1 bc2 in
    (* Find the breadcrumbs connecting t1 and t2, excluding t1. Precondition:
       t1 is an ancestor of t2. *)
    let path_from_to t1 t2 =
      let rec go cursor acc =
        if Breadcrumb.equal cursor t1 then acc
        else
          go
            (Full_frontier.find_exn frontier @@ Breadcrumb.parent_hash cursor)
            (cursor :: acc)
      in
      go t2 []
    in
    [%log' debug t.logger] !"Common ancestor: %{sexp: State_hash.t}" ancestor ;
    ( path_from_to (Full_frontier.find_exn frontier ancestor) bc1
    , path_from_to (Full_frontier.find_exn frontier ancestor) bc2 )

  let handle_diffs t frontier diffs_with_mutants : view option =
    let open Diff.Full.With_mutant in
    let view, should_broadcast =
      List.fold diffs_with_mutants
        ~init:
          ( {new_commands= []; removed_commands= []; reorg_best_tip= false}
          , false )
        ~f:
          (fun ( ({new_commands; removed_commands; reorg_best_tip= _} as acc)
               , should_broadcast ) -> function
          | E (Best_tip_changed new_best_tip, old_best_tip_hash) ->
              let new_best_tip_breadcrumb =
                Full_frontier.find_exn frontier new_best_tip
              in
              let old_best_tip =
                (*FIXME #4404*)
                Full_frontier.find_exn frontier old_best_tip_hash
              in
              let added_to_best_tip_path, removed_from_best_tip_path =
                get_path_diff t frontier new_best_tip_breadcrumb old_best_tip
              in
              [%log' debug t.logger]
                "added %d breadcrumbs and removed %d making path to new best \
                 tip"
                (List.length added_to_best_tip_path)
                (List.length removed_from_best_tip_path)
                ~metadata:
                  [ ( "new_breadcrumbs"
                    , `List
                        (List.map ~f:Breadcrumb.to_yojson
                           added_to_best_tip_path) )
                  ; ( "old_breadcrumbs"
                    , `List
                        (List.map ~f:Breadcrumb.to_yojson
                           removed_from_best_tip_path) ) ] ;
              let new_commands =
                List.bind added_to_best_tip_path ~f:Breadcrumb.commands
                @ new_commands
              in
              let removed_commands =
                List.bind removed_from_best_tip_path ~f:Breadcrumb.commands
                @ removed_commands
              in
              let reorg_best_tip =
                not (List.is_empty removed_from_best_tip_path)
              in
              ({new_commands; removed_commands; reorg_best_tip}, true)
          | E (New_node (Full _), _) -> (acc, should_broadcast)
          | E (Root_transitioned _, _) -> (acc, should_broadcast)
          | E (New_node (Lite _), _) -> failwith "impossible" )
    in
    Option.some_if should_broadcast view
end

include T
module Broadcasted = Functor.Make_broadcasted (T)
