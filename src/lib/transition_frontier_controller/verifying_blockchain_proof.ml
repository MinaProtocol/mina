open Mina_base
open Core_kernel
open Context

(** Update transition's state for a transition in
    [Transiiton_state.Verifying_blockchain_proof] state with [Substate.Processing] status.

    Pre-condition: new status is either [Substate.Failed] or [Substate.Processing].
*)
let update_status_from_processing ~timeout_controller ~transition_states
    ~state_hash status =
  let f = function
    | Transition_state.Verifying_blockchain_proof
        ({ substate = { status = Processing ctx; _ }; gossip_data = gd; _ } as r)
      ->
        Timeout_controller.cancel_in_progress_ctx ~transition_states
          ~state_functions ~timeout_controller ~state_hash ctx ;
        let gossip_data =
          match status with
          | Substate.Failed _ ->
              Gossip.(
                drop_gossip_data `Ignore gd ;
                Not_a_gossip)
          | _ ->
              gd
        in
        Transition_state.Verifying_blockchain_proof
          { r with substate = { r.substate with status }; gossip_data }
    | st ->
        st
  in
  State_hash.Table.change transition_states state_hash ~f:(Option.map ~f)

(** [upon_f] is a callback to be executed upon completion of
  blockchain proof verification (or a failure).
*)
let upon_f ~top_header ~timeout_controller ~mark_processed_and_promote
    ~transition_states res =
  let top_state_hash = state_hash_of_header_with_validation top_header in
  match res with
  | Result.Error () ->
      update_status_from_processing ~timeout_controller ~transition_states
        ~state_hash:top_state_hash
        (Failed (Error.of_string "interrupted"))
  | Result.Ok (Result.Ok lst) ->
      List.iter lst ~f:(fun header ->
          let state_hash = state_hash_of_header_with_validation header in
          update_status_from_processing ~timeout_controller ~transition_states
            ~state_hash (Processing (Done header)) ) ;
      let processed =
        List.rev @@ List.map lst ~f:state_hash_of_header_with_validation
      in
      mark_processed_and_promote processed
  | Result.Ok (Result.Error `Invalid_proof) ->
      (* We mark invalid only the first header because it is the only one for which
         we can be sure it's invalid *)
      Transition_state.mark_invalid ~transition_states
        ~error:(Error.of_string "wrong blockchain proof")
        ( Mina_block.Validation.header_with_hash top_header
        |> State_hash.With_state_hashes.state_hash )
  | Result.Ok (Result.Error (`Verifier_error e)) ->
      update_status_from_processing ~timeout_controller ~transition_states
        ~state_hash:top_state_hash (Failed e)

(** Extract header from a transition in [Transition_state.Verifying_blockchain_proof] state *)
let to_header_exn = function
  | Transition_state.Verifying_blockchain_proof { header; _ } ->
      header
  | _ ->
      failwith "to_header_exn: unexpected state"

(** Launch blockchain proof verification and return the processing context
    for the deferred action launched.  *)
let launch_in_progress ~context:(module Context : CONTEXT)
    ~mark_processed_and_promote ~transition_states ~top_header rest_headers =
  let module I = Interruptible.Make () in
  let action =
    Context.verify_blockchain_proofs (module I) (top_header :: rest_headers)
  in
  let timeout = Time.add (Time.now ()) Context.ancestry_verification_timeout in
  Async_kernel.Deferred.upon (I.force action)
  @@ upon_f ~mark_processed_and_promote ~transition_states
       ~timeout_controller:Context.timeout_controller ~top_header ;
  Substate.In_progress { interrupt_ivar = I.interrupt_ivar; timeout }

(** [launch_verification ?prev_processing state_hash] launches verification
  of [state_hash] and some of its ancestors.

  Function collects ancestors of [state_hash] which are not in [Processed] status and
  for which blockchain verification isn't in progress at the moment. Transition
  [state_hash] is also added to the collected list if it satisfies the condition
  for inclusion.

  If [prev_processing] argument is not provided, a new deferred action to batch-verify
  blockchain proofs of all transitions in collected list is launched. Processing context
  corresponding to the deferred action is assigned to the top transition of the collected
  list (i.e. a transition that is descendant of all other transitions in the collected list)

  If [prev_processing] argument is provided and list of collected transitions is empty,
  the processing context contained in the argument is canceled. If collected transition
  list is non-empty, processing context from [prev_processing] will be assigned to
  top transition of the collected list .
*)
let launch_verification ?prev_processing ~context ~transition_states
    ~mark_processed_and_promote state_hash =
  let states =
    Option.value ~default:[]
    @@ match%bind.Option State_hash.Table.find transition_states state_hash with
       | Transition_state.Verifying_blockchain_proof _ as st ->
           Some
             (Substate.collect_dependent_ancestry ~transition_states
                ~state_functions st )
       | _ ->
           None
  in
  match states with
  | [] ->
      Option.iter prev_processing
        ~f:(fun (timeout_controller, state_hash, ctx) ->
          Timeout_controller.cancel_in_progress_ctx ~transition_states
            ~state_functions ~timeout_controller ~state_hash ctx )
  | Transition_state.Verifying_blockchain_proof ({ header = top_header; _ } as r)
    :: rest_states ->
      let key = state_hash_of_header_with_validation top_header in
      let rest_headers = List.map ~f:to_header_exn rest_states in
      let ctx =
        match prev_processing with
        | Some
            ( timeout_controller
            , prev_hash
            , (Substate.In_progress { timeout; _ } as ctx) ) ->
            Timeout_controller.unregister ~transition_states ~state_functions
              ~state_hash:prev_hash ~timeout timeout_controller ;
            Timeout_controller.register ~state_functions ~transition_states
              ~state_hash:key ~timeout timeout_controller ;
            ctx
        | _ ->
            launch_in_progress ~context ~mark_processed_and_promote
              ~transition_states ~top_header rest_headers
      in
      State_hash.Table.set transition_states ~key
        ~data:
          (Transition_state.Verifying_blockchain_proof
             { r with substate = { r.substate with status = Processing ctx } }
          )
  | _ :: _ ->
      failwith "Unexpected collected state in launch_ancestry_verification"

(** Promote a transition that is in [Received] state with
    [Processed] status to [Verifying_blockchain_proof] state.
*)
let promote_to ~context ~mark_processed_and_promote ~header ~transition_states
    ~substate:s ~gossip_data ~body_opt ~aux =
  let ctx =
    match header with
    | Gossip.Initial_valid h ->
        let parent_hash =
          Mina_block.Validation.header h
          |> Mina_block.Header.protocol_state
          |> Mina_state.Protocol_state.previous_state_hash
        in
        launch_verification ~context ~mark_processed_and_promote
          ~transition_states parent_hash ;
        Substate.Done h
    | _ ->
        Substate.Dependent
  in
  Transition_state.Verifying_blockchain_proof
    { header = Gossip.pre_initial_valid_of_received_header header
    ; gossip_data
    ; body_opt
    ; substate = { s with status = Processing ctx }
    ; aux
    }

(** Mark the transition in [Verifying_blockchain_proof] processed.

   This function is called when a gossip for the transition is received.
   When gossip is received, blockchain proof is verified before any
   further processing. Hence blockchain verification for the transition
   may be skipped upon receival of a gossip.

   Blockhain proof verification is performed in batches, hence in progress
   context is not discarded but passed to the next ancestor that is in 
   [Verifying_blockchain_proof] and isn't [Processed].
*)
let mark_processed ~context ~mark_processed_and_promote ~transition_states
    header =
  let (module Context : CONTEXT) = context in
  let state_hash = state_hash_of_header_with_validation header in
  match State_hash.Table.find transition_states state_hash with
  | Some
      (Transition_state.Verifying_blockchain_proof
        ({ substate = { status = Processing processing_ctx; _ }; _ } as r) ) ->
      State_hash.Table.set transition_states ~key:state_hash
        ~data:
          (Transition_state.Verifying_blockchain_proof
             { r with
               substate = { r.substate with status = Processing (Done header) }
             } ) ;
      mark_processed_and_promote [ state_hash ] ;
      let parent_hash =
        Mina_block.Validation.header header
        |> Mina_block.Header.protocol_state
        |> Mina_state.Protocol_state.previous_state_hash
      in
      launch_verification ~context ~mark_processed_and_promote
        ~transition_states
        ~prev_processing:(Context.timeout_controller, state_hash, processing_ctx)
        parent_hash
  | _ ->
      ()
