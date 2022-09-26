open Mina_base
open Core_kernel
open Async
open Context

let promote_to_higher_state_impl ~mark_processed_and_promote ~context
    ~transition_states state =
  match state with
  | Transition_state.Received { header; substate; gossip_data; body_opt } ->
      Option.some
      @@ Verifying_blockchain_proof.promote_to ~mark_processed_and_promote
           ~context ~transition_states ~header ~substate ~gossip_data ~body_opt
  | Verifying_blockchain_proof { header = _; substate; gossip_data; body_opt }
    ->
      Option.some
      @@ Downloading_body.promote_to ~mark_processed_and_promote ~context
           ~transition_states ~substate ~gossip_data ~body_opt
  | Downloading_body { header; substate; block_vc; next_failed_ancestor = _ } ->
      Option.some
      @@ Verifying_complete_works.promote_to ~mark_processed_and_promote
           ~context ~transition_states ~header ~substate ~block_vc
  | Verifying_complete_works { block; substate; block_vc } ->
      Option.some
      @@ Building_breadcrumb.promote_to ~mark_processed_and_promote ~context
           ~transition_states ~block ~substate ~block_vc
  | Building_breadcrumb { block = _; substate; block_vc } ->
      Option.some
      @@ Waiting_to_be_added_to_frontier.promote_to ~context ~substate ~block_vc
  | Waiting_to_be_added_to_frontier { breadcrumb; source; children = _ } ->
      (* Just remove the state, it should be in frontier by now *)
      let (module Context : CONTEXT) = context in
      Context.write_verified_transition
        ( `Transition (Frontier_base.Breadcrumb.validated_transition breadcrumb)
        , `Source source ) ;

      None
  | Invalid _ as e ->
      Some e

let view_processing =
  let viewer subst =
    match subst.Substate.status with
    | Substate.Processing (Done _) ->
        Some `Done
    | Substate.Processing (In_progress { timeout; _ }) ->
        Some (`In_progress timeout)
    | _ ->
        None
  in
  Fn.compose Option.join
  @@ Substate.view
       ~modify_substate:Transition_state.State_functions.modify_substate
       ~f:{ viewer }

(* Pre-condition: state transition is in transition states *)
let rec promote_to_higher_state ~context:(module Context : CONTEXT)
    ~transition_states state_hash =
  let context = (module Context : CONTEXT) in
  let mark_processed_and_promote =
    mark_processed_and_promote ~context ~transition_states
  in
  let old_state = State_hash.Table.find_exn transition_states state_hash in
  let state_opt =
    promote_to_higher_state_impl ~context ~transition_states
      ~mark_processed_and_promote old_state
  in
  State_hash.Table.change transition_states state_hash ~f:(const state_opt) ;
  let parent_hash = Substate.parent_hash ~state_functions old_state in
  Substate.update_children_on_promotion ~state_functions ~transition_states
    ~parent_hash ~state_hash state_opt ;
  let check_processing =
    Option.iter ~f:(function
      | `Done ->
          mark_processed_and_promote [ state_hash ]
      | `In_progress timeout ->
          Timeout_controller.register ~state_functions ~transition_states
            ~state_hash ~timeout Context.timeout_controller )
  in
  Option.iter ~f:(Fn.compose check_processing view_processing) state_opt

and mark_processed_and_promote ~context:(module Context : CONTEXT)
    ~transition_states state_hashes =
  let higher_state_promotees =
    Substate.mark_processed ~logger:Context.logger ~state_functions
      ~transition_states state_hashes
  in
  List.iter
    ~f:(promote_to_higher_state ~context:(module Context) ~transition_states)
    higher_state_promotees

let handle_produced_transition ~logger ~state breadcrumb =
  let hash = Frontier_base.Breadcrumb.state_hash breadcrumb in
  let data =
    Transition_state.Waiting_to_be_added_to_frontier
      { breadcrumb
      ; source = `Internal
      ; children = Substate.empty_children_sets
      }
  in
  match Hashtbl.add state.transition_states ~key:hash ~data with
  | `Ok ->
      ()
  | `Duplicate ->
      [%log warn]
        "Produced breadcrumb $state_hash is already in bit-catchup state"
        ~metadata:[ ("state_hash", State_hash.to_yojson hash) ]

let run ~context:(module Context_ : Transition_handler.Validator.CONTEXT)
    ~trust_system ~verifier ~network ~time_controller
    ~(collected_transitions : Bootstrap_controller.Transition_cache.element list)
    ~frontier
    ~(network_transition_reader :
       Types.produced_transition Pipe_lib.Strict_pipe.Reader.t )
    ~(producer_transition_reader :
       Transition_frontier.Breadcrumb.t Pipe_lib.Strict_pipe.Reader.t )
    ~clear_reader ~verified_transition_writer =
  let open Pipe_lib in
  (* Overflow of this buffer shouldn't happen because building a breadcrumb is expected to be a more time-heavy action than inserting the breadcrumb into frontier *)
  let breadcrumb_notification_reader, breadcrumb_notification_writer =
    Strict_pipe.create ~name:"frontier-notifier"
      (Buffered (`Capacity 1, `Overflow (Strict_pipe.Drop_head ignore)))
  in
  let breadcrumb_queue = Queue.create () in
  (* TODO is it the right path ? *)
  let block_storage = Block_storage.open_ ~logger:Context_.logger "block-db" in
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

    let write_breadcrumb b =
      Queue.enqueue breadcrumb_queue b ;
      Strict_pipe.Writer.write breadcrumb_notification_writer ()

    let timeout_controller = Timeout_controller.create ()

    let check_body_in_storage = Block_storage.read_body block_storage
  end in
  let transition_states = State_hash.Table.create () in
  let state = { transition_states; orphans = State_hash.Table.create () } in
  let context = (module Context : CONTEXT) in
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
       ~f:(handle_produced_transition ~logger ~state) ;
  don't_wait_for
  @@ Strict_pipe.Reader.iter_without_pushback network_transition_reader
       ~f:
         (Received.handle_network_transition ~context
            ~mark_processed_and_promote ~state ) ;
  don't_wait_for
  @@ Strict_pipe.Reader.iter_without_pushback clear_reader ~f:(fun _ ->
         let open Strict_pipe.Writer in
         Timeout_controller.cancel_all ~state_functions ~transition_states
           Context.timeout_controller ;
         kill breadcrumb_notification_writer ) ;
  Strict_pipe.Reader.iter breadcrumb_notification_reader ~f:(fun () ->
      let breadcrumbs = Queue.to_list breadcrumb_queue in
      Queue.clear breadcrumb_queue ;
      let%map.Deferred () =
        Transition_frontier.add_breadcrumbs_exn Context.frontier breadcrumbs
      in
      let f =
        promote_to_higher_state_impl ~context ~transition_states
          ~mark_processed_and_promote
      in
      let promote =
        State_hash.Table.change transition_states ~f:(Option.bind ~f)
      in
      List.iter breadcrumbs
        ~f:(Fn.compose promote Frontier_base.Breadcrumb.state_hash) )
