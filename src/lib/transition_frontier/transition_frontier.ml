open Core_kernel
open Async_kernel
open Protocols.Coda_transition_frontier
open Coda_base
open Pipe_lib

module type Inputs_intf = Inputs.Inputs_intf

module Make (Inputs : Inputs_intf) :
  Transition_frontier_intf
  with type state_hash := State_hash.t
   and type external_transition_verified :=
              Inputs.External_transition.Verified.t
   and type ledger_database := Ledger.Db.t
   and type staged_ledger_diff := Inputs.Staged_ledger_diff.t
   and type staged_ledger := Inputs.Staged_ledger.t
   and type masked_ledger := Ledger.Mask.Attached.t
   and type transaction_snark_scan_state := Inputs.Staged_ledger.Scan_state.t
   and type consensus_local_state := Consensus.Local_state.t
   and type user_command := User_command.t
   and module Extensions.Work = Inputs.Transaction_snark_work.Statement =
struct
  (* NOTE: is Consensus_mechanism.select preferable over distance? *)
  exception
    Parent_not_found of ([`Parent of State_hash.t] * [`Target of State_hash.t])

  exception Already_exists of State_hash.t

  module Fake_db = struct
    include Coda_base.Ledger.Db

    type location = Location.t

    let get_or_create ledger key =
      let key, loc =
        match
          get_or_create_account_exn ledger key (Account.initialize key)
        with
        | `Existed, loc -> ([], loc)
        | `Added, loc -> ([key], loc)
      in
      (key, get ledger loc |> Option.value_exn, loc)
  end

  module TL = Coda_base.Transaction_logic.Make (Fake_db)

  module Breadcrumb = struct
    (* TODO: external_transition should be type : External_transition.With_valid_protocol_state.t #1344 *)
    type t =
      { transition_with_hash:
          (Inputs.External_transition.Verified.t, State_hash.t) With_hash.t
      ; mutable staged_ledger: Inputs.Staged_ledger.t sexp_opaque
      ; just_emitted_a_proof: bool }
    [@@deriving sexp, fields]

    let to_yojson {transition_with_hash; staged_ledger= _; just_emitted_a_proof}
        =
      `Assoc
        [ ( "transition_with_hash"
          , With_hash.to_yojson Inputs.External_transition.Verified.to_yojson
              State_hash.to_yojson transition_with_hash )
        ; ("staged_ledger", `String "<opaque>")
        ; ("just_emitted_a_proof", `Bool just_emitted_a_proof) ]

    let create transition_with_hash staged_ledger =
      {transition_with_hash; staged_ledger; just_emitted_a_proof= false}

    let copy t =
      {t with staged_ledger= Inputs.Staged_ledger.copy t.staged_ledger}

    let build ~logger ~parent ~transition_with_hash =
      O1trace.measure "Breadcrumb.build" (fun () ->
          let open Deferred.Result.Let_syntax in
          let staged_ledger = parent.staged_ledger in
          let transition = With_hash.data transition_with_hash in
          let transition_protocol_state =
            Inputs.External_transition.Verified.protocol_state transition
          in
          let blockchain_state =
            Consensus.Protocol_state.blockchain_state transition_protocol_state
          in
          let blockchain_staged_ledger_hash =
            Consensus.Blockchain_state.staged_ledger_hash blockchain_state
          in
          let%bind ( `Hash_after_applying staged_ledger_hash
                   , `Ledger_proof proof_opt
                   , `Staged_ledger transitioned_staged_ledger ) =
            let open Deferred.Let_syntax in
            match%map
              Inputs.Staged_ledger.apply ~logger staged_ledger
                (Inputs.External_transition.Verified.staged_ledger_diff
                   transition)
            with
            | Ok x -> Ok x
            | Error (Inputs.Staged_ledger.Staged_ledger_error.Unexpected e) ->
                Error (`Fatal_error (Error.to_exn e))
            | Error e ->
                Error
                  (`Validation_error
                    (Error.of_string
                       (Inputs.Staged_ledger.Staged_ledger_error.to_string e)))
          in
          let just_emitted_a_proof = Option.is_some proof_opt in
          let%map transitioned_staged_ledger =
            Deferred.return
              ( if
                Staged_ledger_hash.equal staged_ledger_hash
                  blockchain_staged_ledger_hash
              then Ok transitioned_staged_ledger
              else
                Error
                  (`Validation_error
                    (Error.of_string
                       "Snarked ledger hash and Staged ledger hash after \
                        applying the diff does not match blockchain state's \
                        ledger hash and staged ledger hash resp.\n")) )
          in
          { transition_with_hash
          ; staged_ledger= transitioned_staged_ledger
          ; just_emitted_a_proof } )

    let state_hash {transition_with_hash; _} =
      With_hash.hash transition_with_hash

    let equal breadcrumb1 breadcrumb2 =
      State_hash.equal (state_hash breadcrumb1) (state_hash breadcrumb2)

    let compare breadcrumb1 breadcrumb2 =
      State_hash.compare (state_hash breadcrumb1) (state_hash breadcrumb2)

    let hash = Fn.compose State_hash.hash state_hash

    let parent_hash {transition_with_hash; _} =
      Consensus.Protocol_state.previous_state_hash
        ( With_hash.data transition_with_hash
        |> Inputs.External_transition.Verified.protocol_state )

    let consensus_state {transition_with_hash; _} =
      With_hash.data transition_with_hash
      |> Inputs.External_transition.Verified.protocol_state
      |> Consensus.Protocol_state.consensus_state

    let blockchain_state {transition_with_hash; _} =
      With_hash.data transition_with_hash
      |> Inputs.External_transition.Verified.protocol_state
      |> Consensus.Protocol_state.blockchain_state

    let name t =
      Visualization.display_short_sexp (module State_hash) @@ state_hash t

    type display =
      { state_hash: string
      ; blockchain_state:
          Inputs.External_transition.Protocol_state.Blockchain_state.display
      ; consensus_state: Consensus.Consensus_state.display
      ; parent: string }
    [@@deriving yojson]

    let display t =
      let blockchain_state =
        Inputs.External_transition.Protocol_state.Blockchain_state.display
          (blockchain_state t)
      in
      let consensus_state = consensus_state t in
      let parent =
        Visualization.display_short_sexp (module State_hash) @@ parent_hash t
      in
      { state_hash= name t
      ; blockchain_state
      ; consensus_state= Consensus.Consensus_state.display consensus_state
      ; parent }

    let to_user_commands
        {transition_with_hash= {data= external_transition; _}; _} =
      let open Inputs.External_transition.Verified in
      let open Inputs.Staged_ledger_diff in
      user_commands @@ staged_ledger_diff external_transition
  end

  module type Transition_frontier_extension_intf =
    Transition_frontier_extension_intf0
    with type transition_frontier_breadcrumb := Breadcrumb.t

  let max_length = Inputs.max_length

  module Extensions = struct
    module Work = Inputs.Transaction_snark_work.Statement

    module Snark_pool_refcount = Snark_pool_refcount.Make (struct
      include Inputs
      module Breadcrumb = Breadcrumb
    end)

    module Root_history = struct
      module Queue = Hash_queue.Make (State_hash)

      type t = {history: Breadcrumb.t Queue.t; capacity: int}

      let create capacity =
        let history = Queue.create () in
        {history; capacity}

      let lookup {history; _} = Queue.lookup history

      let mem {history; _} = Queue.mem history

      let enqueue {history; capacity} state_hash breadcrumb =
        if Queue.length history >= capacity then
          Queue.dequeue_exn history |> ignore ;
        Queue.enqueue history state_hash breadcrumb |> ignore

      let is_empty {history; _} = Queue.is_empty history
    end

    module Best_tip_diff = Best_tip_diff.Make (Breadcrumb)
    module Root_diff = Root_diff.Make (Breadcrumb)

    type diff_mutant = Inputs.Diff_mutant.e

    module Persistence_diff = Persistence_diff.Make (struct
      include Inputs
      module Breadcrumb = Breadcrumb
    end)

    type t =
      { root_history: Root_history.t
      ; snark_pool_refcount: Snark_pool_refcount.t
      ; best_tip_diff: Best_tip_diff.t
      ; root_diff: Root_diff.t
      ; persistence_diff: Persistence_diff.t }
    [@@deriving fields]

    let create () =
      { snark_pool_refcount= Snark_pool_refcount.create ()
      ; best_tip_diff= Best_tip_diff.create ()
      ; root_history= Root_history.create (2 * Inputs.max_length)
      ; root_diff= Root_diff.create ()
      ; persistence_diff= Persistence_diff.create () }

    type writers =
      { snark_pool: Snark_pool_refcount.view Broadcast_pipe.Writer.t
      ; best_tip_diff: Best_tip_diff.view Broadcast_pipe.Writer.t
      ; root_diff: Root_diff.view Broadcast_pipe.Writer.t
      ; persistence_diff: Persistence_diff.view Broadcast_pipe.Writer.t }

    type readers =
      { snark_pool: Snark_pool_refcount.view Broadcast_pipe.Reader.t
      ; best_tip_diff: Best_tip_diff.view Broadcast_pipe.Reader.t
      ; root_diff: Root_diff.view Broadcast_pipe.Reader.t
      ; persistence_diff: Persistence_diff.view Broadcast_pipe.Reader.t }
    [@@deriving fields]

    let make_pipes () : readers * writers =
      let snark_reader, snark_writer =
        Broadcast_pipe.create (Snark_pool_refcount.initial_view ())
      and best_tip_reader, best_tip_writer =
        Broadcast_pipe.create (Best_tip_diff.initial_view ())
      and root_diff_reader, root_diff_writer =
        Broadcast_pipe.create (Root_diff.initial_view ())
      and persistence_diff_reader, persistence_diff_writer =
        Broadcast_pipe.create (Persistence_diff.initial_view ())
      in
      ( { snark_pool= snark_reader
        ; best_tip_diff= best_tip_reader
        ; root_diff= root_diff_reader
        ; persistence_diff= persistence_diff_reader }
      , { snark_pool= snark_writer
        ; best_tip_diff= best_tip_writer
        ; root_diff= root_diff_writer
        ; persistence_diff= persistence_diff_writer } )

    let close_pipes
        ({snark_pool; best_tip_diff; root_diff; persistence_diff} : writers) =
      Broadcast_pipe.Writer.close snark_pool ;
      Broadcast_pipe.Writer.close best_tip_diff ;
      Broadcast_pipe.Writer.close root_diff ;
      Broadcast_pipe.Writer.close persistence_diff

    let mb_write_to_pipe diff ext_t handle pipe =
      Option.value ~default:Deferred.unit
      @@ Option.map ~f:(Broadcast_pipe.Writer.write pipe) (handle ext_t diff)

    let handle_diff t (pipes : writers)
        (diff : Breadcrumb.t Transition_frontier_diff.t) : unit Deferred.t =
      let use handler pipe acc field =
        let%bind () = acc in
        mb_write_to_pipe diff (Field.get field t) handler pipe
      in
      ( match diff with
      | Transition_frontier_diff.New_breadcrumb _ -> ()
      | Transition_frontier_diff.New_best_tip
          {old_root; old_root_length; new_best_tip_length; _} ->
          if new_best_tip_length - old_root_length > max_length then
            let root_state_hash = Breadcrumb.state_hash old_root in
            Root_history.enqueue t.root_history root_state_hash old_root ) ;
      Fields.fold ~init:diff
        ~root_history:(fun _ _ -> Deferred.unit)
        ~snark_pool_refcount:
          (use Snark_pool_refcount.handle_diff pipes.snark_pool)
        ~best_tip_diff:(use Best_tip_diff.handle_diff pipes.best_tip_diff)
        ~root_diff:(use Root_diff.handle_diff pipes.root_diff)
        ~persistence_diff:
          (use Persistence_diff.handle_diff pipes.persistence_diff)
  end

  module Node = struct
    type t =
      { breadcrumb: Breadcrumb.t
      ; successor_hashes: State_hash.t list
      ; length: int }
    [@@deriving sexp, fields]

    type display =
      { length: int
      ; state_hash: string
      ; blockchain_state:
          Inputs.External_transition.Protocol_state.Blockchain_state.display
      ; consensus_state: Consensus.Consensus_state.display }
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

  (* Invariant: The path from the root to the tip inclusively, will be max_length + 1 *)
  (* TODO: Make a test of this invariant *)
  type t =
    { root_snarked_ledger: Ledger.Db.t
    ; mutable root: State_hash.t
    ; mutable best_tip: State_hash.t
    ; logger: Logger.t
    ; table: Node.t State_hash.Table.t
    ; consensus_local_state: Consensus.Local_state.t
    ; extensions: Extensions.t
    ; extension_readers: Extensions.readers
    ; extension_writers: Extensions.writers }

  let logger t = t.logger

  let snark_pool_refcount_pipe {extension_readers; _} =
    extension_readers.snark_pool

  let best_tip_diff_pipe {extension_readers; _} =
    extension_readers.best_tip_diff

  let root_diff_pipe {extension_readers; _} = extension_readers.root_diff

  let persistence_diff_pipe {extension_readers; _} =
    extension_readers.persistence_diff

  (* TODO: load from and write to disk *)
  let create ~logger
      ~(root_transition :
         (Inputs.External_transition.Verified.t, State_hash.t) With_hash.t)
      ~root_snarked_ledger ~root_staged_ledger ~consensus_local_state =
    let open Consensus in
    let root_hash = With_hash.hash root_transition in
    let root_protocol_state =
      Inputs.External_transition.Verified.protocol_state
        (With_hash.data root_transition)
    in
    let root_blockchain_state =
      Protocol_state.blockchain_state root_protocol_state
    in
    let root_blockchain_state_ledger_hash =
      Protocol_state.Blockchain_state.snarked_ledger_hash root_blockchain_state
    in
    assert (
      Ledger_hash.equal
        (Ledger.Db.merkle_root root_snarked_ledger)
        (Frozen_ledger_hash.to_ledger_hash root_blockchain_state_ledger_hash)
    ) ;
    let root_breadcrumb =
      { Breadcrumb.transition_with_hash= root_transition
      ; staged_ledger= root_staged_ledger
      ; just_emitted_a_proof= false }
    in
    let root_node =
      {Node.breadcrumb= root_breadcrumb; successor_hashes= []; length= 0}
    in
    let table = State_hash.Table.of_alist_exn [(root_hash, root_node)] in
    let extension_readers, extension_writers = Extensions.make_pipes () in
    let t =
      { logger
      ; root_snarked_ledger
      ; root= root_hash
      ; best_tip= root_hash
      ; table
      ; consensus_local_state
      ; extensions= Extensions.create ()
      ; extension_readers
      ; extension_writers }
    in
    let%map () =
      Extensions.handle_diff t.extensions t.extension_writers
        (Transition_frontier_diff.New_breadcrumb root_breadcrumb)
    in
    t

  let close {extension_writers; _} = Extensions.close_pipes extension_writers

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

  let path_search t state_hash ~find ~f =
    let open Option.Let_syntax in
    let rec go state_hash =
      let%map breadcrumb = find t state_hash in
      let elem = f breadcrumb in
      match go (Breadcrumb.parent_hash breadcrumb) with
      | Some subresult -> Non_empty_list.cons elem subresult
      | None -> Non_empty_list.singleton elem
    in
    Option.map ~f:Non_empty_list.rev (go state_hash)

  let get_path_inclusively_in_root_history t state_hash ~f =
    path_search t state_hash
      ~find:(fun t -> Extensions.Root_history.lookup t.extensions.root_history)
      ~f

  let root_history_path_map t state_hash ~f =
    let open Option.Let_syntax in
    match path_search t ~find ~f state_hash with
    | None -> get_path_inclusively_in_root_history t state_hash ~f
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
      if State_hash.equal parent_hash t.root then [elem]
      else elem :: find_path (find_exn t parent_hash)
    in
    List.rev (find_path breadcrumb)

  let hash_path t breadcrumb = path_map t breadcrumb ~f:Breadcrumb.state_hash

  let iter t ~f = Hashtbl.iter t.table ~f:(fun n -> f n.breadcrumb)

  let root t = find_exn t t.root

  let best_tip t = find_exn t t.best_tip

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
              | Some child_node -> add_edge acc_graph node child_node
              | None ->
                  Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
                    ~metadata:
                      [ ( "state_hash"
                        , State_hash.to_yojson successor_state_hash ) ]
                    "Could not visualize node $state_hash. Looks like the \
                     node did not get garbage collected properly" ;
                  acc_graph ) )
  end

  let visualize ~filename (t : t) =
    Out_channel.with_file filename ~f:(fun output_channel ->
        let graph = Visualizor.to_graph t in
        Visualizor.output_graph output_channel graph )

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
            "attach_node_to with breadcrumb for state $state_hash already \
             present; catchup scheduler bug?" ;
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
    let children =
      List.map soon_to_be_root_node.successor_hashes ~f:(fun h ->
          (Hashtbl.find_exn t.table h).breadcrumb |> Breadcrumb.staged_ledger
          |> Inputs.Staged_ledger.ledger )
    in
    let root_ledger = Inputs.Staged_ledger.ledger root in
    let soon_to_be_root_ledger = Inputs.Staged_ledger.ledger soon_to_be_root in
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
        (Inputs.Staged_ledger.replace_ledger_exn soon_to_be_root root_ledger)
    in
    let new_root_node = {soon_to_be_root_node with breadcrumb= new_root} in
    let new_root_hash =
      soon_to_be_root_node.breadcrumb.transition_with_hash.hash
    in
    Ledger.remove_and_reparent_exn soon_to_be_root_ledger
      soon_to_be_root_ledger ~children ;
    Hashtbl.remove t.table t.root ;
    Hashtbl.set t.table ~key:new_root_hash ~data:new_root_node ;
    t.root <- new_root_hash ;
    new_root_node

  (* Get the breadcrumbs that are on bc1's path but not bc2's, and vice versa.
     Ordered oldest to newest.
  *)
  let get_path_diff t (bc1 : Breadcrumb.t) (bc2 : Breadcrumb.t) :
      Breadcrumb.t list * Breadcrumb.t list =
    let common_ancestor =
      if Breadcrumb.equal bc1 bc2 then Breadcrumb.state_hash bc1
      else
        let rec go ancestors1 ancestors2 sh1 sh2 =
          if Hash_set.mem ancestors1 sh2 then sh2
          else if Hash_set.mem ancestors2 sh1 then sh1
          else
            let parent_unless_root h =
              if State_hash.equal h t.root then h
              else find_exn t h |> Breadcrumb.parent_hash
            in
            Hash_set.add ancestors1 sh1 ;
            Hash_set.add ancestors2 sh2 ;
            go ancestors1 ancestors2 (parent_unless_root sh1)
              (parent_unless_root sh2)
        in
        go
          (Hash_set.create (module State_hash) ())
          (Hash_set.create (module State_hash) ())
          (Breadcrumb.state_hash bc1)
          (Breadcrumb.state_hash bc2)
    in
    (* Find the breadcrumbs connecting bc1 and bc2, excluding bc1. Precondition:
       bc1 is an ancestor of bc2. *)
    let path_from_to bc1 bc2 =
      let rec go cursor acc =
        if Breadcrumb.equal cursor bc1 then acc
        else go (find_exn t @@ Breadcrumb.parent_hash cursor) (cursor :: acc)
      in
      go bc2 []
    in
    Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
      !"Common ancestor: %{sexp: State_hash.t}"
      common_ancestor ;
    ( path_from_to (find_exn t common_ancestor) bc1
    , path_from_to (find_exn t common_ancestor) bc2 )

  (* Adding a breadcrumb to the transition frontier is broken into the following steps:
   *   1) attach the breadcrumb to the transition frontier
   *   2) calculate the distance from the new node to the parent and the
   *      best tip node
   *   3) set the new node as the best tip if the new node has a greater length than
   *      the current best tip
   *   4) move the root if the path to the new node is longer than the max length
   *       I   ) find the immediate successor of the old root in the path to the
   *             longest node (the heir)
   *       II  ) find all successors of the other immediate successors of the
   *             old root (bads)
   *       III ) cleanup bad node masks, but don't garbage collect yet
   *       IV  ) move_root the breadcrumbs (rewires staged ledgers, cleans up heir)
   *       V   ) garbage collect the bads
   *       VI  ) grab the new root staged ledger
   *       VII ) notify the consensus mechanism of the new root
   *       VIII) if commit on an heir node that just emitted proof txns then
   *             write them to snarked ledger
   *       XI  ) add old root to root_history
   *   5) return a diff object describing what changed (for use in updating extensions)
  *)
  let add_breadcrumb_exn t breadcrumb =
    O1trace.measure "add_breadcrumb" (fun () ->
        let hash =
          With_hash.hash (Breadcrumb.transition_with_hash breadcrumb)
        in
        let root_node = Hashtbl.find_exn t.table t.root in
        (* 1 *)
        attach_breadcrumb_exn t breadcrumb ;
        let node = Hashtbl.find_exn t.table hash in
        (* 2 *)
        let distance_to_parent = node.length - root_node.length in
        let best_tip_node = Hashtbl.find_exn t.table t.best_tip in
        (* 3 *)
        let added_to_best_tip_path, removed_from_best_tip_path =
          if node.length > best_tip_node.length then (
            t.best_tip <- hash ;
            get_path_diff t breadcrumb best_tip_node.breadcrumb )
          else ([], [])
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
          if distance_to_parent > max_length then (
            Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
              !"Distance to parent: %d exceeded max_lenth %d"
              distance_to_parent max_length ;
            (* 4.I *)
            let heir_hash = List.hd_exn (hash_path t node.breadcrumb) in
            let heir_node = Hashtbl.find_exn t.table heir_hash in
            (* 4.II *)
            let bad_hashes =
              List.filter root_node.successor_hashes
                ~f:(Fn.compose not (State_hash.equal heir_hash))
            in
            let bad_nodes =
              List.map bad_hashes ~f:(Hashtbl.find_exn t.table)
            in
            (* 4.III *)
            let root_staged_ledger =
              Breadcrumb.staged_ledger root_node.breadcrumb
            in
            let root_ledger = Inputs.Staged_ledger.ledger root_staged_ledger in
            List.map bad_nodes ~f:breadcrumb_of_node
            |> List.iter ~f:(fun bad ->
                   ignore
                     (Ledger.unregister_mask_exn root_ledger
                        ( Breadcrumb.staged_ledger bad
                        |> Inputs.Staged_ledger.ledger )) ) ;
            (* 4.IV *)
            let new_root_node = move_root t heir_node in
            (* 4.V *)
            let garbage = List.bind bad_hashes ~f:(successor_hashes_rec t) in
            let garbage_breadcrumbs =
              List.map garbage ~f:(fun g ->
                  (Hashtbl.find_exn t.table g).breadcrumb )
            in
            List.iter garbage ~f:(Hashtbl.remove t.table) ;
            (* 4.VI *)
            let new_root_staged_ledger =
              Breadcrumb.staged_ledger new_root_node.breadcrumb
            in
            (* 4.VII *)
            Consensus.lock_transition
              (Breadcrumb.consensus_state root_node.breadcrumb)
              (Breadcrumb.consensus_state new_root_node.breadcrumb)
              ~local_state:t.consensus_local_state
              ~snarked_ledger:
                (Coda_base.Ledger.Any_ledger.cast
                   (module Coda_base.Ledger.Db)
                   t.root_snarked_ledger) ;
            (* 4.VIII *)
            ( match
                ( Inputs.Staged_ledger.proof_txns new_root_staged_ledger
                , heir_node.breadcrumb.just_emitted_a_proof )
              with
            | Some txns, true ->
                let proof_data =
                  Inputs.Staged_ledger.current_ledger_proof
                    new_root_staged_ledger
                  |> Option.value_exn
                in
                [%test_result: Frozen_ledger_hash.t]
                  ~message:
                    "Root snarked ledger hash should be the same as the \
                     source hash in the proof that was just emitted"
                  ~expect:(Inputs.Ledger_proof.statement proof_data).source
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
            | _, false | None, _ -> () ) ;
            [%test_result: Frozen_ledger_hash.t]
              ~message:
                "Root snarked ledger hash diverged from blockchain state \
                 after root transition"
              ~expect:
                (Consensus.Blockchain_state.snarked_ledger_hash
                   (Breadcrumb.blockchain_state new_root_node.breadcrumb))
              ( Ledger.Db.merkle_root t.root_snarked_ledger
              |> Frozen_ledger_hash.of_ledger_hash ) ;
            (* 4.IX *)
            let root_breadcrumb = Node.breadcrumb root_node in
            let root_state_hash = Breadcrumb.state_hash root_breadcrumb in
            Extensions.Root_history.enqueue t.extensions.root_history
              root_state_hash root_breadcrumb ;
            (garbage_breadcrumbs, new_root_node) )
          else ([], root_node)
        in
        (* 5 *)
        Extensions.handle_diff t.extensions t.extension_writers
          ( if node.length > best_tip_node.length then
            Transition_frontier_diff.New_best_tip
              { old_root= root_node.breadcrumb
              ; old_root_length= root_node.length
              ; new_root= new_root_node.breadcrumb
              ; added_to_best_tip_path=
                  Non_empty_list.of_list_opt added_to_best_tip_path
                  |> Option.value_exn
              ; new_best_tip_length= node.length
              ; removed_from_best_tip_path
              ; garbage= garbage_breadcrumbs }
          else Transition_frontier_diff.New_breadcrumb node.breadcrumb ) )

  let add_breadcrumb_if_present_exn t breadcrumb =
    let parent_hash = Breadcrumb.parent_hash breadcrumb in
    match Hashtbl.find t.table parent_hash with
    | Some _ -> add_breadcrumb_exn t breadcrumb
    | None ->
        Logger.warn t.logger ~module_:__MODULE__ ~location:__LOC__
          !"When trying to add breadcrumb, its parent had been removed from \
            transition frontier: %{sexp: State_hash.t}"
          parent_hash ;
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

  module For_tests = struct
    let root_snarked_ledger {root_snarked_ledger; _} = root_snarked_ledger

    let root_history_mem {extensions; _} hash =
      Extensions.Root_history.mem extensions.root_history hash

    let root_history_is_empty {extensions; _} =
      Extensions.Root_history.is_empty extensions.root_history
  end
end
