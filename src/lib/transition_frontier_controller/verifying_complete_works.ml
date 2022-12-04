open Mina_base
open Core_kernel
open Context
open Bit_catchup_state

(** Extract body from a transition in [Transition_state.Verifying_complete_works] state *)
let body_exn = function
  | Transition_state.Verifying_complete_works { block; _ } ->
      Mina_block.Validation.block block |> Mina_block.body
  | _ ->
      failwith "unexpected collected ancestor for Verifying_complete_works"

(** Extract complete works from a block body *)
let works body =
  Mina_block.Body.staged_ledger_diff body
  |> Staged_ledger_diff.completed_works
  |> List.concat_map ~f:(fun { Transaction_snark_work.fee; prover; proofs } ->
         let msg = Sok_message.create ~fee ~prover in
         One_or_two.to_list (One_or_two.map proofs ~f:(fun p -> (p, msg))) )

module F = struct
  type processing_result = unit

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

  let create_in_progress_context ~context:(module Context : CONTEXT) ~holder
      states =
    let bottom_state = Mina_stdlib.Nonempty_list.head states in
    let downto_ =
      (Transition_state.State_functions.transition_meta bottom_state)
        .blockchain_length
    in
    let module I = Interruptible.Make () in
    let timeout =
      Time.add (Time.now ()) Context.transaction_snark_verification_timeout
    in
    interrupt_after_timeout ~timeout I.interrupt_ivar ;
    let states = Mina_stdlib.Nonempty_list.to_list states in
    let f = function
      | Ok (Ok ()) ->
          Ok (List.map states ~f:(const ()))
      | Ok (Error e) ->
          Error (`Invalid_proof e)
      | Error e ->
          Error (`Verifier_error e)
    in
    let works = List.concat_map states ~f:(Fn.compose works body_exn) in
    let action =
      I.map ~f (Context.verify_transaction_proofs (module I) works)
    in
    ( Substate.In_progress
        { interrupt_ivar = I.interrupt_ivar; timeout; downto_; holder }
    , I.force action )

  let data_name = "complete work(s)"
end

include Verifying_generic.Make (F)

(** Promote a transition that is in [Downloading_body] state with
    [Processed] status to [Verifying_complete_works] state.
*)
let promote_to ~actions ~context ~transition_states ~header ~substate ~block_vc
    ~aux =
  let (module Context : CONTEXT) = context in
  let body =
    match substate.Substate.status with
    | Processed b ->
        b
    | _ ->
        failwith "promote_downloading_body: expected processed"
  in
  let block = Mina_block.Validation.with_body header body in
  let works = works body in
  let mk_state status =
    Transition_state.Verifying_complete_works
      { block
      ; substate = { substate with status }
      ; block_vc
      ; aux
      ; baton = false
      }
  in
  let mk_processing x = mk_state (Processing x) in
  let start_parent () =
    let parent_hash =
      Mina_block.Validation.header header
      |> Mina_block.Header.protocol_state
      |> Mina_state.Protocol_state.previous_state_hash
    in
    let%map.Option parent =
      Transition_states.find transition_states parent_hash
    in
    collect_dependent_and_pass_the_baton ~transition_states
      ~dsu:Context.processed_dsu parent
    |> start ~context ~actions ~transition_states
  in
  let handle_done () =
    if aux.Transition_state.received_via_gossip then
      ignore (start_parent () : unit option) ;
    mk_processing (Done ())
  in
  let handle_processing () =
    collect_dependent_and_pass_the_baton ~transition_states
      ~dsu:Context.processed_dsu (mk_processing Dependent)
    |> Mina_stdlib.Nonempty_list.of_list_opt
    |> Option.map
         ~f:
           ( Fn.compose mk_processing
           @@ launch_in_progress ~context ~actions ~transition_states )
    |> function
    | Some x ->
        x
    | None ->
        let state_hash = state_hash_of_header_with_validation header in
        [%log' error Context.logger]
          "Verifying_complete_works: unexpectedly wasn't able to collect the \
           transition itself for start of processing $state_hash"
          ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ] ;
        let empty_collected_err =
          Error.of_string "unable to start processing"
        in
        mk_state @@ Failed empty_collected_err
  in
  if List.is_empty works then handle_done ()
  else if aux.Transition_state.received_via_gossip then handle_processing ()
  else mk_processing Dependent

(** [make_independent state_hash] starts verification of complete works for
       a transition corresponding to the [block].

    This function is called when a gossip is received for a transition
    that is in [Transition_state.Verifying_complete_works] state.

    Pre-condition: transition corresponding to [state_hash] has
    [Substate.Processing Dependent] status and was just received through gossip.
   *)
let make_independent ~context ~actions ~transition_states state_hash =
  let (module Context : CONTEXT) = context in
  let for_start =
    collect_dependent_and_pass_the_baton_by_hash ~transition_states
      ~dsu:Context.processed_dsu state_hash
  in
  start ~context ~actions ~transition_states for_start
