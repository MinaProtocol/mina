open Mina_base
open Core_kernel
open Context

let ancestry_verification_timeout = Time.Span.of_sec 30.

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
              Transition_state.(
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

let upon_f ~initial_valid_header ~first_header ~timeout_controller
    ~mark_processed_and_promote ~transition_states res =
  let state_hash = state_hash_of_header_with_validation initial_valid_header in
  match res with
  | Result.Error () ->
      update_status_from_processing ~timeout_controller ~transition_states
        ~state_hash
        (Failed (Error.of_string "interrupted"))
  | Result.Ok (Result.Ok lst) ->
      update_status_from_processing ~timeout_controller ~transition_states
        ~state_hash (Processing (Done initial_valid_header)) ;
      List.iter lst ~f:(fun ancestor_header ->
          let ancestor_hash =
            state_hash_of_header_with_validation ancestor_header
          in
          update_status_from_processing ~timeout_controller ~transition_states
            ~state_hash:ancestor_hash (Processing (Done ancestor_header)) ) ;
      let processed =
        List.rev
        @@ (state_hash :: List.map lst ~f:state_hash_of_header_with_validation)
      in
      mark_processed_and_promote processed
  | Result.Ok (Result.Error `Invalid_proof) ->
      (* We mark invalid only the first header because it is the only one for which
         we can be sure it's invalid *)
      Transition_state.mark_invalid ~transition_states
        ~error:(Error.of_string "wrong blockchain proof")
        ( Mina_block.Validation.header_with_hash first_header
        |> State_hash.With_state_hashes.state_hash )
  | Result.Ok (Result.Error (`Verifier_error e)) ->
      update_status_from_processing ~timeout_controller ~transition_states
        ~state_hash (Failed e)

let promote_to ~context:(module Context : CONTEXT) ~mark_processed_and_promote
    ~header ~transition_states ~substate:s ~gossip_data ~body_opt =
  let mk_in_progress () =
    let initial_valid_header =
      match header with
      | Transition_state.Initial_valid h ->
          h
      | Pre_initial_valid _ ->
          failwith "unexpected gossip with Pre_initial_valid"
    in
    let parent_hash =
      Mina_block.Validation.header initial_valid_header
      |> Mina_block.Header.protocol_state
      |> Mina_state.Protocol_state.previous_state_hash
    in
    let states =
      Option.value ~default:[]
      @@ let%bind.Option parent =
           State_hash.Table.find transition_states parent_hash
         in
         let%map.Option () =
           match parent with
           | Transition_state.Verifying_blockchain_proof _ ->
               Some ()
           | _ ->
               None
         in
         Substate.collect_dependent_ancestry ~transition_states ~state_functions
           parent
    in
    (* TODO process headers that were filtered out (make them `Done` upon success ?) *)
    let headers =
      List.filter_map states ~f:(fun st ->
          match st with
          | Transition_state.Verifying_blockchain_proof
              { header = Pre_initial_valid h; _ } ->
              Some h
          | _ ->
              None )
    in
    match headers with
    | [] ->
        Substate.Done initial_valid_header
    | first_header :: _ ->
        let module I = Interruptible.Make () in
        let action =
          I.lift
          @@ Mina_block.Validation.validate_proofs ~verifier:Context.verifier
               ~genesis_state_hash:(genesis_state_hash (module Context))
               headers
        in
        let timeout = Time.add (Time.now ()) ancestry_verification_timeout in
        Async_kernel.Deferred.upon (I.force action)
        @@ upon_f ~mark_processed_and_promote ~transition_states
             ~timeout_controller:Context.timeout_controller
             ~initial_valid_header ~first_header ;
        In_progress { interrupt_ivar = I.interrupt_ivar; timeout }
  in
  let ctx =
    if s.Substate.received_via_gossip then mk_in_progress () else Dependent
  in
  Transition_state.Verifying_blockchain_proof
    { header
    ; gossip_data
    ; body_opt
    ; substate = { s with status = Processing ctx }
    }
