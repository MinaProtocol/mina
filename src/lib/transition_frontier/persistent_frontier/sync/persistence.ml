open Async_kernel
open Core_kernel
open Coda_base
open Coda_state
open Pipe_lib

module Make (Inputs : Intf.Inputs_with_transition_storage_intf) = struct
  open Inputs

  module Diff_buffer = Diff_buffer.Make (Inputs)
  module Worker = Worker.Make (Inputs)

  (* TODO: might be able to undo splitting out of db now? *)
  let create ~logger ~db_directory ~root_snarked_ledger ~frontier_hash =
    let db = Db.create ~directory:db_directory in
    (match Db.check db with
    | Ok () ->
        if (Db.get_root_hash db).hash = (Ledger.Db.merkle_root root_snarked_ledger) then (
          Result.ok_if_true
            (Frontier.Hash.equal (Db.get_frontier_hash db) frontier_hash)
            ~error:`Invalid_frontier_hash)
        else if Db.mem_transition root.hash then (
          Logger.info logger ~module_:__MODULE__ ~location:__LOC__
            ~metadata:[("new_root_hash", State_hash.to_yojson root.hash) ]
            "fast forwarding persistent transition frontier root to $new_root_hash";
          let%map () = Db.fast_forward_root db ~new_root:root in
          Db.set_frontier_hash frontier_hash)
        else (
          Db.clear db;
          Db.initialize db ~root_data:root.root_data ~base_hash:frontier_hash;
          Ok ())
    | Error `Not_initialized ->
        Db.initialize db ~root:genesis;
        Ok ()
    | Error `Corrupt ->
        failwith "corrupt transition frontier database: please fix or delete");
    let worker = Worker.create {db; logger} in
    let buffer = Buffer.create () in
    {db; worker; buffer}

  let load_full_frontier t ~consensus_local_state =
    let root_data, root_transition = Db.get_root t.db in
    let staged_ledger_mask = failwith "TODO" in
    let staged_ledger =
      Staged_ledger.of_scan_state_and_ledger
        ~logger ~verifier
        ~snarked_ledger_hash
        ~ledger:staged_ledger_mask
        ~scan_state:root_data.scan_state
        ~pending_coinbases:root_data.pending_coinbase
    in
    let frontier =
      Full_frontier.create
        ~logger:t.logger
        ~root_transition
        ~root_staged_ledger
        ~consensus_local_state
    in
    (* TODO reconstruct and add breadcrumbs dfs, set best tip, perform basic validation *)
    frontier

(***********************)

  type t =
    { worker: Worker.t
    ; worker_thread: unit Deferred.t
    ; max_buffer_capacity: int
    ; flush_capacity: int
    ; work_writer:
        ( work
        , Strict_pipe.synchronous
        , unit Deferred.t )
        Strict_pipe.Writer.t
    ; buffer: Buffer.t }

  let write_diff_and_verify ~logger ~acc_hash worker (diff, ground_truth_mutant)
      =
    Logger.trace logger "Handling mutant diff" ~module_:__MODULE__
      ~location:__LOC__
      ~metadata:
        [("diff_mutant", Diff.key_to_yojson diff)] ;
    let ground_truth_hash =
      Incremental_hash.merge_diff acc_hash diff ground_truth_mutant
    in
    match%map
      Worker.handle_diff worker acc_hash
        (Transition_frontier.Diff.Mutant.E.E diff)
    with
    | Error e ->
        Logger.error ~module_:__MODULE__ ~location:__LOC__ logger
          "Could not connect to worker" ;
        Error.raise e
    | Ok new_hash ->
        if Transition_frontier.Diff.Hash.equal new_hash ground_truth_hash then
          ground_truth_hash
        else
          failwithf
            !"Unable to write mutant diff correctly as hashes are different:\n\
             \ %s. Hash of groundtruth %s Hash of actual %s"
            (Yojson.Safe.to_string
               (Transition_frontier.Diff.Mutant.key_to_yojson diff))
            (Transition_frontier.Diff.Hash.to_string ground_truth_hash)
            (Transition_frontier.Diff.Hash.to_string new_hash)
            ()

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
