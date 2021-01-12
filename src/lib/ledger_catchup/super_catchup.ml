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
    type t = {parent: Node.t; child: Node.t}

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
            f {child; parent} )

  let graph_attributes (_ : t) = [`Rankdir `LeftToRight]

  let get_subgraph _ = None

  let default_vertex_attributes _ = [`Shape `Circle]

  let vertex_attributes (v : Node.t) =
    let color =
      match v.state with
      | Failed ->
          (* red *)
          0xFF3333
      | Root _ | Finished _ ->
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
    [`Shape `Circle; `Style `Filled; `Fillcolor color]

  let vertex_name (node : V.t) =
    sprintf "\"%s\"" (State_hash.to_base58_check node.state_hash)

  let default_edge_attributes _ = []

  let edge_attributes _ = []
end)

let _write_graph (t : t) =
  let path = "/home/izzy/repos/coda/super-catchup-develop/catchup.dot" in
  Out_channel.with_file path ~f:(fun c -> G.output_graph c t)

let write_graph (_ : t) = ()

let verify_transition ~logger ~consensus_constants ~trust_system ~frontier
    ~unprocessed_transition_cache enveloped_transition =
  let sender = Envelope.Incoming.sender enveloped_transition in
  let genesis_state_hash = Transition_frontier.genesis_state_hash frontier in
  let transition_with_hash = Envelope.Incoming.data enveloped_transition in
  let cached_initially_validated_transition_result =
    let open Result.Let_syntax in
    let%bind initially_validated_transition =
      transition_with_hash
      |> External_transition.skip_time_received_validation
           `This_transition_was_not_received_via_gossip
      |> External_transition.validate_genesis_protocol_state
           ~genesis_state_hash
      >>= External_transition.validate_protocol_versions
      >>= External_transition.validate_delta_transition_chain
    in
    let enveloped_initially_validated_transition =
      Envelope.Incoming.map enveloped_transition
        ~f:(Fn.const initially_validated_transition)
    in
    Transition_handler.Validator.validate_transition ~logger ~frontier
      ~consensus_constants ~unprocessed_transition_cache
      enveloped_initially_validated_transition
  in
  let open Deferred.Let_syntax in
  match cached_initially_validated_transition_result with
  | Ok x ->
      Deferred.return @@ Ok (`Building_path x)
  | Error (`In_frontier hash) ->
      [%log trace]
        "transition queried during ledger catchup has already been seen" ;
      Deferred.return @@ Ok (`In_frontier hash)
  | Error (`In_process consumed_state) -> (
      [%log trace]
        "transition queried during ledger catchup is still in process in one \
         of the components in transition_frontier" ;
      match%map Ivar.read consumed_state with
      | `Failed ->
          [%log trace] "transition queried during ledger catchup failed" ;
          Error (Error.of_string "Previous transition failed")
      | `Success hash ->
          Ok (`In_frontier hash) )
  | Error (`Verifier_error error) ->
      [%log warn]
        ~metadata:[("error", Error_json.error_to_yojson error)]
        "verifier threw an error while verifying transiton queried during \
         ledger catchup: $error" ;
      Deferred.Or_error.fail (Error.tag ~tag:"verifier threw an error" error)
  | Error `Invalid_proof ->
      let%map () =
        Trust_system.record_envelope_sender trust_system logger sender
          ( Trust_system.Actions.Gossiped_invalid_transition
          , Some ("invalid proof", []) )
      in
      Error (Error.of_string "invalid proof")
  | Error `Invalid_genesis_protocol_state ->
      let%map () =
        Trust_system.record_envelope_sender trust_system logger sender
          ( Trust_system.Actions.Gossiped_invalid_transition
          , Some ("invalid genesis protocol state", []) )
      in
      Error (Error.of_string "invalid genesis protocol state")
  | Error `Invalid_delta_transition_chain_proof ->
      let%map () =
        Trust_system.record_envelope_sender trust_system logger sender
          ( Trust_system.Actions.Gossiped_invalid_transition
          , Some ("invalid delta transition chain witness", []) )
      in
      Error (Error.of_string "invalid delta transition chain witness")
  | Error `Invalid_protocol_version ->
      let transition =
        External_transition.Validation.forget_validation transition_with_hash
      in
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
                           ~f:Protocol_version.to_string ) ) ] ) )
      in
      Error (Error.of_string "invalid protocol version")
  | Error `Mismatched_protocol_version ->
      let transition =
        External_transition.Validation.forget_validation transition_with_hash
      in
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
                  , `String Protocol_version.(get_current () |> to_string) ) ]
              ) )
      in
      Error (Error.of_string "mismatched protocol version")
  | Error `Disconnected ->
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
                 ; choice (f x) (fun x -> `Ok x) ]
             with
             | `Finished ->
                 ()
             | `Ok (Ok x) ->
                 Ivar.fill_if_empty res (Ok x)
             | `Ok (Error e) ->
                 errs := e :: !errs )
     in
     Ivar.fill_if_empty res (Error (Error.of_list !errs))) ;
  Ivar.read res

let try_to_connect_hash_chain t hashes ~frontier =
  let logger = t.logger in
  List.fold_until
    (Non_empty_list.to_list hashes)
    ~init:[]
    ~f:(fun acc hash ->
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
          Continue (hash :: acc) )
    ~finish:(fun acc ->
      let module T = struct
        type t = State_hash.t list [@@deriving to_yojson]
      end in
      let all_hashes =
        List.map (Transition_frontier.all_breadcrumbs frontier) ~f:(fun b ->
            Frontier_base.Breadcrumb.state_hash b )
      in
      [%log debug]
        ~metadata:
          [ ("n", `Int (List.length acc))
          ; ("hashes", T.to_yojson acc)
          ; ("all_hashes", T.to_yojson all_hashes) ]
        "Finishing download_state_hashes with $n $hashes. with $all_hashes" ;
      Or_error.errorf !"Peer moves too fast" )

(* returns a list of state-hashes with the older ones at the front *)
let download_state_hashes t ~logger ~trust_system ~network ~frontier
    ~target_hash =
  [%log debug]
    ~metadata:[("target_hash", State_hash.to_yojson target_hash)]
    "Doing a catchup job with target $target_hash" ;
  let%bind peers =
    (* TODO: Find some preferred peers, e.g., whoever told us about this target_hash *)
    Mina_networking.peers network >>| List.permute
  in
  let open Deferred.Or_error.Let_syntax in
  find_map_ok ~how:(`Max_concurrent_jobs 12) peers ~f:(fun peer ->
      let%bind transition_chain_proof =
        Mina_networking.get_transition_chain_proof
          ~timeout:(Time.Span.of_sec 10.) network peer target_hash
      in
      (* a list of state_hashes from new to old *)
      let%bind hashes =
        match
          Transition_chain_verifier.verify ~target_hash ~transition_chain_proof
        with
        | Some hashes ->
            Deferred.Or_error.return hashes
        | None ->
            let error_msg =
              sprintf
                !"Peer %{sexp:Network_peer.Peer.t} sent us bad proof"
                peer
            in
            ignore
              Trust_system.(
                record trust_system logger peer
                  Actions.
                    ( Sent_invalid_transition_chain_merkle_proof
                    , Some (error_msg, []) )) ;
            Deferred.Or_error.error_string error_msg
      in
      Deferred.return @@ try_to_connect_hash_chain t hashes ~frontier )

let get_state_hashes = ()

module Initial_validate_batcher = struct
  open Network_pool.Batcher

  type input =
    (External_transition.t, State_hash.t) With_hash.t Envelope.Incoming.t

  type nonrec 'a t = (input, input, 'a) t

  let create ~verifier : _ t =
    create
      ~logger:
        (Logger.create
           ~metadata:[("name", `String "initial_validate_batcher")]
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
            c )
      (fun xs ->
        let input = function `Partially_validated x | `Init x -> x in
        List.map xs ~f:(fun x ->
            External_transition.Validation.wrap
              (Envelope.Incoming.data (input x)) )
        |> External_transition.validate_proofs ~verifier
        >>| function
        | Ok tvs ->
            Ok (List.map tvs ~f:(fun x -> `Valid x))
        | Error `Invalid_proof ->
            Ok (List.map xs ~f:(fun x -> `Potentially_invalid (input x)))
        | Error (`Verifier_error e) ->
            Error e )

  let verify (t : _ t) = verify t
end

module Verify_work_batcher = struct
  open Network_pool.Batcher

  type input = External_transition.Initial_validated.t Envelope.Incoming.t

  type nonrec 'a t = (input, input, 'a) t

  let create ~verifier : _ t =
    let works (x : input) =
      let wh, _ = x.data in
      External_transition.staged_ledger_diff wh.data
      |> Staged_ledger_diff.completed_works
    in
    create
      ~logger:
        (Logger.create ~metadata:[("name", `String "verify_work_batcher")] ())
      ~weight:(fun (x : input) ->
        List.fold ~init:0 (works x) ~f:(fun acc {proofs; _} ->
            acc + One_or_two.length proofs ) )
      ~max_weight_per_call:1000 ~how_to_add:`Insert
      ~compare_init:(fun e1 e2 ->
        let len (x : input) =
          External_transition.Initial_validated.blockchain_length x.data
        in
        match Length.compare (len e1) (len e2) with
        | 0 ->
            compare_envelope e1 e2
        | c ->
            c )
      (fun xs ->
        let input : _ -> input = function
          | `Partially_validated x | `Init x ->
              x
        in
        List.concat_map xs ~f:(fun x ->
            works (input x)
            |> List.concat_map ~f:(fun {fee; prover; proofs} ->
                   let msg = Sok_message.create ~fee ~prover in
                   One_or_two.to_list
                     (One_or_two.map proofs ~f:(fun p -> (p, msg))) ) )
        |> Verifier.verify_transaction_snarks verifier
        >>| function
        | Ok true ->
            Ok (List.map xs ~f:(fun x -> `Valid (input x)))
        | Ok false ->
            Ok (List.map xs ~f:(fun x -> `Potentially_invalid (input x)))
        | Error e ->
            Error e )

  let verify (t : _ t) = verify t
end

let initial_validate ~(precomputed_values : Precomputed_values.t) ~logger
    ~trust_system ~(batcher : _ Initial_validate_batcher.t) ~frontier
    ~unprocessed_transition_cache transition =
  let verification_start_time = Core.Time.now () in
  let open Deferred.Result.Let_syntax in
  let%bind tv =
    let open Deferred.Let_syntax in
    match%bind Initial_validate_batcher.verify batcher transition with
    | Ok (Ok tv) ->
        return (Ok {transition with data= tv})
    | Ok (Error ()) ->
        let s = "proof failed to verify" in
        [%log warn] "%s" s ;
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
          ~metadata:[("error", Error_json.error_to_yojson e)]
          "verification of blockchain snark failed but it was our fault" ;
        return (Error `Couldn't_reach_verifier)
  in
  let verification_end_time = Core.Time.now () in
  [%log debug]
    ~metadata:
      [ ( "time_elapsed"
        , `Float
            Core.Time.(
              Span.to_sec @@ diff verification_end_time verification_start_time)
        ) ]
    "verification of proofs complete" ;
  verify_transition ~logger
    ~consensus_constants:precomputed_values.consensus_constants ~trust_system
    ~frontier ~unprocessed_transition_cache tv
  |> Deferred.map ~f:(Result.map_error ~f:(fun e -> `Error e))

open Frontier_base

module Downloader = struct
  module Key = struct
    module T = struct
      type t = State_hash.t * Length.t [@@deriving to_yojson, hash, sexp]

      let compare (h1, n1) (h2, n2) =
        match Length.compare n1 n2 with
        | 0 ->
            State_hash.compare h1 h2
        | c ->
            c
    end

    include T
    include Hashable.Make (T)
    include Comparable.Make (T)
  end

  include Downloader.Make
            (Key)
            (struct
              include Attempt_history.Attempt

              let download : t = {failure_reason= `Download}

              let worth_retrying (t : t) =
                match t.failure_reason with `Download -> true | _ -> false
            end)
            (struct
              type t = External_transition.t

              let key (t : t) =
                External_transition.(state_hash t, blockchain_length t)
            end)
end

let check_invariant ~downloader t =
  Downloader.check_invariant downloader ;
  [%test_eq: int]
    (Downloader.total_jobs downloader)
    (Hashtbl.count t.nodes ~f:(fun node ->
         Node.State.enum node.state = To_download ))

let download s d ~key ~attempts =
  let logger = Logger.create () in
  [%log debug]
    ~metadata:[("key", Downloader.Key.to_yojson key); ("caller", `String s)]
    "Mownload download $key" ;
  Downloader.download d ~key ~attempts

let create_node ~downloader t ~parent x =
  let attempts = Attempt_history.empty in
  let state, h, blockchain_length, result =
    match x with
    | `Root root ->
        ( Node.State.Finished root
        , Breadcrumb.state_hash root
        , Breadcrumb.blockchain_length root
        , Ivar.create_full (Ok root) )
    | `Hash (h, l) ->
        ( Node.State.To_download
            (download "create_node" downloader ~key:(h, l) ~attempts)
        , h
        , l
        , Ivar.create () )
    | `Initial_validated b ->
        let t = (Cached.peek b).Envelope.Incoming.data in
        let open External_transition.Initial_validated in
        ( Node.State.To_verify b
        , state_hash t
        , blockchain_length t
        , Ivar.create () )
  in
  let node =
    {Node.state; state_hash= h; blockchain_length; attempts; parent; result}
  in
  upon (Ivar.read node.result) (fun _ ->
      Downloader.cancel downloader (h, blockchain_length) ) ;
  Hashtbl.incr t.states (Node.State.enum node.state) ;
  Hashtbl.set t.nodes ~key:h ~data:node ;
  ( try check_invariant ~downloader t
    with e ->
      [%log' debug t.logger]
        ~metadata:[("exn", `String (Exn.to_string e))]
        "create_node $exn" ) ;
  write_graph t ; node

let set_state t node s = set_state t node s ; write_graph t

(* TODO: In the future, this could take over scheduling bootstraps too. *)
let run ~logger ~trust_system ~verifier ~network ~frontier
    ~(catchup_job_reader :
       ( State_hash.t
       * ( External_transition.Initial_validated.t Envelope.Incoming.t
         , State_hash.t )
         Cached.t
         Rose_tree.t
         list )
       Strict_pipe.Reader.t) ~precomputed_values ~unprocessed_transition_cache
    ~(catchup_breadcrumbs_writer :
       ( (Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t Rose_tree.t
         list
         * [`Ledger_catchup of unit Ivar.t | `Catchup_scheduler]
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
  let%bind downloader =
    Downloader.create ~stop ~trust_system ~preferred:[] ~max_batch_size:5
      ~get:(fun peer hs ->
        let timeout =
          let sec_per_block = 15. in
          Time.Span.of_sec (Float.of_int (List.length hs) *. sec_per_block)
        in
        Mina_networking.get_transition_chain
          ~heartbeat_timeout:(Time_ns.Span.of_sec 20.) ~timeout network peer
          (List.map hs ~f:fst) )
      ~peers:(fun () -> Mina_networking.peers network)
  in
  check_invariant ~downloader t ;
  let () =
    Downloader.set_check_invariant (fun downloader ->
        check_invariant ~downloader t )
  in
  every ~stop (Time.Span.of_sec 10.) (fun () ->
      [%log debug] ~metadata:[("states", to_yojson t)] "Catchup states" ) ;
  let initial_validation_batcher = Initial_validate_batcher.create ~verifier in
  let verify_work_batcher = Verify_work_batcher.create ~verifier in
  let set_state t node s =
    set_state t node s ;
    try check_invariant ~downloader t
    with e ->
      [%log' debug t.logger]
        ~metadata:[("exn", `String (Exn.to_string e))]
        "set_state $exn"
  in
  let rec run_node (node : Node.t) =
    let state_hash = node.state_hash in
    let failed ~sender failure_reason =
      node.attempts
      <- ( match sender with
         | Envelope.Sender.Local ->
             node.attempts
         | Remote peer ->
             Map.set node.attempts ~key:peer ~data:{failure_reason} ) ;
      set_state t node
        (To_download
           (download "failed" downloader
              ~key:(state_hash, node.blockchain_length)
              ~attempts:node.attempts)) ;
      run_node node
    in
    let step d : (_, [`Finished]) Deferred.Result.t =
      (* TODO: See if the bail out is happening. *)
      Deferred.any [(Ivar.read node.result >>| fun _ -> Error `Finished); d]
    in
    let open Deferred.Result.Let_syntax in
    let retry () =
      let%bind () =
        step (after (Time.Span.of_sec 15.) |> Deferred.map ~f:Result.return)
      in
      run_node node
    in
    match node.state with
    | Failed | Finished _ | Root _ ->
        return ()
    | To_download download_job ->
        let%bind b, attempts = step (Downloader.Job.result download_job) in
        [%log' debug t.logger]
          ~metadata:
            [ ("state_hash", State_hash.to_yojson state_hash)
            ; ( "donwload_number"
              , `Int
                  (Hashtbl.count t.nodes ~f:(fun node ->
                       Node.State.enum node.state = To_download )) )
            ; ("total_nodes", `Int (Hashtbl.length t.nodes))
            ; ( "node_states"
              , let s = Node.State.Enum.Table.create () in
                Hashtbl.iter t.nodes ~f:(fun node ->
                    Hashtbl.incr s (Node.State.enum node.state) ) ;
                `List
                  (List.map (Hashtbl.to_alist s) ~f:(fun (k, v) ->
                       `List [Node.State.Enum.to_yojson k; `Int v] )) )
            ; ("total_jobs", `Int (Downloader.total_jobs downloader))
            ; ("downloader", Downloader.to_yojson downloader) ]
          "download finished $state_hash" ;
        node.attempts <- attempts ;
        set_state t node (To_initial_validate b) ;
        run_node node
    | To_initial_validate b -> (
        match%bind
          step
            ( initial_validate ~precomputed_values ~logger ~trust_system
                ~batcher:initial_validation_batcher ~frontier
                ~unprocessed_transition_cache
                {b with data= {With_hash.data= b.data; hash= state_hash}}
            |> Deferred.map ~f:(fun x -> Ok x) )
        with
        | Error (`Error _e) ->
            (* TODO: Log *)
            (* Validation failed. Record the failure and go back to download. *)
            failed ~sender:b.sender `Initial_validate
        | Error `Couldn't_reach_verifier ->
            retry ()
        | Ok (`In_frontier hash) ->
            finish t node (Ok (Transition_frontier.find_exn frontier hash)) ;
            Deferred.return (Ok ())
        | Ok (`Building_path tv) ->
            set_state t node (To_verify tv) ;
            run_node node )
    | To_verify tv -> (
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
            (* No need to redownload in this case. We just wait a little and try again. *)
            retry ()
        | Ok (Error ()) ->
            ( match iv.sender with
            | Local ->
                ()
            | Remote peer ->
                Trust_system.(
                  record trust_system logger peer
                    Actions.(Sent_invalid_proof, None))
                |> don't_wait_for ) ;
            let _ = Cached.invalidate_with_failure tv in
            failed ~sender:iv.sender `Verify
        | Ok (Ok av) ->
            let av =
              { av with
                data=
                  External_transition.skip_frontier_dependencies_validation
                    `This_transition_belongs_to_a_detached_subtree av.data }
            in
            let av = Cached.transform tv ~f:(fun _ -> av) in
            set_state t node (Wait_for_parent av) ;
            run_node node )
    | Wait_for_parent av ->
        let%bind parent =
          step
            ( match%map.Async
                Ivar.read (Hashtbl.find_exn t.nodes node.parent).result
              with
            | Ok x ->
                Ok x
            | Error _ ->
                let _ = Cached.invalidate_with_failure av in
                finish t node (Error ()) ;
                Error `Finished )
        in
        set_state t node (To_build_breadcrumb (`Parent parent, av)) ;
        run_node node
    | To_build_breadcrumb (`Parent parent, c) -> (
        let transition_receipt_time = Some (Time.now ()) in
        let av = Cached.peek c in
        match%bind
          step
            ( Transition_frontier.Breadcrumb.build ~logger
                ~skip_staged_ledger_verification:`Proofs ~precomputed_values
                ~verifier ~trust_system ~parent ~transition:av.data
                ~sender:(Some av.sender) ~transition_receipt_time ()
            |> Deferred.map ~f:Result.return )
        with
        | Error _e ->
            let _ = Cached.invalidate_with_failure c in
            failed ~sender:av.sender `Build_breadcrumb
        | Ok breadcrumb ->
            let%bind () =
              Scheduler.yield () |> Deferred.map ~f:Result.return
            in
            let finished = Ivar.create () in
            let c = Cached.transform c ~f:(fun _ -> breadcrumb) in
            Strict_pipe.Writer.write catchup_breadcrumbs_writer
              ( [Rose_tree.of_non_empty_list (Non_empty_list.singleton c)]
              , `Ledger_catchup finished ) ;
            let%bind () =
              (* The cached value is "freed" by the transition processor in [add_and_finalize]. *)
              step (Deferred.map (Ivar.read finished) ~f:Result.return)
            in
            Ivar.fill_if_empty node.result (Ok breadcrumb) ;
            set_state t node (Finished breadcrumb) ;
            return () )
  in
  (* TODO: Maybe add everything from transition frontier at the beginning? *)
  (* TODO: Print out the hashes you're adding *)
  Strict_pipe.Reader.iter_without_pushback catchup_job_reader
    ~f:(fun (target_parent_hash, forest) ->
      don't_wait_for
        (let state_hashes =
           match
             List.find_map (List.concat_map ~f:Rose_tree.flatten forest)
               ~f:(fun c ->
                 let h =
                   External_transition.Initial_validated.state_hash
                     (Cached.peek c).data
                 in
                 let open Option.Let_syntax in
                 let%bind {proof= path, root; data} = Best_tip_lru.get h in
                 let%bind p =
                   Transition_chain_verifier.verify
                     ~target_hash:
                       (External_transition.Initial_validated.state_hash data)
                     ~transition_chain_proof:
                       (External_transition.state_hash root, path)
                 in
                 Result.ok (try_to_connect_hash_chain t p ~frontier) )
           with
           | None ->
               download_state_hashes t ~logger ~trust_system ~network ~frontier
                 ~target_hash:target_parent_hash
           | Some res ->
               [%log debug] "Succeeded in using cache." ;
               Deferred.return (Ok res)
         in
         match%map state_hashes with
         | Error _ ->
             [%log debug]
               ~metadata:
                 [("target_hash", State_hash.to_yojson target_parent_hash)]
               "Failed to download state hashes for $target_hash"
         | Ok (root, state_hashes) ->
             [%log' debug t.logger]
               ~metadata:
                 [ ("downloader", Downloader.to_yojson downloader)
                 ; ( "node_states"
                   , let s = Node.State.Enum.Table.create () in
                     Hashtbl.iter t.nodes ~f:(fun node ->
                         Hashtbl.incr s (Node.State.enum node.state) ) ;
                     `List
                       (List.map (Hashtbl.to_alist s) ~f:(fun (k, v) ->
                            `List [Node.State.Enum.to_yojson k; `Int v] )) ) ]
               "before everything" ;
             let root =
               match root with
               | `Breadcrumb root ->
                   (* If we hit this case we should probably remove the parent from the
                  table and prune, although in theory that should be handled by
                 the frontier calling [Full_catchup_tree.apply_diffs]. *)
                   create_node ~downloader t (`Root root)
                     ~parent:(Breadcrumb.parent_hash root)
               | `Node node ->
                   (* TODO: Log what is going on with transition frontier. *)
                   node
             in
             [%log debug]
               ~metadata:[("n", `Int (List.length state_hashes))]
               "Adding $n nodes" ;
             List.iter forest
               ~f:
                 (Rose_tree.iter ~f:(fun c ->
                      let node =
                        create_node ~downloader t ~parent:target_parent_hash
                          (`Initial_validated c)
                      in
                      run_node node |> ignore )) ;
             List.fold state_hashes
               ~init:(root.state_hash, root.blockchain_length)
               ~f:(fun (parent, l) h ->
                 let l = Length.succ l in
                 ( if not (Hashtbl.mem t.nodes h) then
                   let node =
                     create_node t ~downloader ~parent (`Hash (h, l))
                   in
                   don't_wait_for (run_node node >>| ignore) ) ;
                 (h, l) )
             |> ignore) )

let run ~logger ~precomputed_values ~trust_system ~verifier ~network ~frontier
    ~catchup_job_reader ~catchup_breadcrumbs_writer
    ~unprocessed_transition_cache : unit =
  run ~logger ~trust_system ~verifier ~network ~frontier ~catchup_job_reader
    ~precomputed_values ~unprocessed_transition_cache
    ~catchup_breadcrumbs_writer
  |> don't_wait_for

let%test_module "Ledger_catchup tests" =
  ( module struct
    let () =
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true

    let max_frontier_length = 10

    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let proof_level = precomputed_values.proof_level

    let trust_system = Trust_system.null ()

    let time_controller = Block_time.Controller.basic ~logger

    let downcast_transition transition =
      let transition =
        transition
        |> External_transition.Validation
           .reset_frontier_dependencies_validation
        |> External_transition.Validation.reset_staged_ledger_diff_validation
      in
      Envelope.Incoming.wrap ~data:transition ~sender:Envelope.Sender.Local

    let downcast_breadcrumb breadcrumb =
      downcast_transition
        (Transition_frontier.Breadcrumb.validated_transition breadcrumb)

    type catchup_test =
      { cache: Transition_handler.Unprocessed_transition_cache.t
      ; job_writer:
          ( State_hash.t
            * ( External_transition.Initial_validated.t Envelope.Incoming.t
              , State_hash.t )
              Cached.t
              Rose_tree.t
              list
          , Strict_pipe.crash Strict_pipe.buffered
          , unit )
          Strict_pipe.Writer.t
      ; breadcrumbs_reader:
          ( (Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t
            Rose_tree.t
            list
          * [`Catchup_scheduler | `Ledger_catchup of unit Ivar.t] )
          Strict_pipe.Reader.t }

    let run_catchup ~network ~frontier =
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
      let pids = Child_processes.Termination.create_pid_table () in
      let%map verifier =
        Verifier.create ~logger ~proof_level ~conf_dir:None ~pids
      in
      run ~logger ~precomputed_values ~verifier ~trust_system ~network
        ~frontier ~catchup_breadcrumbs_writer ~catchup_job_reader
        ~unprocessed_transition_cache ;
      { cache= unprocessed_transition_cache
      ; job_writer= catchup_job_writer
      ; breadcrumbs_reader= catchup_breadcrumbs_reader }

    let run_catchup_with_target ~network ~frontier ~target_breadcrumb =
      let%map test = run_catchup ~network ~frontier in
      let parent_hash =
        Transition_frontier.Breadcrumb.parent_hash target_breadcrumb
      in
      let target_transition =
        Transition_handler.Unprocessed_transition_cache.register_exn test.cache
          (downcast_breadcrumb target_breadcrumb)
      in
      Strict_pipe.Writer.write test.job_writer
        (parent_hash, [Rose_tree.T (target_transition, [])]) ;
      (`Test test, `Cached_transition target_transition)

    let test_successful_catchup ~my_net ~target_best_tip_path =
      let open Fake_network in
      let target_breadcrumb = List.last_exn target_best_tip_path in
      let%bind `Test {breadcrumbs_reader; _}, _ =
        run_catchup_with_target ~network:my_net.network
          ~frontier:my_net.state.frontier ~target_breadcrumb
      in
      (* TODO: expose Strict_pipe.read *)
      let%map cached_catchup_breadcrumbs =
        Block_time.Timeout.await_exn time_controller
          ~timeout_duration:(Block_time.Span.of_ms 30000L)
          ( match%map Strict_pipe.Reader.read breadcrumbs_reader with
          | `Eof ->
              failwith "unexpected EOF"
          | `Ok (_, `Catchup_scheduler) ->
              failwith "did not expect a catchup scheduler action"
          | `Ok (breadcrumbs, `Ledger_catchup ivar) ->
              Ivar.fill ivar () ; List.hd_exn breadcrumbs )
      in
      let catchup_breadcrumbs =
        Rose_tree.map cached_catchup_breadcrumbs
          ~f:Cache_lib.Cached.invalidate_with_success
      in
      [%test_result: int]
        ~message:
          "Transition_frontier should not have any more catchup jobs at the \
           end of the test"
        ~equal:( = ) ~expect:0
        (Broadcast_pipe.Reader.peek Catchup_jobs.reader) ;
      let catchup_breadcrumbs_are_best_tip_path =
        Rose_tree.equal (Rose_tree.of_list_exn target_best_tip_path)
          catchup_breadcrumbs ~f:(fun breadcrumb_tree1 breadcrumb_tree2 ->
            External_transition.Validated.equal
              (Transition_frontier.Breadcrumb.validated_transition
                 breadcrumb_tree1)
              (Transition_frontier.Breadcrumb.validated_transition
                 breadcrumb_tree2) )
      in
      if not catchup_breadcrumbs_are_best_tip_path then
        failwith
          "catchup breadcrumbs were not equal to the best tip path we expected"

    let%test_unit "can catchup to a peer within [2/k,k]" =
      Quickcheck.test ~trials:5
        Fake_network.Generator.(
          let open Quickcheck.Generator.Let_syntax in
          let%bind peer_branch_size =
            Int.gen_incl (max_frontier_length / 2) (max_frontier_length - 1)
          in
          gen ~precomputed_values ~max_frontier_length
            [ fresh_peer
            ; peer_with_branch ~frontier_branch_size:peer_branch_size ])
        ~f:(fun network ->
          let open Fake_network in
          let [my_net; peer_net] = network.peer_networks in
          (* TODO: I don't think I'm testing this right... *)
          let target_best_tip_path =
            Transition_frontier.(
              path_map ~f:Fn.id peer_net.state.frontier
                (best_tip peer_net.state.frontier))
          in
          Thread_safe.block_on_async_exn (fun () ->
              test_successful_catchup ~my_net ~target_best_tip_path ) )

    let%test_unit "catchup succeeds even if the parent transition is already \
                   in the frontier" =
      Quickcheck.test ~trials:1
        Fake_network.Generator.(
          gen ~precomputed_values ~max_frontier_length
            [fresh_peer; peer_with_branch ~frontier_branch_size:1])
        ~f:(fun network ->
          let open Fake_network in
          let [my_net; peer_net] = network.peer_networks in
          let target_best_tip_path =
            [Transition_frontier.best_tip peer_net.state.frontier]
          in
          Thread_safe.block_on_async_exn (fun () ->
              test_successful_catchup ~my_net ~target_best_tip_path ) )

    let%test_unit "catchup fails if one of the parent transitions fail" =
      Quickcheck.test ~trials:1
        Fake_network.Generator.(
          gen ~precomputed_values ~max_frontier_length
            [ fresh_peer
            ; peer_with_branch ~frontier_branch_size:(max_frontier_length * 2)
            ])
        ~f:(fun network ->
          let open Fake_network in
          let [my_net; peer_net] = network.peer_networks in
          let target_breadcrumb =
            Transition_frontier.best_tip peer_net.state.frontier
          in
          let failing_transition =
            let open Transition_frontier.Extensions in
            let history =
              get_extension
                (Transition_frontier.extensions peer_net.state.frontier)
                Root_history
            in
            let failing_root_data =
              List.nth_exn (Root_history.to_list history) 1
            in
            downcast_transition
              (Frontier_base.Root_data.Historical.transition failing_root_data)
          in
          Thread_safe.block_on_async_exn (fun () ->
              let%bind `Test {cache; _}, `Cached_transition cached_transition =
                run_catchup_with_target ~network:my_net.network
                  ~frontier:my_net.state.frontier ~target_breadcrumb
              in
              let cached_failing_transition =
                Transition_handler.Unprocessed_transition_cache.register_exn
                  cache failing_transition
              in
              let%bind () = after (Core.Time.Span.of_sec 1.) in
              ignore
                (Cache_lib.Cached.invalidate_with_failure
                   cached_failing_transition) ;
              let%map result =
                Block_time.Timeout.await_exn time_controller
                  ~timeout_duration:(Block_time.Span.of_ms 10000L)
                  (Ivar.read (Cache_lib.Cached.final_state cached_transition))
              in
              if result <> `Failed then
                failwith "expected ledger catchup to fail, but it succeeded" )
          )

    (* TODO: fix and re-enable *)
    let%test_unit "super catchup won't be blocked by transitions that are \
                   still being processed" =
      Quickcheck.test ~trials:1
        Fake_network.Generator.(
          gen ~max_frontier_length ~precomputed_values
            [ fresh_peer
            ; peer_with_branch ~frontier_branch_size:(max_frontier_length - 1)
            ])
        ~f:(fun network ->
          let open Fake_network in
          let [my_net; peer_net] = network.peer_networks in
          Core.Printf.printf "$my_net.state.frontier.root = %s\n"
            ( State_hash.to_base58_check
            @@ Transition_frontier.(
                 Breadcrumb.state_hash @@ root my_net.state.frontier) ) ;
          Core.Printf.printf "$peer_net.state.frontier.root = %s\n"
            ( State_hash.to_base58_check
            @@ Transition_frontier.(
                 Breadcrumb.state_hash @@ root my_net.state.frontier) ) ;
          let missing_breadcrumbs =
            let best_tip_path =
              Transition_frontier.best_tip_path peer_net.state.frontier
            in
            Core.Printf.printf "$best_tip_path=\n  %s\n"
              ( String.concat ~sep:"\n  "
              @@ List.map
                   ~f:
                     (Fn.compose State_hash.to_base58_check
                        Transition_frontier.Breadcrumb.state_hash)
                   best_tip_path ) ;
            (* List.take best_tip_path (List.length best_tip_path - 1) *)
            best_tip_path
          in
          Async.Thread_safe.block_on_async_exn (fun () ->
              let%bind {cache; job_writer; breadcrumbs_reader} =
                run_catchup ~network:my_net.network
                  ~frontier:my_net.state.frontier
              in
              let jobs =
                List.map (List.rev missing_breadcrumbs) ~f:(fun breadcrumb ->
                    let parent_hash =
                      Transition_frontier.Breadcrumb.parent_hash breadcrumb
                    in
                    let cached_transition =
                      Transition_handler.Unprocessed_transition_cache
                      .register_exn cache
                        (downcast_breadcrumb breadcrumb)
                    in
                    Core.Printf.printf "$job = %s --> %s\n"
                      ( State_hash.to_base58_check
                      @@ External_transition.Initial_validated.state_hash
                      @@ Envelope.Incoming.data
                      @@ Cached.peek cached_transition )
                      (State_hash.to_base58_check parent_hash) ;
                    (parent_hash, [Rose_tree.T (cached_transition, [])]) )
              in
              let%bind () = after (Core.Time.Span.of_ms 500.) in
              List.iter jobs ~f:(Strict_pipe.Writer.write job_writer) ;
              match%map
                Block_time.Timeout.await_exn time_controller
                  ~timeout_duration:(Block_time.Span.of_ms 15000L)
                  (Strict_pipe.Reader.fold_until breadcrumbs_reader
                     ~init:missing_breadcrumbs
                     ~f:(fun remaining_breadcrumbs
                        (rose_trees, catchup_signal)
                        ->
                       let[@warning "-8"] [rose_tree] = rose_trees in
                       let catchup_breadcrumb_tree =
                         Rose_tree.map rose_tree
                           ~f:Cached.invalidate_with_success
                       in
                       Core.Printf.printf "!!!%d\n"
                         ( List.length
                         @@ Rose_tree.flatten catchup_breadcrumb_tree ) ;
                       let[@warning "-8"] [received_breadcrumb] =
                         Rose_tree.flatten catchup_breadcrumb_tree
                       in
                       match remaining_breadcrumbs with
                       | [] ->
                           failwith "received more breadcrumbs than expected"
                       | expected_breadcrumb :: remaining_breadcrumbs' ->
                           Core.Printf.printf "COMPARING %s vs. %s..."
                             ( State_hash.to_base58_check
                             @@ Transition_frontier.Breadcrumb.state_hash
                                  expected_breadcrumb )
                             ( State_hash.to_base58_check
                             @@ Transition_frontier.Breadcrumb.state_hash
                                  received_breadcrumb ) ;
                           [%test_eq: State_hash.t]
                             (Transition_frontier.Breadcrumb.state_hash
                                expected_breadcrumb)
                             (Transition_frontier.Breadcrumb.state_hash
                                received_breadcrumb)
                             ~message:
                               "received breadcrumb state hash did not match \
                                expected breadcrumb state hash" ;
                           [%test_eq: Transition_frontier.Breadcrumb.t]
                             expected_breadcrumb received_breadcrumb
                             ~message:
                               "received breadcrumb matched expected state \
                                hash, but was not equal to expected breadcrumb" ;
                           ( match catchup_signal with
                           | `Catchup_scheduler ->
                               failwith
                                 "Did not expect a catchup scheduler action"
                           | `Ledger_catchup ivar ->
                               Ivar.fill ivar () ) ;
                           print_endline " ok" ;
                           if remaining_breadcrumbs' = [] then
                             return (`Stop ())
                           else return (`Continue remaining_breadcrumbs') ))
              with
              | `Eof _ ->
                  failwith "unexpected EOF"
              | `Terminated () ->
                  () ) )
  end )
