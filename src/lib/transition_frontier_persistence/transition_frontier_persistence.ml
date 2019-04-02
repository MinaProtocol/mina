open Core_kernel
open Coda_base
open Async_kernel
open Pipe_lib
module Diff_mutant = Diff_mutant
module Worker = Worker
module Intf = Intf
module Diff_hash = Diff_hash
module Transition_storage = Transition_storage

module Make (Inputs : Intf.Main_inputs) = struct
  open Inputs
  module Worker = Inputs.Make_worker (Inputs)
  module Transition_storage = Inputs.Make_transition_storage (Inputs)

  type t = Worker.t

  let create = Worker.create

  let apply_diff (type mutant) frontier
      (diff :
        ( ( External_transition.Stable.Latest.t
          , State_hash.Stable.Latest.t )
          With_hash.t
        , mutant )
        Diff_mutant.t) : mutant =
    match diff with
    | New_frontier _ -> ()
    | Add_transition {data= transition; _} ->
        let parent_hash = External_transition.parent_hash transition in
        Transition_frontier.find_exn frontier parent_hash
        |> Transition_frontier.Breadcrumb.transition_with_hash
        |> With_hash.data |> External_transition.Verified.consensus_state
    | Remove_transitions external_transitions_with_hashes ->
        List.map external_transitions_with_hashes
          ~f:(Fn.compose External_transition.consensus_state With_hash.data)
    | Update_root _ ->
        let previous_root =
          Transition_frontier.previous_root frontier |> Option.value_exn
        in
        let state_hash =
          Transition_frontier.Breadcrumb.state_hash previous_root
        in
        ( state_hash
        , Transition_frontier.Breadcrumb.staged_ledger previous_root
          |> Staged_ledger.scan_state )

  let to_state_hash_diff (type output)
      (diff :
        ( (External_transition.t, State_hash.t) With_hash.t
        , output )
        Diff_mutant.t) : State_hash.t Diff_mutant.E.t =
    match diff with
    | Remove_transitions removed_transitions_with_hashes ->
        E
          (Remove_transitions
             (List.map ~f:With_hash.hash removed_transitions_with_hashes))
    | New_frontier first_root -> E (New_frontier first_root)
    | Add_transition added_transition -> E (Add_transition added_transition)
    | Update_root new_root -> E (Update_root new_root)

  let write_diff_and_verify ~logger ~acc_hash worker frontier diff_mutant =
    ( Debug_assert.debug_assert
    @@ fun () ->
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__
      ~metadata:
        [ ( "diff_request"
          , Diff_mutant.yojson_of_key diff_mutant
              ~f:(Fn.compose State_hash.to_yojson With_hash.hash) ) ]
      "Applying mutant diff; $diff_request" ) ;
    let ground_truth_diff = apply_diff frontier diff_mutant in
    let ground_truth_hash =
      Diff_mutant.hash acc_hash diff_mutant ground_truth_diff
        ~f:(Fn.compose State_hash.to_bytes With_hash.hash)
    in
    ( Debug_assert.debug_assert
    @@ fun () ->
    Logger.trace ~module_:__MODULE__ ~location:__LOC__ logger
      ~metadata:
        [ ( "diff_response"
          , Diff_mutant.yojson_of_value diff_mutant ground_truth_diff ) ]
      "Ground truth diff mutant" ) ;
    match%map
      Worker.handle_diff worker acc_hash (to_state_hash_diff diff_mutant)
    with
    | Error e ->
        Logger.error ~module_:__MODULE__ ~location:__LOC__ logger
          "Could not connect to worker" ;
        Error.raise e
    | Ok new_hash ->
        if Diff_hash.equal new_hash ground_truth_hash then ground_truth_hash
        else
          failwith
            "Unable to write mutant diff correctly as hashes are different"

  let listen_to_frontier_broadcast_pipe ~logger
      (frontier_broadcast_pipe :
        Transition_frontier.t option Broadcast_pipe.Reader.t) worker =
    let%bind _ : Diff_hash.t =
      Broadcast_pipe.Reader.fold frontier_broadcast_pipe ~init:Diff_hash.empty
        ~f:(fun acc_hash frontier_opt ->
          match frontier_opt with
          | Some frontier ->
              Broadcast_pipe.Reader.fold
                (Transition_frontier.persistence_diff_pipe frontier)
                ~init:acc_hash ~f:(fun acc_hash diffs ->
                  Deferred.List.fold diffs ~init:acc_hash
                    ~f:(fun acc_hash (E mutant) ->
                      write_diff_and_verify ~logger ~acc_hash worker frontier
                        mutant ) )
          | None ->
              (* TODO: need to delete persistence once it get's back up *)
              Deferred.return Diff_hash.empty )
    in
    Deferred.unit

  let directly_add_breadcrumb ~logger transition_frontier transition_with_hash
      parent =
    let log_error () =
      Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:
          [("hash", State_hash.to_yojson (With_hash.hash transition_with_hash))]
        "Failed to add breadcrumb into $hash"
    in
    let%bind child_breadcrumb =
      match%map
        Transition_frontier.Breadcrumb.build ~logger ~parent
          ~transition_with_hash
      with
      | Ok child_breadcrumb -> child_breadcrumb
      | Error (`Fatal_error exn) -> log_error () ; raise exn
      | Error (`Validation_error error) -> log_error () ; Error.raise error
    in
    let%map () =
      Transition_frontier.add_breadcrumb_exn transition_frontier
        child_breadcrumb
    in
    child_breadcrumb

  let staged_ledger_hash transition =
    let open External_transition.Verified in
    let protocol_state = protocol_state transition in
    Coda_base.Staged_ledger_hash.ledger_hash
      External_transition.Protocol_state.(
        Blockchain_state.staged_ledger_hash @@ blockchain_state protocol_state)

  let with_database ~directory_name ~f =
    let transition_storage =
      Transition_storage.create ~directory:directory_name
    in
    let result = f transition_storage in
    Transition_storage.close transition_storage ;
    result

  let deserialize ~directory_name ~logger ~root_snarked_ledger
      ~consensus_local_state =
    let open Transition_storage.Schema in
    with_database ~directory_name ~f:(fun transition_storage ->
        let state_hash, scan_state =
          Transition_storage.get transition_storage ~logger Root
        in
        let get_verified_transition state_hash =
          let transition, root_successor_hashes =
            Transition_storage.get transition_storage ~logger
              (Transition state_hash)
          in
          (* We read a transition that was already verified before it was written to disk *)
          let (`I_swear_this_is_safe_see_my_comment verified_transition) =
            External_transition.to_verified transition
          in
          (verified_transition, root_successor_hashes)
        in
        let root_transition, root_successor_hashes =
          let verified_transition, children_hashes =
            get_verified_transition state_hash
          in
          ( {With_hash.data= verified_transition; hash= state_hash}
          , children_hashes )
        in
        let%bind root_staged_ledger =
          Staged_ledger.of_scan_state_and_snarked_ledger ~scan_state
            ~snarked_ledger:(Ledger.of_database root_snarked_ledger)
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
          | [] -> Deferred.unit
          | (state_hash, parent_breadcrumb) :: remaining_jobs ->
              let verified_transition, child_hashes =
                get_verified_transition state_hash
              in
              let%bind new_breadcrumb =
                directly_add_breadcrumb ~logger transition_frontier
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
        transition_frontier )

  module For_tests = struct
    let write_diff_and_verify = write_diff_and_verify
  end
end
