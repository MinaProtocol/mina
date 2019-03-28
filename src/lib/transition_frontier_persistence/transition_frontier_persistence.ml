open Core_kernel
open Coda_base
open Async_kernel
open Pipe_lib
module Diff_mutant = Diff_mutant
module Worker = Worker

module Make (Inputs : Intf.Main_inputs) = struct
  open Inputs

  let consensus_state transition =
    let open External_transition in
    transition |> of_verified |> consensus_state
    |> Binable.to_string (module Consensus.Consensus_state.Value.Stable.V1)

  let serialize_root_data new_root new_scan_state =
    let bin_type =
      [%bin_type_class:
        State_hash.Stable.Latest.t * Staged_ledger.Scan_state.Stable.Latest.t]
    in
    Bin_prot.Utils.bin_dump bin_type.writer (new_root, new_scan_state)

  let apply_diff (type mutant) frontier (diff : mutant Diff_mutant.t) : mutant
      =
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

  let write_diff_and_verify ~logger ~acc_hash worker frontier diff_mutant =
    ( Debug_assert.debug_assert
    @@ fun () ->
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__
      ~metadata:[("diff_request", Diff_mutant.yojson_of_key diff_mutant)]
      "Applying mutant diff; $diff_request" ) ;
    let ground_truth_diff = apply_diff frontier diff_mutant in
    let ground_truth_hash =
      Diff_mutant.hash acc_hash diff_mutant ground_truth_diff
    in
    ( Debug_assert.debug_assert
    @@ fun () ->
    Logger.trace ~module_:__MODULE__ ~location:__LOC__ logger
      ~metadata:
        [ ( "diff_response"
          , Diff_mutant.yojson_of_value diff_mutant ground_truth_diff ) ]
      "Ground truth diff mutant" ) ;
    match%map Worker.handle_diff worker acc_hash diff_mutant with
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
end
