open Core_kernel
open Context
open Mina_base

let building_broadcast_timeout = Time.Span.of_min 2.

let validate_frontier_dependencies ~transition_states
    ~context:(module Context : CONTEXT) =
  let module Validation_context = struct
    let logger = Context.logger

    let constraint_constants = Context.constraint_constants

    let consensus_constants = Context.consensus_constants
  end in
  let is_block_in_frontier state_hash =
    Option.is_some
    @@ Option.first_some
         (Transition_frontier.find Context.frontier state_hash)
         (let%bind.Option state =
            State_hash.Table.find transition_states state_hash
          in
          match state with
          | Transition_state.Building_breadcrumb
              { substate = { status = Processed breadcrumb; _ }; _ }
          | Waiting_to_be_added_to_frontier { breadcrumb; _ } ->
              Some breadcrumb
          | _ ->
              None )
  in
  Mina_block.Validation.validate_frontier_dependencies
    ~to_header:Mina_block.header
    ~context:(module Validation_context)
    ~root_block:
      ( Transition_frontier.root Context.frontier
      |> Frontier_base.Breadcrumb.block_with_hash )
    ~is_block_in_frontier

(* Pre-condition: new [status] is Failed or Processing *)
let update_status_from_processing ~timeout_controller ~transition_states
    ~state_hash status =
  let f = function
    | Transition_state.Building_breadcrumb
        ({ substate = { status = Processing ctx; _ }; block_vc; _ } as r) ->
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
        Transition_state.Building_breadcrumb
          { r with substate = { r.substate with status }; block_vc }
    | st ->
        st
  in
  State_hash.Table.change transition_states state_hash ~f:(Option.map ~f)

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
      I.lift
        (Frontier_base.Breadcrumb.build ~skip_staged_ledger_verification:`Proofs
           ~logger ~precomputed_values ~verifier ~trust_system ~parent
           ~transition ~sender:(Some sender)
           ~transition_receipt_time:(Some received_at) () )
    in
    Async_kernel.Deferred.upon (I.force action)
      (upon_f ~transition_states ~state_hash ~mark_processed_and_promote
         ~timeout_controller ) ;
    Substate.In_progress
      { interrupt_ivar = I.interrupt_ivar
      ; timeout = Time.(add @@ now ()) building_broadcast_timeout
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

let promote_to ~mark_processed_and_promote ~context ~transition_states ~block
    ~substate ~block_vc =
  ignore mark_processed_and_promote ;
  let parent_hash =
    Mina_block.Validation.block block
    |> Mina_block.header |> Mina_block.Header.protocol_state
    |> Mina_state.Protocol_state.previous_state_hash
  in
  let build parent =
    building_breadcrumb_status ~context ~mark_processed_and_promote
      ~transition_states ~received_at:substate.Substate.received_at
      ~sender:substate.sender ~parent block
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
    | None ->
        let (module Context : CONTEXT) = context in
        Option.value_map ~default:(Substate.Waiting_for_parent mk_status)
          ~f:build
        @@ Transition_frontier.find Context.frontier parent_hash
  in
  let status = mk_status () in
  Transition_state.Building_breadcrumb
    { block; block_vc; substate = { substate with status } }
