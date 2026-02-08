open Core_kernel
open Mina_base
open Frontier_base

module T = struct
  type t = { logger : Logger.t; best_tip_diff_logger : Logger.t }

  type view =
    { new_commands :
        Mina_transaction.Transaction_hash.User_command_with_valid_signature.t
        With_status.t
        list
    ; removed_commands :
        Mina_transaction.Transaction_hash.User_command_with_valid_signature.t
        With_status.t
        list
    ; reorg_best_tip : bool
    }

  let name = "best_tip_diff"

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

  let create ~logger frontier =
    let best_tip_diff_logger =
      Logger.create ~id:Logger.Logger_id.best_tip_diff ()
    in
    ( { logger; best_tip_diff_logger }
    , { new_commands =
          Breadcrumb.valid_commands_hashed (Full_frontier.root frontier)
      ; removed_commands = []
      ; reorg_best_tip = false
      } )

  let find_in_frontier ~message frontier hash =
    Full_frontier.find frontier hash
    |> Option.value_map ~default:(Error (hash, message)) ~f:Result.return

  (* Get the breadcrumbs that are on bc1's path but not bc2's, and vice versa.
     Ordered oldest to newest. *)
  let get_path_diff t frontier (bc1 : Breadcrumb.t) (bc2 : Breadcrumb.t) :
      (Breadcrumb.t list * Breadcrumb.t list, _) Result.t =
    let%bind.Result ancestor_hash =
      Full_frontier.common_ancestor frontier bc1 bc2
      |> Result.map_error
           ~f:(fun (`Parent_not_found (hash, `Parent parent_hash)) ->
             ( parent_hash
             , sprintf
                 "finding common ancestor for %s and %s: parent for %s not \
                  found"
                 (State_hash.to_base58_check @@ Breadcrumb.state_hash bc1)
                 (State_hash.to_base58_check @@ Breadcrumb.state_hash bc2)
                 (State_hash.to_base58_check hash) ) )
    in
    (* Find the breadcrumbs connecting t1 and t2, excluding t1. Precondition:
       t1 is an ancestor of t2. *)
    let path_from_to t1 t2 =
      let rec go cursor acc =
        if Breadcrumb.equal cursor t1 then Result.return acc
        else
          let parent_hash = Breadcrumb.parent_hash cursor in
          let%bind.Result parent =
            match Full_frontier.find frontier parent_hash with
            | Some parent ->
                Result.return parent
            | None ->
                Result.fail
                  ( parent_hash
                  , sprintf
                      "finding path from %s to %s: parent for %s not found"
                      (State_hash.to_base58_check @@ Breadcrumb.state_hash t1)
                      (State_hash.to_base58_check @@ Breadcrumb.state_hash t2)
                      ( State_hash.to_base58_check
                      @@ Breadcrumb.state_hash cursor ) )
          in
          go parent (cursor :: acc)
      in
      go t2 []
    in
    let%bind.Result ancestor =
      find_in_frontier ~message:"ancestor not found in frontier" frontier
        ancestor_hash
    in
    [%log' debug t.logger]
      !"Common ancestor: %{sexp: State_hash.t}"
      ancestor_hash ;
    let%bind.Result path1 = path_from_to ancestor bc1 in
    let%map.Result path2 = path_from_to ancestor bc2 in
    (path1, path2)

  let load_paths ~new_best_tip_hash ~old_best_tip_hash t frontier =
    let%bind.Result new_best_tip =
      find_in_frontier ~message:"new best tip not found in frontier" frontier
        new_best_tip_hash
    in
    let%bind.Result old_best_tip =
      (*FIXME #4404*)
      find_in_frontier ~message:"old best tip not found in frontier" frontier
        old_best_tip_hash
    in
    get_path_diff t frontier new_best_tip old_best_tip

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
            | E (Best_tip_changed new_best_tip_hash, old_best_tip_hash) ->
                let added_to_best_tip_path, removed_from_best_tip_path =
                  load_paths ~new_best_tip_hash ~old_best_tip_hash t frontier
                  |> Result.map_error ~f:(fun (hash, message) ->
                         Error.of_string
                         @@ sprintf
                              "failed to retrieve hash %s from frontier in \
                               best_tip_diff extension: %s"
                              (State_hash.to_base58_check hash)
                              message )
                  |> Or_error.ok_exn
                in
                let new_commands =
                  List.bind added_to_best_tip_path
                    ~f:Breadcrumb.valid_commands_hashed
                  @ new_commands
                in
                let removed_commands =
                  List.bind removed_from_best_tip_path
                    ~f:Breadcrumb.valid_commands_hashed
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
                      } )
                    added_to_best_tip_path
                in
                let removed_transitions =
                  List.map
                    ~f:(fun b ->
                      { Log_event.protocol_state = Breadcrumb.protocol_state b
                      ; state_hash = Breadcrumb.state_hash b
                      ; just_emitted_a_proof = Breadcrumb.just_emitted_a_proof b
                      } )
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
            | E (New_node (Full _), _) ->
                (acc, should_broadcast)
            | E (Root_transitioned _, _) ->
                (acc, should_broadcast) )
    in
    Option.some_if should_broadcast view
end

include T
module Broadcasted = Functor.Make_broadcasted (T)
