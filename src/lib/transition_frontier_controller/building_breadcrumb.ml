open Core_kernel
open Context
open Mina_base
open Bit_catchup_state

(** [update_status_for_unprocessed ~state_hash status] updates status of a transition
  corresponding to [state_hash] that is in [Building_breadcrumb] state.
  
  Pre-condition: new [status] is either [Failed] or [Processing].
*)
let update_status_for_unprocessed ~logger ~transition_states ~state_hash status
    =
  let f = function
    | Transition_state.Building_breadcrumb
        ( { substate = { status = Processing (In_progress _) as old_status; _ }
          ; block_vc
          ; _
          } as r )
    | Transition_state.Building_breadcrumb
        ({ substate = { status = Failed _ as old_status; _ }; block_vc; _ } as r)
      ->
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
        let metadata =
          Substate.add_error_if_failed ~tag:"old_status_error" old_status
          @@ Substate.add_error_if_failed ~tag:"new_status_error" status
          @@ [ ("state_hash", State_hash.to_yojson state_hash) ]
        in
        [%log debug]
          "Updating status of $state_hash from %s to %s (state: building \
           breadcrumb)"
          (Substate.name_of_status old_status)
          (Substate.name_of_status status)
          ~metadata ;
        Some
          (Transition_state.Building_breadcrumb
             { r with substate = { r.substate with status }; block_vc } )
    | st ->
        Some st
  in
  Transition_states.update' transition_states state_hash ~f

(** [upon_f] is a callback to be executed upon completion of building
  a breadcrumb (or a failure).
*)
let upon_f ~logger ~state_hash ~transition_states (actions, res) =
  match res with
  | Result.Error () ->
      update_status_for_unprocessed ~logger ~transition_states ~state_hash
        (Failed (Error.of_string "interrupted"))
  | Result.Ok (Result.Ok breadcrumb) ->
      update_status_for_unprocessed ~logger ~transition_states ~state_hash
        (Processing (Done breadcrumb)) ;
      actions.Misc.mark_processed_and_promote ~reason:"built breadcrumb"
        [ state_hash ]
  | Result.Ok (Error (`Invalid (error, reason))) ->
      actions.Misc.mark_invalid ~reason ~error state_hash
  | Result.Ok (Error (`Verifier_error e)) ->
      update_status_for_unprocessed ~logger ~transition_states ~state_hash
      @@ Failed e
  | Result.Ok (Error `Late_to_start) ->
      ()

(** [building_breadcrumb_status ~parent block] decides upon status of [block]
  that is a child of transition with the already-built breadcrumb [parent].
  
  This function validates frontier dependencies and if validation is successful,
  returns a [Processing (In_progress _)] status and [Failed] otherwise.  
*)
let building_breadcrumb_status ~context ~actions ~transition_states ~received
    ~parent block =
  let (module Context : CONTEXT) = context in
  let state_hash =
    State_hash.With_state_hashes.state_hash
      (Mina_block.Validation.block_with_hash block)
  in
  let transition =
    Mina_block.Validation.skip_frontier_dependencies_validation
      `This_block_belongs_to_a_detached_subtree block
  in
  let downto_ =
    Mina_block.blockchain_length (Mina_block.Validation.block block)
  in
  let module I = Interruptible.Make () in
  let received_at = (List.last_exn received).Transition_state.received_at in
  let process_f () =
    ( Context.build_breadcrumb ~received_at ~parent ~transition (module I)
    , Context.building_breadcrumb_timeout )
  in
  let upon_f = upon_f ~logger:Context.logger ~transition_states ~state_hash in
  let processing_status =
    controlling_verifier_bandwidth ~context ~actions ~transition_states
      ~state_hash ~process_f ~upon_f
      (module I)
  in
  Substate.Processing
    (In_progress
       { interrupt_ivar = I.interrupt_ivar
       ; processing_status
       ; downto_
       ; holder = ref state_hash
       } )

let get_parent ~transition_states ~context meta =
  let (module Context : CONTEXT) = context in
  let parent_hash = meta.Substate.parent_state_hash in
  match Transition_states.find transition_states parent_hash with
  | Some
      (Transition_state.Building_breadcrumb
        { substate = { status = Processed parent; _ }; _ } )
  | Some
      (Transition_state.Waiting_to_be_added_to_frontier
        { breadcrumb = parent; _ } ) ->
      Ok parent
  | Some (Transition_state.Building_breadcrumb { ancestors; _ }) ->
      Error ancestors
  | Some st ->
      [%log' warn Context.logger]
        "Parent $parent_hash of transition $state_hash in Building_breadcrumb \
         status has unexpected state %s"
        (Transition_state.State_functions.name st)
        ~metadata:
          [ ("parent_hash", State_hash.to_yojson parent_hash)
          ; ("state_hash", State_hash.to_yojson meta.state_hash)
          ] ;
      (* It's only possible to be invalid and then this function shouldn't
         have been called *)
      Error Length_map.empty
  | None -> (
      match Transition_frontier.find Context.frontier parent_hash with
      | None ->
          [%log' warn Context.logger]
            "Parent $parent_hash of transition $state_hash in \
             Building_breadcrumb status is neither in frontier nor in catchup \
             state"
            ~metadata:
              [ ("parent_hash", State_hash.to_yojson parent_hash)
              ; ("state_hash", State_hash.to_yojson meta.state_hash)
              ] ;
          Error Length_map.empty
      | Some p ->
          Ok p )

(** Filter unprocessed takes a map from blockchain length to state hash
    and returns a map with processed or higher state transitions removed. *)
let filter_unprocessed ~transition_states ancestors =
  let is_processed state_hash =
    match Transition_states.find transition_states state_hash with
    | Some
        (Transition_state.Building_breadcrumb
          { substate = { status = Processed _; _ }; _ } ) ->
        `Left
    | Some (Transition_state.Building_breadcrumb _) ->
        `Right
    | _ ->
        `Left
  in
  let segment_of ~key:_ ~data = is_processed data in
  let last_processed_opt =
    Length_map.binary_search_segmented ancestors ~segment_of `Last_on_left
  in
  Option.value_map ~default:ancestors
    ~f:(fun (k, _) ->
      let _, _, unprocessed = Length_map.split ancestors k in
      unprocessed )
    last_processed_opt

let restart_failed_ancestor ~actions ~context ~transition_states ~state_hash
    ancestor_hash =
  let (module Context : CONTEXT) = context in
  match Transition_states.find transition_states ancestor_hash with
  | Some
      ( Transition_state.Building_breadcrumb
          ({ substate = { status = Failed _; _ }; _ } as r) as st ) -> (
      let ancestor_meta = Transition_state.State_functions.transition_meta st in
      match get_parent ~transition_states ~context ancestor_meta with
      | Ok parent ->
          let status =
            building_breadcrumb_status ~context ~actions ~transition_states
              ~received:r.aux.Transition_state.received ~parent r.block
          in
          [%log' debug Context.logger]
            "Updating status of ancestor $ancestor_hash of transition \
             $state_hash from failed to %s (state: building breadcrumb)"
            (Substate.name_of_status status)
            ~metadata:
              [ ("ancestor_hash", State_hash.to_yojson ancestor_hash)
              ; ("state_hash", State_hash.to_yojson state_hash)
              ] ;
          Transition_states.update transition_states
            (Building_breadcrumb
               { r with substate = { r.substate with status } } )
      | _ ->
          [%log' error Context.logger]
            "Failed ancestor $ancestor_hash of transition $state_hash in \
             Building_breadcrumb can't be restarted: no parent breadcrumb"
            ~metadata:
              [ ("ancestor_hash", State_hash.to_yojson ancestor_hash)
              ; ("state_hash", State_hash.to_yojson state_hash)
              ] )
  | _ ->
      ()

(** Promote a transition that is in [Verifying_complete_works] state with
    [Processed] status to [Building_breadcrumb] state.
*)
let promote_to ~actions ~context ~transition_states ~block ~substate ~block_vc
    ~aux =
  let meta =
    Substate.transition_meta_of_header_with_hash
      (With_hash.map ~f:Mina_block.header
         (Mina_block.Validation.block_with_hash block) )
  in
  let build parent =
    building_breadcrumb_status ~context ~actions ~transition_states
      ~received:aux.Transition_state.received ~parent block
  in
  let mk_status () =
    (Option.value_map ~f:build
       ~default:(Substate.Failed (Error.of_string "parent not present")) )
      (Result.ok @@ get_parent ~transition_states ~context meta)
  in
  let status, ancestors =
    match get_parent ~transition_states ~context meta with
    | Ok p ->
        (build p, Length_map.empty)
    | Error ancestors ->
        ( Waiting_for_parent mk_status
        , Length_map.add_exn
            ~key:(Mina_numbers.Length.pred meta.blockchain_length)
            ~data:meta.parent_state_hash ancestors )
  in
  let ancestors = filter_unprocessed ~transition_states ancestors in
  Option.iter (Length_map.min_elt ancestors) ~f:(fun (_, ancestor_hash) ->
      restart_failed_ancestor ~actions ~context ~transition_states
        ~state_hash:meta.state_hash ancestor_hash ) ;
  Transition_state.Building_breadcrumb
    { block; block_vc; substate = { substate with status }; aux; ancestors }
