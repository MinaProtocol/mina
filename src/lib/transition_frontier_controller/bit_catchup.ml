open Mina_base
open Core_kernel
open Async
open Context

(** [promote_to_higher_state_impl] takes state with [Processed] status and
    returns the next state with [Processing] status or [None] if the transition
    exits the catchup state.
    
    If needed, this function launches deferred action related to the new state.

    Note that some other states may be restarted (transitioned from [Failed] to [In_progress])
    on the course.
    *)
let promote_to_higher_state_impl ~mark_processed_and_promote ~context
    ~(transition_states : Transition_states.t) state =
  match state with
  | Transition_state.Received { header; substate; gossip_data; body_opt; aux }
    ->
      Option.some
      @@ Verifying_blockchain_proof.promote_to ~mark_processed_and_promote
           ~context ~transition_states ~header ~substate ~gossip_data ~body_opt
           ~aux
  | Verifying_blockchain_proof
      { header = _; substate; gossip_data; body_opt; aux; baton = _ } ->
      Option.some
      @@ Downloading_body.promote_to ~mark_processed_and_promote ~context
           ~transition_states ~substate ~gossip_data ~body_opt ~aux
  | Downloading_body { header; substate; block_vc; baton = _; aux } ->
      Option.some
      @@ Verifying_complete_works.promote_to ~mark_processed_and_promote
           ~context ~transition_states ~header ~substate ~block_vc ~aux
  | Verifying_complete_works { block; substate; block_vc; aux; baton = _ } ->
      Option.some
      @@ Building_breadcrumb.promote_to ~mark_processed_and_promote ~context
           ~transition_states ~block ~substate ~block_vc ~aux
  | Building_breadcrumb { block = _; substate; block_vc; aux; ancestors = _ } ->
      Option.some
      @@ Waiting_to_be_added_to_frontier.promote_to ~context ~substate ~block_vc
           ~aux
  | Waiting_to_be_added_to_frontier { breadcrumb; source; children = _ } ->
      let (module Context : CONTEXT) = context in
      Context.write_verified_transition
        ( `Transition (Frontier_base.Breadcrumb.validated_transition breadcrumb)
        , `Source source ) ;
      (* Just remove the state, it should be in frontier by now *)
      None
  | Invalid _ as e ->
      Some e

let pre_validate_header_invalid_action ~header = function
  | `Invalid_delta_block_chain_proof ->
      ( Trust_system.Actions.Gossiped_invalid_transition
      , Some ("invalid delta transition chain witness", []) )
  | `Invalid_genesis_protocol_state ->
      ( Trust_system.Actions.Gossiped_invalid_transition
      , Some ("invalid genesis protocol state", []) )
  | `Invalid_protocol_version ->
      ( Trust_system.Actions.Sent_invalid_protocol_version
      , Some
          ( "Invalid current or proposed protocol version in catchup block"
          , [ ( "current_protocol_version"
              , `String
                  ( Mina_block.Header.current_protocol_version header
                  |> Protocol_version.to_string ) )
            ; ( "proposed_protocol_version"
              , `String
                  ( Mina_block.Header.proposed_protocol_version_opt header
                  |> Option.value_map ~default:"<None>"
                       ~f:Protocol_version.to_string ) )
            ] ) )
  | `Mismatched_protocol_version ->
      ( Trust_system.Actions.Sent_mismatched_protocol_version
      , Some
          ( "Current protocol version in catchup block does not match daemon \
             protocol version"
          , [ ( "block_current_protocol_version"
              , `String
                  ( Mina_block.Header.current_protocol_version header
                  |> Protocol_version.to_string ) )
            ; ( "daemon_current_protocol_version"
              , `String Protocol_version.(get_current () |> to_string) )
            ] ) )

(** [promote_to_higher_state] takes state hash of a transition with [Processed] status
    and updates it.
    
    The transition is updated to the highest state possible (given the available data).
    E.g. a transition with block body available from the gossip will be
    updated from [Verifying_blockchain_proof] to [Verifying_complete_works] without
    launching action to download body.

    Some other states may also be updated (promoted) if promotion of the transition
    triggers their subsequent update (promotion).

    Pre-condition: state transition is in transition states and has [Processed] status.*)
let rec promote_to_higher_state ~context:(module Context : CONTEXT)
    ~transition_states state_hash =
  let context = (module Context : CONTEXT) in
  let mark_processed_and_promote =
    mark_processed_and_promote ~context ~transition_states
  in
  let old_state =
    Option.value_exn @@ Transition_states.find transition_states state_hash
  in
  let state_opt =
    promote_to_higher_state_impl ~context ~transition_states
      ~mark_processed_and_promote old_state
  in
  ( match state_opt with
  | None ->
      Transition_states.remove transition_states state_hash
  | Some state ->
      Transition_states.update transition_states state ) ;
  let parent_hash =
    (Transition_state.State_functions.transition_meta old_state)
      .parent_state_hash
  in
  Substate.update_children_on_promotion ~state_functions ~transition_states
    ~parent_hash ~state_hash state_opt ;
  Option.iter state_opt ~f:(fun state ->
      if Substate.is_processing_done ~state_functions state then
        mark_processed_and_promote [ state_hash ] )

(** [mark_processed_and_promote] takes a list of state hashes and marks corresponding
transitions processed. Then it promotes all of the transitions that can be promoted
as the result of [mark_processed].

  Pre-conditions:
   1. Order of [state_hashes] respects parent-child relationship and parent always comes first
   2. Respective substates for states from [processed] are in [Processing (Done _)] status

  Post-condition: list returned respects parent-child relationship and parent always comes first 

This is a recursive function that is called recursively when a transition
is promoted multiple times or upon completion of deferred action.
*)
and mark_processed_and_promote ~context:(module Context : CONTEXT)
    ~transition_states state_hashes =
  let higher_state_promotees =
    Substate.mark_processed ~logger:Context.logger ~state_functions
      ~transition_states state_hashes
  in
  let open State_hash.Set in
  let processed = of_list state_hashes in
  let promoted = of_list higher_state_promotees in
  iter (diff processed promoted) ~f:(fun key ->
      Option.iter (Transition_states.find transition_states key) ~f:(fun st ->
          let data = Transition_state.State_functions.transition_meta st in
          let open Processed_skipping.Dsu in
          add_exn ~key ~data Context.processed_dsu ;
          union ~a:key ~b:data.parent_state_hash Context.processed_dsu ;
          let children = Transition_state.children st in
          iter children.processed ~f:(fun b ->
              union ~a:key ~b Context.processed_dsu ) ) ) ;
  iter (diff processed promoted) ~f:(fun key ->
      Processed_skipping.Dsu.remove ~key Context.processed_dsu ) ;
  List.iter
    ~f:(promote_to_higher_state ~context:(module Context) ~transition_states)
    higher_state_promotees

let make_context ~frontier ~time_controller ~verifier ~trust_system ~network
    ~verified_transition_writer ~block_storage ~breadcrumb_queue
    ~breadcrumb_notification_writer
    ~context:(module Context_ : Transition_handler.Validator.CONTEXT) =
  let module Context = struct
    include Context_

    let frontier = frontier

    let time_controller = time_controller

    let verifier = verifier

    let trust_system = trust_system

    let network = network

    let write_verified_transition (`Transition t, `Source s) : unit =
      (* TODO remove validation_callback from Transition_router and then remove the `Valid_cb argument *)
      Pipe_lib.Strict_pipe.Writer.write verified_transition_writer
        (`Transition t, `Source s, `Valid_cb None)

    let write_breadcrumb source b =
      Queue.enqueue breadcrumb_queue (source, b) ;
      Pipe_lib.Strict_pipe.Writer.write breadcrumb_notification_writer ()

    let check_body_in_storage = Block_storage.read_body block_storage

    (* TODO Timeouts are for now set to these values, but we want them in config *)

    let building_breadcrumb_timeout = Time.Span.of_min 2.

    let bitwap_download_timeout = Time.Span.of_min 2.

    let peer_download_timeout = Time.Span.of_min 2.

    let ancestry_verification_timeout = Time.Span.of_sec 30.

    let ancestry_download_timeout = Time.Span.of_sec 30.

    let transaction_snark_verification_timeout = Time.Span.of_sec 30.

    let download_body ~header:_ (module I : Interruptible.F) =
      I.lift @@ Deferred.never ()

    let build_breadcrumb ~received_at ~parent ~transition
        (module I : Interruptible.F) =
      let f = function
        | `Invalid_body_reference -> Error.of_string "invalid body reference"
       | `Invalid_staged_ledger_diff lst -> 
          String.concat ~sep:" and " @@
          List.map ~f:(function

          )
         [ `Incorrect_target_snarked_ledger_hash
         | `Incorrect_target_staged_ledger_hash ]
         list
       | `Staged_ledger_application_failed of
         Staged_ledger.Staged_ledger_error.t ]
    in
      I.lift
        (Frontier_base.Breadcrumb.build_no_reporting
           ~skip_staged_ledger_verification:`Proofs ~logger ~precomputed_values
           ~verifier ~parent ~transition
           ~transition_receipt_time:(Some received_at) () |> Deferred.Result.map_error ~f)

    let retrieve_chain ~some_ancestors:_ ~target:_ ~parent_cache:_ ~sender:_
        ~lookup_transition:_ (module I : Interruptible.F) =
      I.lift @@ Deferred.never ()

    let genesis_state_hash =
      let genesis_protocol_state =
        Precomputed_values.genesis_state_with_hashes precomputed_values
      in
      State_hash.With_state_hashes.state_hash genesis_protocol_state

    let verify_blockchain_proofs (module I : Interruptible.F) =
      Fn.compose I.lift
      @@ Mina_block.Validation.validate_proofs ~verifier ~genesis_state_hash

    let verify_transaction_proofs (module I : Interruptible.F) =
      Fn.compose I.lift @@ Verifier.verify_transaction_snarks verifier

    let processed_dsu = Processed_skipping.Dsu.create ()

    let record_event = function
      | `Invalid_frontier_dependencies (e, state_hash, sender) ->
          Transition_handler.Processor.handle_frontier_validation_error
            ~trust_system ~logger ~sender ~state_hash e
      | `Verified_header_relevance (Ok (), header_with_hash, sender) ->
          (* This action is deferred because it may potentially trigger change of
             ban status of a peer which requires writing to a synchonous pipe. *)
          don't_wait_for
          @@ Transition_handler.Validator.record_transition_is_relevant ~logger
               ~trust_system ~sender ~time_controller header_with_hash
      | `Verified_header_relevance (Error error, header_with_hash, sender) ->
          (* This action is deferred because it may potentially trigger change of
             ban status of a peer which requires writing to a synchonous pipe. *)
          don't_wait_for
          @@ Transition_handler.Validator.record_transition_is_irrelevant
               ~logger ~trust_system ~sender ~error header_with_hash
      | `Pre_validate_header_invalid (sender, header, e) ->
          let action = pre_validate_header_invalid_action ~header e in
          don't_wait_for
          @@ Trust_system.record_envelope_sender trust_system logger sender
               action
  end in
  (module Context : CONTEXT)

module Transition_states_callbacks (Context : CONTEXT) = struct
  open Context

  (* TODO add logging *)
  let on_invalid ~error ~aux _meta =
    don't_wait_for
    @@ Trust_system.record_envelope_sender trust_system logger
         aux.Transition_state.sender
         ( Trust_system.Actions.Gossiped_invalid_transition
         , Some (Error.to_string_hum error, []) )

  let on_add_new _ =
    Mina_metrics.Gauge.inc_one
      Mina_metrics.Transition_frontier_controller.transitions_being_processed

  let on_remove _ =
    Mina_metrics.Gauge.dec_one
      Mina_metrics.Transition_frontier_controller.transitions_being_processed
end

let run ~context ~trust_system ~verifier ~network ~time_controller
    ~collected_transitions ~frontier ~network_transition_reader
    ~producer_transition_reader ~clear_reader ~verified_transition_writer =
  let open Pipe_lib in
  (* Overflow of this buffer shouldn't happen because building a breadcrumb is expected to be a more time-heavy action than inserting the breadcrumb into frontier *)
  let breadcrumb_notification_reader, breadcrumb_notification_writer =
    Strict_pipe.create ~name:"frontier-notifier"
      (Buffered (`Capacity 1, `Overflow (Strict_pipe.Drop_head ignore)))
  in
  let breadcrumb_queue = Queue.create () in
  let (module Context_ : Transition_handler.Validator.CONTEXT) = context in
  (* TODO is "block-db" the right path ? *)
  let block_storage = Block_storage.open_ ~logger:Context_.logger "block-db" in
  let context =
    make_context ~context ~frontier ~time_controller ~verifier ~trust_system
      ~network ~verified_transition_writer ~block_storage ~breadcrumb_queue
      ~breadcrumb_notification_writer
  in
  let (module Context : CONTEXT) = context in
  let transition_states =
    Transition_states.create_inmem (module Transition_states_callbacks (Context))
  in
  let state =
    { transition_states
    ; orphans = State_hash.Table.create ()
    ; parents = State_hash.Table.create ()
    }
  in
  let mark_processed_and_promote =
    mark_processed_and_promote ~context ~transition_states
  in
  let logger = Context.logger in
  List.iter collected_transitions
    ~f:
      (Received.handle_collected_transition ~context ~mark_processed_and_promote
         ~state ) ;
  don't_wait_for
  @@ Strict_pipe.Reader.iter_without_pushback producer_transition_reader
       ~f:
         (Waiting_to_be_added_to_frontier.handle_produced_transition ~context
            ~transition_states ) ;
  don't_wait_for
  @@ Strict_pipe.Reader.iter_without_pushback network_transition_reader
       ~f:
         (Received.handle_network_transition ~context
            ~mark_processed_and_promote ~state ) ;
  don't_wait_for
  @@ Strict_pipe.Reader.iter_without_pushback clear_reader ~f:(fun _ ->
         let open Strict_pipe.Writer in
         Transition_states.shutdown_in_progress transition_states ;
         kill breadcrumb_notification_writer ) ;
  Strict_pipe.Reader.iter breadcrumb_notification_reader ~f:(fun () ->
      let f (_, b) =
        let parent_hash = Frontier_base.Breadcrumb.parent_hash b in
        match Transition_frontier.find frontier parent_hash with
        | Some _ ->
            true
        | _ ->
            [%log warn]
              "When trying to add breadcrumb $state_hash, its parent had been \
               removed from transition frontier: $parent_hash"
              ~metadata:
                [ ("parent_hash", State_hash.to_yojson parent_hash)
                ; ( "state_hash"
                  , Frontier_base.Breadcrumb.state_hash b
                    |> State_hash.to_yojson )
                ] ;
            false
      in
      let breadcrumbs = Queue.to_list breadcrumb_queue |> List.filter ~f in
      Queue.clear breadcrumb_queue ;
      List.iter breadcrumbs ~f:(fun (source, b) ->
          match source with
          | `Gossip ->
              Mina_metrics.Counter.inc_one
                Mina_metrics.Transition_frontier_controller
                .breadcrumbs_built_by_processor
          | `Internal ->
              let transition_time =
                Transition_frontier.Breadcrumb.validated_transition b
                |> Mina_block.Validated.header
                |> Mina_block.Header.protocol_state
                |> Mina_state.Protocol_state.blockchain_state
                |> Mina_state.Blockchain_state.timestamp
                |> Block_time.to_time_exn
              in
              Perf_histograms.add_span ~name:"accepted_transition_local_latency"
                (Core_kernel.Time.diff
                   Block_time.(now time_controller |> to_time_exn)
                   transition_time )
          | _ ->
              () ) ;
      let%map.Deferred () =
        Transition_frontier.add_breadcrumbs_exn Context.frontier
          (List.map ~f:snd breadcrumbs)
      in
      let promote_do =
        promote_to_higher_state_impl ~context ~transition_states
          ~mark_processed_and_promote
      in
      let promote (source, b) =
        ( match source with
        | `Internal ->
            ()
        | _ ->
            Transition_handler.Processor.record_block_inclusion_time
              (Frontier_base.Breadcrumb.validated_transition b)
              ~time_controller ~consensus_constants:Context.consensus_constants
        ) ;
        Transition_states.update' transition_states
          (Frontier_base.Breadcrumb.state_hash b)
          ~f:promote_do
      in
      List.iter breadcrumbs ~f:promote )
