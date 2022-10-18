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
         (State_hash.Table.find transition_states state_hash)
  in
  Mina_block.Validation.validate_frontier_dependencies
    ~to_header:Mina_block.header
    ~context:(module Validation_context)
    ~root_block:
      ( Transition_frontier.root Context.frontier
      |> Frontier_base.Breadcrumb.block_with_hash )
    ~is_block_in_frontier

(** [update_status_from_processing ~state_hash status] updates status of a transition
  corresponding to [state_hash] that is in [Building_breadcrumb] state.
  
  Pre-condition: new [status] is either [Failed] or [Processing].
*)
let update_status_from_processing ~timeout_controller ~transition_states
    ~state_hash status =
  let f = function
    | Transition_state.Building_breadcrumb
        ({ substate = { status = Processing ctx; _ }; block_vc; _ } as r) ->
        Timeout_controller.cancel_in_progress_ctx ~transition_states
          ~state_functions ~timeout_controller ~state_hash ctx ;
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
        Transition_state.Building_breadcrumb
          { r with substate = { r.substate with status }; block_vc }
    | st ->
        st
  in
  State_hash.Table.change transition_states state_hash ~f:(Option.map ~f)

(** [upon_f] is a callback to be executed upon completion of building
  a breadcrumb (or a failure).
*)
let upon_f ~state_hash ~timeout_controller ~mark_processed_and_promote
    ~transition_states res =
  let mark_invalid ~tag e =
    Transition_state.mark_invalid ~transition_states ~error:(Error.tag ~tag e)
      state_hash
  in
  match res with
  | Result.Error () ->
      update_status_from_processing ~timeout_controller ~transition_states
        ~state_hash
        (Failed (Error.of_string "interrupted"))
  | Result.Ok (Result.Ok breadcrumb) ->
      update_status_from_processing ~timeout_controller ~transition_states
        ~state_hash (Processing (Done breadcrumb)) ;
      mark_processed_and_promote [ state_hash ]
  | Result.Ok (Result.Error (`Invalid_staged_ledger_diff e)) ->
      mark_invalid ~tag:"invalid staged ledger diff" e
  | Result.Ok (Result.Error (`Invalid_staged_ledger_hash e)) ->
      mark_invalid ~tag:"invalid staged ledger hash" e
  | Result.Ok (Result.Error (`Fatal_error e)) ->
      update_status_from_processing ~timeout_controller ~transition_states
        ~state_hash
      @@ Failed (Error.of_exn e)

(** [building_breadcrumb_status ~parent block] decides upon status of [block]
  that is a child of transition with the already-built breadcrumb [parent].
  
  This function validates frontier dependencies and if validation is successful,
  returns a [Processing (In_progress _)] status and [Failed] otherwise.  
*)
let building_breadcrumb_status ~context ~mark_processed_and_promote
    ~transition_states ~received_at ~sender ~parent block =
  let impl =
    let%map.Result transition =
      validate_frontier_dependencies ~transition_states ~context block
    in
    let state_hash = state_hash_of_block_with_validation transition in
    let (module Context : CONTEXT) = context in
    let open Context in
    let module I = Interruptible.Make () in
    let action =
      Context.build_breadcrumb ~received_at ~sender ~parent ~transition
        (module I)
    in
    Async_kernel.Deferred.upon (I.force action)
      (upon_f ~transition_states ~state_hash ~mark_processed_and_promote
         ~timeout_controller ) ;
    Substate.In_progress
      { interrupt_ivar = I.interrupt_ivar
      ; timeout = Time.(add @@ now ()) Context.building_breadcrumb_timeout
      }
  in
  match impl with
  | Result.Ok ctx ->
      Substate.Processing ctx
  | Result.Error err ->
      let err_str =
        match err with
        | `Already_in_frontier ->
            "already in frontier"
        | `Not_selected_over_frontier_root ->
            "not selected over frontier root"
        | `Parent_missing_from_frontier ->
            "parent missing from frontier"
      in
      Substate.Failed
        (Error.createf "failed to validate frontier dependencies: %s" err_str)

(** Promote a transition that is in [Verifying_complete_works] state with
    [Processed] status to [Building_breadcrumb] state.
*)
let promote_to ~mark_processed_and_promote ~context ~transition_states ~block
    ~substate ~block_vc ~aux =
  let parent_hash =
    Mina_block.Validation.block block
    |> Mina_block.header |> Mina_block.Header.protocol_state
    |> Mina_state.Protocol_state.previous_state_hash
  in
  let build parent =
    building_breadcrumb_status ~context ~mark_processed_and_promote
      ~transition_states ~received_at:aux.Transition_state.received_at
      ~sender:aux.sender ~parent block
  in
  let rec mk_status () =
    match State_hash.Table.find transition_states parent_hash with
    | Some
        (Transition_state.Building_breadcrumb
          { substate = { status = Processed parent; _ }; _ } )
    | Some
        (Transition_state.Waiting_to_be_added_to_frontier
          { breadcrumb = parent; _ } ) ->
        build parent
    | Some _ ->
        Substate.Waiting_for_parent mk_status
    | None -> (
        let (module Context : CONTEXT) = context in
        match Transition_frontier.find Context.frontier parent_hash with
        | Some parent ->
            build parent
        | None ->
            (* parent is neither in transition states nor in frontier,
               this case should not happen *)
            failwith
              "Building breadcrumb: parent is neither in catchup state nor in \
               the frontier" )
  in
  let status = mk_status () in
  Transition_state.Building_breadcrumb
    { block; block_vc; substate = { substate with status }; aux }
