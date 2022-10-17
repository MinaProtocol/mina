open Mina_base
open Core_kernel
open Context

(* Pre-condition: new [status] is Failed or Processing *)
let update_status_from_processing ~timeout_controller ~transition_states
    ~state_hash status =
  let f = function
    | Transition_state.Verifying_complete_works
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
        Transition_state.Verifying_complete_works
          { r with substate = { r.substate with status }; block_vc }
    | st ->
        st
  in
  State_hash.Table.change transition_states state_hash ~f:(Option.map ~f)

let upon_f ~timeout_controller ~block ~mark_processed_and_promote
    ~transition_states ~ancestors_to_process res =
  let state_hash = state_hash_of_block_with_validation block in
  match res with
  | Result.Error () ->
      update_status_from_processing ~timeout_controller ~transition_states
        ~state_hash
        (Failed (Error.of_string "interrupted"))
  | Result.Ok (Result.Ok false) ->
      (* We mark invalid only the first header because it is the only one for which
         we can be sure it's invalid *)
      Transition_state.mark_invalid ~transition_states
        ~error:(Error.of_string "wrong blockchain proof")
        state_hash
  | Result.Ok (Result.Ok true) ->
      let processed = List.rev (state_hash :: ancestors_to_process) in
      List.iter processed ~f:(fun state_hash ->
          update_status_from_processing ~timeout_controller ~transition_states
            ~state_hash (Processing (Done ())) ) ;
      mark_processed_and_promote processed
  | Result.Ok (Result.Error e) ->
      update_status_from_processing ~timeout_controller ~transition_states
        ~state_hash (Failed e)

let get_body = function
  | Transition_state.Verifying_complete_works { block; _ } ->
      Mina_block.Validation.block block |> Mina_block.body
  | _ ->
      failwith "unexpected collected ancestor for Verifying_complete_works"

let get_hash = function
  | Transition_state.Verifying_complete_works { block; _ } ->
      state_hash_of_block_with_validation block
  | _ ->
      failwith "unexpected collected ancestor for Verifying_complete_works"

let mk_in_progress ~mark_processed_and_promote
    ~context:(module Context : CONTEXT) ~transition_states block_with_validation
    =
  let block = Mina_block.Validation.block block_with_validation in
  let parent_hash =
    Mina_block.header block |> Mina_block.Header.protocol_state
    |> Mina_state.Protocol_state.previous_state_hash
  in
  let states =
    Option.value ~default:[]
    @@ match%bind.Option
         State_hash.Table.find transition_states parent_hash
       with
       | Transition_state.Verifying_complete_works _ as parent ->
           Some
             (Substate.collect_dependent_ancestry ~transition_states
                ~state_functions parent )
       | _ ->
           None
  in
  let bodies = Mina_block.body block :: List.map ~f:get_body states in
  let works =
    List.concat_map bodies
      ~f:
        (Fn.compose Staged_ledger_diff.completed_works
           Mina_block.Body.staged_ledger_diff )
    |> List.concat_map ~f:(fun { Transaction_snark_work.fee; prover; proofs } ->
           let msg = Sok_message.create ~fee ~prover in
           One_or_two.to_list (One_or_two.map proofs ~f:(fun p -> (p, msg))) )
  in
  let module I = Interruptible.Make () in
  let action =
    I.lift @@ Verifier.verify_transaction_snarks Context.verifier works
  in
  Async_kernel.Deferred.upon (I.force action)
    (upon_f ~timeout_controller:Context.timeout_controller
       ~block:block_with_validation ~mark_processed_and_promote
       ~transition_states
       ~ancestors_to_process:(List.map ~f:get_hash states) ) ;
  Substate.In_progress
    { interrupt_ivar = I.interrupt_ivar
    ; timeout =
        Time.add (Time.now ()) Context.transaction_snark_verification_timeout
    }

let promote_to ~mark_processed_and_promote ~context ~transition_states ~header
    ~substate ~block_vc ~aux =
  let body =
    match substate.Substate.status with
    | Processed b ->
        b
    | _ ->
        failwith "promote_downloading_body: expected processed"
  in
  let block = Mina_block.Validation.with_body header body in
  let ctx =
    if aux.Transition_state.received_via_gossip then
      mk_in_progress ~mark_processed_and_promote ~context ~transition_states
        block
    else Substate.Dependent
  in
  Transition_state.Verifying_complete_works
    { block
    ; substate = { substate with status = Processing ctx }
    ; block_vc
    ; aux
    }

(** [start_processing block] starts verification of complete works for
    a transition corresponding to the [block].

    This function is called when a gossip is received for a transition
    that is in [Transition_state.Verifying_complete_works] state.

    Pre-condition: transition corresponding to [block] has
    [Substate.Processing Dependent] status.
*)
let start_processing ~context ~mark_processed_and_promote ~transition_states
    block =
  let (module Context : CONTEXT) = context in
  let state_hash = state_hash_of_block_with_validation block in
  let ctx =
    mk_in_progress ~mark_processed_and_promote ~context ~transition_states block
  in
  update_status_from_processing ~timeout_controller:Context.timeout_controller
    ~transition_states ~state_hash (Substate.Processing ctx)
