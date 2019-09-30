open Core_kernel
open Coda_base
open Coda_state
open Async_kernel
open Pipe_lib
open Coda_transition
module Intf = Intf

module Components = struct
  module Transition_storage = Transition_storage
  module Worker = Worker
end

module Make (Inputs : Intf.Main_inputs) = struct
  open Inputs
  module Worker = Inputs.Make_worker (Inputs)

  type t =
    { worker: Worker.t
    ; worker_thread: unit Deferred.t
    ; max_buffer_capacity: int
    ; flush_capacity: int
    ; worker_writer:
        ( Transition_frontier.Diff.Mutant.E.with_value list
        , Strict_pipe.synchronous
        , unit Deferred.t )
        Strict_pipe.Writer.t
    ; buffer: Transition_frontier.Diff.Mutant.E.with_value Queue.t }

  let write_diff_and_verify ~logger ~acc_hash worker (diff, ground_truth_mutant)
      =
    Logger.trace logger "Handling mutant diff: $diff_mutant"
      ~module_:__MODULE__ ~location:__LOC__
      ~metadata:
        [("diff_mutant", Transition_frontier.Diff.Mutant.key_to_yojson diff)] ;
    let ground_truth_hash =
      Transition_frontier.Diff.Mutant.hash acc_hash diff ground_truth_mutant
    in
    match%map
      Worker.handle_diff worker acc_hash
        (Transition_frontier.Diff.Mutant.E.E diff)
    with
    | Error e ->
        Logger.error ~module_:__MODULE__ ~location:__LOC__ logger
          "Could not connect to worker to handle mutant diff: $error"
          ~metadata:[("error", `String (Error.to_string_hum e))] ;
        Error.raise e
    | Ok new_hash ->
        if Transition_frontier.Diff.Hash.equal new_hash ground_truth_hash then
          ground_truth_hash
        else (
          (* TODO: this should be a failure that never occurs *)
          Logger.error logger
            "Mutant diff hashes differ: diff_mutant: $diff_mutant; hash of \
             ground truth: $hash_of_ground_truth; hash of actual: \
             $hash_of_actual"
            ~module_:__MODULE__ ~location:__LOC__
            ~metadata:
              [ ( "diff_mutant"
                , Transition_frontier.Diff.Mutant.key_to_yojson diff )
              ; ( "hash_of_ground_truth"
                , `String
                    (Transition_frontier.Diff.Hash.to_string ground_truth_hash)
                )
              ; ( "hash_of_actual"
                , `String (Transition_frontier.Diff.Hash.to_string new_hash) )
              ] ;
          ground_truth_hash )

  let rec flush ({buffer; worker_writer; flush_capacity; _} as t) =
    let list = Queue.to_list buffer in
    Queue.clear buffer ;
    let%bind () = Strict_pipe.Writer.write worker_writer list in
    if Queue.length buffer >= flush_capacity then flush t else Deferred.unit

  let create ?directory_name ~logger ~flush_capacity ~max_buffer_capacity () =
    let worker = Worker.create ?directory_name ~logger () in
    let buffer = Queue.create () in
    let reader, writer =
      Strict_pipe.create ~name:"Transition_frontier_persistence worker"
        Strict_pipe.Synchronous
    in
    let worker_thread =
      Strict_pipe.Reader.fold reader ~init:Transition_frontier.Diff.Hash.empty
        ~f:(fun init_hash diff_pairs ->
          Deferred.List.fold diff_pairs ~init:init_hash
            ~f:(fun acc_hash
               (Transition_frontier.Diff.Mutant.E.With_value
                 (diff, ground_truth_mutant))
               ->
              write_diff_and_verify ~logger ~acc_hash worker
                (diff, ground_truth_mutant) ) )
      |> Deferred.ignore
    in
    { worker
    ; worker_writer= writer
    ; flush_capacity
    ; max_buffer_capacity
    ; buffer
    ; worker_thread }

  (* TODO: Remove once #2115 is solved *)
  let close_and_finish_copy_without_closing_worker t =
    (* Flush the remaining amount of work into worker pipe *)
    let list = Queue.to_list t.buffer in
    Queue.clear t.buffer ;
    Strict_pipe.Writer.write t.worker_writer list |> don't_wait_for ;
    (* Synchronously close pipe so that the worker only process remaining work in the pipe *)
    Strict_pipe.Writer.close t.worker_writer ;
    t.worker_thread

  let close_and_finish_copy t =
    let%map () = close_and_finish_copy_without_closing_worker t in
    Worker.close t.worker

  let select_work ({max_buffer_capacity; flush_capacity; buffer; _} as t)
      current_work =
    if
      Queue.length buffer >= flush_capacity
      && Deferred.is_determined current_work
    then flush t
    else if Queue.length buffer > max_buffer_capacity then
      Debug_assert.debug_assert_deferred
      @@ fun () ->
      failwithf
        !"There is too many work that a Transition Frontier Persistence \
          worker is waiting for. Retune buffer parameters: {flush_capacity: \
          %i, buffer_capacity: %i}"
        flush_capacity max_buffer_capacity ()
    else current_work

  let listen_to_frontier_broadcast_pipe
      (frontier_broadcast_pipe :
        Transition_frontier.t option Broadcast_pipe.Reader.t) t =
    Broadcast_pipe.Reader.iter frontier_broadcast_pipe
      ~f:
        (Option.value_map ~default:Deferred.unit ~f:(fun frontier ->
             Deferred.join
             @@ Broadcast_pipe.Reader.fold ~init:Deferred.unit
                  (Transition_frontier.persistence_diff_pipe frontier)
                  ~f:(fun worker_thread new_diffs ->
                    Deferred.return
                    @@
                    if not @@ Strict_pipe.Writer.is_closed t.worker_writer then (
                      Queue.enqueue_all t.buffer new_diffs ;
                      select_work t worker_thread )
                    else worker_thread ) ))

  let directly_add_breadcrumb ~logger ~verifier ~trust_system
      transition_frontier transition parent =
    let log_error () =
      Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:[("hash", State_hash.to_yojson (With_hash.hash transition))]
        "Failed to add breadcrumb to transition $hash"
    in
    let previous_state_hash =
      With_hash.data transition |> External_transition.Validated.parent_hash
    in
    (* TMP HACK: our transition is already validated, so we "downgrade" it's validation #2486 *)
    let mostly_validated_external_transition =
      ( With_hash.map ~f:External_transition.Validation.forget_validation
          transition
      , ( (`Time_received, Truth.True ())
        , (`Proof, Truth.True ())
        , ( `Delta_merkle_list
          , Truth.True (Non_empty_list.singleton previous_state_hash) )
        , (`Frontier_dependencies, Truth.True ())
        , (`Staged_ledger_diff, Truth.False)
        , (`Delta_boundary, Truth.True ()) ) )
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
    let%map result = f transition_storage in
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
      get_verified_transition state_hash
    in
    let%bind root_staged_ledger =
      Staged_ledger.of_scan_state_pending_coinbases_and_snarked_ledger ~logger
        ~verifier ~scan_state
        ~snarked_ledger:(Ledger.of_database root_snarked_ledger)
        ~pending_coinbases
        ~expected_merkle_root:(staged_ledger_hash root_transition)
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

module Base_inputs = struct
  open Coda_transition

  let max_length = Consensus.Constants.k

  module Verifier = Verifier
  module Ledger_proof = Ledger_proof
  module External_transition = External_transition
  module Internal_transition = Internal_transition
  module Staged_ledger = Staged_ledger
  module Transition_frontier = Transition_frontier
  module Staged_ledger_diff = Staged_ledger_diff
  module Transaction_snark_work = Transaction_snark_work
end

module Inputs = struct
  include Base_inputs
  module Transition_storage = Transition_storage.Make (Base_inputs)
  module Make_worker = Worker.Make_async
end

include Make (Inputs)
