open Mina_base
open Core_kernel
open Context

let bitwap_download_timeout = Time.Span.of_min 2.

let peer_download_timeout = Time.Span.of_min 2.

(** Notify descedants of transition [state_hash] that its downloading
    failed.
    
    This function recursively traverses descendants of the transition in a DFS
    fashion. Recursive call happens only if a child has [next_failed_ancestor] equal
    to [None].
    *)
let rec notify_descedants_of_failed ~transition_states ~state_hash
    (children : Substate.children_sets) =
  let f child_hash =
    match State_hash.Table.find transition_states child_hash with
    | Some
        (Transition_state.Downloading_body
          ({ next_failed_ancestor = None; _ } as r) ) ->
        State_hash.Table.set transition_states ~key:child_hash
          ~data:
            (Downloading_body { r with next_failed_ancestor = Some state_hash }) ;
        notify_descedants_of_failed ~transition_states ~state_hash
          r.substate.children
    | _ ->
        ()
  in
  State_hash.Set.iter children.processing_or_failed ~f ;
  State_hash.Set.iter children.processed ~f

(** [next_actual_failed_ancestor candidate_hash] next ancestor that is actually in
    the [Failed] state. This function is required because [next_failed_ancestor]
    field is not updated when transition becomes [Processed].

    This function is performed recursively: when [candidate_hash] is either in
    [Failed] or [Processing] state, it just returns [Some candidate_hash].

    Otherwise it performs the recursive call for state hash found in the
    [next_failed_ancestor] field and updates this field with the result of the call.
*)
let rec next_actual_failed_ancestor ~transition_states candidate_hash =
  match State_hash.Table.find transition_states candidate_hash with
  | Some
      (Transition_state.Downloading_body
        { substate = { status = Failed _; _ }; _ } )
  | Some (Downloading_body { substate = { status = Processing _; _ }; _ }) ->
      Some candidate_hash
  | Some (Downloading_body ({ next_failed_ancestor = Some next; _ } as r)) ->
      let next_failed_ancestor =
        next_actual_failed_ancestor ~transition_states next
      in
      State_hash.Table.set transition_states ~key:candidate_hash
        ~data:(Downloading_body { r with next_failed_ancestor }) ;
      next_failed_ancestor
  | _ ->
      None

(** [collect_failed_ancestry state_hash] collects all ancestors of [state_hash] that
    are in [Failed] state. A list is returned with each failed ancestor's
    state.
    The reulting list is prepended with state of [state_hash] if it's also in a
    [Failed] state.

    Collecting is performed with use of [next_actual_failed_ancestor] function and
    hence it makes [next_failed_ancestor] links up-to-date.
    *)
let rec collect_failed_ancestry ~transition_states state_hash =
  let next = Option.bind ~f:(next_actual_failed_ancestor ~transition_states) in
  let continue =
    Option.value_map ~default:[] ~f:(collect_failed_ancestry ~transition_states)
  in
  match State_hash.Table.find transition_states state_hash with
  | Some
      (Transition_state.Downloading_body
        ({ substate = { status = Failed _; _ }; _ } as r) ) ->
      let next_failed_ancestor = next r.next_failed_ancestor in
      let state' =
        Transition_state.Downloading_body { r with next_failed_ancestor }
      in
      State_hash.Table.set transition_states ~key:state_hash ~data:state' ;
      state' :: continue next_failed_ancestor
  | Some (Downloading_body ({ substate = { status = Processing _; _ }; _ } as r))
    ->
      let next_failed_ancestor = next r.next_failed_ancestor in
      State_hash.Table.set transition_states ~key:state_hash
        ~data:(Downloading_body { r with next_failed_ancestor }) ;
      continue next_failed_ancestor
  | _ ->
      []

(** [update_status_from_processing ~state_hash status] updates status of a transition
  corresponding to [state_hash] that is in [Downloading_body] state.

  When the new [status] is [Failed], descedants are notified about it.
  
  Pre-condition: new [status] is either [Failed] or [Processing].
*)
let update_status_from_processing ~timeout_controller ~transition_states
    ~state_hash status =
  let f = function
    | Transition_state.Downloading_body
        ( { substate = { status = Processing ctx; children; _ }; block_vc; _ }
        as r ) ->
        Timeout_controller.cancel_in_progress_ctx ~timeout_controller
          ~state_hash ctx ;
        let block_vc =
          match status with
          | Substate.Failed _ ->
              Option.iter block_vc
                ~f:
                  (Fn.flip
                     Mina_net2.Validation_callback.fire_if_not_already_fired
                     `Ignore ) ;
              None
          | _ ->
              block_vc
        in
        notify_descedants_of_failed ~transition_states ~state_hash children ;
        Transition_state.Downloading_body
          { r with substate = { r.substate with status }; block_vc }
    | st ->
        st
  in
  State_hash.Table.change transition_states state_hash ~f:(Option.map ~f)

(** [upon_f] is a callback to be executed upon completion of downloading
  a body (or a failure).
*)
let upon_f ~timeout_controller ~transition_states ~state_hash
    ~mark_processed_and_promote = function
  | Result.Error () ->
      update_status_from_processing ~timeout_controller ~transition_states
        ~state_hash
        (Failed (Error.of_string "interrupted"))
  | Result.Ok (Result.Ok body) ->
      update_status_from_processing ~timeout_controller ~transition_states
        ~state_hash (Processing (Done body)) ;
      mark_processed_and_promote [ state_hash ]
  | Result.Ok (Result.Error e) ->
      update_status_from_processing ~timeout_controller ~transition_states
        ~state_hash (Failed e)

(** Creates a [Substate.processing_context] for a transition.

  In case of [body_opt] equaling to [Some body], returns [Substate.Done body].

  Otherwise starts downloading body for a transition and returns the
  [Substate.In_progress] context.
*)
let make_download_body_ctx ~body_opt ~header ~transition_states
    ~timeout_controller ~mark_processed_and_promote =
  let state_hash = state_hash_of_header_with_validation header in
  match body_opt with
  | Some body ->
      Substate.Done body
  | None ->
      let module I = Interruptible.Make () in
      (* TODO launch downloading of bodies *)
      let action = I.lift (Async_kernel.Deferred.never ()) in
      Async_kernel.Deferred.upon (I.force action)
        (upon_f ~timeout_controller ~transition_states ~state_hash
           ~mark_processed_and_promote ) ;
      let span = Time.Span.(bitwap_download_timeout + peer_download_timeout) in
      let timeout = Time.(add @@ now ()) span in
      Substate.In_progress { interrupt_ivar = I.interrupt_ivar; timeout }

(** Restart a failed ancestor. This function takes a transition state of ancestor and
    restarts the downloading process for it.  *)
let restart_failed_ancestor ~transition_states ~mark_processed_and_promote
    ~timeout_controller = function
  | Transition_state.Downloading_body
      ({ header; substate = { status = Failed _; _ } as s; _ } as r) -> (
      let state_hash = state_hash_of_header_with_validation header in
      let ctx =
        make_download_body_ctx ~body_opt:None ~header ~transition_states
          ~mark_processed_and_promote ~timeout_controller
      in
      let data =
        Transition_state.Downloading_body
          { r with substate = { s with status = Processing ctx } }
      in
      State_hash.Table.set transition_states ~key:state_hash ~data ;
      match ctx with
      | Substate.In_progress { timeout; _ } ->
          Timeout_controller.register ~state_functions ~transition_states
            ~state_hash ~timeout timeout_controller
      | _ ->
          ()
      (* We don't need to update parent's childen sets because
         Failed -> Processing status change doesn't require that *) )
  | _ ->
      failwith
        "promote_verifying_blockchain_proof: unexpected non-failed ancestor"

(** Promote a transition that is in [Verifying_blockchain_proof] state with
    [Processed] status to [Downloading_body] state.
*)
let promote_to ~context:(module Context : CONTEXT) ~mark_processed_and_promote
    ~transition_states ~substate ~gossip_data ~body_opt =
  let header =
    match substate.Substate.status with
    | Processed h ->
        h
    | _ ->
        failwith "promote_verifying_blockchain_proof: expected processed"
  in
  let parent_hash =
    Mina_block.Validation.header header
    |> Mina_block.Header.protocol_state
    |> Mina_state.Protocol_state.previous_state_hash
  in
  let next_failed_ancestor =
    match State_hash.Table.find transition_states parent_hash with
    | Some
        (Transition_state.Downloading_body
          { substate = { status = Failed _; _ }; _ } ) ->
        Some parent_hash
    | Some (Transition_state.Downloading_body { next_failed_ancestor; _ }) ->
        Option.bind
          ~f:(next_actual_failed_ancestor ~transition_states)
          next_failed_ancestor
    | _ ->
        None
  in
  let consensus_state =
    Mina_block.Validation.header header
    |> Mina_block.Header.protocol_state
    |> Mina_state.Protocol_state.consensus_state
  in
  let timeout_controller = Context.timeout_controller in
  let ctx =
    make_download_body_ctx ~body_opt ~header ~transition_states
      ~mark_processed_and_promote ~timeout_controller
  in
  let substate = { substate with status = Processing ctx } in
  let block_vc =
    match gossip_data with
    | Transition_state.Not_a_gossip ->
        None
    | Gossiped_header vc ->
        accept_gossip ~context:(module Context) ~valid_cb:vc consensus_state ;
        None
    | Gossiped_block vc ->
        Some vc
    | Gossiped_both { block_vc; header_vc } ->
        accept_gossip
          ~context:(module Context)
          ~valid_cb:header_vc consensus_state ;
        Some block_vc
  in
  let state' =
    Transition_state.Downloading_body
      { header; substate; block_vc; next_failed_ancestor }
  in
  let restart_f =
    restart_failed_ancestor ~transition_states ~mark_processed_and_promote
      ~timeout_controller
  in
  if substate.received_via_gossip then
    List.iter ~f:restart_f
    @@ Option.value_map ~default:[]
         ~f:(collect_failed_ancestry ~transition_states)
         next_failed_ancestor ;
  state'
