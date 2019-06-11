open Async_kernel
open Core_kernel
open Coda_base
open Pipe_lib

module Make (Inputs : sig
  include Inputs.Inputs_intf

  module Transition_frontier :
    Coda_intf.Transition_frontier_base0_intf
    with type mostly_validated_external_transition :=
                ( [`Time_received] * Truth.true_t
                , [`Proof] * Truth.true_t
                , [`Frontier_dependencies] * Truth.true_t
                , [`Staged_ledger_diff] * Truth.false_t )
                External_transition.Validation.with_transition
     and type external_transition_validated := External_transition.Validated.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type verifier := Verifier.t

  module Breadcrumb = Transition_frontier.Breadcrumb

  module Mutant : sig
    module Root : sig
      (** Data representing the root of a transition frontier. 'root can either be an external_transition with hash or a state_hash  *)
      module Poly : sig
        type ('root, 'scan_state, 'pending_coinbase) t =
          { root: 'root
          ; scan_state: 'scan_state
          ; pending_coinbase: 'pending_coinbase }
      end

      type 'root t =
        ('root, Staged_ledger.Scan_state.t, Pending_coinbase.t) Poly.t
    end

    module Best_tip_changed : sig
      type t =
        { previous: External_transition.Validated.t
        ; new_: External_transition.Validated.t }
    end
  end

  module Diff : sig
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

    module E : sig
      type t = E : 'output diff_mutant -> t
    end
  end
end) =
struct
  (* Have to treat functor Transition_frontier as Inputs.Transition_frontier *)
  (* Invariant: No mutations are allowed to the transition_frontier on the transactions *)
  open Inputs

  module Root_history = struct
    module Queue = Hash_queue.Make (State_hash)

    type t = {history: Breadcrumb.t Queue.t; capacity: int}

    let create capacity =
      let history = Queue.create () in
      {history; capacity}

    let lookup {history; _} = Queue.lookup history

    let mem {history; _} = Queue.mem history

    let enqueue {history; capacity} breadcrumb =
      if Queue.length history >= capacity then
        Queue.dequeue_front_exn history |> ignore ;
      Queue.enqueue_back history (Breadcrumb.state_hash breadcrumb) breadcrumb
      |> ignore

    let is_empty {history; _} = Queue.is_empty history
  end

  module Extensions = struct
    module type Base_ext_intf = sig
      type t

      type view

      val create : Breadcrumb.t -> t * view

      val handle_diffs :
           t
        -> Inputs.Transition_frontier.t
        -> Diff.E.t list
        -> view Deferred.Option.t
    end

    module type Broadcast_extension_intf = sig
      type t

      val create : Breadcrumb.t -> t

      val update :
        t -> Inputs.Transition_frontier.t -> Diff.E.t list -> unit Deferred.t
    end

    module Broadcast_extension (Ext : Base_ext_intf) :
      Broadcast_extension_intf = struct
      type t =
        { t: Ext.t
        ; writer: Ext.view Broadcast_pipe.Writer.t
        ; reader: Ext.view Broadcast_pipe.Reader.t }

      let create breadcrumb =
        let t, initial_view = Ext.create breadcrumb in
        let reader, writer = Broadcast_pipe.create initial_view in
        {t; reader; writer}

      let update {t; writer; _} transition_frontier diffs =
        match%bind Ext.handle_diffs t transition_frontier diffs with
        | Some view ->
            Broadcast_pipe.Writer.write writer view
        | None ->
            Deferred.unit
    end

    module Root_history = struct
      type t = Root_history.t

      module View : sig
        type t = private Root_history.t

        val lookup : t -> State_hash.t -> Breadcrumb.t option

        val of_root_history : Root_history.t -> t
      end = struct
        include Root_history

        let of_root_history = Fn.id
      end

      type view = View.t

      let create breadcrumb =
        let root_history =
          Root_history.create (2 * Inputs.Transition_frontier.max_length)
        in
        Root_history.enqueue root_history breadcrumb ;
        (root_history, View.of_root_history root_history)

      let handle_diffs root_history transition_frontier diffs =
        let should_produce_view =
          List.exists diffs ~f:(function
            | Diff.E.E (Diff.Root_transitioned _) ->
                Root_history.enqueue root_history
                  (Inputs.Transition_frontier.root transition_frontier) ;
                true
            | Diff.E.E _ ->
                false )
        in
        Deferred.return
        @@ Option.some_if should_produce_view
        @@ View.of_root_history root_history
    end

    module Snark_pool_refcount = struct
      module Work = Inputs.Transaction_snark_work.Statement

      type t = int Work.Table.t

      type view = int * int Work.Table.t

      type input = unit

      let get_work (breadcrumb : Breadcrumb.t) : Work.t Sequence.t =
        let staged_ledger =
          Inputs.Transition_frontier.Breadcrumb.staged_ledger breadcrumb
        in
        let scan_state = Inputs.Staged_ledger.scan_state staged_ledger in
        let work_to_do =
          Inputs.Staged_ledger.Scan_state.all_work_to_do scan_state
        in
        Or_error.ok_exn work_to_do

      (** Returns true if this update changed which elements are in the table
          (but not if the same elements exist with a different reference count) *)
      let add_breadcrumb_to_ref_table table breadcrumb : bool =
        Sequence.fold ~init:false (get_work breadcrumb) ~f:(fun acc work ->
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
        Sequence.fold (get_work breadcrumb) ~init:false ~f:(fun acc work ->
            match Work.Table.find table work with
            | Some 1 ->
                Work.Table.remove table work ;
                true
            | Some v ->
                Work.Table.set table ~key:work ~data:(v - 1) ;
                acc
            | None ->
                failwith "Removed a breadcrumb we didn't know about" )

      let create breadcrumb =
        let t = Work.Table.create () in
        let (_ : bool) = add_breadcrumb_to_ref_table t breadcrumb in
        (t, (0, t))

      type diff_update = {num_removed: int; is_added: bool}

      let handle_diffs t transition_frontier diffs =
        let {num_removed; is_added} =
          List.fold diffs ~init:{num_removed= 0; is_added= false}
            ~f:(fun ({num_removed; is_added} as init) -> function
            | Diff.E.E (New_breadcrumb breadcrumb) ->
                { num_removed
                ; is_added=
                    is_added || add_breadcrumb_to_ref_table t breadcrumb }
            | Diff.E.E (Root_transitioned {new_= _; garbage}) ->
                let extra_num_removed =
                  List.fold ~init:0
                    ~f:(fun acc bc ->
                      acc
                      + if remove_breadcrumb_from_ref_table t bc then 1 else 0
                      )
                    garbage
                in
                {num_removed= num_removed + extra_num_removed; is_added}
            | Diff.E.E (Best_tip_changed _) ->
                init )
        in
        Deferred.return
          (if num_removed > 0 || is_added then Some (num_removed, t) else None)
    end

    module Best_tip_diff = struct
      type t = unit

      type input = unit

      type view =
        { new_user_commands: User_command.t list
        ; removed_user_commands: User_command.t list }

      let create breadcrumb =
        ( ()
        , { new_user_commands= Breadcrumb.to_user_commands breadcrumb
          ; removed_user_commands= [] } )

      let common_ancestor (t : Inputs.Transition_frontier.t)
          (bc1 : Breadcrumb.t) (bc2 : Breadcrumb.t) : State_hash.t =
        let rec go ancestors1 ancestors2 sh1 sh2 =
          Hash_set.add ancestors1 sh1 ;
          Hash_set.add ancestors2 sh2 ;
          if Hash_set.mem ancestors1 sh2 then sh2
          else if Hash_set.mem ancestors2 sh1 then sh1
          else
            let open Inputs.Transition_frontier in
            let parent_unless_root sh =
              if State_hash.equal sh (Breadcrumb.state_hash @@ root t) then sh
              else Breadcrumb.parent_hash (find_exn t sh)
            in
            go ancestors1 ancestors2 (parent_unless_root sh1)
              (parent_unless_root sh2)
        in
        go
          (Hash_set.create (module State_hash) ())
          (Hash_set.create (module State_hash) ())
          (Breadcrumb.state_hash bc1)
          (Breadcrumb.state_hash bc2)

      (* TODO: Might be an error *)
      (* Get the breadcrumbs that are on bc1's path but not bc2's, and vice versa.
         Ordered oldest to newest.
      *)
      let get_path_diff t (bc1 : Breadcrumb.t) (bc2 : Breadcrumb.t) :
          Breadcrumb.t list * Breadcrumb.t list =
        let ancestor = common_ancestor t bc1 bc2 in
        (* Find the breadcrumbs connecting bc1 and bc2, excluding bc1. Precondition:
           bc1 is an ancestor of bc2. *)
        let open Inputs.Transition_frontier in
        let path_from_to bc1 bc2 =
          let rec go cursor acc =
            if Breadcrumb.equal cursor bc1 then acc
            else
              go (find_exn t @@ Breadcrumb.parent_hash cursor) (cursor :: acc)
          in
          go bc2 []
        in
        Logger.debug (logger t) ~module_:__MODULE__ ~location:__LOC__
          !"Common ancestor: %{sexp: State_hash.t}"
          ancestor ;
        ( path_from_to (find_exn t ancestor) bc1
        , path_from_to (find_exn t ancestor) bc2 )

      let handle_diffs () transition_frontier diffs : view Deferred.Option.t =
        let old_best_tip =
          Inputs.Transition_frontier.best_tip transition_frontier
        in
        let view, _, should_broadcast =
          List.fold diffs
            ~init:
              ( {new_user_commands= []; removed_user_commands= []}
              , old_best_tip
              , false )
            ~f:
              (fun ( ({new_user_commands; removed_user_commands} as acc)
                   , old_best_tip
                   , should_broadcast ) -> function
              | Diff.E.E (Best_tip_changed new_best_tip_breadcrumb) ->
                  (* TODO: probably do not use state_hash and use breadcrumb *)
                  let added_to_best_tip_path, removed_from_best_tip_path =
                    get_path_diff transition_frontier new_best_tip_breadcrumb
                      old_best_tip
                  in
                  Logger.debug
                    (Transition_frontier.logger transition_frontier)
                    ~module_:__MODULE__ ~location:__LOC__
                    "added %d breadcrumbs and removed %d making path to new \
                     best tip"
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
                  let new_user_commands =
                    List.bind added_to_best_tip_path
                      ~f:Breadcrumb.to_user_commands
                    @ new_user_commands
                  in
                  let removed_user_commands =
                    List.bind removed_from_best_tip_path
                      ~f:Breadcrumb.to_user_commands
                    @ removed_user_commands
                  in
                  ( {new_user_commands; removed_user_commands}
                  , new_best_tip_breadcrumb
                  , true ) | Diff.E.E (New_breadcrumb _) ->
                  (acc, old_best_tip, should_broadcast)
              | Diff.E.E (Root_transitioned _) ->
                  (acc, old_best_tip, should_broadcast) )
        in
        Deferred.return @@ Option.some_if should_broadcast view
    end

    module Broadcast = struct
      module Root_history = Broadcast_extension (Root_history)
      module Snark_pool_refcount = Broadcast_extension (Snark_pool_refcount)
      module Best_tip_diff = Broadcast_extension (Best_tip_diff)
    end

    type t =
      { snark_pool_refcount: Broadcast.Snark_pool_refcount.t
      ; root_history: Broadcast.Root_history.t
      ; best_tip_diff: Broadcast.Best_tip_diff.t }
    [@@deriving fields]

    let update_all (t : t) transition_frontier diffs =
      let run_update (type t)
          (module Broadcast : Broadcast_extension_intf with type t = t)
          (deferred_unit : unit Deferred.t) field =
        let%bind () = deferred_unit in
        let extension = Field.get field t in
        Broadcast.update extension transition_frontier diffs
      in
      let open Broadcast in
      Fields.fold ~init:Deferred.unit
        ~snark_pool_refcount:(run_update (module Snark_pool_refcount))
        ~root_history:(run_update (module Root_history))
        ~best_tip_diff:(run_update (module Best_tip_diff))
  end

  let consensus_state_of_breadcrumb b =
    Breadcrumb.transition_with_hash b
    |> With_hash.data |> External_transition.Validated.protocol_state
    |> Coda_state.Protocol_state.consensus_state

  let calculate_diffs transition_frontier breadcrumb =
    let open Inputs.Transition_frontier in
    O1trace.measure "calculate_diffs" (fun () ->
        let logger = logger transition_frontier in
        let hash =
          With_hash.hash (Breadcrumb.transition_with_hash breadcrumb)
        in
        let root = root transition_frontier in
        let new_breadcrumb_diff = Diff.New_breadcrumb breadcrumb in
        let best_tip_breadcrumb = best_tip transition_frontier in
        let new_best_tip_diff =
          match
            Consensus.Hooks.select
              ~existing:(consensus_state_of_breadcrumb best_tip_breadcrumb)
              ~candidate:(consensus_state_of_breadcrumb breadcrumb)
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
          if distance_to_root > Transition_frontier.max_length then (
            Logger.info logger ~module_:__MODULE__ ~location:__LOC__
              !"Distance to parent: %d exceeded max_lenth %d"
              distance_to_root max_length ;
            let heir_hash =
              List.hd_exn (hash_path transition_frontier breadcrumb)
            in
            let bad_children =
              List.filter
                (Transition_frontier.successors transition_frontier root)
                ~f:(fun breadcrumb ->
                  not
                  @@ State_hash.equal heir_hash
                       (Breadcrumb.state_hash breadcrumb) )
            in
            let bad_children_descendants =
              List.bind bad_children ~f:(successors_rec transition_frontier)
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
                      (Transition_frontier.consensus_local_state
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

  let add_breadcrumb_exn t breadcrumb =
    let open Inputs.Transition_frontier in
    let old_consensus_state = Transition_frontier.consensus_local_state t in
    let old_best_tip = best_tip t in
    let old_root = Transition_frontier.root t in
    let diffs = calculate_diffs t breadcrumb in
    List.iter diffs ~f:(function
      | Diff.E.E (New_breadcrumb breadcrumb) ->
          attach_breadcrumb_exn t breadcrumb
      | Diff.E.E (Best_tip_changed new_breadcrumb) ->
          t.best_tip <- Breadcrumb.state_hash new_breadcrumb
      | Diff.E.E (Root_transitioned {new_; garbage}) ->
          (* 4.III Unregister staged ledger *)
          let root_staged_ledger = Breadcrumb.staged_ledger old_root in
          let root_ledger = Staged_ledger.ledger root_staged_ledger in
          (* TODO: Seperate bad root child nodes with descendants of the garbage on diff *)
          List.iter garbage ~f:(fun bad ->
              ignore
                (Ledger.unregister_mask_exn root_ledger
                   (Staged_ledger.ledger @@ Breadcrumb.staged_ledger bad)) ) ;
          (* TODO: replace with new_ *)
          let new_root_node = move_root t heir_node in
          let new_root_staged_ledger =
            Breadcrumb.staged_ledger new_root_node.breadcrumb
          in
          Consensus.Hooks.frontier_root_transition
            (consensus_state_of_breadcrumb old_root)
            (consensus_state_of_breadcrumb new_)
            ~local_state:t.consensus_local_state
            ~snarked_ledger:
              (Coda_base.Ledger.Any_ledger.cast
                 (module Coda_base.Ledger.Db)
                 t.root_snarked_ledger) ;
          Debug_assert.debug_assert (fun () ->
              (* After the lock transition, if the local_state was previously synced, it should continue to be synced *)
              match
                Consensus.Hooks.required_local_state_sync
                  ~consensus_state:
                    (consensus_state_of_breadcrumb
                       (Hashtbl.find_exn t.table t.best_tip).breadcrumb)
                  ~local_state:t.consensus_local_state
              with
              | Some jobs ->
                  (* But if there wasn't sync work to do when we started, then there shouldn't be now. *)
                  (* TODO: get old local_state_was_synced *)
                  if local_state_was_synced_at_start then (
                    Logger.fatal t.logger
                      "after lock transition, the best tip consensus state is \
                       out of sync with the local state -- bug in either \
                       required_local_state_sync or frontier_root_transition."
                      ~module_:__MODULE__ ~location:__LOC__
                      ~metadata:
                        [ ( "sync_jobs"
                          , `List
                              ( Non_empty_list.to_list jobs
                              |> List.map
                                   ~f:
                                     Consensus.Hooks.local_state_sync_to_yojson
                              ) )
                        ; ( "local_state"
                          , Consensus.Data.Local_state.to_yojson
                              t.consensus_local_state )
                        ; ("tf_viz", `String (visualize_to_string t)) ] ;
                    assert false )
              | None ->
                  () ) ;
          ( match
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
                ( Ledger.Db.merkle_root t.root_snarked_ledger
                |> Frozen_ledger_hash.of_ledger_hash ) ;
              let db_mask = Ledger.of_database t.root_snarked_ledger in
              Non_empty_list.iter txns ~f:(fun txn ->
                  (* TODO: @cmr use the ignore-hash ledger here as well *)
                  TL.apply_transaction t.root_snarked_ledger txn
                  |> Or_error.ok_exn |> ignore ) ;
              (* TODO: See issue #1606 to make this faster *)

              (*Ledger.commit db_mask ;*)
              ignore
                (Ledger.Maskable.unregister_mask_exn
                   (Ledger.Any_ledger.cast
                      (module Ledger.Db)
                      t.root_snarked_ledger)
                   db_mask)
          | _, false | None, _ ->
              () ) ;
          (garbage_breadcrumbs, new_root_node) )
end
