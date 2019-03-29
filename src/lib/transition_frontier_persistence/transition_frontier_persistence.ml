open Core_kernel
open Coda_base
open Async_kernel
open Pipe_lib
module Diff_mutant = Diff_mutant
module Worker = Worker
module Intf = Intf

module Make (Inputs : Intf.Main_inputs) :
  Intf.S
  with type frontier := Inputs.Transition_frontier.t
   and type worker := Inputs.Worker.t
   and type diff_hash := Inputs.Diff_hash.t
   and type 'output diff :=
              ( (Inputs.External_transition.t, State_hash.t) With_hash.t
              , 'output )
              Inputs.Diff_mutant.t = struct
  open Inputs

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
        Diff_mutant.t) : (State_hash.t, output) Diff_mutant.t =
    match diff with
    | Remove_transitions removed_transitions_with_hashes ->
        Remove_transitions
          (List.map ~f:With_hash.hash removed_transitions_with_hashes)
    | New_frontier first_root -> New_frontier first_root
    | Add_transition added_transition -> Add_transition added_transition
    | Update_root new_root -> Update_root new_root

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

  module For_tests = struct
    let write_diff_and_verify = write_diff_and_verify
  end
end
