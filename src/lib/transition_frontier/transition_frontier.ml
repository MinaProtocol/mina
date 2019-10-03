open Core_kernel
open Async_kernel
open Coda_base
open Coda_state
open Coda_transition
open Coda_incremental
open Pipe_lib

module type Inputs_intf = Inputs.Inputs_intf

module Make (Inputs : Inputs_intf) : Coda_intf.Transition_frontier_intf =
struct
  (* NOTE: is Consensus_mechanism.select preferable over distance? *)
  exception
    Parent_not_found of ([`Parent of State_hash.t] * [`Target of State_hash.t])

  exception Already_exists of State_hash.t

  module Breadcrumb = struct
    type t =
      { validated_transition: External_transition.Validated.t
      ; staged_ledger: Staged_ledger.t sexp_opaque
      ; just_emitted_a_proof: bool }
    [@@deriving sexp, fields]

    let to_yojson {validated_transition; staged_ledger= _; just_emitted_a_proof}
        =
      `Assoc
        [ ( "validated_transition"
          , External_transition.Validated.to_yojson validated_transition )
        ; ("staged_ledger", `String "<opaque>")
        ; ("just_emitted_a_proof", `Bool just_emitted_a_proof) ]

    let create validated_transition staged_ledger =
      {validated_transition; staged_ledger; just_emitted_a_proof= false}

    let copy t = {t with staged_ledger= Staged_ledger.copy t.staged_ledger}

    module Staged_ledger_validation =
      External_transition.Staged_ledger_validation

    let build ~logger ~verifier ~trust_system ~parent
        ~transition:transition_with_validation ~sender =
      O1trace.measure "Breadcrumb.build" (fun () ->
          let open Deferred.Let_syntax in
          match%bind
            Staged_ledger_validation.validate_staged_ledger_diff ~logger
              ~verifier ~parent_staged_ledger:parent.staged_ledger
              transition_with_validation
          with
          | Ok
              ( `Just_emitted_a_proof just_emitted_a_proof
              , `External_transition_with_validation
                  fully_valid_external_transition
              , `Staged_ledger transitioned_staged_ledger ) ->
              return
                (Ok
                   { validated_transition= fully_valid_external_transition
                   ; staged_ledger= transitioned_staged_ledger
                   ; just_emitted_a_proof })
          | Error (`Invalid_staged_ledger_diff errors) ->
              let reasons =
                String.concat ~sep:" && "
                  (List.map errors ~f:(function
                    | `Incorrect_target_staged_ledger_hash ->
                        "staged ledger hash"
                    | `Incorrect_target_snarked_ledger_hash ->
                        "snarked ledger hash" ))
              in
              let message =
                "invalid staged ledger diff: incorrect " ^ reasons
              in
              let%map () =
                match sender with
                | None | Some Envelope.Sender.Local ->
                    return ()
                | Some (Envelope.Sender.Remote inet_addr) ->
                    Trust_system.(
                      record trust_system logger inet_addr
                        Actions.
                          (Gossiped_invalid_transition, Some (message, [])))
              in
              Error (`Invalid_staged_ledger_hash (Error.of_string message))
          | Error
              (`Staged_ledger_application_failed
                (Staged_ledger.Staged_ledger_error.Unexpected e)) ->
              return (Error (`Fatal_error (Error.to_exn e)))
          | Error (`Staged_ledger_application_failed staged_ledger_error) ->
              let%map () =
                match sender with
                | None | Some Envelope.Sender.Local ->
                    return ()
                | Some (Envelope.Sender.Remote inet_addr) ->
                    let error_string =
                      Staged_ledger.Staged_ledger_error.to_string
                        staged_ledger_error
                    in
                    let make_actions action =
                      ( action
                      , Some
                          ( "Staged_ledger error: $error"
                          , [("error", `String error_string)] ) )
                    in
                    let open Trust_system.Actions in
                    (* TODO : refine these actions, issue 2375 *)
                    let open Staged_ledger.Pre_diff_info.Error in
                    let action =
                      match staged_ledger_error with
                      | Invalid_proof _ ->
                          make_actions Sent_invalid_proof
                      | Pre_diff (Bad_signature _) ->
                          make_actions Sent_invalid_signature
                      | Pre_diff _
                      | Non_zero_fee_excess _
                      | Insufficient_work _ ->
                          make_actions Gossiped_invalid_transition
                      | Unexpected _ ->
                          failwith
                            "build: Unexpected staged ledger error should \
                             have been caught in another pattern"
                    in
                    Trust_system.record trust_system logger inet_addr action
              in
              Error
                (`Invalid_staged_ledger_diff
                  (Staged_ledger.Staged_ledger_error.to_error
                     staged_ledger_error)) )

    let lift f {validated_transition; _} = f validated_transition

    let state_hash = lift External_transition.Validated.state_hash

    let parent_hash = lift External_transition.Validated.parent_hash

    let protocol_state = lift External_transition.Validated.protocol_state

    let consensus_state = lift External_transition.Validated.consensus_state

    let blockchain_state = lift External_transition.Validated.blockchain_state

    let proposer = lift External_transition.Validated.proposer

    let user_commands = lift External_transition.Validated.user_commands

    let payments = lift External_transition.Validated.payments

    let mask = Fn.compose Staged_ledger.ledger staged_ledger

    let equal breadcrumb1 breadcrumb2 =
      State_hash.equal (state_hash breadcrumb1) (state_hash breadcrumb2)

    let compare breadcrumb1 breadcrumb2 =
      State_hash.compare (state_hash breadcrumb1) (state_hash breadcrumb2)

    let hash = Fn.compose State_hash.hash state_hash

    let name t =
      Visualization.display_short_sexp (module State_hash) @@ state_hash t

    type display =
      { state_hash: string
      ; blockchain_state: Blockchain_state.display
      ; consensus_state: Consensus.Data.Consensus_state.display
      ; parent: string }
    [@@deriving yojson]

    let display t =
      let blockchain_state = Blockchain_state.display (blockchain_state t) in
      let consensus_state = consensus_state t in
      let parent =
        Visualization.display_short_sexp (module State_hash) @@ parent_hash t
      in
      { state_hash= name t
      ; blockchain_state
      ; consensus_state= Consensus.Data.Consensus_state.display consensus_state
      ; parent }

    let all_user_commands breadcrumbs =
      Sequence.fold (Sequence.of_list breadcrumbs) ~init:User_command.Set.empty
        ~f:(fun acc_set breadcrumb ->
          let user_commands = user_commands breadcrumb in
          Set.union acc_set (User_command.Set.of_list user_commands) )
  end

  let max_length = Inputs.max_length

  module Diff = Diff.Make (struct
    include Inputs
    module Breadcrumb = Breadcrumb
  end)

  module Extensions = Extensions.Make (struct
    include Inputs
    module Breadcrumb = Breadcrumb
    module Diff = Diff
  end)

  module Node = struct
    type t =
      { breadcrumb: Breadcrumb.t
      ; successor_hashes: State_hash.t list
      ; length: int }
    [@@deriving sexp, fields]

    type display =
      { length: int
      ; state_hash: string
      ; blockchain_state: Blockchain_state.display
      ; consensus_state: Consensus.Data.Consensus_state.display }
    [@@deriving yojson]

    let equal node1 node2 = Breadcrumb.equal node1.breadcrumb node2.breadcrumb

    let hash node = Breadcrumb.hash node.breadcrumb

    let compare node1 node2 =
      Breadcrumb.compare node1.breadcrumb node2.breadcrumb

    let name t = Breadcrumb.name t.breadcrumb

    let display t =
      let {Breadcrumb.state_hash; consensus_state; blockchain_state; _} =
        Breadcrumb.display t.breadcrumb
      in
      {state_hash; blockchain_state; length= t.length; consensus_state}
  end

  let breadcrumb_of_node {Node.breadcrumb; _} = breadcrumb

  type num_catchup_jobs =
    { mvar: int Mvar.Read_write.t
    ; signal_reader: [`Normal | `Catchup] Broadcast_pipe.Reader.t
    ; signal_writer: [`Normal | `Catchup] Broadcast_pipe.Writer.t }

  (* Invariant: The path from the root to the tip inclusively, will be max_length + 1 *)
  (* TODO: Make a test of this invariant *)
  type t =
    { root_snarked_ledger: Ledger.Db.t
    ; mutable root: State_hash.t
    ; mutable best_tip: State_hash.t
    ; logger: Logger.t
    ; table: Node.t State_hash.Table.t
    ; consensus_local_state: Consensus.Data.Local_state.t
    ; extensions: Extensions.t
    ; extension_readers: Extensions.readers
    ; extension_writers: Extensions.writers
    ; num_catchup_jobs: num_catchup_jobs }

  let logger t = t.logger

  let snark_pool_refcount_pipe {extension_readers; _} =
    extension_readers.snark_pool

  let best_tip_diff_pipe {extension_readers; _} =
    extension_readers.best_tip_diff

  let root_diff_pipe {extension_readers; _} = extension_readers.root_diff

  let persistence_diff_pipe {extension_readers; _} =
    extension_readers.persistence_diff

  let new_transition {extensions; _} =
    let new_transition_incr =
      New_transition.Var.watch extensions.new_transition
    in
    New_transition.stabilize () ;
    new_transition_incr

  (* TODO: load from and write to disk *)
  let create ~logger ~(root_transition : External_transition.Validated.t)
      ~root_snarked_ledger ~root_staged_ledger ~consensus_local_state =
    let root_hash = External_transition.Validated.state_hash root_transition in
    let root_protocol_state =
      External_transition.Validated.protocol_state root_transition
    in
    let root_blockchain_state =
      Protocol_state.blockchain_state root_protocol_state
    in
    let root_blockchain_state_ledger_hash =
      Blockchain_state.snarked_ledger_hash root_blockchain_state
    in
    assert (
      Ledger_hash.equal
        (Ledger.Db.merkle_root root_snarked_ledger)
        (Frozen_ledger_hash.to_ledger_hash root_blockchain_state_ledger_hash)
    ) ;
    let root_breadcrumb =
      { Breadcrumb.validated_transition= root_transition
      ; staged_ledger= root_staged_ledger
      ; just_emitted_a_proof= false }
    in
    let root_node =
      {Node.breadcrumb= root_breadcrumb; successor_hashes= []; length= 0}
    in
    let table = State_hash.Table.of_alist_exn [(root_hash, root_node)] in
    let extension_readers, extension_writers = Extensions.make_pipes () in
    let%bind num_catchup_jobs =
      let signal_reader, signal_writer = Broadcast_pipe.create `Normal in
      let mvar = Mvar.create () in
      let%map () = Mvar.put mvar 0 in
      {mvar; signal_reader; signal_writer}
    in
    let t =
      { logger
      ; root_snarked_ledger
      ; root= root_hash
      ; best_tip= root_hash
      ; table
      ; consensus_local_state
      ; extensions= Extensions.create root_breadcrumb
      ; extension_readers
      ; extension_writers
      ; num_catchup_jobs }
    in
    let%map () =
      Extensions.handle_diff t.extensions t.extension_writers
        (Diff.New_frontier root_breadcrumb)
    in
    Coda_metrics.(Gauge.set Transition_frontier.active_breadcrumbs 1.0) ;
    t

  let incr_num_catchup_jobs
      {num_catchup_jobs= {mvar; signal_writer; _}; logger; _} =
    let%bind current_num_catchup_jobs = Mvar.take mvar in
    Logger.trace logger "Incrementing num catch up jobs. Current number %i"
      current_num_catchup_jobs ~module_:__MODULE__ ~location:__LOC__ ;
    let%bind () =
      if current_num_catchup_jobs = 0 then
        Broadcast_pipe.Writer.write signal_writer `Catchup
      else Deferred.unit
    in
    Mvar.put mvar (current_num_catchup_jobs + 1)

  let decr_num_catchup_jobs
      {num_catchup_jobs= {mvar; signal_writer; _}; logger; _} =
    let%bind current_num_catchup_jobs = Mvar.take mvar in
    Logger.trace logger "Decrementing num catch up jobs. Current number % i"
      current_num_catchup_jobs ~module_:__MODULE__ ~location:__LOC__ ;
    [%test_pred: int]
      ~message:"The number of current catchup jobs cannot be negative"
      (fun num_catchup_jobs -> num_catchup_jobs > 0)
      current_num_catchup_jobs ;
    let%bind () =
      if current_num_catchup_jobs = 1 then
        Broadcast_pipe.Writer.write signal_writer `Normal
      else Deferred.unit
    in
    Mvar.put mvar (current_num_catchup_jobs - 1)

  let catchup_signal {num_catchup_jobs= {signal_reader; _}; _} = signal_reader

  let close {extension_writers; num_catchup_jobs= {signal_writer; _}; _} =
    Coda_metrics.(Gauge.set Transition_frontier.active_breadcrumbs 0.0) ;
    Broadcast_pipe.Writer.close signal_writer ;
    Extensions.close_pipes extension_writers

  let consensus_local_state {consensus_local_state; _} = consensus_local_state

  let all_breadcrumbs t =
    List.map (Hashtbl.data t.table) ~f:(fun {breadcrumb; _} -> breadcrumb)

  let find t hash =
    let open Option.Let_syntax in
    let%map node = Hashtbl.find t.table hash in
    node.breadcrumb

  let find_exn t hash =
    let node = Hashtbl.find_exn t.table hash in
    node.breadcrumb

  let find_in_root_history t hash =
    Extensions.Root_history.lookup t.extensions.root_history hash

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

  let previous_root t =
    Extensions.Root_history.most_recent t.extensions.root_history

  let oldest_breadcrumb_in_history t =
    Extensions.Root_history.oldest t.extensions.root_history

  let get_path_inclusively_in_root_history t state_hash ~f =
    path_search t state_hash
      ~find:(fun t -> Extensions.Root_history.lookup t.extensions.root_history)
      ~f

  let root_history_path_map t state_hash ~f =
    let open Option.Let_syntax in
    match path_search t ~find ~f state_hash with
    | None ->
        get_path_inclusively_in_root_history t state_hash ~f
    | Some frontier_path ->
        let root_history_path =
          let%bind root_breadcrumb = find t t.root in
          get_path_inclusively_in_root_history t
            (Breadcrumb.parent_hash root_breadcrumb)
            ~f
        in
        Some
          (Option.value_map root_history_path ~default:frontier_path
             ~f:(fun root_history ->
               Non_empty_list.append root_history frontier_path ))

  let path_map t breadcrumb ~f =
    let rec find_path b =
      let elem = f b in
      let parent_hash = Breadcrumb.parent_hash b in
      if State_hash.equal (Breadcrumb.state_hash b) t.root then []
      else if State_hash.equal parent_hash t.root then [elem]
      else elem :: find_path (find_exn t parent_hash)
    in
    List.rev (find_path breadcrumb)

  let hash_path t breadcrumb = path_map t breadcrumb ~f:Breadcrumb.state_hash

  let iter t ~f = Hashtbl.iter t.table ~f:(fun n -> f n.breadcrumb)

  let root t = find_exn t t.root

  let root_length t = (Hashtbl.find_exn t.table t.root).length

  let best_tip t = find_exn t t.best_tip

  let best_tip_path t = path_map t (best_tip t) ~f:Fn.id

  let successor_hashes t hash =
    let node = Hashtbl.find_exn t.table hash in
    node.successor_hashes

  let rec successor_hashes_rec t hash =
    List.bind (successor_hashes t hash) ~f:(fun succ_hash ->
        succ_hash :: successor_hashes_rec t succ_hash )

  let successors t breadcrumb =
    List.map
      (successor_hashes t (Breadcrumb.state_hash breadcrumb))
      ~f:(find_exn t)

  let rec successors_rec t breadcrumb =
    List.bind (successors t breadcrumb) ~f:(fun succ ->
        succ :: successors_rec t succ )

  (* Visualize the structure of the transition frontier or a particular node
   * within the frontier (for debugging purposes). *)
  module Visualizor = struct
    let fold t ~f = Hashtbl.fold t.table ~f:(fun ~key:_ ~data -> f data)

    include Visualization.Make_ocamlgraph (Node)

    let to_graph t =
      fold t ~init:empty ~f:(fun (node : Node.t) graph ->
          let graph_with_node = add_vertex graph node in
          List.fold node.successor_hashes ~init:graph_with_node
            ~f:(fun acc_graph successor_state_hash ->
              match State_hash.Table.find t.table successor_state_hash with
              | Some child_node ->
                  add_edge acc_graph node child_node
              | None ->
                  Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
                    ~metadata:
                      [ ( "state_hash"
                        , State_hash.to_yojson successor_state_hash )
                      ; ("error", `String "missing from frontier") ]
                    "Could not visualize state $state_hash: $error" ;
                  acc_graph ) )
  end

  let visualize ~filename (t : t) =
    Out_channel.with_file filename ~f:(fun output_channel ->
        let graph = Visualizor.to_graph t in
        Visualizor.output_graph output_channel graph )

  let visualize_to_string t =
    let graph = Visualizor.to_graph t in
    let buf = Buffer.create 0 in
    let formatter = Format.formatter_of_buffer buf in
    Visualizor.fprint_graph formatter graph ;
    Format.pp_print_flush formatter () ;
    Buffer.contents buf

  let attach_node_to t ~(parent_node : Node.t) ~(node : Node.t) =
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
            "attach_node_to called with breadcrumb for state $state_hash \
             which is already present; catchup scheduler bug?" ;
          Some x
      | None ->
          Hashtbl.set t.table ~key:parent_hash
            ~data:
              { parent_node with
                successor_hashes= hash :: parent_node.successor_hashes } ;
          Some node )

  let attach_breadcrumb_exn t breadcrumb =
    let hash = Breadcrumb.state_hash breadcrumb in
    let parent_hash = Breadcrumb.parent_hash breadcrumb in
    let parent_node =
      Option.value_exn
        (Hashtbl.find t.table parent_hash)
        ~error:
          (Error.of_exn (Parent_not_found (`Parent parent_hash, `Target hash)))
    in
    let node =
      {Node.breadcrumb; successor_hashes= []; length= parent_node.length + 1}
    in
    Coda_metrics.(Gauge.inc_one Transition_frontier.active_breadcrumbs) ;
    Coda_metrics.(Counter.inc_one Transition_frontier.total_breadcrumbs) ;
    attach_node_to t ~parent_node ~node

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
  let move_root t (soon_to_be_root_node : Node.t) : Node.t =
    let root_node = Hashtbl.find_exn t.table t.root in
    let root_breadcrumb = root_node.breadcrumb in
    let root = root_breadcrumb |> Breadcrumb.staged_ledger in
    let soon_to_be_root =
      soon_to_be_root_node.breadcrumb |> Breadcrumb.staged_ledger
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
      Breadcrumb.create soon_to_be_root_node.breadcrumb.validated_transition
        (Staged_ledger.replace_ledger_exn soon_to_be_root root_ledger)
    in
    let new_root_node = {soon_to_be_root_node with breadcrumb= new_root} in
    let new_root_hash =
      Breadcrumb.state_hash soon_to_be_root_node.breadcrumb
    in
    Ledger.remove_and_reparent_exn soon_to_be_root_ledger
      soon_to_be_root_ledger ;
    Hashtbl.remove t.table t.root ;
    Hashtbl.set t.table ~key:new_root_hash ~data:new_root_node ;
    t.root <- new_root_hash ;
    let num_finalized_staged_txns =
      Breadcrumb.user_commands new_root |> List.length |> Float.of_int
    in
    (* TODO: these metrics are too expensive to compute in this way, but it should be ok for beta *)
    let root_snarked_ledger_accounts =
      Ledger.Db.to_list t.root_snarked_ledger
    in
    Coda_metrics.(
      Gauge.set Transition_frontier.recently_finalized_staged_txns
        num_finalized_staged_txns) ;
    Coda_metrics.(
      Counter.inc Transition_frontier.finalized_staged_txns
        num_finalized_staged_txns) ;
    Coda_metrics.(
      Gauge.set Transition_frontier.root_snarked_ledger_accounts
        (Float.of_int @@ List.length root_snarked_ledger_accounts)) ;
    Coda_metrics.(
      Gauge.set Transition_frontier.root_snarked_ledger_total_currency
        ( Float.of_int
        @@ List.fold_left root_snarked_ledger_accounts ~init:0
             ~f:(fun sum account ->
               sum + Currency.Balance.to_int account.balance ) )) ;
    Coda_metrics.(Counter.inc_one Transition_frontier.root_transitions) ;
    let consensus_state = Breadcrumb.consensus_state new_root in
    let blockchain_length =
      consensus_state |> Consensus.Data.Consensus_state.blockchain_length
      |> Coda_numbers.Length.to_int |> Float.of_int
    in
    let global_slot =
      consensus_state |> Consensus.Data.Consensus_state.global_slot
      |> Float.of_int
    in
    Coda_metrics.(
      Gauge.set Transition_frontier.slot_fill_rate
        (blockchain_length /. global_slot)) ;
    new_root_node

  let common_ancestor t (bc1 : Breadcrumb.t) (bc2 : Breadcrumb.t) :
      State_hash.t =
    let rec go ancestors1 ancestors2 sh1 sh2 =
      Hash_set.add ancestors1 sh1 ;
      Hash_set.add ancestors2 sh2 ;
      if Hash_set.mem ancestors1 sh2 then sh2
      else if Hash_set.mem ancestors2 sh1 then sh1
      else
        let parent_unless_root sh =
          if State_hash.equal sh t.root then sh
          else find_exn t sh |> Breadcrumb.parent_hash
        in
        go ancestors1 ancestors2 (parent_unless_root sh1)
          (parent_unless_root sh2)
    in
    go
      (Hash_set.create (module State_hash) ())
      (Hash_set.create (module State_hash) ())
      (Breadcrumb.state_hash bc1)
      (Breadcrumb.state_hash bc2)

  (* Get the breadcrumbs that are on bc1's path but not bc2's, and vice versa.
     Ordered oldest to newest.
  *)
  let get_path_diff t (bc1 : Breadcrumb.t) (bc2 : Breadcrumb.t) :
      Breadcrumb.t list * Breadcrumb.t list =
    let ancestor = common_ancestor t bc1 bc2 in
    (* Find the breadcrumbs connecting bc1 and bc2, excluding bc1. Precondition:
       bc1 is an ancestor of bc2. *)
    let path_from_to bc1 bc2 =
      let rec go cursor acc =
        if Breadcrumb.equal cursor bc1 then acc
        else go (find_exn t @@ Breadcrumb.parent_hash cursor) (cursor :: acc)
      in
      go bc2 []
    in
    Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
      "Common ancestor: $state_hash"
      ~metadata:[("state_hash", State_hash.to_yojson ancestor)] ;
    ( path_from_to (find_exn t ancestor) bc1
    , path_from_to (find_exn t ancestor) bc2 )

  (* Adding a breadcrumb to the transition frontier is broken into the following steps:
   *   1) attach the breadcrumb to the transition frontier
   *   2) calculate the distance from the new node to the parent and the
   *      best tip node
   *   3) set the new node as the best tip if the new node is selected over the
   *      old best tip by the Consensus module.
   *   4) move the root if the path to the new node is longer than the max length
   *       I   ) find the immediate successor of the old root in the path to the
   *             longest node (the heir)
   *       II  ) find all successors of the other immediate successors of the
   *             old root (bads)
   *       III ) drop bad nodes from the hashtable and clean up their masks
   *       IV  ) move_root the breadcrumbs (rewires staged ledgers, cleans up heir)
   *       V   ) grab the new root staged ledger
   *       VI  ) notify the consensus mechanism of the new root
   *       VII ) if commit on an heir node that just emitted proof txns then
   *             write them to snarked ledger
   *       VIII) add old root to root_history
   *   5) return a diff object describing what changed (for use in updating extensions)
  *)
  let add_breadcrumb_exn t breadcrumb =
    O1trace.measure "add_breadcrumb" (fun () ->
        let hash = Breadcrumb.state_hash breadcrumb in
        let root_node = Hashtbl.find_exn t.table t.root in
        let old_best_tip = best_tip t in
        let local_state_was_synced_at_start =
          Consensus.Hooks.required_local_state_sync
            ~consensus_state:(Breadcrumb.consensus_state old_best_tip)
            ~local_state:t.consensus_local_state
          |> Option.is_none
        in
        (* 1 *)
        attach_breadcrumb_exn t breadcrumb ;
        let parent_hash = Breadcrumb.parent_hash breadcrumb in
        let parent_node =
          Option.value_exn
            (Hashtbl.find t.table parent_hash)
            ~error:
              (Error.of_exn
                 (Parent_not_found (`Parent parent_hash, `Target hash)))
        in
        Debug_assert.debug_assert (fun () ->
            (* if the proof verified, then this should always hold*)
            assert (
              Consensus.Hooks.select
                ~existing:(Breadcrumb.consensus_state parent_node.breadcrumb)
                ~candidate:(Breadcrumb.consensus_state breadcrumb)
                ~logger:
                  (Logger.extend t.logger
                     [ ( "selection_context"
                       , `String
                           "debug_assert that child is preferred over parent"
                       ) ])
              = `Take ) ) ;
        let node = Hashtbl.find_exn t.table hash in
        (* 2 *)
        let distance_to_root = node.length - root_node.length in
        let best_tip_node = Hashtbl.find_exn t.table t.best_tip in
        (* 3 *)
        let best_tip_change =
          Consensus.Hooks.select
            ~existing:(Breadcrumb.consensus_state best_tip_node.breadcrumb)
            ~candidate:(Breadcrumb.consensus_state node.breadcrumb)
            ~logger:
              (Logger.extend t.logger
                 [ ( "selection_context"
                   , `String "comparing new breadcrumb to best tip" ) ])
        in
        let added_to_best_tip_path, removed_from_best_tip_path =
          match best_tip_change with
          | `Keep ->
              ([], [])
          | `Take ->
              t.best_tip <- hash ;
              get_path_diff t breadcrumb best_tip_node.breadcrumb
        in
        Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
          "added %d breadcrumbs and removed %d making path to new best tip"
          (List.length added_to_best_tip_path)
          (List.length removed_from_best_tip_path)
          ~metadata:
            [ ( "new_breadcrumbs"
              , `List (List.map ~f:Breadcrumb.to_yojson added_to_best_tip_path)
              )
            ; ( "old_breadcrumbs"
              , `List
                  (List.map ~f:Breadcrumb.to_yojson removed_from_best_tip_path)
              ) ] ;
        (* 4 *)
        (* note: new_root_node is the same as root_node if the root didn't change *)
        let garbage_breadcrumbs, new_root_node =
          if distance_to_root > max_length then (
            Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
              "Moving the root of the transition frontier. The new node is \
               $distance_to_root blocks after the root, which exceeds the max \
               length of $max_length."
              ~metadata:
                [ ("distance_to_parent", `Int distance_to_root)
                ; ("max_length", `Int max_length) ] ;
            (* 4.I *)
            let heir_hash = List.hd_exn (hash_path t node.breadcrumb) in
            let heir_node = Hashtbl.find_exn t.table heir_hash in
            (* 4.II *)
            let bad_children_hashes =
              List.filter root_node.successor_hashes
                ~f:(Fn.compose not (State_hash.equal heir_hash))
            in
            let garbage_hashes =
              bad_children_hashes
              @ List.bind bad_children_hashes ~f:(successor_hashes_rec t)
            in
            let garbage_breadcrumbs =
              List.map garbage_hashes ~f:(fun h ->
                  Hashtbl.find_exn t.table h |> breadcrumb_of_node )
            in
            (* 4.III *)
            let unregister_sl_mask breadcrumb =
              let child = Breadcrumb.mask breadcrumb in
              let parent =
                Breadcrumb.mask @@ breadcrumb_of_node
                @@ Hashtbl.find_exn t.table
                @@ Breadcrumb.parent_hash breadcrumb
              in
              ignore @@ Ledger.unregister_mask_exn parent child
            in
            let cleanup_bc bc =
              unregister_sl_mask bc ;
              Hashtbl.remove t.table (Breadcrumb.state_hash bc)
            in
            Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
              ~metadata:
                [ ( "all_garbage"
                  , `List (List.map garbage_hashes ~f:State_hash.to_yojson) )
                ; ("length_of_garbage", `Int (List.length garbage_hashes))
                ; ( "garbage_direct_descendants"
                  , `List
                      (List.map bad_children_hashes ~f:State_hash.to_yojson) )
                ; ( "all_masks"
                  , `List
                      (List.map garbage_breadcrumbs ~f:(fun crumb ->
                           `String
                             ( Breadcrumb.mask crumb |> Ledger.get_uuid
                             |> Uuid.to_string_hum ) )) )
                ; ( "local_state"
                  , Consensus.Data.Local_state.to_yojson
                      t.consensus_local_state ) ]
              "Removing $length_of_garbage nodes because the old root is one \
               of their ancestors and we're deleting it" ;
            List.iter (List.rev garbage_breadcrumbs) ~f:cleanup_bc ;
            (* removing root + garbage, so total removed == 1 + #garbage *)
            Coda_metrics.(
              Gauge.dec Transition_frontier.active_breadcrumbs
                (Float.of_int @@ (1 + List.length garbage_hashes))) ;
            (* 4.IV *)
            let new_root_node = move_root t heir_node in
            (* 4.V *)
            let new_root_staged_ledger =
              Breadcrumb.staged_ledger new_root_node.breadcrumb
            in
            (* 4.VI *)
            Consensus.Hooks.frontier_root_transition
              (Breadcrumb.consensus_state root_node.breadcrumb)
              (Breadcrumb.consensus_state new_root_node.breadcrumb)
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
                      (Breadcrumb.consensus_state
                         (Hashtbl.find_exn t.table t.best_tip).breadcrumb)
                    ~local_state:t.consensus_local_state
                with
                | Some jobs ->
                    (* But if there wasn't sync work to do when we started, then there shouldn't be now. *)
                    if local_state_was_synced_at_start then (
                      Logger.fatal t.logger
                        "after lock transition, the best tip consensus state \
                         is out of sync with the local state -- bug in either \
                         required_local_state_sync or \
                         frontier_root_transition."
                        ~module_:__MODULE__ ~location:__LOC__
                        ~metadata:
                          [ ( "sync_jobs"
                            , `List
                                ( Non_empty_list.to_list jobs
                                |> List.map
                                     ~f:
                                       Consensus.Hooks
                                       .local_state_sync_to_yojson ) )
                          ; ( "local_state"
                            , Consensus.Data.Local_state.to_yojson
                                t.consensus_local_state )
                          ; ("tf_viz", `String (visualize_to_string t)) ] ;
                      assert false )
                | None ->
                    () ) ;
            (* 4.VII *)
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
                    "Root snarked ledger hash should be the same as the \
                     source hash in the proof that was just emitted"
                  ~expect:(Ledger_proof.statement proof_data).source
                  ( Ledger.Db.merkle_root t.root_snarked_ledger
                  |> Frozen_ledger_hash.of_ledger_hash ) ;
                (* Apply all the transactions associated with the new ledger
                   proof to the database-backed SNARKed ledger. We create a
                   mask and apply them to that, then commit it to the DB. This
                   saves a lot of IO since committing is batched. Would be even
                   faster if we implemented #2760. *)
                let db_casted =
                  Ledger.Any_ledger.cast
                    (module Ledger.Db)
                    t.root_snarked_ledger
                in
                let db_mask =
                  Ledger.Maskable.register_mask db_casted
                    (Ledger.Mask.create ())
                in
                Non_empty_list.iter txns ~f:(fun txn ->
                    Ledger.apply_transaction db_mask txn
                    |> Or_error.ok_exn |> ignore ) ;
                Ledger.commit db_mask ;
                ignore @@ Ledger.Maskable.unregister_mask_exn db_casted db_mask
            | _, false | None, _ ->
                () ) ;
            [%test_result: Frozen_ledger_hash.t]
              ~message:
                "Root snarked ledger hash diverged from blockchain state \
                 after root transition"
              ~expect:
                (Blockchain_state.snarked_ledger_hash
                   (Breadcrumb.blockchain_state new_root_node.breadcrumb))
              ( Ledger.Db.merkle_root t.root_snarked_ledger
              |> Frozen_ledger_hash.of_ledger_hash ) ;
            (* 4.VIII *)
            let root_breadcrumb = Node.breadcrumb root_node in
            let root_state_hash = Breadcrumb.state_hash root_breadcrumb in
            Extensions.Root_history.enqueue t.extensions.root_history
              root_state_hash root_breadcrumb ;
            (garbage_breadcrumbs, new_root_node) )
          else ([], root_node)
        in
        (* 5 *)
        Extensions.handle_diff t.extensions t.extension_writers
          ( match best_tip_change with
          | `Keep ->
              Diff.New_breadcrumb
                {previous= parent_node.breadcrumb; added= node.breadcrumb}
          | `Take ->
              Diff.New_best_tip
                { old_root= root_node.breadcrumb
                ; old_root_length= root_node.length
                ; new_root= new_root_node.breadcrumb
                ; parent= parent_node.breadcrumb
                ; added_to_best_tip_path=
                    Non_empty_list.of_list_opt added_to_best_tip_path
                    |> Option.value_exn
                ; new_best_tip_length= node.length
                ; removed_from_best_tip_path
                ; garbage= garbage_breadcrumbs } ) )

  let add_breadcrumb_if_present_exn t breadcrumb =
    let parent_hash = Breadcrumb.parent_hash breadcrumb in
    match Hashtbl.find t.table parent_hash with
    | Some _ ->
        add_breadcrumb_exn t breadcrumb
    | None ->
        Logger.warn t.logger ~module_:__MODULE__ ~location:__LOC__
          "Failed to add breadcrumb for state $state_hash: $error"
          ~metadata:
            [ ("error", `String "parent missing")
            ; ("parent_state_hash", State_hash.to_yojson parent_hash)
            ; ( "state_hash"
              , State_hash.to_yojson (Breadcrumb.state_hash breadcrumb) ) ] ;
        Deferred.unit

  let best_tip_path_length_exn {table; root; best_tip; _} =
    let open Option.Let_syntax in
    let result =
      let%bind best_tip_node = Hashtbl.find table best_tip in
      let%map root_node = Hashtbl.find table root in
      best_tip_node.length - root_node.length
    in
    result |> Option.value_exn

  let shallow_copy_root_snarked_ledger {root_snarked_ledger; _} =
    Ledger.of_database root_snarked_ledger

  let wait_for_transition t target_hash =
    if Hashtbl.mem t.table target_hash then Deferred.unit
    else
      let transition_registry = Extensions.transition_registry t.extensions in
      Extensions.Transition_registry.register transition_registry target_hash

  let equal t1 t2 =
    let sort_breadcrumbs = List.sort ~compare:Breadcrumb.compare in
    let equal_breadcrumb breadcrumb1 breadcrumb2 =
      let open Breadcrumb in
      let open Option.Let_syntax in
      let get_successor_nodes frontier breadcrumb =
        let%map node = Hashtbl.find frontier.table @@ state_hash breadcrumb in
        Node.successor_hashes node
      in
      equal breadcrumb1 breadcrumb2
      && State_hash.equal (parent_hash breadcrumb1) (parent_hash breadcrumb2)
      && (let%bind successors1 = get_successor_nodes t1 breadcrumb1 in
          let%map successors2 = get_successor_nodes t2 breadcrumb2 in
          List.equal State_hash.equal
            (successors1 |> List.sort ~compare:State_hash.compare)
            (successors2 |> List.sort ~compare:State_hash.compare))
         |> Option.value_map ~default:false ~f:Fn.id
    in
    List.equal equal_breadcrumb
      (all_breadcrumbs t1 |> sort_breadcrumbs)
      (all_breadcrumbs t2 |> sort_breadcrumbs)

  let all_user_commands t = Breadcrumb.all_user_commands (all_breadcrumbs t)

  module For_tests = struct
    let root_snarked_ledger {root_snarked_ledger; _} = root_snarked_ledger

    let root_history_mem {extensions; _} hash =
      Extensions.Root_history.mem extensions.root_history hash

    let root_history_is_empty {extensions; _} =
      Extensions.Root_history.is_empty extensions.root_history
  end
end

module Inputs = struct
  module Verifier = Verifier
  module Ledger_proof = Ledger_proof
  module Transaction_snark_work = Transaction_snark_work
  module External_transition = External_transition
  module Internal_transition = Internal_transition
  module Staged_ledger_diff = Staged_ledger_diff
  module Staged_ledger = Staged_ledger

  let max_length = Consensus.Constants.k
end

include Make (Inputs)
