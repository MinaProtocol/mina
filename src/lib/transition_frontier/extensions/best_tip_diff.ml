open Core_kernel
open Mina_base
open Frontier_base

module T = struct
  type t = { logger : Logger.t; best_tip_diff_logger : Logger.t }

  type view =
    { new_commands : User_command.Valid.t With_status.t list
    ; removed_commands : User_command.Valid.t With_status.t list
    ; reorg_best_tip : bool
    }

  module Log_event = struct
    type t =
      { protocol_state : Mina_state.Protocol_state.Value.t
      ; state_hash : State_hash.t
      ; just_emitted_a_proof : bool
      }
    [@@deriving yojson, sexp]

    let compare t t' = State_hash.compare t.state_hash t'.state_hash

    type Structured_log_events.t +=
      | New_best_tip_event of
          { added_transitions : t list
          ; removed_transitions : t list
          ; reorg_best_tip : bool
          }
      [@@deriving register_event { msg = "Formed a new best tip" }]
  end

  let breadcrumb_commands =
    Fn.compose Mina_block.Validated.valid_commands
      Breadcrumb.validated_transition

  let create ~logger frontier =
    let best_tip_diff_logger =
      Logger.create ~id:Logger.Logger_id.best_tip_diff ()
    in
    ( { logger; best_tip_diff_logger }
    , { new_commands = breadcrumb_commands (Full_frontier.root frontier)
      ; removed_commands = []
      ; reorg_best_tip = false
      } )

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
          ( { new_commands = []; removed_commands = []; reorg_best_tip = false }
          , false )
        ~f:
          (fun ( ({ new_commands; removed_commands; reorg_best_tip = _ } as acc)
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
              let new_commands =
                List.bind added_to_best_tip_path ~f:breadcrumb_commands
                @ new_commands
              in
              let removed_commands =
                List.bind removed_from_best_tip_path ~f:breadcrumb_commands
                @ removed_commands
              in
              let reorg_best_tip =
                not (List.is_empty removed_from_best_tip_path)
              in
              let added_transitions =
                List.map
                  ~f:(fun b ->
                    { Log_event.protocol_state = Breadcrumb.protocol_state b
                    ; state_hash = Breadcrumb.state_hash b
                    ; just_emitted_a_proof = Breadcrumb.just_emitted_a_proof b
                    })
                  added_to_best_tip_path
              in
              let removed_transitions =
                List.map
                  ~f:(fun b ->
                    { Log_event.protocol_state = Breadcrumb.protocol_state b
                    ; state_hash = Breadcrumb.state_hash b
                    ; just_emitted_a_proof = Breadcrumb.just_emitted_a_proof b
                    })
                  removed_from_best_tip_path
              in
              let event =
                Log_event.New_best_tip_event
                  { added_transitions; removed_transitions; reorg_best_tip }
              in
              [%str_log' debug t.logger]
                ~metadata:
                  [ ( "no_of_added_breadcrumbs"
                    , `Int (List.length added_to_best_tip_path) )
                  ; ( "no_of_removed_breadcrumbs"
                    , `Int (List.length removed_from_best_tip_path) )
                  ]
                event ;
              [%str_log' best_tip_diff t.best_tip_diff_logger] event ;
              ({ new_commands; removed_commands; reorg_best_tip }, true)
          | E (New_node (Full _), _) -> (acc, should_broadcast)
          | E (Root_transitioned _, _) -> (acc, should_broadcast))
    in
    Option.some_if should_broadcast view
end

include T
module Broadcasted = Functor.Make_broadcasted (T)
