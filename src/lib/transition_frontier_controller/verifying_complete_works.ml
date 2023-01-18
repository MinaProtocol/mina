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

  let verify ~context:(module Context : CONTEXT) (module I : Interruptible.F)
      states =
    let states = Mina_stdlib.Nonempty_list.to_list states in
    let works = List.concat_map states ~f:(Fn.compose works body_exn) in
    let batches =
      let rec mk_batch acc rest =
        let batch, rest' =
          List.split_n rest Context.catchup_config.max_proofs_per_batch
        in
        let acc' = batch :: acc in
        if List.is_empty rest' then acc' else mk_batch acc' rest'
      in
      mk_batch [] works
    in
    let batch_count = List.length batches in
    let f = function
      | Ok (Error e) ->
          Error (`Invalid_proof e)
      | Ok (Ok ()) ->
          Ok ()
      | Error e ->
          Error (`Verifier_error e)
    in
    let state_hash_of_state st =
      (Transition_state.State_functions.transition_meta st).state_hash
    in
    let state_hashes =
      List.map ~f:(Fn.compose State_hash.to_yojson state_hash_of_state) states
    in
    [%log' debug Context.logger] "verify transaction proofs of $state_hashes"
      ~metadata:[ ("state_hashes", `List state_hashes) ] ;
    let verify_batch batch =
      I.map ~f (Context.verify_transaction_proofs (module I) batch)
    in
    ( I.Result.map ~f:(const @@ List.map states ~f:(const ()))
      @@ I.Result.all_unit (List.map batches ~f:verify_batch)
    , Time.Span.scale
        Context.catchup_config.transaction_snark_verification_timeout
        (float_of_int batch_count) )

  let data_name = "complete work(s)"

  let split_to_batches ~context:(module Context : CONTEXT) =
    let open Mina_stdlib.Nonempty_list in
    let init_f st =
      singleton (body_exn st |> works |> List.length, singleton st)
    in
    let f res st =
      let (n, head), rest = uncons res in
      let works = works (body_exn st) in
      let wn = List.length works in
      if n + wn > Context.catchup_config.max_proofs_per_batch then
        cons (wn, singleton st) res
      else init (n + wn, cons st head) rest
    in
    Fn.compose
      (map ~f:(Fn.compose rev snd))
      (fold_with_initiated_accum ~init:init_f ~f)
    |> Fn.compose rev
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
    Mina_block.Validation.header header
    |> Mina_block.Header.protocol_state
    |> Mina_state.Protocol_state.previous_state_hash
    |> collect_dependent_and_pass_the_baton_by_hash ~logger:Context.logger
         ~transition_states ~dsu:Context.processed_dsu
    |> start ~context ~actions ~transition_states
  in
  let handle_done () =
    if aux.Transition_state.received_via_gossip then start_parent () ;
    mk_processing (Done ())
  in
  let handle_processing () =
    collect_dependent_and_pass_the_baton ~logger:Context.logger
      ~transition_states ~dsu:Context.processed_dsu (mk_processing Dependent)
    |> Mina_stdlib.Nonempty_list.of_list_opt
    |> function
    | Some sts ->
        mk_processing
          (launch_in_progress ~context ~actions ~transition_states sts)
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
    collect_dependent_and_pass_the_baton_by_hash ~logger:Context.logger
      ~transition_states ~dsu:Context.processed_dsu state_hash
  in
  start ~context
    ~actions:(Async_kernel.Deferred.return actions)
    ~transition_states for_start
