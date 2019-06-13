open Core_kernel
open Async_kernel
open Coda_base
open Coda_state
open Pipe_lib

module Make (Inputs : Inputs.Inputs_intf) = struct
  open Inputs
  module Transition_frontier_base = Transition_frontier0.Make (Inputs)
  module Breadcrumb = Transition_frontier_base.Breadcrumb
  module Node = Transition_frontier_base.Node

  module Diff = struct
    type _ t =
      (* External transition of the node that is going on top of it *)
      | New_breadcrumb : Breadcrumb.t -> External_transition.Validated.t t
      (* External transition of the node that is going on top of it *)
      | Root_transitioned :
          { new_: Breadcrumb.t (* The nodes to remove excluding the old root *)
          ; garbage: Breadcrumb.t list }
          -> (* Remove the old Root *)
          External_transition.Validated.t t
      (* TODO: Mutant is just the old best tip *)
      | Best_tip_changed : Breadcrumb.t -> External_transition.Validated.t t

    type 'a diff_mutant = 'a t

    module E = struct
      type t = E : 'output diff_mutant -> t
    end
  end

  module Extensions = Extensions0.Make (struct
    module Diff = Diff
    module Transition_frontier = Transition_frontier_base
    include Inputs
  end)

  module Fake_db = struct
    include Coda_base.Ledger.Db

    type location = Location.t

    let get_or_create ledger key =
      let key, loc =
        match
          get_or_create_account_exn ledger key (Account.initialize key)
        with
        | `Existed, loc ->
            ([], loc)
        | `Added, loc ->
            ([key], loc)
      in
      (key, get ledger loc |> Option.value_exn, loc)
  end

  module TL = Coda_base.Transaction_logic.Make (Fake_db)

  type t =
    {transition_frontier: Transition_frontier_base.t; extensions: Extensions.t}

  let find_in_root_history {extensions; _} hash =
    let root_history =
      Extensions.Broadcast.Root_history.peek extensions.root_history
    in
    Extensions.Extensions.Root_history.View.lookup root_history hash

  let path_search t state_hash ~find ~f =
    let open Option.Let_syntax in
    let rec go state_hash =
      let%map breadcrumb = find t state_hash in
      let elem = f breadcrumb in
      match go (Breadcrumb.parent_hash breadcrumb) with
      | Some subresult ->
          Non_empty_list.cons elem subresult
      | None ->
          Non_empty_list.singleton elem
    in
    Option.map ~f:Non_empty_list.rev (go state_hash)

  let get_path_inclusively_in_root_history {extensions; _} state_hash ~f =
    let root_history =
      Extensions.Broadcast.Root_history.peek extensions.root_history
    in
    path_search root_history state_hash
      ~find:(fun root_history ->
        Extensions.Extensions.Root_history.View.lookup root_history )
      ~f

  let root_history_path_map t state_hash ~f =
    match
      path_search t.transition_frontier ~find:Transition_frontier_base.find ~f
        state_hash
    with
    | None ->
        get_path_inclusively_in_root_history t state_hash ~f
    | Some frontier_path ->
        let root_history_path =
          let root_breadcrumb =
            Transition_frontier_base.root t.transition_frontier
          in
          get_path_inclusively_in_root_history t
            (Breadcrumb.parent_hash root_breadcrumb)
            ~f
        in
        Some
          (Option.value_map root_history_path ~default:frontier_path
             ~f:(fun root_history ->
               Non_empty_list.append root_history frontier_path ))

  let length_at_transition (transition_frontier : Transition_frontier_base.t)
      hash =
    Option.map (Coda_base.State_hash.Table.find transition_frontier.table hash)
      ~f:(fun (node : Node.t) -> node.length)

  let calculate_diffs (transition_frontier : Transition_frontier_base.t)
      breadcrumb =
    O1trace.measure "calculate_diffs" (fun () ->
        let logger = transition_frontier.logger in
        let hash =
          With_hash.hash (Breadcrumb.transition_with_hash breadcrumb)
        in
        let root = Transition_frontier_base.root transition_frontier in
        let new_breadcrumb_diff = Diff.New_breadcrumb breadcrumb in
        let best_tip_breadcrumb =
          Transition_frontier_base.best_tip transition_frontier
        in
        let new_best_tip_diff =
          match
            Consensus.Hooks.select
              ~existing:(Breadcrumb.consensus_state best_tip_breadcrumb)
              ~candidate:(Breadcrumb.consensus_state breadcrumb)
              ~logger:
                (Logger.extend logger
                   [ ( "selection_context"
                     , `String "comparing new breadcrumb to best tip" ) ])
          with
          | `Keep ->
              None
          | `Take ->
              Some (Diff.Best_tip_changed breadcrumb)
        in
        let new_breadcrumb_length =
          Option.value_exn (length_at_transition transition_frontier hash) + 1
        in
        let root_length =
          Option.value_exn
            (length_at_transition transition_frontier
               (Breadcrumb.state_hash root))
        in
        let distance_to_root = new_breadcrumb_length - root_length in
        let root_transitioned_diff =
          if distance_to_root > max_length then (
            Logger.info logger ~module_:__MODULE__ ~location:__LOC__
              !"Distance to parent: %d exceeded max_lenth %d"
              distance_to_root max_length ;
            let heir_hash =
              List.hd_exn
                (Transition_frontier_base.hash_path transition_frontier
                   breadcrumb)
            in
            let bad_children =
              List.filter
                (Transition_frontier_base.successors transition_frontier root)
                ~f:(fun breadcrumb ->
                  not
                  @@ State_hash.equal heir_hash
                       (Breadcrumb.state_hash breadcrumb) )
            in
            let bad_children_descendants =
              List.bind bad_children
                ~f:
                  (Transition_frontier_base.successors_rec transition_frontier)
            in
            let total_garbage = bad_children @ bad_children_descendants in
            let yojson_breadcrumb =
              Fn.compose State_hash.to_yojson Breadcrumb.state_hash
            in
            Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
              ~metadata:
                [ ( "bad_children"
                  , `List (List.map bad_children ~f:yojson_breadcrumb) )
                ; ("length_of_garbage", `Int (List.length total_garbage))
                ; ( "bad_children_descendants"
                  , `List
                      (List.map bad_children_descendants ~f:yojson_breadcrumb)
                  )
                ; ( "local_state"
                  , Consensus.Data.Local_state.to_yojson
                      (Transition_frontier_base.consensus_local_state
                         transition_frontier) ) ]
              "collecting $length_of_garbage nodes rooted from $bad_hashes" ;
            Some (Diff.Root_transitioned {new_= root; garbage= bad_children}) )
          else None
        in
        Diff.E.E new_breadcrumb_diff
        :: List.filter_opt
             [ Option.map new_best_tip_diff ~f:(fun diff -> Diff.E.E diff)
             ; Option.map root_transitioned_diff ~f:(fun diff -> Diff.E.E diff)
             ] )

  let attach_node_to (t : Transition_frontier_base.t) ~(parent_node : Node.t)
      ~(node : Node.t) =
    let hash = Breadcrumb.state_hash (Node.breadcrumb node) in
    let parent_hash = Breadcrumb.state_hash parent_node.breadcrumb in
    if
      not
        (State_hash.equal parent_hash (Breadcrumb.parent_hash node.breadcrumb))
    then
      failwith
        "invalid call to attach_to: hash parent_node <> parent_hash node" ;
    (* We only want to update the parent node if we don't have a dupe *)
    Hashtbl.change t.table hash ~f:(function
      | Some x ->
          Logger.warn t.logger ~module_:__MODULE__ ~location:__LOC__
            ~metadata:[("state_hash", State_hash.to_yojson hash)]
            "attach_node_to with breadcrumb for state $state_hash already \
             present; catchup scheduler bug?" ;
          Some x
      | None ->
          Hashtbl.set t.table ~key:parent_hash
            ~data:
              { parent_node with
                successor_hashes= hash :: parent_node.successor_hashes } ;
          Some node )

  let attach_breadcrumb_exn (t : Transition_frontier_base.t) breadcrumb =
    let hash = Breadcrumb.state_hash breadcrumb in
    let parent_hash = Breadcrumb.parent_hash breadcrumb in
    let parent_node =
      Option.value_exn
        (Hashtbl.find t.table parent_hash)
        ~error:
          (Error.of_exn
             (Transition_frontier_base.Parent_not_found
                (`Parent parent_hash, `Target hash)))
    in
    let node =
      {Node.breadcrumb; successor_hashes= []; length= parent_node.length + 1}
    in
    attach_node_to t ~parent_node ~node ;
    (* TODO: This should probably be in consensus_state  *)
    Debug_assert.debug_assert (fun () ->
        (* if the proof verified, then this should always hold*)
        assert (
          Consensus.Hooks.select
            ~existing:(Breadcrumb.consensus_state parent_node.breadcrumb)
            ~candidate:(Breadcrumb.consensus_state breadcrumb)
            ~logger:
              (Logger.extend t.logger
                 [ ( "selection_context"
                   , `String "debug_assert that child is preferred over parent"
                   ) ])
          = `Take ) )

  (** Given:
   *
   *        o                   o
   *       /                   /
   *    o ---- o --------------
   *    t  \ soon_to_be_root   \
   *        o                   o
   *                        children
   *
   *  Delegates up to Staged_ledger reparent and makes the
   *  modifies the heir's staged-ledger and sets the heir as the new root.
   *  Modifications are in-place
  *)
  let move_root (transition_frontier : Transition_frontier_base.t)
      (soon_to_be_root_node : Node.t) : Node.t =
    (* TODO: decompose this to new root and old root *)
    let root_node =
      Hashtbl.find_exn transition_frontier.table transition_frontier.root
    in
    let root_breadcrumb = root_node.breadcrumb in
    let root = root_breadcrumb |> Breadcrumb.staged_ledger in
    let soon_to_be_root =
      soon_to_be_root_node.breadcrumb |> Breadcrumb.staged_ledger
    in
    let children =
      List.map soon_to_be_root_node.successor_hashes ~f:(fun h ->
          (Hashtbl.find_exn transition_frontier.table h).breadcrumb
          |> Breadcrumb.staged_ledger |> Staged_ledger.ledger )
    in
    let root_ledger = Staged_ledger.ledger root in
    let soon_to_be_root_ledger = Staged_ledger.ledger soon_to_be_root in
    let soon_to_be_root_merkle_root =
      Ledger.merkle_root soon_to_be_root_ledger
    in
    Ledger.commit soon_to_be_root_ledger ;
    let root_ledger_merkle_root_after_commit =
      Ledger.merkle_root root_ledger
    in
    [%test_result: Ledger_hash.t]
      ~message:
        "Merkle root of soon-to-be-root before commit, is same as root \
         ledger's merkle root afterwards"
      ~expect:soon_to_be_root_merkle_root root_ledger_merkle_root_after_commit ;
    let new_root =
      Breadcrumb.create soon_to_be_root_node.breadcrumb.transition_with_hash
        (Staged_ledger.replace_ledger_exn soon_to_be_root root_ledger)
    in
    let new_root_node = {soon_to_be_root_node with breadcrumb= new_root} in
    let new_root_hash =
      soon_to_be_root_node.breadcrumb.transition_with_hash.hash
    in
    Ledger.remove_and_reparent_exn soon_to_be_root_ledger
      soon_to_be_root_ledger ~children ;
    Hashtbl.remove transition_frontier.table transition_frontier.root ;
    Hashtbl.set transition_frontier.table ~key:new_root_hash
      ~data:new_root_node ;
    transition_frontier.root <- new_root_hash ;
    new_root_node

  let apply_diff (transition_frontier : Transition_frontier_base.t) = function
    | Diff.E.E (New_breadcrumb new_breadcrumb) ->
        attach_breadcrumb_exn transition_frontier new_breadcrumb
    | Diff.E.E (Best_tip_changed new_best_tip_breadcrumb) ->
        transition_frontier.best_tip
        <- Breadcrumb.state_hash new_best_tip_breadcrumb
    | Diff.E.E (Root_transitioned {new_; garbage}) -> (
        (* TODO: probably divide this up *)
        let old_consensus_state =
          Transition_frontier_base.consensus_local_state transition_frontier
        in
        let old_best_tip =
          Transition_frontier_base.best_tip transition_frontier
        in
        let old_root = Transition_frontier_base.root transition_frontier in
        let local_state_before_adding_breadcrumb =
          Consensus.Hooks.required_local_state_sync
            ~consensus_state:(Breadcrumb.consensus_state old_best_tip)
            ~local_state:old_consensus_state
          |> Option.is_none
        in
        (* 4.III Unregister staged ledger *)
        let old_root_staged_ledger = Breadcrumb.staged_ledger old_root in
        let old_root_ledger = Staged_ledger.ledger old_root_staged_ledger in
        (* TODO: Seperate bad root child nodes with descendants of the garbage on diff *)
        List.iter garbage ~f:(fun bad ->
            ignore
              (Ledger.unregister_mask_exn old_root_ledger
                 (Staged_ledger.ledger @@ Breadcrumb.staged_ledger bad)) ) ;
        let heir_node =
          Hashtbl.find_exn transition_frontier.table
            (Breadcrumb.state_hash new_)
        in
        let new_root_node = move_root transition_frontier heir_node in
        let new_root_staged_ledger =
          Breadcrumb.staged_ledger new_root_node.breadcrumb
        in
        Consensus.Hooks.frontier_root_transition
          (Breadcrumb.consensus_state old_root)
          (Breadcrumb.consensus_state new_)
          ~local_state:transition_frontier.consensus_local_state
          ~snarked_ledger:
            (Coda_base.Ledger.Any_ledger.cast
               (module Coda_base.Ledger.Db)
               transition_frontier.root_snarked_ledger) ;
        Debug_assert.debug_assert (fun () ->
            (* After the lock transition, if the local_state was previously synced, it should continue to be synced *)
            match
              Consensus.Hooks.required_local_state_sync
                ~consensus_state:
                  (Breadcrumb.consensus_state
                     (Hashtbl.find_exn transition_frontier.table
                        transition_frontier.best_tip)
                       .breadcrumb)
                ~local_state:transition_frontier.consensus_local_state
            with
            | Some jobs ->
                (* But if there wasn't sync work to do when we started, then there shouldn't be now. *)
                (* TODO: get old local_state_was_synced *)
                if local_state_before_adding_breadcrumb then (
                  Logger.fatal transition_frontier.logger
                    "after lock transition, the best tip consensus state is \
                     out of sync with the local state -- bug in either \
                     required_local_state_sync or frontier_root_transition."
                    ~module_:__MODULE__ ~location:__LOC__
                    ~metadata:
                      [ ( "sync_jobs"
                        , `List
                            ( Non_empty_list.to_list jobs
                            |> List.map
                                 ~f:Consensus.Hooks.local_state_sync_to_yojson
                            ) )
                      ; ( "local_state"
                        , Consensus.Data.Local_state.to_yojson
                            transition_frontier.consensus_local_state )
                      ; ( "tf_viz"
                        , `String
                            (Transition_frontier_base.visualize_to_string
                               transition_frontier) ) ] ;
                  assert false )
            | None ->
                () ) ;
        match
          ( Staged_ledger.proof_txns new_root_staged_ledger
          , heir_node.breadcrumb.just_emitted_a_proof )
        with
        | Some txns, true ->
            let proof_data =
              Staged_ledger.current_ledger_proof new_root_staged_ledger
              |> Option.value_exn
            in
            [%test_result: Frozen_ledger_hash.t]
              ~message:
                "Root snarked ledger hash should be the same as the source \
                 hash in the proof that was just emitted"
              ~expect:(Ledger_proof.statement proof_data).source
              ( Ledger.Db.merkle_root transition_frontier.root_snarked_ledger
              |> Frozen_ledger_hash.of_ledger_hash ) ;
            let db_mask =
              Ledger.of_database transition_frontier.root_snarked_ledger
            in
            Non_empty_list.iter txns ~f:(fun txn ->
                (* TODO: @cmr use the ignore-hash ledger here as well *)
                TL.apply_transaction transition_frontier.root_snarked_ledger
                  txn
                |> Or_error.ok_exn |> ignore ) ;
            (* TODO: See issue #1606 to make this faster *)
            Ledger.commit db_mask ;
            ignore
              (Ledger.Maskable.unregister_mask_exn
                 (Ledger.Any_ledger.cast
                    (module Ledger.Db)
                    transition_frontier.root_snarked_ledger)
                 db_mask)
        | _, false | None, _ ->
            () )

  let add_breadcrumb_exn {transition_frontier; extensions} breadcrumb =
    let diffs = calculate_diffs transition_frontier breadcrumb in
    let%bind () = Extensions.update_all extensions transition_frontier diffs in
    List.iter diffs ~f:(apply_diff transition_frontier) ;
    Deferred.unit

  let add_breadcrumb_if_ t breadcrumb =
    let parent_hash = Breadcrumb.parent_hash breadcrumb in
    match Hashtbl.find t.transition_frontier.table parent_hash with
    | Some _ ->
        add_breadcrumb_exn t breadcrumb
    | None ->
        Logger.warn t.transition_frontier.logger ~module_:__MODULE__
          ~location:__LOC__
          !"When trying to add breadcrumb, its parent had been removed from \
            transition frontier: %{sexp: State_hash.t}"
          parent_hash ;
        Deferred.unit

  let find_in_root_history t hash =
    let root_history =
      Extensions.Broadcast.Root_history.peek t.extensions.root_history
    in
    Extensions.Extensions.Root_history.View.lookup root_history hash

  (** Methods from transition_frontier_base are added to the last parts of the module to prevent shadowing of modules from base and give other developers an idea *)
  module Transition_frontier_base_methods = struct
    open Transition_frontier_base

    let max_length = max_length

    let consensus_local_state {transition_frontier; _} =
      consensus_local_state transition_frontier

    let all_breadcrumbs {transition_frontier; _} =
      all_breadcrumbs transition_frontier

    let root {transition_frontier; _} = root transition_frontier

    let root_length {transition_frontier; _} = root_length transition_frontier

    let best_tip {transition_frontier; _} = best_tip transition_frontier

    let path_map {transition_frontier; _} = path_map transition_frontier

    let find {transition_frontier; _} = find transition_frontier

    let successor_hashes {transition_frontier; _} =
      successor_hashes transition_frontier

    let successor_hashes_rec {transition_frontier; _} =
      successor_hashes_rec transition_frontier

    let successors {transition_frontier; _} = successors transition_frontier

    let successors_rec {transition_frontier; _} =
      successors_rec transition_frontier

    let common_ancestor {transition_frontier; _} =
      common_ancestor transition_frontier

    let iter {transition_frontier; _} = iter transition_frontier

    let best_tip_path_length_exn {transition_frontier; _} =
      best_tip_path_length_exn transition_frontier

    let shallow_copy_root_snarked_ledger {transition_frontier; _} =
      shallow_copy_root_snarked_ledger transition_frontier
  end

  include Transition_frontier_base_methods

  module For_tests = struct
    let root_snarked_ledger {transition_frontier; _} =
      transition_frontier.root_snarked_ledger

    let root_history_mem {extensions; _} hash =
      let root_history =
        Extensions.Broadcast.Root_history.peek extensions.root_history
      in
      Extensions.Extensions.Root_history.View.mem root_history hash

    let root_history_is_empty {extensions; _} =
      let root_history =
        Extensions.Broadcast.Root_history.peek extensions.root_history
      in
      Extensions.Extensions.Root_history.View.is_empty root_history
  end
end
