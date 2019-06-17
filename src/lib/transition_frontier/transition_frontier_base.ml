open Core_kernel
open Async_kernel
open Coda_base
open Coda_state

module Make (Inputs : Inputs.Inputs_intf) = struct
  open Inputs

  (* NOTE: is Consensus_mechanism.select preferable over distance? *)

  let max_length = max_length

  module Breadcrumb = struct
    type t =
      { transition_with_hash:
          (External_transition.Validated.t, State_hash.t) With_hash.t
      ; mutable staged_ledger: Staged_ledger.t sexp_opaque
      ; just_emitted_a_proof: bool }
    [@@deriving sexp, fields]

    let to_yojson {transition_with_hash; staged_ledger= _; just_emitted_a_proof}
        =
      `Assoc
        [ ( "transition_with_hash"
          , With_hash.to_yojson External_transition.Validated.to_yojson
              State_hash.to_yojson transition_with_hash )
        ; ("staged_ledger", `String "<opaque>")
        ; ("just_emitted_a_proof", `Bool just_emitted_a_proof) ]

    let create transition_with_hash staged_ledger =
      {transition_with_hash; staged_ledger; just_emitted_a_proof= false}

    let copy t = {t with staged_ledger= Staged_ledger.copy t.staged_ledger}

    module Staged_ledger_validation =
      External_transition.Staged_ledger_validation (Staged_ledger)

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
                   { transition_with_hash=
                       External_transition.Validation.lift
                         fully_valid_external_transition
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
                      | Pre_diff _ | Bad_prev_hash _ | Non_zero_fee_excess _ ->
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

    let external_transition {transition_with_hash; _} =
      With_hash.data transition_with_hash

    let state_hash {transition_with_hash; _} =
      With_hash.hash transition_with_hash

    let parent_hash {transition_with_hash; _} =
      With_hash.data transition_with_hash
      |> External_transition.Validated.protocol_state
      |> Protocol_state.previous_state_hash

    let equal breadcrumb1 breadcrumb2 =
      State_hash.equal (state_hash breadcrumb1) (state_hash breadcrumb2)

    let compare breadcrumb1 breadcrumb2 =
      State_hash.compare (state_hash breadcrumb1) (state_hash breadcrumb2)

    let hash = Fn.compose State_hash.hash state_hash

    let consensus_state {transition_with_hash; _} =
      With_hash.data transition_with_hash
      |> External_transition.Validated.protocol_state
      |> Protocol_state.consensus_state

    let blockchain_state {transition_with_hash; _} =
      With_hash.data transition_with_hash
      |> External_transition.Validated.protocol_state
      |> Protocol_state.blockchain_state

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

    let to_user_commands
        {transition_with_hash= {data= external_transition; _}; _} =
      let open External_transition.Validated in
      let open Staged_ledger_diff in
      user_commands @@ staged_ledger_diff external_transition
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

  (* Invariant: The path from the root to the tip inclusively, will be max_length *)
  type t =
    { root_snarked_ledger: Ledger.Db.t
    ; mutable root: State_hash.t
    ; mutable best_tip: State_hash.t
    ; logger: Logger.t
    ; table: Node.t State_hash.Table.t
    ; consensus_local_state: Consensus.Data.Local_state.t }

  let create ~logger
      ~(root_transition :
         (External_transition.Validated.t, State_hash.t) With_hash.t)
      ~root_snarked_ledger ~root_staged_ledger ~consensus_local_state =
    let root_hash = With_hash.hash root_transition in
    let root_protocol_state =
      External_transition.Validated.protocol_state
        (With_hash.data root_transition)
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
      { Breadcrumb.transition_with_hash= root_transition
      ; staged_ledger= root_staged_ledger
      ; just_emitted_a_proof= false }
    in
    let root_node =
      {Node.breadcrumb= root_breadcrumb; successor_hashes= []; length= 0}
    in
    let table = State_hash.Table.of_alist_exn [(root_hash, root_node)] in
    { logger
    ; root_snarked_ledger
    ; root= root_hash
    ; best_tip= root_hash
    ; table
    ; consensus_local_state }

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

  let logger t = t.logger

  let root_length t = (Hashtbl.find_exn t.table t.root).length

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

  let path_map t breadcrumb ~f =
    let rec find_path b =
      let elem = f b in
      let parent_hash = Breadcrumb.parent_hash b in
      if State_hash.equal (Breadcrumb.state_hash b) t.root then []
      else if State_hash.equal parent_hash t.root then [elem]
      else elem :: find_path (find_exn t parent_hash)
    in
    List.rev (find_path breadcrumb)

  (* TODO: create a unit test for hash_path *)
  let hash_path t breadcrumb = path_map t breadcrumb ~f:Breadcrumb.state_hash

  let iter t ~f = Hashtbl.iter t.table ~f:(fun n -> f n.breadcrumb)

  let root t = find_exn t t.root

  let shallow_copy_root_snarked_ledger {root_snarked_ledger; _} =
    Ledger.of_database root_snarked_ledger

  let best_tip_path_length_exn {table; root; best_tip; _} =
    let open Option.Let_syntax in
    let result =
      let%bind best_tip_node = Hashtbl.find table best_tip in
      let%map root_node = Hashtbl.find table root in
      best_tip_node.length - root_node.length
    in
    result |> Option.value_exn

  let common_ancestor t (bc1 : Breadcrumb.t) (bc2 : Breadcrumb.t) :
      State_hash.t =
    let rec go ancestors1 ancestors2 b1 b2 =
      let sh1 = Breadcrumb.state_hash b1 in
      let sh2 = Breadcrumb.state_hash b2 in
      Hash_set.add ancestors1 sh1 ;
      Hash_set.add ancestors2 sh2 ;
      if Hash_set.mem ancestors1 sh2 then sh2
      else if Hash_set.mem ancestors2 sh1 then sh1
      else
        let parent_unless_root breadcrumb =
          if State_hash.equal (Breadcrumb.state_hash breadcrumb) t.root then
            breadcrumb
          else find_exn t (Breadcrumb.parent_hash breadcrumb)
        in
        go ancestors1 ancestors2 (parent_unless_root b1)
          (parent_unless_root b2)
    in
    go
      (Hash_set.create (module State_hash) ())
      (Hash_set.create (module State_hash) ())
      bc1 bc2

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

  let visualize_to_string t =
    let graph = Visualizor.to_graph t in
    let buf = Buffer.create 0 in
    let formatter = Format.formatter_of_buffer buf in
    Visualizor.fprint_graph formatter graph ;
    Format.pp_print_flush formatter () ;
    Buffer.contents buf
end
