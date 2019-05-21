open Core_kernel
open Coda_base
open Coda_state
open Async_kernel
open Pipe_lib
module Worker = Worker
module Intf = Intf
module Transition_storage = Transition_storage

module Make (Inputs : Intf.Main_inputs) = struct
  open Inputs
  module Worker = Inputs.Make_worker (Inputs)

  type t =
    { worker: Worker.t
    ; worker_thread: unit Deferred.t
    ; reader: Transition_frontier.Diff_mutant.E.pair list Pipe.Reader.t
    ; writer: Transition_frontier.Diff_mutant.E.pair list Pipe.Writer.t
    ; max_buffer_capacity: int
    ; buffer: Transition_frontier.Diff_mutant.E.pair Queue.t }

  let write_diff_and_verify ~logger ~acc_hash worker (diff, ground_truth_mutant)
      =
    Logger.trace logger "Handling mutant diff" ~module_:__MODULE__
      ~location:__LOC__
      ~metadata:
        [("diff_mutant", Transition_frontier.Diff_mutant.key_to_yojson diff)] ;
    let ground_truth_hash =
      Transition_frontier.Diff_mutant.hash acc_hash diff ground_truth_mutant
    in
    match%map
      Worker.handle_diff worker acc_hash
        (Transition_frontier.Diff_mutant.E.E diff)
    with
    | Error e ->
        Logger.error ~module_:__MODULE__ ~location:__LOC__ logger
          "Could not connect to worker" ;
        Error.raise e
    | Ok new_hash ->
        if Transition_frontier.Diff_hash.equal new_hash ground_truth_hash then
          ground_truth_hash
        else
          failwithf
            !"Unable to write mutant diff correctly as hashes are different:\n\
             \ %s. Hash of groundtruth %s Hash of actual %s"
            (Yojson.Safe.to_string
               (Transition_frontier.Diff_mutant.key_to_yojson diff))
            (Transition_frontier.Diff_hash.to_string ground_truth_hash)
            (Transition_frontier.Diff_hash.to_string new_hash)
            ()

  let create ?directory_name ~logger max_buffer_capacity =
    let worker = Worker.create ?directory_name ~logger () in
    let reader, writer = Pipe.create () in
    let buffer = Queue.create () in
    let worker_thread =
      Pipe.fold ~flushed:Pipe.Flushed.When_value_processed
        ~init:Transition_frontier.Diff_hash.empty reader
        ~f:(fun init_hash diff_pairs ->
          Deferred.List.fold diff_pairs ~init:init_hash
            ~f:(fun acc_hash
               (Transition_frontier.Diff_mutant.E.Pair
                 (diff, ground_truth_mutant))
               ->
              let%bind result =
                write_diff_and_verify ~logger ~acc_hash worker
                  (diff, ground_truth_mutant)
              in
              (* We would want the scheduler to run other jobs after computing a diff *)
              Deferred.create @@ fun ivar -> Ivar.fill ivar result ) )
      |> Deferred.ignore
    in
    {worker; reader; writer; max_buffer_capacity; buffer; worker_thread}

  let close {worker; writer; _} = Pipe.close writer ; Worker.close worker

  let flush {writer; buffer; _} =
    let list = Queue.to_list buffer in
    Pipe.write_without_pushback writer list ;
    Queue.clear buffer

  let close_and_finish_copy ({worker; writer; worker_thread; _} as t) =
    flush t ;
    Pipe.close writer ;
    let%map () = worker_thread in
    Worker.close worker

  let listen_to_frontier_broadcast_pipe
      (frontier_broadcast_pipe :
        Transition_frontier.t option Broadcast_pipe.Reader.t)
      ({max_buffer_capacity; buffer; _} as t) =
    Broadcast_pipe.Reader.iter frontier_broadcast_pipe
      ~f:
        (Option.value_map ~default:Deferred.unit ~f:(fun frontier ->
             Broadcast_pipe.Reader.iter
               (Transition_frontier.persistence_diff_pipe frontier)
               ~f:(fun new_diffs ->
                 Queue.enqueue_all buffer new_diffs ;
                 if Queue.length buffer >= max_buffer_capacity then (
                   flush t ;
                   assert (Queue.is_empty buffer) ) ;
                 Deferred.unit ) ))

  let directly_add_breadcrumb ~logger ~verifier ~trust_system
      transition_frontier transition parent =
    let log_error () =
      Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:[("hash", State_hash.to_yojson (With_hash.hash transition))]
        "Failed to add breadcrumb into $hash"
    in
    (* TMP HACK: our transition is already validated, so we "downgrade" it's validation #2486 *)
    let mostly_validated_external_transition =
      ( With_hash.map ~f:External_transition.Validated.forget_validation
          transition
      , ( (`Time_received, Truth.True)
        , (`Proof, Truth.True)
        , (`Frontier_dependencies, Truth.True)
        , (`Staged_ledger_diff, Truth.False) ) )
    in
    let%bind child_breadcrumb =
      match%map
        Transition_frontier.Breadcrumb.build ~logger ~verifier ~trust_system
          ~parent ~transition:mostly_validated_external_transition ~sender:None
      with
      | Ok child_breadcrumb ->
          child_breadcrumb
      | Error (`Fatal_error exn) ->
          log_error () ; raise exn
      | Error (`Invalid_staged_ledger_diff error)
      | Error (`Invalid_staged_ledger_hash error) ->
          log_error () ; Error.raise error
    in
    let%map () =
      Transition_frontier.add_breadcrumb_exn transition_frontier
        child_breadcrumb
    in
    child_breadcrumb

  let staged_ledger_hash transition =
    let open External_transition.Validated in
    let protocol_state = protocol_state transition in
    Staged_ledger_hash.ledger_hash
      Protocol_state.(
        Blockchain_state.staged_ledger_hash @@ blockchain_state protocol_state)

  let with_database ~directory_name ~f =
    let transition_storage =
      Transition_storage.create ~directory:directory_name
    in
    let result = f transition_storage in
    Transition_storage.close transition_storage ;
    result

  let read ~logger ~verifier ~trust_system ~root_snarked_ledger
      ~consensus_local_state transition_storage =
    let state_hash, scan_state, pending_coinbases =
      Transition_storage.get transition_storage ~logger Root
    in
    let get_verified_transition state_hash =
      Transition_storage.get transition_storage ~logger (Transition state_hash)
    in
    let root_transition, root_successor_hashes =
      let verified_transition, children_hashes =
        get_verified_transition state_hash
      in
      ({With_hash.data= verified_transition; hash= state_hash}, children_hashes)
    in
    let%bind root_staged_ledger =
      Staged_ledger.of_scan_state_pending_coinbases_and_snarked_ledger ~logger
        ~verifier ~scan_state
        ~snarked_ledger:(Ledger.of_database root_snarked_ledger)
        ~pending_coinbases
        ~expected_merkle_root:
          (staged_ledger_hash @@ With_hash.data root_transition)
      |> Deferred.Or_error.ok_exn
    in
    let%bind transition_frontier =
      Transition_frontier.create ~logger ~consensus_local_state
        ~root_transition ~root_snarked_ledger ~root_staged_ledger
    in
    let create_job breadcrumb child_hashes =
      List.map child_hashes ~f:(fun child_hash -> (child_hash, breadcrumb))
    in
    let rec dfs = function
      | [] ->
          Deferred.unit
      | (state_hash, parent_breadcrumb) :: remaining_jobs ->
          let verified_transition, child_hashes =
            get_verified_transition state_hash
          in
          let%bind new_breadcrumb =
            directly_add_breadcrumb ~logger ~verifier ~trust_system
              transition_frontier
              With_hash.{data= verified_transition; hash= state_hash}
              parent_breadcrumb
          in
          dfs
            ( List.map child_hashes ~f:(fun child_hash ->
                  (child_hash, new_breadcrumb) )
            @ remaining_jobs )
    in
    let%map () =
      dfs
        (create_job
           (Transition_frontier.root transition_frontier)
           root_successor_hashes)
    in
    transition_frontier

  let deserialize ~directory_name ~logger ~verifier ~trust_system
      ~root_snarked_ledger ~consensus_local_state =
    with_database ~directory_name
      ~f:
        (read ~logger ~verifier ~trust_system ~root_snarked_ledger
           ~consensus_local_state)

  module For_tests = struct
    let write_diff_and_verify = write_diff_and_verify
  end
end
