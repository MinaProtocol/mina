open Core_kernel
open Coda_base
open Async_kernel
open Pipe_lib
module Diff_mutant = Diff_mutant

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

  let find_consensus_state_exn frontier hash =
    Transition_frontier.find_exn frontier hash
    |> Transition_frontier.Breadcrumb.transition_with_hash |> With_hash.data
    |> consensus_state

  let apply_diff (type mutant) frontier (diff : mutant Diff_mutant.t) : mutant
      =
    match diff with
    | Add_transition {data= transition; _} ->
        let parent_hash = External_transition.parent_hash transition in
        find_consensus_state_exn frontier parent_hash
    | Move_root
        { best_tip= {hash= best_tip_hash; _}
        ; removed_transitions
        ; new_root
        ; new_scan_state } ->
        let parent = find_consensus_state_exn frontier best_tip_hash in
        let removed_transitions =
          List.map removed_transitions ~f:(find_consensus_state_exn frontier)
        in
        let old_root_data =
          serialize_root_data new_root new_scan_state |> Bigstring.to_string
        in
        {parent; removed_transitions; old_root_data}

  let write_diff_and_verify ~logger ~init_hash frontier worker =
    Broadcast_pipe.Reader.fold diff_mutant_reader ~init:init_hash
      ~f:(fun acc_hash (E diff_mutant) ->
        Logger.info logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:[("diff_request", Diff_mutant.yojson_of_key diff_mutant)]
          "Applying mutant diff; $diff_request" ;
        let ground_truth_diff = apply_diff frontier diff_mutant in
        let ground_truth_hash =
          Diff_mutant.hash acc_hash diff_mutant ground_truth_diff
        in
        match%map Worker.handle_diff worker acc_hash diff_mutant with
        | Error e ->
            Logger.error ~module_:__MODULE__ ~location:__LOC__ logger
              "Could not connect to worker" ;
            Error.raise e
        | Ok new_hash ->
            if Diff_hash.equal new_hash ground_truth_hash then (
              (* TODO: create function to yojson  *)
              Logger.trace ~module_:__MODULE__ ~location:__LOC__ logger
                ~metadata:
                  [ ( "diff_response"
                    , Diff_mutant.yojson_of_value diff_mutant ground_truth_diff
                    ) ]
                "Processed diff correctly. Got answer $diff_response" ;
              ground_truth_hash )
            else
              failwith
                "Unable to write mutant diff correctly as hashes are different"
    )

  let listen_to_frontier_broadcast_pipe ~logger
      (frontier_broadcast_pipe :
        Transition_frontier.t option Broadcast_pipe.Reader.t) worker =
    Broadcast_pipe.Reader.fold frontier_broadcast_pipe ~init:Diff_hash.empty
      ~f:(fun acc_hash frontier_opt ->
        match frontier_opt with
        | Some frontier ->
            write_diff_and_verify ~logger ~init_hash:acc_hash frontier worker
        | None ->
            (* TODO: need to delete persistence once it get's back up *)
            Deferred.return Diff_hash.empty )
end
