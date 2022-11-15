open Core_kernel
open Context
open Mina_base

(** [validate_frontier_dependencies] converts [Mina_block.Validation.initial_valid_with_block]
    to [Mina_block.Validation.almost_valid_with_block].
  
  Internally a [Mina_block.Validation.validate_frontier_dependencies] function is used.
  Note that contary to other usages of the function, it's being checked that transition
  is either in catchup state or in frontier (not just the latter).
*)
let validate_frontier_dependencies ~transition_states
    ~context:(module Context : CONTEXT) =
  let module Validation_context = struct
    let logger = Context.logger

    let constraint_constants = Context.constraint_constants

    let consensus_constants = Context.consensus_constants
  end in
  let is_block_in_frontier state_hash =
    let f = function
      | Transition_state.Building_breadcrumb
          { substate = { status = Processed _; _ }; _ }
      | Waiting_to_be_added_to_frontier _ ->
          true
      | _ ->
          false
    in
    Option.is_some (Transition_frontier.find Context.frontier state_hash)
    || Option.value_map ~default:false ~f
         (Transition_states.find transition_states state_hash)
  in
  Mina_block.Validation.validate_frontier_dependencies
    ~to_header:Mina_block.header
    ~context:(module Validation_context)
    ~root_block:
      ( Transition_frontier.root Context.frontier
      |> Frontier_base.Breadcrumb.block_with_hash )
    ~is_block_in_frontier

(** [update_status_for_unprocessed ~state_hash status] updates status of a transition
  corresponding to [state_hash] that is in [Building_breadcrumb] state.
  
  Pre-condition: new [status] is either [Failed] or [Processing].
*)
let update_status_for_unprocessed ~transition_states ~state_hash status =
  let f = function
    | Transition_state.Building_breadcrumb
        ( { substate = { status = Processing (In_progress _); _ }; block_vc; _ }
        as r )
    | Transition_state.Building_breadcrumb
        ({ substate = { status = Failed _; _ }; block_vc; _ } as r) ->
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
let upon_f ~state_hash ~mark_processed_and_promote ~transition_states =
  let mark_invalid ~tag e =
    Transition_states.mark_invalid transition_states ~error:(Error.tag ~tag e)
      ~state_hash
  in
  function
  | Result.Error () ->
      update_status_for_unprocessed ~transition_states ~state_hash
        (Failed (Error.of_string "interrupted"))
  | Result.Ok (Result.Ok breadcrumb) ->
      update_status_for_unprocessed ~transition_states ~state_hash
        (Processing (Done breadcrumb)) ;
      mark_processed_and_promote [ state_hash ]
  | Result.Ok (Result.Error (`Invalid_staged_ledger_diff e)) ->
      mark_invalid ~tag:"invalid staged ledger diff" e
  | Result.Ok (Result.Error (`Invalid_staged_ledger_hash e)) ->
      mark_invalid ~tag:"invalid staged ledger hash" e
  | Result.Ok (Result.Error (`Fatal_error e)) ->
      update_status_for_unprocessed ~transition_states ~state_hash
      @@ Failed (Error.of_exn e)

(** [building_breadcrumb_status ~parent block] decides upon status of [block]
  that is a child of transition with the already-built breadcrumb [parent].
  
  This function validates frontier dependencies and if validation is successful,
  returns a [Processing (In_progress _)] status and [Failed] otherwise.  
*)
let building_breadcrumb_status ~context ~mark_processed_and_promote
    ~transition_states ~received_at ~sender ~parent block =
  let (module Context : CONTEXT) = context in
  let state_hash =
    State_hash.With_state_hashes.state_hash
      (Mina_block.Validation.block_with_hash block)
  in
  let impl =
    let%map.Result transition =
      validate_frontier_dependencies ~transition_states ~context block
    in
    let downto_ =
      Mina_block.blockchain_length (Mina_block.Validation.block block)
    in
    let module I = Interruptible.Make () in
    let action =
      Context.build_breadcrumb ~received_at ~sender ~parent ~transition
        (module I)
    in
    let timeout = Time.(add @@ now ()) Context.building_breadcrumb_timeout in
    Async_kernel.Deferred.upon (I.force action)
      (upon_f ~transition_states ~state_hash ~mark_processed_and_promote) ;
    interrupt_after_timeout ~timeout I.interrupt_ivar ;
    Substate.In_progress
      { interrupt_ivar = I.interrupt_ivar
      ; timeout
      ; downto_
      ; holder = ref state_hash
      }
  in
  match impl with
  | Result.Ok ctx ->
      Substate.Processing ctx
  | Result.Error err ->
      let err_str =
        match err with
        | `Already_in_frontier ->
            Context.record_event
            @@ `Invalid_frontier_dependencies
                 (`Already_in_frontier, state_hash, sender) ;
            "already in frontier"
        | `Not_selected_over_frontier_root ->
            Context.record_event
            @@ `Invalid_frontier_dependencies
                 (`Not_selected_over_frontier_root, state_hash, sender) ;
            "not selected over frontier root"
        | `Parent_missing_from_frontier ->
            "parent missing from frontier"
      in
      Substate.Failed
        (Error.createf "failed to validate frontier dependencies: %s" err_str)

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
         status hash unexpected state $state"
        ~metadata:
          [ ("parent_hash", State_hash.to_yojson parent_hash)
          ; ("state_hash", State_hash.to_yojson meta.state_hash)
          ; ("state", `String (Transition_state.name st))
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

let restart_failed_ancestor ~build ~context ~transition_states ~state_hash
    ancestor_hash =
  match Transition_states.find transition_states ancestor_hash with
  | Some
      ( Transition_state.Building_breadcrumb
          ({ substate = { status = Failed _; _ }; _ } as r) as st ) -> (
      let ancestor_meta = Transition_state.State_functions.transition_meta st in
      match get_parent ~transition_states ~context ancestor_meta with
      | Ok parent ->
          Transition_states.update transition_states
            (Building_breadcrumb
               { r with substate = { r.substate with status = build parent } }
            )
      | _ ->
          let (module Context : CONTEXT) = context in
          [%log' error Context.logger]
            "Failed ancestor $ancestor_hash of transition $state_hash in \
             Building_breadcrumb can't be restarted"
            ~metadata:
              [ ("ancestor_hash", State_hash.to_yojson ancestor_hash)
              ; ("state_hash", State_hash.to_yojson state_hash)
              ] )
  | _ ->
      ()

(** Promote a transition that is in [Verifying_complete_works] state with
    [Processed] status to [Building_breadcrumb] state.
*)
let promote_to ~mark_processed_and_promote ~context ~transition_states ~block
    ~substate ~block_vc ~aux =
  let meta =
    Substate.transition_meta_of_header_with_hash
      (With_hash.map ~f:Mina_block.header
         (Mina_block.Validation.block_with_hash block) )
  in
  let build parent =
    building_breadcrumb_status ~context ~mark_processed_and_promote
      ~transition_states ~received_at:aux.Transition_state.received_at
      ~sender:aux.sender ~parent block
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
      restart_failed_ancestor ~build ~context ~transition_states
        ~state_hash:meta.state_hash ancestor_hash ) ;
  Transition_state.Building_breadcrumb
    { block; block_vc; substate = { substate with status }; aux; ancestors }
