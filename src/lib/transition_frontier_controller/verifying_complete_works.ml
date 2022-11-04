open Mina_base
open Core_kernel
open Context

module F = struct
  type proceessing_result = unit

  let ignore_gossip = function
    | Transition_state.Verifying_complete_works ({ block_vc = Some vc; _ } as r)
      ->
        Mina_net2.Validation_callback.fire_if_not_already_fired vc `Ignore ;
        Transition_state.Verifying_complete_works { r with block_vc = None }
    | st ->
        st

  let to_data = function
    | Transition_state.Verifying_complete_works { substate; baton; _ } ->
        Some Verifying_generic.{ substate; baton }
    | _ ->
        None

  let update Verifying_generic.{ substate; baton } = function
    | Transition_state.Verifying_complete_works r ->
        Transition_state.Verifying_complete_works { r with substate; baton }
    | st ->
        st
end

include Verifying_generic.Make (F)

(** Extract body from a transition in [Transition_state.Verifying_complete_works] state *)
let get_body = function
  | Transition_state.Verifying_complete_works { block; _ } ->
      Mina_block.Validation.block block |> Mina_block.body
  | _ ->
      failwith "unexpected collected ancestor for Verifying_complete_works"

(** Extract state hash from a transition in [Transition_state.Verifying_complete_works] state *)
let get_state_hash = function
  | Transition_state.Verifying_complete_works { block; _ } ->
      state_hash_of_block_with_validation block
  | _ ->
      failwith "unexpected collected ancestor for Verifying_complete_works"

(** [upon_f] is a callback to be executed upon completion of
  transaction snark verification for a transition (or a failure).
*)
let rec upon_f ~context ~mark_processed_and_promote ~transition_states
    ~state_hashes ~holder res =
  let (module Context : CONTEXT) = context in
  let top_state_hash = !holder in
  match res with
  | Result.Error () ->
      (* Top state hash will be set to Failed only if it was Processing/Failed before this point *)
      let for_restart_opt =
        update_to_failed ~dsu:Context.processed_dsu ~transition_states
          ~state_hash:top_state_hash
          (Error.of_string "interrupted")
      in
      Option.iter for_restart_opt
        ~f:(start ~context ~mark_processed_and_promote ~transition_states)
  | Result.Ok (Result.Ok false) ->
      (* We mark invalid only the first header because it is the only one for which
         we can be sure it's invalid *)
      Transition_state.mark_invalid ~transition_states
        ~error:(Error.of_string "wrong blockchain proof")
        top_state_hash
  | Result.Ok (Result.Ok true) ->
      List.iter state_hashes ~f:(fun state_hash ->
          let for_restart_opt =
            update_to_processing_done ~transition_states ~state_hash
              ~dsu:Context.processed_dsu
              ~reuse_ctx:State_hash.(state_hash <> top_state_hash)
              ()
          in
          Option.iter for_restart_opt ~f:(fun for_restart ->
              start ~context ~mark_processed_and_promote ~transition_states
                for_restart ;
              mark_processed_and_promote [ state_hash ] ) )
  | Result.Ok (Result.Error e) ->
      let for_restart_opt =
        update_to_failed ~dsu:Context.processed_dsu ~transition_states
          ~state_hash:top_state_hash e
      in
      Option.iter for_restart_opt
        ~f:(start ~context ~mark_processed_and_promote ~transition_states)

and start ~context ~mark_processed_and_promote ~transition_states states =
  Option.value ~default:()
  @@ let%map.Option top_state = List.last states in
     let ctx =
       launch_in_progress ~context ~mark_processed_and_promote
         ~transition_states states
     in
     match top_state with
     | Transition_state.Verifying_complete_works ({ block; substate; _ } as r)
       ->
         let key =
           State_hash.With_state_hashes.state_hash
             (Mina_block.Validation.block_with_hash block)
         in
         State_hash.Table.set transition_states ~key
           ~data:
             (Transition_state.Verifying_complete_works
                { r with substate = { substate with status = Processing ctx } }
             )
     | _ ->
         ()

(** Launch transaction snark (complete work) verification
    and return the processing context for the deferred action launched.
    
    Batch-verification is launched for the block provided and for all of its
    ancestors that are neither in [Substate.Processed] status nor has an
    verification action already launched for it and its ancestors.
    *)
and launch_in_progress ~mark_processed_and_promote
    ~context:(module Context : CONTEXT) ~transition_states states =
  let bottom_state = List.hd_exn states in
  let downto_ =
    (Transition_state.State_functions.transition_meta bottom_state)
      .blockchain_length
  in
  let bodies = List.map ~f:get_body states in
  let works =
    List.concat_map bodies
      ~f:
        (Fn.compose Staged_ledger_diff.completed_works
           Mina_block.Body.staged_ledger_diff )
    |> List.concat_map ~f:(fun { Transaction_snark_work.fee; prover; proofs } ->
           let msg = Sok_message.create ~fee ~prover in
           One_or_two.to_list (One_or_two.map proofs ~f:(fun p -> (p, msg))) )
  in
  let state_hashes = List.map ~f:get_state_hash states in
  let module I = Interruptible.Make () in
  let action = Context.verify_transaction_proofs (module I) works in
  let holder = ref (List.last_exn state_hashes) in
  Async_kernel.Deferred.upon (I.force action)
    (upon_f
       ~context:(module Context)
       ~mark_processed_and_promote ~transition_states ~state_hashes ~holder ) ;
  let timeout =
    Time.add (Time.now ()) Context.transaction_snark_verification_timeout
  in
  interrupt_after_timeout ~timeout I.interrupt_ivar ;
  Substate.In_progress
    { interrupt_ivar = I.interrupt_ivar; timeout; downto_; holder }

(** Promote a transition that is in [Downloading_body] state with
    [Processed] status to [Verifying_complete_works] state.
*)
let promote_to ~mark_processed_and_promote ~context ~transition_states ~header
    ~substate ~block_vc ~aux =
  let (module Context : CONTEXT) = context in
  let body =
    match substate.Substate.status with
    | Processed b ->
        b
    | _ ->
        failwith "promote_downloading_body: expected processed"
  in
  let block = Mina_block.Validation.with_body header body in
  let pre_st =
    Transition_state.Verifying_complete_works
      { block
      ; substate = { substate with status = Processing Dependent }
      ; block_vc
      ; aux
      ; baton = false
      }
  in
  if aux.Transition_state.received_via_gossip then
    let for_start =
      collect_dependent_and_pass_the_baton ~transition_states
        ~dsu:Context.processed_dsu pre_st
    in
    let ctx =
      launch_in_progress ~context ~mark_processed_and_promote ~transition_states
        for_start
    in
    Transition_state.Verifying_complete_works
      { block
      ; substate = { substate with status = Processing ctx }
      ; block_vc
      ; aux
      ; baton = false
      }
  else pre_st

(** [make_independent block] starts verification of complete works for
       a transition corresponding to the [block].

       This function is called when a gossip is received for a transition
       that is in [Transition_state.Verifying_complete_works] state.

       Pre-condition: transition corresponding to [block] has
       [Substate.Processing Dependent] status.
   *)
let make_independent ~context ~mark_processed_and_promote ~transition_states
    state_hash =
  let (module Context : CONTEXT) = context in
  let for_start =
    collect_dependent_and_pass_the_baton_by_hash ~transition_states
      ~dsu:Context.processed_dsu state_hash
  in
  start ~context ~mark_processed_and_promote ~transition_states for_start
