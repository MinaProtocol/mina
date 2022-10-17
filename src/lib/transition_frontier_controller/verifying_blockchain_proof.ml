open Mina_base
open Core_kernel
open Context

(* Pre-condition: new [status] is Failed or Processing *)
let update_status_from_processing ~timeout_controller ~transition_states
    ~state_hash status =
  let f = function
    | Transition_state.Verifying_blockchain_proof
        ({ substate = { status = Processing ctx; _ }; gossip_data = gd; _ } as r)
      ->
        Timeout_controller.cancel_in_progress_ctx ~timeout_controller
          ~state_hash ctx ;
        let gossip_data =
          match status with
          | Substate.Failed _ ->
              Gossip_types.(
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

let to_header_exn = function
  | Transition_state.Verifying_blockchain_proof { header; _ } ->
      header
  | _ ->
      failwith "to_header_exn: unexpected state"

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

let launch_ancestry_verification ?prev_processing ~context ~transition_states
    ~mark_processed_and_promote parent_hash =
  let states =
    Option.value ~default:[]
    @@ match%bind.Option
         State_hash.Table.find transition_states parent_hash
       with
       | Transition_state.Verifying_blockchain_proof _ as parent ->
           Some
             (Substate.collect_dependent_ancestry ~transition_states
                ~state_functions parent )
       | _ ->
           None
  in
  match states with
  | [] ->
      Option.iter prev_processing
        ~f:(fun (timeout_controller, state_hash, ctx) ->
          Timeout_controller.cancel_in_progress_ctx ~timeout_controller
            ~state_hash ctx )
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
            Timeout_controller.unregister ~state_hash:prev_hash ~timeout
              timeout_controller ;
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

let promote_to ~context ~mark_processed_and_promote ~header ~transition_states
    ~substate:s ~gossip_data ~body_opt ~aux =
  let ctx =
    match header with
    | Gossip_types.Initial_valid h ->
        let parent_hash =
          Mina_block.Validation.header h
          |> Mina_block.Header.protocol_state
          |> Mina_state.Protocol_state.previous_state_hash
        in
        launch_ancestry_verification ~context ~mark_processed_and_promote
          ~transition_states parent_hash ;
        Substate.Done h
    | _ ->
        Substate.Dependent
  in
  Transition_state.Verifying_blockchain_proof
    { header = Gossip_types.pre_initial_valid_of_received_header header
    ; gossip_data
    ; body_opt
    ; substate = { s with status = Processing ctx }
    ; aux
    }

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
      launch_ancestry_verification ~context ~mark_processed_and_promote
        ~transition_states
        ~prev_processing:(Context.timeout_controller, state_hash, processing_ctx)
        parent_hash
  | _ ->
      ()
