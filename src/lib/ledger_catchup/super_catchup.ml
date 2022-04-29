(* Only show stdout for failed inline tests. *)
open Inline_test_quiet_logs
open Core
open Async
open Cache_lib
open Pipe_lib
open Mina_numbers
open Mina_base
open Mina_transition
open Network_peer

(** [Ledger_catchup] is a procedure that connects a foreign external transition
    into a transition frontier by requesting a path of external_transitions
    from its peer. It receives the state_hash to catchup from
    [Catchup_scheduler]. With that state_hash, it will ask its peers for
    a merkle path/list from their oldest transition to the state_hash it is
    asking for. Upon receiving the merkle path/list, it will do the following:

    1. verify the merkle path/list is correct by calling
    [Transition_chain_verifier.verify]. This function would returns a list
    of state hashes if the verification is successful.

    2. using the list of state hashes to poke a transition frontier
    in order to find the hashes of missing transitions. If none of the hashes
    are found, then it means some more transitions are missing.

    Once the list of missing hashes are computed, it would do another request to
    download the corresponding transitions in a batch fashion. Next it will perform the
    following validations on each external_transition:

    1. Check the list of transitions corresponds to the list of hashes that we
    requested;

    2. Each transition is checked through [Transition_processor.Validator] and
    [Protocol_state_validator]

    If any of the external_transitions is invalid,
    1) the sender is punished;
    2) those external_transitions that already passed validation would be
       invalidated.
    Otherwise, [Ledger_catchup] will build a corresponding breadcrumb path from
    the path of external_transitions. A breadcrumb from the path is built using
    its corresponding external_transition staged_ledger_diff and applying it to
    its preceding breadcrumb staged_ledger to obtain its corresponding
    staged_ledger. If there was an error in building the breadcrumbs, then
    catchup would invalidate the cached transitions.
    After building the breadcrumb path, [Ledger_catchup] will then send it to
    the [Processor] via writing them to catchup_breadcrumbs_writer. *)

open Transition_frontier.Full_catchup_tree

module G = Graph.Graphviz.Dot (struct
  type nonrec t = t

  module V = struct
    type t = Node.t
  end

  module E = struct
    type t = { parent : Node.t; child : Node.t }

    let src t = t.parent

    let dst t = t.child
  end

  let iter_vertex (f : V.t -> unit) (t : t) = Hashtbl.iter t.nodes ~f

  let iter_edges_e (f : E.t -> unit) (t : t) =
    Hashtbl.iter t.nodes ~f:(fun child ->
        match Hashtbl.find t.nodes child.parent with
        | None ->
            ()
        | Some parent ->
            f { child; parent })

  let graph_attributes (_ : t) = [ `Rankdir `LeftToRight ]

  let get_subgraph _ = None

  let default_vertex_attributes _ = [ `Shape `Circle ]

  let vertex_attributes (v : Node.t) =
    let color =
      match v.state with
      | Failed ->
          (* red *)
          0xFF3333
      | Root _ | Finished ->
          (* green *)
          0x00CC00
      | To_download _ ->
          (* gray *)
          0xA0A0A0
      | Wait_for_parent _ ->
          (* black *)
          0x000000
      | To_build_breadcrumb _ ->
          (* dark purple *)
          0x330033
      | To_initial_validate _ ->
          (* yellow *)
          0xFFFF33
      | To_verify _ ->
          (* orange *)
          0xFF9933
    in
    [ `Shape `Circle; `Style `Filled; `Fillcolor color ]

  let vertex_name (node : V.t) =
    sprintf "\"%s\"" (State_hash.to_base58_check node.state_hash)

  let default_edge_attributes _ = []

  let edge_attributes _ = []
end)

let write_graph (_ : t) =
  let _ = G.output_graph in
  ()

let verify_transition ~logger ~consensus_constants ~trust_system ~frontier
    ~unprocessed_transition_cache enveloped_transition =
  let sender = Envelope.Incoming.sender enveloped_transition in
  let genesis_state_hash = Transition_frontier.genesis_state_hash frontier in
  let transition_with_hash = Envelope.Incoming.data enveloped_transition in
  let cached_initially_validated_transition_result =
    let open Result.Let_syntax in
    let%bind initially_validated_transition =
      transition_with_hash
      |> Validation.skip_time_received_validation
           `This_block_was_not_received_via_gossip
      |> Validation.validate_genesis_protocol_state ~genesis_state_hash
      >>= Validation.validate_protocol_versions
      >>= Validation.validate_delta_block_chain
    in
    let enveloped_initially_validated_transition =
      Envelope.Incoming.map enveloped_transition
        ~f:(Fn.const initially_validated_transition)
    in
    Transition_handler.Validator.validate_transition ~logger ~frontier
      ~consensus_constants ~unprocessed_transition_cache
      enveloped_initially_validated_transition
  in
  let state_hash =
    Validation.block_with_hash transition_with_hash
    |> State_hash.With_state_hashes.state_hash |> State_hash.to_yojson
  in
  let open Deferred.Let_syntax in
  match cached_initially_validated_transition_result with
  | Ok x ->
      [%log trace]
        ~metadata:[ ("state_hash", state_hash) ]
        "initial_validate: validation is successful" ;
      Deferred.return @@ Ok (`Building_path x)
  | Error (`In_frontier hash) ->
      [%log trace]
        ~metadata:[ ("state_hash", state_hash) ]
        "initial_validate: transition queried during ledger catchup has \
         already been seen" ;
      Deferred.return @@ Ok (`In_frontier hash)
  | Error (`In_process consumed_state) -> (
      [%log trace]
        ~metadata:[ ("state_hash", state_hash) ]
        "initial_validate: transition queried during ledger catchup is still \
         in process in one of the components in transition_frontier" ;
      match%map Ivar.read consumed_state with
      | `Failed ->
          [%log trace]
            ~metadata:[ ("state_hash", state_hash) ]
            "initial_validate: transition queried during ledger catchup failed" ;
          Error (Error.of_string "Previous transition failed")
      | `Success hash ->
          [%log trace]
            ~metadata:[ ("state_hash", state_hash) ]
            "initial_validate: transition queried during ledger catchup is \
             added to frontier" ;
          Ok (`In_frontier hash) )
  | Error (`Verifier_error error) ->
      [%log warn]
        ~metadata:
          [ ("error", Error_json.error_to_yojson error)
          ; ("state_hash", state_hash)
          ]
        "initial_validate: verifier threw an error while verifying transiton \
         queried during ledger catchup: $error" ;
      Deferred.Or_error.fail (Error.tag ~tag:"verifier threw an error" error)
  | Error `Invalid_proof ->
      let%map () =
        Trust_system.record_envelope_sender trust_system logger sender
          ( Trust_system.Actions.Gossiped_invalid_transition
          , Some ("invalid proof", []) )
      in
      [%log warn]
        ~metadata:[ ("state_hash", state_hash) ]
        "initial_validate: invalid proof" ;
      Error (Error.of_string "invalid proof")
  | Error `Invalid_genesis_protocol_state ->
      let%map () =
        Trust_system.record_envelope_sender trust_system logger sender
          ( Trust_system.Actions.Gossiped_invalid_transition
          , Some ("invalid genesis protocol state", []) )
      in
      [%log warn]
        ~metadata:[ ("state_hash", state_hash) ]
        "initial_validate: invalid genesis protocol state" ;
      Error (Error.of_string "invalid genesis protocol state")
  | Error `Invalid_delta_block_chain_proof ->
      [%log warn]
        ~metadata:[ ("state_hash", state_hash) ]
        "initial_validate: invalid delta transition chain proof" ;
      let%map () =
        Trust_system.record_envelope_sender trust_system logger sender
          ( Trust_system.Actions.Gossiped_invalid_transition
          , Some ("invalid delta transition chain witness", []) )
      in
      Error (Error.of_string "invalid delta transition chain witness")
  | Error `Invalid_protocol_version ->
      [%log warn]
        ~metadata:[ ("state_hash", state_hash) ]
        "initial_validate: invalid protocol version" ;
      let transition = Validation.block transition_with_hash in
      let%map () =
        Trust_system.record_envelope_sender trust_system logger sender
          ( Trust_system.Actions.Sent_invalid_protocol_version
          , Some
              ( "Invalid current or proposed protocol version in catchup block"
              , [ ( "current_protocol_version"
                  , `String
                      ( External_transition.current_protocol_version transition
                      |> Protocol_version.to_string ) )
                ; ( "proposed_protocol_version"
                  , `String
                      ( External_transition.proposed_protocol_version_opt
                          transition
                      |> Option.value_map ~default:"<None>"
                           ~f:Protocol_version.to_string ) )
                ] ) )
      in
      Error (Error.of_string "invalid protocol version")
  | Error `Mismatched_protocol_version ->
      [%log warn]
        ~metadata:[ ("state_hash", state_hash) ]
        "initial_validate: mismatch protocol version" ;
      let transition = Validation.block transition_with_hash in
      let%map () =
        Trust_system.record_envelope_sender trust_system logger sender
          ( Trust_system.Actions.Sent_mismatched_protocol_version
          , Some
              ( "Current protocol version in catchup block does not match \
                 daemon protocol version"
              , [ ( "block_current_protocol_version"
                  , `String
                      ( External_transition.current_protocol_version transition
                      |> Protocol_version.to_string ) )
                ; ( "daemon_current_protocol_version"
                  , `String Protocol_version.(get_current () |> to_string) )
                ] ) )
      in
      Error (Error.of_string "mismatched protocol version")
  | Error `Disconnected ->
      [%log warn]
        ~metadata:[ ("state_hash", state_hash) ]
        "initial_validate: disconnected chain" ;
      Deferred.Or_error.fail @@ Error.of_string "disconnected chain"

let find_map_ok ?how xs ~f =
  let res = Ivar.create () in
  let errs = ref [] in
  don't_wait_for
    (let%map () =
       Deferred.List.iter xs ?how ~f:(fun x ->
           if Ivar.is_full res then Deferred.unit
           else
             match%map
               choose
                 [ choice (Ivar.read res) (fun _ -> `Finished)
                 ; choice (f x) (fun x -> `Ok x)
                 ]
             with
             | `Finished ->
                 ()
             | `Ok (Ok x) ->
                 Ivar.fill_if_empty res (Ok x)
             | `Ok (Error e) ->
                 errs := e :: !errs)
     in
     Ivar.fill_if_empty res (Error !errs)) ;
  Ivar.read res

type download_state_hashes_error =
  [ `Peer_moves_too_fast
  | `No_common_ancestor
  | `Failed_to_download_transition_chain_proof
  | `Invalid_transition_chain_proof ]

let rec contains_no_common_ancestor = function
  | [] ->
      false
  | `No_common_ancestor :: _ ->
      true
  | _ :: errors ->
      contains_no_common_ancestor errors

let try_to_connect_hash_chain t hashes ~frontier
    ~blockchain_length_of_target_hash =
  let logger = t.logger in
  let blockchain_length_of_root =
    Transition_frontier.root frontier
    |> Transition_frontier.Breadcrumb.consensus_state
    |> Consensus.Data.Consensus_state.blockchain_length
  in
  List.fold_until
    (Non_empty_list.to_list hashes)
    ~init:(blockchain_length_of_target_hash, [])
    ~f:(fun (blockchain_length, acc) hash ->
      let f x = Continue_or_stop.Stop (Ok (x, acc)) in
      match
        (Hashtbl.find t.nodes hash, Transition_frontier.find frontier hash)
      with
      | Some node, None ->
          f (`Node node)
      | Some node, Some b ->
          finish t node (Ok b) ;
          f (`Node node)
      | None, Some b ->
          f (`Breadcrumb b)
      | None, None ->
          Continue (Unsigned.UInt32.pred blockchain_length, hash :: acc))
    ~finish:(fun (blockchain_length, acc) ->
      let module T = struct
        type t = State_hash.t list [@@deriving to_yojson]
      end in
      let all_hashes =
        List.map (Transition_frontier.all_breadcrumbs frontier) ~f:(fun b ->
            Frontier_base.Breadcrumb.state_hash b)
      in
      [%log debug]
        ~metadata:
          [ ("n", `Int (List.length acc))
          ; ("hashes", T.to_yojson acc)
          ; ("all_hashes", T.to_yojson all_hashes)
          ]
        "Finishing download_state_hashes with $n $hashes. with $all_hashes" ;
      if
        Unsigned.UInt32.compare blockchain_length blockchain_length_of_root <= 0
      then Result.fail `No_common_ancestor
      else Result.fail `Peer_moves_too_fast)

module Downloader = struct
  module Key = struct
    module T = struct
      type t = State_hash.t * Length.t [@@deriving to_yojson, hash, sexp]

      let compare (h1, n1) (h2, n2) =
        match Length.compare n1 n2 with 0 -> State_hash.compare h1 h2 | c -> c
    end

    include T
    include Hashable.Make (T)
    include Comparable.Make (T)
  end

  include Downloader.Make
            (Key)
            (struct
              include Attempt_history.Attempt

              let download : t = { failure_reason = `Download }

              let worth_retrying (t : t) =
                match t.failure_reason with `Download -> true | _ -> false
            end)
            (struct
              type t = External_transition.t

              let key (t : t) =
                External_transition.
                  ((state_hashes t).state_hash, blockchain_length t)
            end)
            (struct
              type t = (State_hash.t * Length.t) option
            end)
end

let with_lengths hs ~target_length =
  List.filter_mapi (Non_empty_list.to_list hs) ~f:(fun i x ->
      let open Option.Let_syntax in
      let%map x_len = Length.sub target_length (Length.of_int i) in
      (x, x_len))

(* returns a list of state-hashes with the older ones at the front *)
let download_state_hashes t ~logger ~trust_system ~network ~frontier
    ~target_hash ~target_length ~downloader ~blockchain_length_of_target_hash
    ~preferred_peers =
  [%log debug]
    ~metadata:[ ("target_hash", State_hash.to_yojson target_hash) ]
    "Doing a catchup job with target $target_hash" ;
  let%bind all_peers = Mina_networking.peers network >>| Peer.Set.of_list in
  let preferred_peers_alive = Peer.Set.inter all_peers preferred_peers in
  let non_preferred_peers = Peer.Set.diff all_peers preferred_peers_alive in
  let peers =
    Peer.Set.to_list preferred_peers @ Peer.Set.to_list non_preferred_peers
  in
  let open Deferred.Result.Let_syntax in
  find_map_ok ~how:(`Max_concurrent_jobs 5) peers ~f:(fun peer ->
      let%bind transition_chain_proof =
        let open Deferred.Let_syntax in
        match%map
          Mina_networking.get_transition_chain_proof
            ~timeout:(Time.Span.of_sec 10.) network peer target_hash
        with
        | Error _ ->
            Result.fail `Failed_to_download_transition_chain_proof
        | Ok transition_chain_proof ->
            Result.return transition_chain_proof
      in
      let now = Time.now () in
      (* a list of state_hashes from new to old *)
      let%bind hashes =
        match
          Transition_chain_verifier.verify ~target_hash ~transition_chain_proof
        with
        | Some hs ->
            let ks = with_lengths hs ~target_length in
            Downloader.update_knowledge downloader peer (`Some ks) ;
            Downloader.mark_preferred downloader peer ~now ;
            Deferred.Result.return hs
        | None ->
            let error_msg =
              sprintf !"Peer %{sexp:Network_peer.Peer.t} sent us bad proof" peer
            in
            let%bind.Deferred () =
              Trust_system.(
                record trust_system logger peer
                  Actions.
                    ( Sent_invalid_transition_chain_merkle_proof
                    , Some (error_msg, []) ))
            in
            Deferred.Result.fail `Invalid_transition_chain_proof
      in
      Deferred.return
        ( match
            try_to_connect_hash_chain t hashes ~frontier
              ~blockchain_length_of_target_hash
          with
        | Ok x ->
            Downloader.mark_preferred downloader peer ~now ;
            Ok x
        | Error e ->
            Error e ))

let get_state_hashes = ()

module Initial_validate_batcher = struct
  open Network_pool.Batcher

  type input =
    (External_transition.t, State_hash.t) With_hash.t Envelope.Incoming.t

  type nonrec 'a t = (input, input, 'a) t

  let create ~verifier ~precomputed_values : _ t =
    create
      ~logger:
        (Logger.create
           ~metadata:[ ("name", `String "initial_validate_batcher") ]
           ())
      ~how_to_add:`Insert ~max_weight_per_call:1000
      ~weight:(fun _ -> 1)
      ~compare_init:(fun e1 e2 ->
        let len (x : input) =
          External_transition.blockchain_length x.data.data
        in
        match Length.compare (len e1) (len e2) with
        | 0 ->
            compare_envelope e1 e2
        | c ->
            c)
      (fun xs ->
        let input = function `Partially_validated x | `Init x -> x in
        let genesis_state_hash =
          Precomputed_values.genesis_state_with_hashes precomputed_values
          |> State_hash.With_state_hashes.state_hash
        in
        List.map xs ~f:(fun x ->
            input x |> Envelope.Incoming.data
            |> With_hash.map_hash ~f:(fun state_hash ->
                   { State_hash.State_hashes.state_hash
                   ; state_body_hash = None
                   })
            |> Validation.wrap)
        |> Validation.validate_proofs ~verifier ~genesis_state_hash
        >>| function
        | Ok tvs ->
            Ok (List.map tvs ~f:(fun x -> `Valid x))
        | Error `Invalid_proof ->
            Ok (List.map xs ~f:(fun x -> `Potentially_invalid (input x)))
        | Error (`Verifier_error e) ->
            Error e)

  let verify (t : _ t) = verify t
end

module Verify_work_batcher = struct
  open Network_pool.Batcher

  type input = Mina_block.initial_valid_block Envelope.Incoming.t

  type nonrec 'a t = (input, input, 'a) t

  let create ~verifier : _ t =
    let works (x : input) =
      let wh, _ = x.data in
      External_transition.staged_ledger_diff wh.data
      |> Staged_ledger_diff.completed_works
    in
    create
      ~logger:
        (Logger.create ~metadata:[ ("name", `String "verify_work_batcher") ] ())
      ~weight:(fun (x : input) ->
        List.fold ~init:0 (works x) ~f:(fun acc { proofs; _ } ->
            acc + One_or_two.length proofs))
      ~max_weight_per_call:1000 ~how_to_add:`Insert
      ~compare_init:(fun e1 e2 ->
        let len (x : input) =
          Validation.block x.data |> Mina_block.blockchain_length
        in
        match Length.compare (len e1) (len e2) with
        | 0 ->
            compare_envelope e1 e2
        | c ->
            c)
      (fun xs ->
        let input : _ -> input = function
          | `Partially_validated x | `Init x ->
              x
        in
        List.concat_map xs ~f:(fun x ->
            works (input x)
            |> List.concat_map ~f:(fun { fee; prover; proofs } ->
                   let msg = Sok_message.create ~fee ~prover in
                   One_or_two.to_list
                     (One_or_two.map proofs ~f:(fun p -> (p, msg)))))
        |> Verifier.verify_transaction_snarks verifier
        >>| function
        | Ok true ->
            Ok (List.map xs ~f:(fun x -> `Valid (input x)))
        | Ok false ->
            Ok (List.map xs ~f:(fun x -> `Potentially_invalid (input x)))
        | Error e ->
            Error e)

  let verify (t : _ t) = verify t
end

let initial_validate ~(precomputed_values : Precomputed_values.t) ~logger
    ~trust_system ~(batcher : _ Initial_validate_batcher.t) ~frontier
    ~unprocessed_transition_cache transition =
  let verification_start_time = Core.Time.now () in
  let open Deferred.Result.Let_syntax in
  let state_hash =
    Envelope.Incoming.data transition |> With_hash.hash |> State_hash.to_yojson
  in
  [%log debug]
    ~metadata:[ ("state_hash", state_hash) ]
    "initial_validate: start processing $state_hash" ;
  let%bind tv =
    let open Deferred.Let_syntax in
    match%bind Initial_validate_batcher.verify batcher transition with
    | Ok (Ok tv) ->
        return (Ok { transition with data = tv })
    | Ok (Error ()) ->
        let s = "initial_validate: proof failed to verify" in
        [%log warn] ~metadata:[ ("state_hash", state_hash) ] "%s" s ;
        let%map () =
          match transition.sender with
          | Local ->
              Deferred.unit
          | Remote peer ->
              Trust_system.(
                record trust_system logger peer
                  Actions.(Sent_invalid_proof, None))
        in
        Error (`Error (Error.of_string s))
    | Error e ->
        [%log warn]
          ~metadata:
            [ ("error", Error_json.error_to_yojson e)
            ; ("state_hash", state_hash)
            ]
          "initial_validate: verification of blockchain snark failed but it \
           was our fault" ;
        return (Error `Couldn't_reach_verifier)
  in
  let verification_end_time = Core.Time.now () in
  [%log debug]
    ~metadata:
      [ ( "time_elapsed"
        , `Float
            Core.Time.(
              Span.to_sec @@ diff verification_end_time verification_start_time)
        )
      ; ("state_hash", state_hash)
      ]
    "initial_validate: verification of proofs complete" ;
  verify_transition ~logger
    ~consensus_constants:precomputed_values.consensus_constants ~trust_system
    ~frontier ~unprocessed_transition_cache tv
  |> Deferred.map ~f:(Result.map_error ~f:(fun e -> `Error e))

open Frontier_base

let check_invariant ~downloader t =
  O1trace.sync_thread "check_super_catchup_invariants" (fun () ->
      Downloader.check_invariant downloader ;
      [%test_eq: int]
        (Downloader.total_jobs downloader)
        (Hashtbl.count t.nodes ~f:(fun node ->
             Node.State.Enum.equal (Node.State.enum node.state) To_download)))

let download s d ~key ~attempts =
  let logger = Logger.create () in
  [%log debug]
    ~metadata:[ ("key", Downloader.Key.to_yojson key); ("caller", `String s) ]
    "Download download $key" ;
  Downloader.download d ~key ~attempts

let create_node ~downloader t x =
  let attempts = Attempt_history.empty in
  let state, h, blockchain_length, parent, result =
    match x with
    | `Root root ->
        ( Node.State.Finished
        , Breadcrumb.state_hash root
        , Breadcrumb.consensus_state root
          |> Consensus.Data.Consensus_state.blockchain_length
        , Breadcrumb.parent_hash root
        , Ivar.create_full (Ok `Added_to_frontier) )
    | `Hash (h, l, parent) ->
        ( Node.State.To_download
            (download "create_node" downloader ~key:(h, l) ~attempts)
        , h
        , l
        , parent
        , Ivar.create () )
    | `Initial_validated b ->
        let t = (Cached.peek b).Envelope.Incoming.data in
        ( Node.State.To_verify b
        , Validation.block_with_hash t
          |> State_hash.With_state_hashes.state_hash
        , Validation.block t |> Mina_block.blockchain_length
        , Validation.block t |> Mina_block.header
          |> Mina_block.Header.protocol_state
          |> Mina_state.Protocol_state.previous_state_hash
        , Ivar.create () )
  in
  let node =
    { Node.state; state_hash = h; blockchain_length; attempts; parent; result }
  in
  upon (Ivar.read node.result) (fun _ ->
      Downloader.cancel downloader (h, blockchain_length)) ;
  Transition_frontier.Full_catchup_tree.add_state t.states node ;
  Hashtbl.set t.nodes ~key:h ~data:node ;
  ( try check_invariant ~downloader t
    with e ->
      [%log' debug t.logger]
        ~metadata:[ ("exn", `String (Exn.to_string e)) ]
        "create_node $exn" ) ;
  write_graph t ; node

let set_state t node s = set_state t node s ; write_graph t

let pick ~constants
    (x : Mina_state.Protocol_state.Value.t State_hash.With_state_hashes.t)
    (y : Mina_state.Protocol_state.Value.t State_hash.With_state_hashes.t) =
  let f = With_hash.map ~f:Mina_state.Protocol_state.consensus_state in
  match
    Consensus.Hooks.select ~constants ~existing:(f x) ~candidate:(f y)
      ~logger:(Logger.null ())
  with
  | `Keep ->
      x
  | `Take ->
      y

let forest_pick forest =
  with_return (fun { return } ->
      List.iter forest ~f:(Rose_tree.iter ~f:return) ;
      assert false)

let setup_state_machine_runner ~t ~verifier ~downloader ~logger
    ~precomputed_values ~trust_system ~frontier ~unprocessed_transition_cache
    ~catchup_breadcrumbs_writer
    ~(build_func :
          ?skip_staged_ledger_verification:[ `All | `Proofs ]
       -> logger:Logger.t
       -> precomputed_values:Precomputed_values.t
       -> verifier:Verifier.t
       -> trust_system:Trust_system.t
       -> parent:Breadcrumb.t
       -> transition:Mina_block.almost_valid_block
       -> sender:Envelope.Sender.t option
       -> transition_receipt_time:Time.t option
       -> unit
       -> ( Breadcrumb.t
          , [> `Invalid_staged_ledger_diff of Error.t
            | `Invalid_staged_ledger_hash of Error.t
            | `Fatal_error of exn ] )
          Result.t
          Deferred.t) =
  (* setup_state_machine_runner returns a fully configured lambda function, which is the state machine runner *)
  let initial_validation_batcher =
    Initial_validate_batcher.create ~verifier ~precomputed_values
  in
  let verify_work_batcher = Verify_work_batcher.create ~verifier in
  let set_state t node s =
    set_state t node s ;
    try check_invariant ~downloader t
    with e ->
      [%log' debug t.logger]
        ~metadata:[ ("exn", `String (Exn.to_string e)) ]
        "set_state $exn"
  in
  let rec run_node (node : Node.t) =
    O1trace.thread "exec_super_catchup_fstm" (fun () ->
        let state_hash = node.state_hash in
        let failed ?error ~sender failure_reason =
          [%log' debug t.logger] "failed with $error"
            ~metadata:
              [ ( "error"
                , Option.value_map ~default:`Null error ~f:(fun e ->
                      `String (Error.to_string_hum e)) )
              ; ( "reason"
                , Attempt_history.Attempt.reason_to_yojson failure_reason )
              ] ;
          node.attempts <-
            ( match sender with
            | Envelope.Sender.Local ->
                node.attempts
            | Remote peer ->
                Map.set node.attempts ~key:peer ~data:{ failure_reason } ) ;
          set_state t node
            (To_download
               (download "failed" downloader
                  ~key:(state_hash, node.blockchain_length)
                  ~attempts:node.attempts)) ;
          run_node node
        in
        let step d : (_, [ `Finished ]) Deferred.Result.t =
          (* TODO: See if the bail out is happening. *)
          Deferred.any
            [ (Ivar.read node.result >>| fun _ -> Error `Finished); d ]
        in
        let open Deferred.Result.Let_syntax in
        let retry () =
          let%bind () =
            step (after (Time.Span.of_sec 15.) |> Deferred.map ~f:Result.return)
          in
          run_node node
        in
        match node.state with
        | Failed | Finished | Root _ ->
            return ()
        | To_download download_job ->
            let start_time = Time.now () in
            let%bind external_block, attempts =
              step (Downloader.Job.result download_job)
            in
            [%log' debug t.logger]
              ~metadata:
                [ ("state_hash", State_hash.to_yojson state_hash)
                ; ( "donwload_number"
                  , `Int
                      (Hashtbl.count t.nodes ~f:(fun node ->
                           Node.State.Enum.equal
                             (Node.State.enum node.state)
                             To_download)) )
                ; ("total_nodes", `Int (Hashtbl.length t.nodes))
                ; ( "node_states"
                  , let s = Node.State.Enum.Table.create () in
                    Hashtbl.iter t.nodes ~f:(fun node ->
                        Hashtbl.incr s (Node.State.enum node.state)) ;
                    `List
                      (List.map (Hashtbl.to_alist s) ~f:(fun (k, v) ->
                           `List [ Node.State.Enum.to_yojson k; `Int v ])) )
                ; ("total_jobs", `Int (Downloader.total_jobs downloader))
                ; ("downloader", Downloader.to_yojson downloader)
                ]
              "download finished $state_hash" ;
            node.attempts <- attempts ;
            Mina_metrics.(
              Gauge.set Catchup.download_time
                Time.(Span.to_ms @@ diff (now ()) start_time)) ;
            set_state t node (To_initial_validate external_block) ;
            run_node node
        | To_initial_validate external_block -> (
            let start_time = Time.now () in
            match%bind
              step
                ( initial_validate ~precomputed_values ~logger ~trust_system
                    ~batcher:initial_validation_batcher ~frontier
                    ~unprocessed_transition_cache
                    { external_block with
                      data =
                        { With_hash.data = external_block.data
                        ; hash = state_hash
                        }
                    }
                |> Deferred.map ~f:(fun x -> Ok x) )
            with
            | Error (`Error e) ->
                (* TODO: Log *)
                (* Validation failed. Record the failure and go back to download. *)
                failed ~error:e ~sender:external_block.sender `Initial_validate
            | Error `Couldn't_reach_verifier ->
                retry ()
            | Ok result -> (
                Mina_metrics.(
                  Gauge.set Catchup.initial_validation_time
                    Time.(Span.to_ms @@ diff (now ()) start_time)) ;
                match result with
                | `In_frontier hash ->
                    finish t node
                      (Ok (Transition_frontier.find_exn frontier hash)) ;
                    Deferred.return (Ok ())
                | `Building_path tv ->
                    set_state t node (To_verify tv) ;
                    run_node node ) )
        | To_verify tv -> (
            let start_time = Time.now () in
            let iv = Cached.peek tv in
            (* TODO: Set up job to invalidate tv on catchup_breadcrumbs_writer closing *)
            match%bind
              step
                (* TODO: give the batch verifier a way to somehow throw away stuff if
                    this node gets removed from the tree. *)
                ( Verify_work_batcher.verify verify_work_batcher iv
                |> Deferred.map ~f:Result.return )
            with
            | Error _e ->
                [%log' debug t.logger] "Couldn't reach verifier. Retrying"
                  ~metadata:
                    [ ("state_hash", State_hash.to_yojson node.state_hash) ] ;
                (* No need to redownload in this case. We just wait a little and try again. *)
                retry ()
            | Ok result -> (
                Mina_metrics.(
                  Gauge.set Catchup.verification_time
                    Time.(Span.to_ms @@ diff (now ()) start_time)) ;
                match result with
                | Error () ->
                    [%log' warn t.logger] "verification failed! redownloading"
                      ~metadata:
                        [ ("state_hash", State_hash.to_yojson node.state_hash) ] ;
                    ( match iv.sender with
                    | Local ->
                        ()
                    | Remote peer ->
                        Trust_system.(
                          record trust_system logger peer
                            Actions.(Sent_invalid_proof, None))
                        |> don't_wait_for ) ;
                    ignore
                      ( Cached.invalidate_with_failure tv
                        : Mina_block.initial_valid_block Envelope.Incoming.t ) ;
                    failed ~sender:iv.sender `Verify
                | Ok av ->
                    let av =
                      { av with
                        data =
                          Validation.skip_frontier_dependencies_validation
                            `This_block_belongs_to_a_detached_subtree av.data
                      }
                    in
                    let av = Cached.transform tv ~f:(fun _ -> av) in
                    set_state t node (Wait_for_parent av) ;
                    run_node node ) )
        | Wait_for_parent av ->
            let%bind parent =
              step
                (let parent = Hashtbl.find_exn t.nodes node.parent in
                 match%map.Async.Deferred Ivar.read parent.result with
                 | Ok `Added_to_frontier ->
                     Ok parent.state_hash
                 | Error _ ->
                     ignore
                       ( Cached.invalidate_with_failure av
                         : Mina_block.almost_valid_block Envelope.Incoming.t ) ;
                     finish t node (Error ()) ;
                     Error `Finished)
            in
            set_state t node (To_build_breadcrumb (`Parent parent, av)) ;
            run_node node
        | To_build_breadcrumb (`Parent parent_hash, c) -> (
            let start_time = Time.now () in
            let transition_receipt_time = Some start_time in
            let av = Cached.peek c in
            match%bind
              let s =
                let open Deferred.Result.Let_syntax in
                let%bind parent =
                  Deferred.return
                    ( match Transition_frontier.find frontier parent_hash with
                    | None ->
                        Error `Parent_breadcrumb_not_found
                    | Some breadcrumb ->
                        Ok breadcrumb )
                in
                build_func ~logger ~skip_staged_ledger_verification:`Proofs
                  ~precomputed_values ~verifier ~trust_system ~parent
                  ~transition:av.data ~sender:(Some av.sender)
                  ~transition_receipt_time ()
              in
              step (Deferred.map ~f:Result.return s)
            with
            | Error e ->
                ignore
                  ( Cached.invalidate_with_failure c
                    : Mina_block.almost_valid_block Envelope.Incoming.t ) ;
                let e =
                  match e with
                  | `Exn e ->
                      Error.tag (Error.of_exn e) ~tag:"exn"
                  | `Fatal_error e ->
                      Error.tag (Error.of_exn e) ~tag:"fatal"
                  | `Invalid_staged_ledger_diff e ->
                      Error.tag e ~tag:"invalid staged ledger diff"
                  | `Invalid_staged_ledger_hash e ->
                      Error.tag e ~tag:"invalid staged ledger hash"
                  | `Parent_breadcrumb_not_found ->
                      Error.tag
                        (Error.of_string
                           (sprintf
                              "Parent breadcrumb with state_hash %s not found"
                              (State_hash.to_base58_check parent_hash)))
                        ~tag:"parent breadcrumb not found"
                in
                failed ~error:e ~sender:av.sender `Build_breadcrumb
            | Ok breadcrumb ->
                Mina_metrics.(
                  Gauge.set Catchup.build_breadcrumb_time
                    Time.(Span.to_ms @@ diff (now ()) start_time)) ;
                let%bind () =
                  Scheduler.yield () |> Deferred.map ~f:Result.return
                in
                let finished = Ivar.create () in
                let c = Cached.transform c ~f:(fun _ -> breadcrumb) in
                Strict_pipe.Writer.write catchup_breadcrumbs_writer
                  ( [ Rose_tree.of_non_empty_list (Non_empty_list.singleton c) ]
                  , `Ledger_catchup finished ) ;
                let%bind () =
                  (* The cached value is "freed" by the transition processor in [add_and_finalize]. *)
                  step (Deferred.map (Ivar.read finished) ~f:Result.return)
                in
                Ivar.fill_if_empty node.result (Ok `Added_to_frontier) ;
                set_state t node Finished ;
                return () ))
  in
  run_node

(* TODO: In the future, this could take over scheduling bootstraps too. *)
let run_catchup ~logger ~trust_system ~verifier ~network ~frontier ~build_func
    ~(catchup_job_reader :
       ( State_hash.t
       * ( Mina_block.initial_valid_block Envelope.Incoming.t
         , State_hash.t )
         Cached.t
         Rose_tree.t
         list )
       Strict_pipe.Reader.t) ~precomputed_values ~unprocessed_transition_cache
    ~(catchup_breadcrumbs_writer :
       ( (Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t Rose_tree.t
         list
         * [ `Ledger_catchup of unit Ivar.t | `Catchup_scheduler ]
       , Strict_pipe.crash Strict_pipe.buffered
       , unit )
       Strict_pipe.Writer.t) =
  let t =
    match Transition_frontier.catchup_tree frontier with
    | Full t ->
        t
    | Hash _ ->
        failwith
          "If super catchup is running, the frontier should have a full \
           catchup tree"
  in
  let stop = Transition_frontier.closed frontier in
  upon stop (fun () -> tear_down t) ;
  let combine =
    Option.merge
      ~f:
        (pick
           ~constants:precomputed_values.Precomputed_values.consensus_constants)
  in
  let pre_context
      (trees :
        (Mina_block.initial_valid_block Envelope.Incoming.t, _) Cached.t
        Rose_tree.t
        list) =
    let f tree =
      let best = ref None in
      Rose_tree.iter tree
        ~f:(fun
             (x :
               (Mina_block.initial_valid_block Envelope.Incoming.t, _) Cached.t)
           ->
          let x, _ = (Cached.peek x).data in
          best :=
            combine !best
              (Some (With_hash.map ~f:External_transition.protocol_state x))) ;
      !best
    in
    List.map trees ~f |> List.reduce ~f:combine |> Option.join
  in
  let best_tip_r, best_tip_w = Broadcast_pipe.create None in
  let%bind downloader =
    let knowledge h peer =
      let heartbeat_timeout = Time_ns.Span.of_sec 30. in
      match h with
      | None ->
          return `All
      | Some (h, len) -> (
          match%map
            Mina_networking.get_transition_chain_proof
              ~timeout:(Time.Span.of_sec 30.) ~heartbeat_timeout network peer h
          with
          | Error _ ->
              `Some []
          | Ok p -> (
              match
                Transition_chain_verifier.verify ~target_hash:h
                  ~transition_chain_proof:p
              with
              | Some hs ->
                  let ks = with_lengths hs ~target_length:len in
                  `Some ks
              | None ->
                  `Some [] ) )
    in
    O1trace.thread "super_catchup_downloader" (fun () ->
        Downloader.create ~stop ~trust_system ~preferred:[] ~max_batch_size:5
          ~get:(fun peer hs ->
            let sec =
              let sec_per_block =
                Option.value_map
                  (Sys.getenv "MINA_EXPECTED_PER_BLOCK_DOWNLOAD_TIME")
                  ~default:15. ~f:Float.of_string
              in
              Float.of_int (List.length hs) *. sec_per_block
            in
            Mina_networking.get_transition_chain
              ~heartbeat_timeout:(Time_ns.Span.of_sec sec)
              ~timeout:(Time.Span.of_sec sec) network peer (List.map hs ~f:fst))
          ~peers:(fun () -> Mina_networking.peers network)
          ~knowledge_context:
            (Broadcast_pipe.map best_tip_r
               ~f:
                 (Option.map ~f:(fun x ->
                      ( State_hash.With_state_hashes.state_hash x
                      , Mina_state.Protocol_state.consensus_state x.data
                        |> Consensus.Data.Consensus_state.blockchain_length ))))
          ~knowledge)
  in
  check_invariant ~downloader t ;
  let () =
    Downloader.set_check_invariant (fun downloader ->
        check_invariant ~downloader t)
  in
  every ~stop (Time.Span.of_sec 10.) (fun () ->
      [%log debug]
        ~metadata:[ ("states", to_yojson t) ]
        "Catchup states $states") ;
  let run_state_machine =
    setup_state_machine_runner ~t ~verifier ~downloader ~logger
      ~precomputed_values ~trust_system ~frontier ~unprocessed_transition_cache
      ~catchup_breadcrumbs_writer ~build_func
  in
  (* TODO: Maybe add everything from transition frontier at the beginning? *)
  (* TODO: Print out the hashes you're adding *)
  O1trace.thread "handle_super_catchup_jobs" (fun () ->
      Strict_pipe.Reader.iter_without_pushback catchup_job_reader
        ~f:(fun (target_parent_hash, forest) ->
          (* whenever anything comes through the catchup_job_reader, this anonymous function is called. `target_parent_hash` is actually the parent of all the trees in `forest`, is in other words if one expands `target_parent_hash` and combines it with `forest` them one actually obtains a single tree. *)
          don't_wait_for
            (let prev_ctx = Broadcast_pipe.Reader.peek best_tip_r in
             let ctx = combine prev_ctx (pre_context forest) in
             let eq x y =
               let f = Option.map ~f:State_hash.With_state_hashes.state_hash in
               Option.equal State_hash.equal (f x) (f y)
             in
             if eq prev_ctx ctx then Deferred.unit
             else Broadcast_pipe.Writer.write best_tip_w ctx) ;
          don't_wait_for
            ( (* primary super_catchup business logic begins here, in this second `don't_wait_for` *)
              [%log debug]
                ~metadata:
                  [ ( "target_parent_hash"
                    , Yojson.Safe.from_string
                        (Marlin_plonk_bindings_pasta_fp.to_string
                           target_parent_hash) )
                  ]
                "Catchup job started with $target_parent_hash " ;
              let state_hashes =
                let target_length =
                  let len =
                    forest_pick forest |> Cached.peek |> Envelope.Incoming.data
                    |> Validation.block |> Mina_block.blockchain_length
                  in
                  Option.value_exn (Length.sub len (Length.of_int 1))
                in
                let blockchain_length_of_target_hash =
                  let blockchain_length_of_dangling_block =
                    List.hd_exn forest |> Rose_tree.root |> Cached.peek
                    |> Envelope.Incoming.data |> Validation.block
                    |> Mina_block.blockchain_length
                  in
                  Unsigned.UInt32.pred blockchain_length_of_dangling_block
                in
                (* check if the target_parent_hash's own parent is a part of the transition frontier, or not *)
                match
                  List.find_map (List.concat_map ~f:Rose_tree.flatten forest)
                    ~f:(fun c ->
                      let h =
                        State_hash.With_state_hashes.state_hash
                          (Validation.block_with_hash (Cached.peek c).data)
                      in
                      ( match (Cached.peek c).sender with
                      | Local ->
                          ()
                      | Remote peer ->
                          Downloader.add_knowledge downloader peer
                            [ (target_parent_hash, target_length) ] ) ;
                      let open Option.Let_syntax in
                      let%bind { proof = path, root; data } =
                        Best_tip_lru.get h
                      in
                      let%bind p =
                        Transition_chain_verifier.verify
                          ~target_hash:
                            ( Validation.block_with_hash data
                            |> State_hash.With_state_hashes.state_hash )
                          ~transition_chain_proof:
                            ( (External_transition.state_hashes root).state_hash
                            , path )
                      in
                      Result.ok
                        (try_to_connect_hash_chain t p ~frontier
                           ~blockchain_length_of_target_hash))
                with
                | None ->
                    (* if the target_parent_hash's own parent is not a part of the transition frontier, then the entire chain of blocks connecting some node in the
                       transition frontier to target_parent_hash needs to be downloaded *)
                    let preferred_peers =
                      List.fold (List.concat_map ~f:Rose_tree.flatten forest)
                        ~init:Peer.Set.empty ~f:(fun acc c ->
                          match (Cached.peek c).sender with
                          | Local ->
                              acc
                          | Remote peer ->
                              Peer.Set.add acc peer)
                    in
                    download_state_hashes t ~logger ~trust_system ~network
                      ~frontier ~downloader ~target_length
                      ~target_hash:target_parent_hash
                      ~blockchain_length_of_target_hash ~preferred_peers
                | Some res ->
                    [%log debug] "Succeeded in using cache." ;
                    Deferred.Result.return res
              in
              match%map state_hashes with
              | Error errors ->
                  [%log debug]
                    ~metadata:
                      [ ("target_hash", State_hash.to_yojson target_parent_hash)
                      ]
                    "Failed to download state hashes for $target_hash" ;
                  if contains_no_common_ancestor errors then
                    List.iter forest ~f:(fun subtree ->
                        let transition =
                          Rose_tree.root subtree |> Cached.peek
                          |> Envelope.Incoming.data
                        in
                        let children_transitions =
                          List.concat_map
                            (Rose_tree.children subtree)
                            ~f:Rose_tree.flatten
                        in
                        let children_state_hashes =
                          List.map children_transitions
                            ~f:(fun cached_transition ->
                              Cached.peek cached_transition
                              |> Envelope.Incoming.data
                              |> Validation.block_with_hash
                              |> State_hash.With_state_hashes.state_hash)
                        in
                        [%log error]
                          ~metadata:
                            [ ( "state_hashes_of_children"
                              , `List
                                  (List.map children_state_hashes
                                     ~f:State_hash.to_yojson) )
                            ; ( "state_hash"
                              , State_hash.to_yojson
                                  ( Validation.block_with_hash transition
                                  |> State_hash.With_state_hashes.state_hash )
                              )
                            ; ( "reason"
                              , `String
                                  "no common ancestor with our transition \
                                   frontier" )
                            ; ( "protocol_state"
                              , Validation.block transition
                                |> Mina_block.header |> Header.protocol_state
                                |> Mina_state.Protocol_state.value_to_yojson )
                            ]
                          "Validation error: external transition with state \
                           hash $state_hash and its children were rejected for \
                           reason $reason" ;
                        Mina_metrics.(
                          Counter.inc Rejected_blocks.no_common_ancestor
                            ( Float.of_int
                            @@ (1 + List.length children_transitions) ))) ;
                  List.iter forest ~f:(fun subtree ->
                      Rose_tree.iter subtree ~f:(fun cached ->
                          ( Cached.invalidate_with_failure cached
                            : Mina_block.initial_valid_block Envelope.Incoming.t
                            )
                          |> ignore))
              | Ok (root, state_hashes) ->
                  [%log' debug t.logger]
                    ~metadata:
                      [ ("downloader", Downloader.to_yojson downloader)
                      ; ( "node_states"
                        , let s = Node.State.Enum.Table.create () in
                          Hashtbl.iter t.nodes ~f:(fun node ->
                              Hashtbl.incr s (Node.State.enum node.state)) ;
                          `List
                            (List.map (Hashtbl.to_alist s) ~f:(fun (k, v) ->
                                 `List [ Node.State.Enum.to_yojson k; `Int v ]))
                        )
                      ]
                    "before entering state machine.  node_states: $node_states" ;
                  let root =
                    match root with
                    | `Breadcrumb root ->
                        (* If we hit this case we should probably remove the parent from the
                            table and prune, although in theory that should be handled by
                           the frontier calling [Full_catchup_tree.apply_diffs]. *)
                        create_node ~downloader t (`Root root)
                    | `Node node ->
                        (* TODO: Log what is going on with transition frontier. *)
                        node
                  in
                  [%log debug]
                    ~metadata:[ ("n", `Int (List.length state_hashes)) ]
                    "Adding $n nodes" ;
                  (* if state_hashes is Ok, then we iterate through the forest and fold over state_hashes and call run_state_machine on each node.  order doesn't really matter because nodes called "out of order" will enter the `Wait_for_parent` state and begin running again when ready *)
                  List.iter forest
                    ~f:
                      (Rose_tree.iter ~f:(fun c ->
                           let node =
                             create_node ~downloader t (`Initial_validated c)
                           in
                           ignore
                             ( run_state_machine node
                               : (unit, [ `Finished ]) Deferred.Result.t ))) ;
                  ignore
                    ( List.fold state_hashes
                        ~init:(root.state_hash, root.blockchain_length)
                        ~f:(fun (parent, l) h ->
                          let l = Length.succ l in
                          ( if not (Hashtbl.mem t.nodes h) then
                            let node =
                              create_node t ~downloader (`Hash (h, l, parent))
                            in
                            don't_wait_for (run_state_machine node >>| ignore)
                          ) ;
                          (h, l))
                      : State_hash.t * Length.t ) )))

let run ~logger ~precomputed_values ~trust_system ~verifier ~network ~frontier
    ~catchup_job_reader ~catchup_breadcrumbs_writer
    ~unprocessed_transition_cache : unit =
  O1trace.background_thread "perform_super_catchup" (fun () ->
      run_catchup ~logger ~trust_system ~verifier ~network ~frontier
        ~catchup_job_reader ~precomputed_values ~unprocessed_transition_cache
        ~catchup_breadcrumbs_writer
        ~build_func:Transition_frontier.Breadcrumb.build)

(* Unit tests *)

(* let run_test_only ~logger ~precomputed_values ~trust_system ~verifier ~network ~frontier
    ~catchup_job_reader ~catchup_breadcrumbs_writer
    ~unprocessed_transition_cache : unit =
  run_catchup ~logger ~trust_system ~verifier ~network ~frontier ~catchup_job_reader
    ~precomputed_values ~unprocessed_transition_cache
    ~catchup_breadcrumbs_writer ~build_func:(Transition_frontier.Breadcrumb.For_tests.build_fail)
  |> don't_wait_for *)

let%test_module "Ledger_catchup tests" =
  ( module struct
    let () =
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true

    let max_frontier_length = 10

    let logger = Logger.create ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let proof_level = precomputed_values.proof_level

    let constraint_constants = precomputed_values.constraint_constants

    let trust_system = Trust_system.null ()

    (* let time_controller = Block_time.Controller.basic ~logger *)

    let use_super_catchup = true

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.create ~logger ~proof_level ~constraint_constants
            ~conf_dir:None
            ~pids:(Child_processes.Termination.create_pid_table ()))

    (* let mock_verifier =
       Async.Thread_safe.block_on_async_exn (fun () ->
           Verifier.Dummy.create ~logger ~proof_level ~constraint_constants
             ~conf_dir:None
             ~pids:(Child_processes.Termination.create_pid_table ())) *)

    let downcast_transition transition =
      let transition =
        transition |> Validation.reset_frontier_dependencies_validation
        |> Validation.reset_staged_ledger_diff_validation
      in
      Envelope.Incoming.wrap ~data:transition ~sender:Envelope.Sender.Local

    let downcast_breadcrumb breadcrumb =
      downcast_transition
        ( Transition_frontier.Breadcrumb.validated_transition breadcrumb
        |> Mina_block.Validated.remember )

    type catchup_test =
      { cache : Transition_handler.Unprocessed_transition_cache.t
      ; job_writer :
          ( State_hash.t
            * ( Mina_block.initial_valid_block Envelope.Incoming.t
              , State_hash.t )
              Cached.t
              Rose_tree.t
              list
          , Strict_pipe.crash Strict_pipe.buffered
          , unit )
          Strict_pipe.Writer.t
      ; breadcrumbs_reader :
          ( (Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t Rose_tree.t
            list
          * [ `Catchup_scheduler | `Ledger_catchup of unit Ivar.t ] )
          Strict_pipe.Reader.t
      }

    let setup_catchup_pipes ~network ~frontier =
      let catchup_job_reader, catchup_job_writer =
        Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
          (Buffered (`Capacity 10, `Overflow Crash))
      in
      let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
        Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
          (Buffered (`Capacity 10, `Overflow Crash))
      in
      let unprocessed_transition_cache =
        Transition_handler.Unprocessed_transition_cache.create ~logger
      in
      run ~logger ~precomputed_values ~verifier ~trust_system ~network ~frontier
        ~catchup_breadcrumbs_writer ~catchup_job_reader
        ~unprocessed_transition_cache ;
      { cache = unprocessed_transition_cache
      ; job_writer = catchup_job_writer
      ; breadcrumbs_reader = catchup_breadcrumbs_reader
      }

    (* let setup_catchup_pipes_fail_build_breadcrumb ~network ~frontier =
       let catchup_job_reader, catchup_job_writer =
         Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
           (Buffered (`Capacity 10, `Overflow Crash))
       in
       let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
         Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
           (Buffered (`Capacity 10, `Overflow Crash))
       in
       let unprocessed_transition_cache =
         Transition_handler.Unprocessed_transition_cache.create ~logger
       in
       run_test_only ~logger ~precomputed_values ~verifier ~trust_system ~network ~frontier
         ~catchup_breadcrumbs_writer ~catchup_job_reader
         ~unprocessed_transition_cache ;
       { cache = unprocessed_transition_cache
       ; job_writer = catchup_job_writer
       ; breadcrumbs_reader = catchup_breadcrumbs_reader
       } *)

    let setup_catchup_with_target ~network ~frontier ~target_breadcrumb =
      let test = setup_catchup_pipes ~network ~frontier in
      let parent_hash =
        Transition_frontier.Breadcrumb.parent_hash target_breadcrumb
      in
      let target_transition =
        Transition_handler.Unprocessed_transition_cache.register_exn test.cache
          (downcast_breadcrumb target_breadcrumb)
      in
      Strict_pipe.Writer.write test.job_writer
        (parent_hash, [ Rose_tree.T (target_transition, []) ]) ;
      (`Test test, `Cached_transition target_transition)

    let rec call_read ~target_best_tip_path ~breadcrumbs_reader
        ~(my_peer : Fake_network.peer_network) b_list n =
      if n < List.length target_best_tip_path then
        let%bind breadcrumb =
          [%log info] "calling read, n=%d..." n ;
          match%map
            Strict_pipe.Reader.read breadcrumbs_reader
            |> Async.with_timeout (Time.Span.create ~sec:30 ())
          with
          | `Timeout ->
              failwith
                (String.concat
                   [ "read of breadcrumbs_reader pipe timed out, n= "
                   ; string_of_int n
                   ])
          | `Result res -> (
              match res with
              | `Eof ->
                  failwith "breadcrumb not found"
              | `Ok (_, `Catchup_scheduler) ->
                  failwith "breadcrumb not found"
              | `Ok (breadcrumbs, `Ledger_catchup ivar) ->
                  let breadcrumb : Breadcrumb.t =
                    Rose_tree.root (List.hd_exn breadcrumbs)
                    |> Cache_lib.Cached.invalidate_with_success
                  in
                  Ivar.fill ivar () ; breadcrumb )
        in
        let%bind () =
          Transition_frontier.add_breadcrumb_exn my_peer.state.frontier
            breadcrumb
        in
        call_read ~target_best_tip_path ~breadcrumbs_reader ~my_peer
          (List.append b_list [ breadcrumb ])
          (n + 1)
      else Deferred.return b_list

    let test_successful_catchup ~my_net ~target_best_tip_path =
      let open Fake_network in
      let target_breadcrumb = List.last_exn target_best_tip_path in
      let `Test { breadcrumbs_reader; _ }, _ =
        setup_catchup_with_target ~network:my_net.network
          ~frontier:my_net.state.frontier ~target_breadcrumb
      in
      let%map breadcrumb_list =
        call_read ~breadcrumbs_reader ~target_best_tip_path ~my_peer:my_net [] 0
      in
      let breadcrumbs_tree = Rose_tree.of_list_exn breadcrumb_list in
      [%test_result: int]
        ~message:
          "Transition_frontier should not have any more catchup jobs at the \
           end of the test"
        ~equal:( = ) ~expect:0
        (Broadcast_pipe.Reader.peek Catchup_jobs.reader) ;
      [%log info] "target_best_tip_path length: %d"
        (List.length target_best_tip_path) ;
      let target_best_tip_tree = Rose_tree.of_list_exn target_best_tip_path in
      [%log info] "breadcrumb_list length: %d" (List.length breadcrumb_list) ;
      let catchup_breadcrumbs_are_best_tip_path =
        Rose_tree.equal target_best_tip_tree
          breadcrumbs_tree ~f:(fun br1 br2 ->
            let b1 = Transition_frontier.Breadcrumb.validated_transition
                 br1 in
            let b2 = Transition_frontier.Breadcrumb.validated_transition
                 br2 in
            (* We force evaluation of state body hash for both blocks for further equality check *)
            let _hash1 = Mina_block.Validated.state_body_hash b1 in
            let _hash2 = Mina_block.Validated.state_body_hash b2 in
            Mina_block.Validated.equal b1 b2)
      in
      if not catchup_breadcrumbs_are_best_tip_path then
        failwith
          "catchup breadcrumbs were not equal to the best tip path we expected"

    let%test_unit "can catchup to a peer within [k/2,k]" =
      [%log info] "running catchup to peer" ;
      Quickcheck.test ~trials:5
        Fake_network.Generator.(
          let open Quickcheck.Generator.Let_syntax in
          let%bind peer_branch_size =
            Int.gen_incl (max_frontier_length / 2) (max_frontier_length - 1)
          in
          gen ~precomputed_values ~verifier ~max_frontier_length
            ~use_super_catchup
            [ fresh_peer
            ; peer_with_branch ~frontier_branch_size:peer_branch_size
            ])
        ~f:(fun network ->
          let open Fake_network in
          let [ my_net; peer_net ] = network.peer_networks in
          let target_best_tip_path =
            Transition_frontier.(
              path_map ~f:Fn.id peer_net.state.frontier
                (best_tip peer_net.state.frontier))
          in
          Thread_safe.block_on_async_exn (fun () ->
              test_successful_catchup ~my_net ~target_best_tip_path))

    let%test_unit "catchup succeeds even if the parent transition is already \
                   in the frontier" =
      Quickcheck.test ~trials:1
        Fake_network.Generator.(
          gen ~precomputed_values ~verifier ~max_frontier_length
            ~use_super_catchup
            [ fresh_peer; peer_with_branch ~frontier_branch_size:1 ])
        ~f:(fun network ->
          let open Fake_network in
          let [ my_net; peer_net ] = network.peer_networks in
          let target_best_tip_path =
            [ Transition_frontier.best_tip peer_net.state.frontier ]
          in
          Thread_safe.block_on_async_exn (fun () ->
              test_successful_catchup ~my_net ~target_best_tip_path))

    let%test_unit "catchup succeeds even if the parent transition is already \
                   in the frontier" =
      Quickcheck.test ~trials:1
        Fake_network.Generator.(
          gen ~precomputed_values ~verifier ~max_frontier_length
            ~use_super_catchup
            [ fresh_peer; peer_with_branch ~frontier_branch_size:1 ])
        ~f:(fun network ->
          let open Fake_network in
          let [ my_net; peer_net ] = network.peer_networks in
          let target_best_tip_path =
            [ Transition_frontier.best_tip peer_net.state.frontier ]
          in
          Thread_safe.block_on_async_exn (fun () ->
              test_successful_catchup ~my_net ~target_best_tip_path))

    let%test_unit "when catchup fails to download state hashes, catchup will \
                   properly clear the unprocessed_transition_cache of the \
                   blocks that triggered catchup" =
      Quickcheck.test ~trials:1
        Fake_network.Generator.(
          gen ~precomputed_values ~verifier ~max_frontier_length
            ~use_super_catchup
            [ fresh_peer
            ; peer_with_branch
                ~frontier_branch_size:((max_frontier_length * 3) + 1)
            ])
        ~f:(fun network ->
          let open Fake_network in
          let [ my_net; peer_net ] = network.peer_networks in
          let target_best_tip_path =
            [ Transition_frontier.best_tip peer_net.state.frontier ]
          in
          let open Fake_network in
          let target_breadcrumb = List.last_exn target_best_tip_path in
          let test =
            setup_catchup_pipes ~network:my_net.network
              ~frontier:my_net.state.frontier
          in
          let parent_hash =
            Transition_frontier.Breadcrumb.parent_hash target_breadcrumb
          in
          let target_transition =
            Transition_handler.Unprocessed_transition_cache.register_exn
              test.cache
              (downcast_breadcrumb target_breadcrumb)
          in
          [%log info] "download state hashes fails unit test" ;
          Strict_pipe.Writer.write test.job_writer
            (parent_hash, [ Rose_tree.T (target_transition, []) ]) ;
          Thread_safe.block_on_async_exn (fun () ->
              let final = Cache_lib.Cached.final_state target_transition in
              match%map
                Deferred.any
                  [ (Ivar.read final >>| fun x -> `Catchup_failed x)
                  ; Strict_pipe.Reader.read test.breadcrumbs_reader
                    >>| const `Catchup_success
                  ]
              with
              | `Catchup_failed fnl -> (
                  match fnl with
                  | `Failed ->
                      [%log info]
                        "download state hashes fails unit test: correctly fails" ;

                      ()
                  | `Success _ ->
                      [%log info]
                        "download state hashes fails unit test: incorrectly \
                         succeeds" ;

                      failwith
                        "target transition should've been invalidated with a \
                         failure" )
              | `Catchup_success ->
                  [%log info]
                    "download state hashes fails unit test: incorrectly \
                     succeeds" ;

                  failwith
                    "target transition should've been invalidated with a \
                     failure"))

    let%test_unit "when catchup fails to download a block, catchup will retry \
                   and attempt again" =
      let attempts_ivar = Ivar.create () in
      let attempt_counter = ref 0 in
      let impl_rpc :
             Mina_networking.Rpcs.Get_transition_chain.query Envelope.Incoming.t
          -> Mina_networking.Rpcs.Get_transition_chain.response Deferred.t =
       fun _ ->
        let () =
          attempt_counter := !attempt_counter + 1 ;
          if !attempt_counter > 1 then Ivar.fill_if_empty attempts_ivar true
        in
        Deferred.return (Some [])
      in
      Quickcheck.test ~trials:1
        Fake_network.Generator.(
          gen ~precomputed_values ~verifier ~max_frontier_length
            ~use_super_catchup
            [ fresh_peer
              (* ; peer_with_branch ~frontier_branch_size:(max_frontier_length / 2) *)
            ; peer_with_branch_custom_rpc
                ~frontier_branch_size:(max_frontier_length / 2)
                ?get_staged_ledger_aux_and_pending_coinbases_at_hash:None
                ?get_some_initial_peers:None ?answer_sync_ledger_query:None
                ?get_ancestry:None ?get_best_tip:None ?get_node_status:None
                ?get_transition_knowledge:None ?get_transition_chain_proof:None
                ?get_transition_chain:(Some impl_rpc)
            ; peer_with_branch_custom_rpc
                ~frontier_branch_size:(max_frontier_length / 2)
                ?get_staged_ledger_aux_and_pending_coinbases_at_hash:None
                ?get_some_initial_peers:None ?answer_sync_ledger_query:None
                ?get_ancestry:None ?get_best_tip:None ?get_node_status:None
                ?get_transition_knowledge:None ?get_transition_chain_proof:None
                ?get_transition_chain:(Some impl_rpc)
            ; peer_with_branch_custom_rpc
                ~frontier_branch_size:(max_frontier_length / 2)
                ?get_staged_ledger_aux_and_pending_coinbases_at_hash:None
                ?get_some_initial_peers:None ?answer_sync_ledger_query:None
                ?get_ancestry:None ?get_best_tip:None ?get_node_status:None
                ?get_transition_knowledge:None ?get_transition_chain_proof:None
                ?get_transition_chain:(Some impl_rpc)
            ])
        ~f:(fun network ->
          let open Fake_network in
          let [ my_net; peer1; _; _ ] = network.peer_networks in
          let target_best_tip_path =
            [ Transition_frontier.best_tip peer1.state.frontier ]
          in
          let open Fake_network in
          let target_breadcrumb = List.last_exn target_best_tip_path in
          let test =
            setup_catchup_pipes ~network:my_net.network
              ~frontier:my_net.state.frontier
          in
          let parent_hash =
            Transition_frontier.Breadcrumb.parent_hash target_breadcrumb
          in
          let target_transition =
            Transition_handler.Unprocessed_transition_cache.register_exn
              test.cache
              (downcast_breadcrumb target_breadcrumb)
          in
          Strict_pipe.Writer.write test.job_writer
            (parent_hash, [ Rose_tree.T (target_transition, []) ]) ;
          Thread_safe.block_on_async_exn (fun () ->
              let final = Cache_lib.Cached.final_state target_transition in
              match%map
                Deferred.any
                  [ (Ivar.read final >>| fun x -> `Catchup_failed x)
                  ; (Ivar.read attempts_ivar >>| fun _ -> `Attempts_exceeded)
                  ; Strict_pipe.Reader.read test.breadcrumbs_reader
                    >>| const `Catchup_success
                  ]
              with
              | `Attempts_exceeded ->
                  ()
              | `Catchup_success ->
                  failwith
                    "target transition should've been invalidated with a \
                     failure"
              | `Catchup_failed fnl -> (
                  match fnl with
                  | `Success _ ->
                      failwith "final state should be at `Failed"
                  | `Failed ->
                      let catchup_tree =
                        match
                          Transition_frontier.catchup_tree my_net.state.frontier
                        with
                        | Full tr ->
                            tr
                        | Hash _ ->
                            failwith
                              "in super catchup unit tests, the catchup tree \
                               should always be Full_catchup_tree, but it is \
                               Catchup_hash_tree for some reason"
                      in
                      let catchup_tree_node_list =
                        State_hash.Table.data catchup_tree.nodes
                      in
                      let catchup_tree_node =
                        List.hd_exn catchup_tree_node_list
                      in
                      let num_attempts =
                        Peer.Map.length catchup_tree_node.attempts
                      in
                      if num_attempts < 2 then
                        let failstring =
                          Format.sprintf
                            "UNIT TEST FAILED.  catchup should have made more \
                             attempts after failing to download a block.  \
                             attempts= %d.  length of catchup_tree_node_list= \
                             %d"
                            num_attempts
                            (List.length catchup_tree_node_list)
                        in
                        failwith failstring
                      else () )))

    (* let%test_unit "when initial validation of a blocks fails (except for the \
                    verifier_unreachable case), then catchup will cancel the \
                    block's children's catchup job" =
       Quickcheck.test ~trials:1
         Fake_network.Generator.(
           gen ~precomputed_values ~verifier ~max_frontier_length
             ~use_super_catchup
             [ fresh_peer
             ; broken_rpc_peer_branch
                 ~frontier_branch_size:(max_frontier_length / 2)
                 ~get_transition_chain_impl_option:None
               (* TODO: write some kind of mock that makes validation fail, and thus make the test pass *)
             ])
         ~f:(fun network ->
           let open Fake_network in
           let [ my_net; peer_net ] = network.peer_networks in
           let target_best_tip_path =
             Transition_frontier.best_tip_path peer_net.state.frontier
           in
           let open Fake_network in
           let target_breadcrumb_child = List.last_exn target_best_tip_path in
           let target_breadcrumb_child_hash =
             Transition_frontier.Breadcrumb.state_hash target_breadcrumb_child
           in
           let target_breadcrumb_parent =
             List.nth_exn target_best_tip_path
               (List.length target_best_tip_path - 2)
           in
           let test =
             setup_catchup_pipes ~network:my_net.network
               ~frontier:my_net.state.frontier
           in
           let parent_hash =
             Transition_frontier.Breadcrumb.parent_hash target_breadcrumb_parent
           in
           let target_transition_parent =
             Transition_handler.Unprocessed_transition_cache.register_exn
               test.cache
               (downcast_breadcrumb target_breadcrumb_parent)
           in
           let target_transition_child =
             Transition_handler.Unprocessed_transition_cache.register_exn
               test.cache
               (downcast_breadcrumb target_breadcrumb_child)
           in
           [%log info] "validation fails unit test" ;
           Strict_pipe.Writer.write test.job_writer
             ( parent_hash
             , [ Rose_tree.T
                   ( target_transition_parent
                   , [ Rose_tree.T (target_transition_child, []) ] )
               ] ) ;
           Thread_safe.block_on_async_exn (fun () ->
               let final =
                 Cache_lib.Cached.final_state target_transition_parent
               in
               match%map
                 Deferred.any
                   [ (Ivar.read final >>| fun x -> `Catchup_failed x)
                   ; Strict_pipe.Reader.read test.breadcrumbs_reader
                     >>| const `Catchup_success
                   ]
               with
               | `Catchup_success ->
                   [%log info]
                     "validation fails unit test: somehow incorrectly succeeded" ;

                   failwith
                     "target transition should've been invalidated with a \
                      failure"
               | `Catchup_failed fnl -> (
                   match fnl with
                   | `Success _ ->
                       [%log info]
                         "validation fails unit test: somehow incorrectly \
                          succeeded" ;
                       failwith "final state should be at `Failed"
                   | `Failed ->
                       [%log info]
                         "validation fails unit test: correctly failed, running \
                          checks" ;

                       let catchup_tree =
                         match
                           Transition_frontier.catchup_tree my_net.state.frontier
                         with
                         | Full tr ->
                             tr
                         | Hash _ ->
                             failwith
                               "in super catchup unit tests, the catchup tree \
                                should always be Full_catchup_tree, but it is \
                                Catchup_hash_tree for some reason"
                       in
                       let catchup_tree_node_list =
                         State_hash.Table.data catchup_tree.nodes
                       in
                       List.iter catchup_tree_node_list ~f:(fun catchup_node ->
                           let hash = catchup_node.state_hash in
                           if
                             Marlin_plonk_bindings_pasta_fp.equal hash
                               target_breadcrumb_child_hash
                           then
                             failwith
                               "the catchup job associated with \
                                target_breadcrumb_child_hash should have been \
                                cancelled and thus removed from the catchup \
                                tree, but it is still here"
                           else ()) ))) *)

    (* let%test_unit "when verification of a blocks fails, catchup will cancel \
                    its children's catchup job and remove the failed-to-verify \
                    block from the cache" =
       Quickcheck.test ~trials:1
         Fake_network.Generator.(
           gen ~precomputed_values ~verifier ~max_frontier_length
             ~use_super_catchup
             [ fresh_peer
             ; broken_rpc_peer_branch
                 ~frontier_branch_size:(max_frontier_length / 2)
                 ~get_transition_chain_impl_option:None
               (* TODO: write some kind of mock that makes verification fail, and thus make the test pass *)
             ])
         ~f:(fun network ->
           let open Fake_network in
           let [ my_net; peer_net ] = network.peer_networks in
           let target_best_tip_path =
             Transition_frontier.best_tip_path peer_net.state.frontier
           in
           let open Fake_network in
           let target_breadcrumb_child = List.last_exn target_best_tip_path in
           let target_breadcrumb_child_hash =
             Transition_frontier.Breadcrumb.state_hash target_breadcrumb_child
           in
           let target_breadcrumb_parent =
             List.nth_exn target_best_tip_path
               (List.length target_best_tip_path - 2)
           in
           let test =
             setup_catchup_pipes ~network:my_net.network
               ~frontier:my_net.state.frontier
           in
           let parent_hash =
             Transition_frontier.Breadcrumb.parent_hash target_breadcrumb_parent
           in
           let target_transition_parent =
             Transition_handler.Unprocessed_transition_cache.register_exn
               test.cache
               (downcast_breadcrumb target_breadcrumb_parent)
           in
           let target_transition_child =
             Transition_handler.Unprocessed_transition_cache.register_exn
               test.cache
               (downcast_breadcrumb target_breadcrumb_child)
           in
           Strict_pipe.Writer.write test.job_writer
             ( parent_hash
             , [ Rose_tree.T
                   ( target_transition_parent
                   , [ Rose_tree.T (target_transition_child, []) ] )
               ] ) ;
           Thread_safe.block_on_async_exn (fun () ->
               let final =
                 Cache_lib.Cached.final_state target_transition_parent
               in
               match%map
                 Deferred.any
                   [ (Ivar.read final >>| fun x -> `Catchup_failed x)
                   ; Strict_pipe.Reader.read test.breadcrumbs_reader
                     >>| const `Catchup_success
                   ]
               with
               | `Catchup_success ->
                   failwith
                     "target transition should've been invalidated with a \
                      failure"
               | `Catchup_failed fnl -> (
                   match fnl with
                   | `Success _ ->
                       failwith "final state should be at `Failed"
                   | `Failed ->
                       let catchup_tree =
                         match
                           Transition_frontier.catchup_tree my_net.state.frontier
                         with
                         | Full tr ->
                             tr
                         | Hash _ ->
                             failwith
                               "in super catchup unit tests, the catchup tree \
                                should always be Full_catchup_tree, but it is \
                                Catchup_hash_tree for some reason"
                       in
                       let catchup_tree_node_list =
                         State_hash.Table.data catchup_tree.nodes
                       in
                       List.iter catchup_tree_node_list ~f:(fun catchup_node ->
                           let hash = catchup_node.state_hash in
                           if
                             Marlin_plonk_bindings_pasta_fp.equal hash
                               target_breadcrumb_child_hash
                           then
                             failwith
                               "the catchup job associated with \
                                target_breadcrumb_child_hash should have been \
                                cancelled and thus removed from the catchup \
                                tree, but it is still here"
                           else ()) ))) *)

    (* let%test_unit "when building a breadcrumb fails, catchup will cancel its \
                    children's catchup job and remove the failed-to-build block \
                    from the cache" =
       Quickcheck.test ~trials:1
         Fake_network.Generator.(
           gen ~precomputed_values ~verifier ~max_frontier_length
             ~use_super_catchup
             [ fresh_peer
             ; broken_rpc_peer_branch
                 ~frontier_branch_size:(max_frontier_length / 2)
                 ~get_transition_chain_impl_option:None
             ])
         ~f:(fun network ->
           let open Fake_network in
           let [ my_net; peer_net ] = network.peer_networks in
           let target_best_tip_path =
             Transition_frontier.best_tip_path peer_net.state.frontier
           in
           let open Fake_network in
           let target_breadcrumb_child = List.last_exn target_best_tip_path in
           let target_breadcrumb_child_hash =
             Transition_frontier.Breadcrumb.state_hash target_breadcrumb_child
           in
           let target_breadcrumb_parent =
             List.nth_exn target_best_tip_path
               (List.length target_best_tip_path - 2)
           in
           let test =
             setup_catchup_pipes ~network:my_net.network
               ~frontier:my_net.state.frontier
             (* setup_catchup_pipes_fail_build_breadcrumb ~network:my_net.network
               ~frontier:my_net.state.frontier *)
           in
           let parent_hash =
             Transition_frontier.Breadcrumb.parent_hash target_breadcrumb_parent
           in
           let target_transition_parent =
             Transition_handler.Unprocessed_transition_cache.register_exn
               test.cache
               (downcast_breadcrumb target_breadcrumb_parent)
           in
           let target_transition_child =
             Transition_handler.Unprocessed_transition_cache.register_exn
               test.cache
               (downcast_breadcrumb target_breadcrumb_child)
           in
           Strict_pipe.Writer.write test.job_writer
             ( parent_hash
             , [ Rose_tree.T
                   ( target_transition_parent
                   , [ Rose_tree.T (target_transition_child, []) ] )
               ] ) ;
           Thread_safe.block_on_async_exn (fun () ->
               let final =
                 Cache_lib.Cached.final_state target_transition_parent
               in
               match%map
                 Deferred.any
                   [ (Ivar.read final >>| fun x -> `Catchup_failed x)
                   ; Strict_pipe.Reader.read test.breadcrumbs_reader
                     >>| const `Catchup_success
                   ]
               with
               | `Catchup_success ->
                   failwith
                     "target transition should've been invalidated with a \
                      failure"
               | `Catchup_failed fnl -> (
                   match fnl with
                   | `Success _ ->
                       failwith "final state should be at `Failed"
                   | `Failed ->
                       let catchup_tree =
                         match
                           Transition_frontier.catchup_tree my_net.state.frontier
                         with
                         | Full tr ->
                             tr
                         | Hash _ ->
                             failwith
                               "in super catchup unit tests, the catchup tree \
                                should always be Full_catchup_tree, but it is \
                                Catchup_hash_tree for some reason"
                       in
                       let catchup_tree_node_list =
                         State_hash.Table.data catchup_tree.nodes
                       in
                       List.iter catchup_tree_node_list ~f:(fun catchup_node ->
                           let hash = catchup_node.state_hash in
                           if
                             Marlin_plonk_bindings_pasta_fp.equal hash
                               target_breadcrumb_child_hash
                           then
                             failwith
                               "the catchup job associated with \
                                target_breadcrumb_child_hash should have been \
                                cancelled and thus removed from the catchup \
                                tree, but it is still here"
                           else ()) ))) *)
  end )
