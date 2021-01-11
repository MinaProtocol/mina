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
          (* TODO: Isolate and punish all the evil sender *)
          Deferred.unit
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
            end)
            (struct
              type t = External_transition.t

              let to_yojson _ = `List []

              let key (t : t) =
                External_transition.(state_hash t, blockchain_length t)
            end)
end

let check_invariant ~downloader t =
  Downloader.check_invariant downloader ;
  (*
  let nonzero = List.filter ~f:(fun (_, n) -> n <> 0) |>  in
  [%test_eq: (Node.State.Enum.t * int) list]
    (Hashtbl.to_alist t.states |> nonzero)
    (let s = Node.State.Enum.Table.create () in
     Hashtbl.iter t.nodes ~f:(fun node ->
         Hashtbl.incr s (Node.State.enum node.state) );
     nonzero (Hashtbl.to_alist s)); *)
  [%test_eq: int]
    (Downloader.total_jobs downloader)
    (Hashtbl.count t.nodes ~f:(fun node ->
         Node.State.enum node.state = To_download ))

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
            (Downloader.download downloader ~key:(h, l) ~attempts)
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
        Mina_networking.get_transition_chain ~timeout network peer
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
           (Downloader.download downloader
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
            (* TODO: Punish *)
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
             |> ignore ;
             List.iter forest
               ~f:
                 (Rose_tree.iter ~f:(fun c ->
                      let node =
                        create_node ~downloader t ~parent:target_parent_hash
                          (`Initial_validated c)
                      in
                      run_node node |> ignore )) ;
             [%log' fatal t.logger]
               ~metadata:
                 [ ( "donwload_number"
                   , `Int
                       (Hashtbl.count t.nodes ~f:(fun node ->
                            Node.State.enum node.state = To_download )) )
                 ; ("total_jobs", `Int (Downloader.total_jobs downloader))
                 ; ( "node_states"
                   , let s = Node.State.Enum.Table.create () in
                     Hashtbl.iter t.nodes ~f:(fun node ->
                         Hashtbl.incr s (Node.State.enum node.state) ) ;
                     `List
                       (List.map (Hashtbl.to_alist s) ~f:(fun (k, v) ->
                            `List [Node.State.Enum.to_yojson k; `Int v] )) ) ]
               "heres good") )

let run ~logger ~precomputed_values ~trust_system ~verifier ~network ~frontier
    ~catchup_job_reader ~catchup_breadcrumbs_writer
    ~unprocessed_transition_cache : unit =
  run ~logger ~trust_system ~verifier ~network ~frontier ~catchup_job_reader
    ~precomputed_values ~unprocessed_transition_cache
    ~catchup_breadcrumbs_writer
  |> don't_wait_for

(*
module Downloader : sig
  type t

  module Job = Downloader_job

  val cancel : t -> State_hash.t -> unit

  val create :
       stop:unit Deferred.t
    -> trust_system:Trust_system.t
    -> network:Mina_networking.t
    -> t Deferred.t

  val download :
       t
    -> state_hash:State_hash.t
    -> blockchain_length:Length.t
    -> attempts:Attempt_history.t
    -> Job.t

  val total_jobs : t -> int

  val check_invariant : t -> unit

  val set_check_invariant : (t -> unit) -> unit
end = struct
  let max_wait = Time.Span.of_ms 100.

  module Job = Downloader_job
  open Job

  module Q = struct
    module Key = State_hash

    module Key_value = struct
      type 'a t = {key: Key.t; mutable value: 'a} [@@deriving fields]
    end

    (* Hash_queue would be perfect, but it doesn't expose enough for
         us to make sure the underlying queue is sorted by blockchain_length. *)
    type 'a t =
      { queue: 'a Key_value.t Doubly_linked.t
      ; table: 'a Key_value.t Doubly_linked.Elt.t Key.Table.t }

    let dequeue t =
      Option.map (Doubly_linked.remove_first t.queue) ~f:(fun {key; value} ->
          Hashtbl.remove t.table key ; value )

    let enqueue t (e : Job.t) =
      if Hashtbl.mem t.table e.hash then `Key_already_present
      else
        let kv = {Key_value.key= e.hash; value= e} in
        let elt =
          match
            Doubly_linked.find_elt t.queue ~f:(fun {value; _} ->
                Length.( < ) e.blockchain_length value.Job.blockchain_length )
          with
          | None ->
              (* e is >= everything. Put it at the back. *)
              Doubly_linked.insert_last t.queue kv
          | Some pred ->
              Doubly_linked.insert_before t.queue pred kv
        in
        Hashtbl.set t.table ~key:e.hash ~data:elt ;
        `Ok

    let enqueue_exn t e =
      match enqueue t e with
      | `Key_already_present ->
          failwith "key already present"
      | `Ok ->
          ()

    let iter t ~f = Doubly_linked.iter t.queue ~f:(fun {value; _} -> f value)

    let lookup t k =
      Option.map (Hashtbl.find t.table k) ~f:(fun x ->
          (Doubly_linked.Elt.value x).value )

    let remove t k =
      match Hashtbl.find_and_remove t.table k with
      | None ->
          ()
      | Some elt ->
          Doubly_linked.remove t.queue elt

    let length t = Doubly_linked.length t.queue

    let is_empty t = Doubly_linked.is_empty t.queue

    let to_list t = List.map (Doubly_linked.to_list t.queue) ~f:Key_value.value

    let create () =
      {table= State_hash.Table.create (); queue= Doubly_linked.create ()}
  end

  module Useful_peers = struct
    type t =
      { all: State_hash.Hash_set.t Peer.Table.t
      ; r: (Peer.t * State_hash.Hash_set.t) Strict_pipe.Reader.t sexp_opaque
      ; w:
          ( Peer.t * State_hash.Hash_set.t
          , Strict_pipe.drop_head Strict_pipe.buffered
          , unit )
          Strict_pipe.Writer.t
          sexp_opaque }
    [@@deriving sexp]

    let create ~all_peers =
      let all = Peer.Table.create () in
      List.iter all_peers ~f:(fun p ->
          Hashtbl.set all ~key:p ~data:(State_hash.Hash_set.create ()) ) ;
      let r, w =
        Strict_pipe.create ~name:"useful_peers"
          (Buffered (`Capacity 4096, `Overflow Drop_head))
      in
      Hashtbl.iteri all ~f:(fun ~key ~data ->
          Strict_pipe.Writer.write w (key, data) ) ;
      {all; r; w}

    let tear_down {all; r= _; w} =
      Hashtbl.iter all ~f:Hash_set.clear ;
      Hashtbl.clear all ;
      Strict_pipe.Writer.close w

    let rec read t =
      match%bind Strict_pipe.Reader.read t.r with
      | `Eof ->
          return `Eof
      | `Ok (_, s) as res ->
          if Hash_set.is_empty s then read t else return res

    type update =
      | New_job of {new_job: Job.t; all_peers: Peer.Set.t}
      | New_peers of
          { new_peers: Peer.Set.t
          ; lost_peers: Peer.Set.t
          ; pending: Job.t Q.t }
      | Download_finished of Peer.t * State_hash.t list
      | Job_cancelled of State_hash.t

    let replace t peer =
      match Hashtbl.find t.all peer with
      | None ->
          ()
      | Some s ->
          Strict_pipe.Writer.write t.w (peer, s)

    let update t u =
      match u with
      | Job_cancelled h ->
          Hashtbl.filter_inplace t.all ~f:(fun s ->
              Hash_set.remove s h ; Hash_set.is_empty s )
      | Download_finished (peer, hs) -> (
        match Hashtbl.find t.all peer with
        | None ->
            ()
        | Some s ->
            List.iter hs ~f:(Hash_set.remove s) ;
            if Hash_set.is_empty s then Hashtbl.remove t.all peer
            else Strict_pipe.Writer.write t.w (peer, s) )
      | New_peers {new_peers; lost_peers; pending} ->
          Set.iter lost_peers ~f:(fun p ->
              match Hashtbl.find t.all p with
              | None ->
                  ()
              | Some s ->
                  Hash_set.clear s ; Hashtbl.remove t.all p ) ;
          Set.iter new_peers ~f:(fun p ->
              if not (Hashtbl.mem t.all p) then (
                let to_try = State_hash.Hash_set.create () in
                Q.iter pending ~f:(fun j ->
                    if not (Map.mem j.attempts p) then
                      Hash_set.add to_try j.hash ) ;
                Hashtbl.add_exn t.all ~key:p ~data:to_try ;
                Strict_pipe.Writer.write t.w (p, to_try) ) )
      | New_job {new_job; all_peers} ->
          Set.iter all_peers ~f:(fun p ->
              let useful_for_job = not (Map.mem new_job.attempts p) in
              if useful_for_job then
                match Hashtbl.find t.all p with
                | Some s ->
                    Hash_set.add s new_job.hash
                | None ->
                    let s = State_hash.Hash_set.of_list [new_job.hash] in
                    Hashtbl.add_exn t.all ~key:p ~data:s ;
                    Strict_pipe.Writer.write t.w (p, s) )
  end

  type t =
    { mutable next_flush: (unit, unit) Clock.Event.t option
    ; mutable all_peers: Peer.Set.t
    ; pending: Job.t Q.t
    ; stalled: Job.t Q.t
    ; downloading: (Peer.t * Job.t) State_hash.Table.t
    ; useful_peers: Useful_peers.t
    ; flush_r: unit Strict_pipe.Reader.t (* Single reader *)
    ; flush_w:
        ( unit
        , Strict_pipe.drop_head Strict_pipe.buffered
        , unit )
        Strict_pipe.Writer.t
          (* buffer of length 0 *)
    ; network: Mina_networking.t
          (* A peer is useful if there is a job in the pending queue which has not
   been attempted with that peer. *)
    ; got_new_peers_w:
        ( unit
        , Strict_pipe.drop_head Strict_pipe.buffered
        , unit )
        Strict_pipe.Writer.t
          (* buffer of length 0 *)
    ; got_new_peers_r: unit Strict_pipe.Reader.t
    ; logger: Logger.t
    ; trust_system: Trust_system.t
    ; stop: unit Deferred.t }

  let total_jobs (t : t) =
    Q.length t.pending + Q.length t.stalled + Hashtbl.length t.downloading

  (* Checks disjointness *)
  let check_invariant (t : t) =
    Set.length
      (State_hash.Set.union_list
         [ Q.to_list t.pending |> List.map ~f:(fun j -> j.hash) |> State_hash.Set.of_list
         ; Q.to_list t.stalled |> List.map ~f:(fun j -> j.hash) |> State_hash.Set.of_list
         ; State_hash.Set.of_hashtbl_keys t.downloading
         ] )
    |> [%test_eq: int] (total_jobs t)

  let check_invariant_r = ref check_invariant

  let set_check_invariant f = check_invariant_r := f

  let job_finished t j x =
    Hashtbl.remove t.downloading j.hash ;
    Ivar.fill_if_empty j.res x ;
    try 
      !check_invariant_r t
    with e -> (
      [%log' debug t.logger]
        ~metadata:[ "exn", `String (Exn.to_string e) ]
        "job_finished $exn" 
      )


  let kill_job _t j =  Ivar.fill_if_empty j.res (Error `Finished)

  let flush_soon t =
    Option.iter t.next_flush ~f:(fun e -> Clock.Event.abort_if_possible e ()) ;
    t.next_flush
    <- Some
         (Clock.Event.run_after max_wait
            (fun () -> Strict_pipe.Writer.write t.flush_w ())
            ())

  let cancel t h =
    let job =
      List.find_map ~f:Lazy.force
        [ lazy (Q.lookup t.pending h)
        ; lazy (Q.lookup t.stalled h)
        ; lazy (Option.map ~f:snd (Hashtbl.find t.downloading h)) ]
    in
    Q.remove t.pending h ;
    Q.remove t.stalled h ;
    Hashtbl.remove t.downloading h ;
    match job with
    | None ->
        ()
    | Some j ->
        kill_job t j ;
        Useful_peers.update t.useful_peers (Job_cancelled h)

  let is_stalled t e = Set.for_all t.all_peers ~f:(Map.mem e.attempts)

  (* TODO: rewrite as "enqueue_all" *)
  let enqueue t e =
    Hashtbl.remove t.downloading e.hash ;
    if is_stalled t e then Q.enqueue t.stalled e
    else
      let r = Q.enqueue t.pending e in
      ( match r with
      | `Key_already_present ->
          ()
      | `Ok ->
          Useful_peers.update t.useful_peers
            (New_job {new_job= e; all_peers= t.all_peers}) ) ;
      r

  let enqueue_exn t e = assert (enqueue t e = `Ok)

  let refresh_peers t =
    let%map peers = Mina_networking.peers t.network in
    let peers' = Peer.Set.of_list peers in
    let new_peers = Set.diff peers' t.all_peers in
    let lost_peers = Set.diff t.all_peers peers' in
    Useful_peers.update t.useful_peers
      (New_peers {new_peers; lost_peers; pending= t.pending}) ;
    if not (Set.is_empty new_peers) then
      Strict_pipe.Writer.write t.got_new_peers_w () ;
    t.all_peers <- Peer.Set.of_list peers ;
    let rec go n =
      (* We need the initial length explicitly because we may re-enqueue things
           while looping. *)
      if n = 0 then ()
      else
        match Q.dequeue t.stalled with
        | None ->
            ()
        | Some e ->
            enqueue_exn t e ;
            go (n - 1)
    in
    go (Q.length t.stalled)

  let peer_refresh_interval = Time.Span.of_min 1.

  let tear_down
      ({ next_flush
      ; all_peers= _
      ; flush_w
      ; network= _
      ; got_new_peers_w
      ; flush_r= _
      ; useful_peers
      ; got_new_peers_r= _
      ; pending
      ; stalled
      ; downloading
      ; logger= _
      ; trust_system= _
      ; stop= _ } as t) =
    let rec clear_queue q =
      match Q.dequeue q with
      | None ->
          ()
      | Some j ->
          kill_job t j ; clear_queue q
    in
    Option.iter next_flush ~f:(fun e -> Clock.Event.abort_if_possible e ()) ;
    Strict_pipe.Writer.close flush_w ;
    Useful_peers.tear_down useful_peers ;
    Strict_pipe.Writer.close got_new_peers_w ;
    Hashtbl.iter downloading ~f:(fun (_, j) -> kill_job t j) ;
    Hashtbl.clear downloading ;
    clear_queue pending ;
    clear_queue stalled

  let make_peer_available t p =
    if Set.mem t.all_peers p then Useful_peers.replace t.useful_peers p

  let reader r = (Strict_pipe.Reader.to_linear_pipe r).pipe

  let download t peer xs =
    let timeout =
      let sec_per_block = 5. in
      Time.Span.of_sec (Float.of_int (List.length xs) *. sec_per_block)
    in
    let hs = List.map xs ~f:(fun x -> x.hash) in
    let fail ?punish (e : Error.t) =
      let e = Error.to_string_hum e in
      if Option.is_some punish then
        (* TODO: Make this an insta ban *)
        Trust_system.(
          record t.trust_system t.logger peer
            Actions.(Violated_protocol, Some (e, [])))
        |> don't_wait_for ;
      [%log' debug t.logger]
        "Downloading from $peer failed ($error) on $hashes"
        ~metadata:
          [ ("peer", Peer.to_yojson peer)
          ; ("error", `String e)
          ; ("hashes", `List (List.map hs ~f:State_hash.to_yojson)) ] ;
      (* TODO: Log error *)
      List.iter xs ~f:(fun x ->
          enqueue_exn t
            { x with
              attempts=
                Map.set x.attempts ~key:peer ~data:{failure_reason= `Download}
            } ) ;
      flush_soon t
    in
    List.iter xs ~f:(fun x ->
        Hashtbl.add_exn t.downloading ~key:x.hash ~data:(peer, x) ) ;
    let%map res =
      Deferred.choose
        [ Deferred.choice
            (Mina_networking.get_transition_chain ~timeout t.network peer hs)
            (fun x -> `Not_stopped x)
        ; Deferred.choice t.stop (fun () -> `Stopped)
        ; Deferred.choice
            (* This happens if all the jobs are cancelled. *)
            (Deferred.List.map xs ~f:(fun x -> Ivar.read x.res))
            (fun _ -> `Stopped) ]
    in
    List.iter xs ~f:(fun j -> Hashtbl.remove t.downloading j.hash) ;
    match res with
    | `Stopped ->
        List.iter xs ~f:(kill_job t)
    | `Not_stopped r -> (
        Useful_peers.update t.useful_peers (Download_finished (peer, hs)) ;
        match r with
        | Error e ->
            fail e
        | Ok bs -> (
          match
            List.map2 bs xs ~f:(fun b x ->
                if State_hash.equal (External_transition.state_hash b) x.hash
                then (
                  job_finished t x
                    (Ok
                       ( { Envelope.Incoming.data= b
                         ; received_at= Time.now ()
                         ; sender= Remote peer }
                       , x.attempts )) ;
                  Ok () )
                else Or_error.error_string "State had wrong hash" )
          with
          | Unequal_lengths ->
              fail ~punish:()
                (Error.of_string "Got wrong number of external transitions")
          | Ok rs -> (
            match Or_error.all_unit rs with
            | Error e ->
                fail ~punish:() e
            | Ok () ->
                () ) ) )

  let is_empty t = Q.is_empty t.pending && Q.is_empty t.stalled

  let all_stalled t = Q.is_empty t.pending

  let max_chunk_length = 5

  let rec step t =
    if is_empty t then (
      match%bind Strict_pipe.Reader.read t.flush_r with
      | `Eof ->
          [%log' debug t.logger] "Downloader: flush eof" ;
          Deferred.unit
      | `Ok () ->
          [%log' debug t.logger] "Downloader: flush" ;
          step t )
    else if all_stalled t then (
      [%log' debug t.logger] "Downloader: all stalled" ;
      (* TODO: Put a log here *)
      match%bind
        choose
          [ Pipe.read_choice_single_consumer_exn (reader t.flush_r) [%here]
          ; Pipe.read_choice_single_consumer_exn (reader t.got_new_peers_r)
              [%here] ]
      with
      | `Ok () ->
          [%log' debug t.logger] "Downloader: keep going" ;
          step t
      | `Eof ->
          [%log' debug t.logger] "Downloader: other eof" ;
          Deferred.unit )
    else (
      [%log' debug t.logger] "Downloader: else"
        ~metadata:
          [ ( "peer_available"
            , `Bool
                (Option.is_some
                   ( Strict_pipe.Reader.to_linear_pipe t.useful_peers.r
                   |> Linear_pipe.peek )) ) ] ;
      match%bind Useful_peers.read t.useful_peers with
      | `Eof ->
          Deferred.unit
      | `Ok (peer, _hs) -> (
          [%log' debug t.logger] "Downloader: got $peer"
            ~metadata:[("peer", Peer.to_yojson peer)] ;
          let to_download =
            let rec go n acc skipped =
              if n >= max_chunk_length then acc
              else
                match Q.dequeue t.pending with
                | None ->
                    (* We can just enqueue directly into pending without going thru
                    enqueue_exn since we know these skipped jobs are not stalled*)
                    List.iter (List.rev skipped) ~f:(Q.enqueue_exn t.pending) ;
                    List.rev acc
                | Some x ->
                    if Map.mem x.attempts peer then go n acc (x :: skipped)
                    else go (n + 1) (x :: acc) skipped
            in
            go 0 [] []
          in
          [%log' debug t.logger] "Downloader: to download $n"
            ~metadata:[("n", `Int (List.length to_download))] ;
          match to_download with
          | [] ->
              make_peer_available t peer ; step t
          | _ :: _ ->
              don't_wait_for (download t peer to_download) ;
              step t ) )

  let to_json t : Yojson.Safe.t =
    check_invariant t ; 
    let list xs =
      `Assoc [("length", `Int (List.length xs)); ("elts", `List xs)]
    in
    let f q = list (List.map ~f:Job.to_yojson (Q.to_list q)) in
    `Assoc
      [ ("total_jobs", `Int (total_jobs t))
      ; ("pending", f t.pending)
      ; ("stalled", f t.stalled)
      ; ( "downloading"
        , list
            (List.map (Hashtbl.to_alist t.downloading) ~f:(fun (h, (p, _)) ->
                 `Assoc
                   [ ("hash", State_hash.to_yojson h)
                   ; ("peer", `String (Peer.to_multiaddr_string p)) ] )) ) ]

  let create ~stop ~trust_system ~network =
    let%map all_peers = Mina_networking.peers network in
    let pipe ~name c =
      Strict_pipe.create ~name (Buffered (`Capacity c, `Overflow Drop_head))
    in
    let flush_r, flush_w = pipe ~name:"flush" 0 in
    let got_new_peers_r, got_new_peers_w = pipe ~name:"got_new_peers" 0 in
    let t =
      { all_peers= Peer.Set.of_list all_peers
      ; pending= Q.create ()
      ; stalled= Q.create ()
      ; next_flush= None
      ; flush_r
      ; flush_w
      ; got_new_peers_r
      ; got_new_peers_w
      ; useful_peers= Useful_peers.create ~all_peers
      ; network
      ; logger= Logger.create ()
      ; trust_system
      ; downloading= State_hash.Table.create ()
      ; stop }
    in
    don't_wait_for (step t) ;
    upon stop (fun () -> tear_down t) ;
    every ~stop (Time.Span.of_sec 10.) (fun () ->
        [%log' debug t.logger]
          ~metadata:[("jobs", to_json t)]
          "Downloader jobs" ) ;
    Clock.every' ~stop peer_refresh_interval (fun () -> refresh_peers t) ;
    t

  (* After calling download, if no one else has called within time [max_wait], 
       we flush our queue. *)
  let download t ~state_hash:hash ~blockchain_length ~attempts : Job.t =
    match (Q.lookup t.pending hash, Q.lookup t.stalled hash) with
    | Some _, Some _ ->
        assert false
    | Some x, None | None, Some x ->
        x
    | None, None ->
        flush_soon t ;
        let e = {hash; blockchain_length; attempts; res= Ivar.create ()} in
        enqueue_exn t e ; e
end *)
