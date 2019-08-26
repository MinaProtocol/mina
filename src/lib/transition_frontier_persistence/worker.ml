open Core
open Coda_base
open Coda_state
open Async

module Make (Inputs : Intf.Worker_inputs) :
  Intf.Worker
  with type hash := Inputs.Transition_frontier.Diff.Hash.t
   and type diff := Inputs.Transition_frontier.Diff.Mutant.E.t
   and type transition_storage := Inputs.Transition_storage.t = struct
  open Inputs

  type t = {transition_storage: Transition_storage.t; logger: Logger.t}

  let create ?directory_name ~logger () =
    let directory = File_system.make_directory_name directory_name in
    let transition_storage = Transition_storage.create ~directory in
    {transition_storage; logger}

  let close {transition_storage; _} =
    Transition_storage.close transition_storage

  let apply_add_transition ({transition_storage; logger}, batch)
      validated_transition =
    let open Transition_storage.Schema in
    let hash = External_transition.Validated.state_hash validated_transition in
    let parent_hash =
      External_transition.Validated.parent_hash validated_transition
    in
    let parent_transition, children_hashes =
      Transition_storage.get transition_storage ~logger
        (Transition parent_hash) ~location:__LOC__
    in
    Transition_storage.Batch.set batch ~key:(Transition hash)
      ~data:(validated_transition, []) ;
    Transition_storage.Batch.set batch ~key:(Transition parent_hash)
      ~data:(parent_transition, hash :: children_hashes) ;
    Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
      ~metadata:
        [ ("hash", State_hash.to_yojson hash)
        ; ("parent_hash", State_hash.to_yojson parent_hash) ]
      "Added transition $hash and $parent_hash !" ;
    External_transition.Validated.protocol_state parent_transition
    |> Protocol_state.consensus_state

  let handle_diff (t : t) acc_hash
      (E diff : Transition_frontier.Diff.Mutant.E.t) =
    match diff with
    | New_frontier
        Transition_frontier.Diff.Mutant.Root.Poly.
          {root= first_root; scan_state; pending_coinbase} ->
        let first_root_hash =
          External_transition.Validated.state_hash first_root
        in
        Transition_storage.Batch.with_batch t.transition_storage
          ~f:(fun batch ->
            Transition_storage.Batch.set batch ~key:Root
              ~data:(first_root_hash, scan_state, pending_coinbase) ;
            Transition_storage.Batch.set batch
              ~key:(Transition first_root_hash) ~data:(first_root, []) ;
            Transition_frontier.Diff.Mutant.hash acc_hash diff () )
    | Add_transition validated_transition ->
        Transition_storage.Batch.with_batch t.transition_storage
          ~f:(fun batch ->
            let mutant =
              apply_add_transition (t, batch) validated_transition
            in
            Transition_frontier.Diff.Mutant.hash acc_hash diff mutant )
    | Remove_transitions removed_transitions ->
        let mutant =
          Transition_storage.Batch.with_batch t.transition_storage
            ~f:(fun batch ->
              List.map removed_transitions ~f:(fun state_hash ->
                  let removed_transition, _ =
                    Transition_storage.get ~logger:t.logger
                      t.transition_storage (Transition state_hash)
                  in
                  Transition_storage.Batch.remove batch
                    ~key:(Transition state_hash) ;
                  External_transition.Validated.protocol_state
                    removed_transition
                  |> Protocol_state.consensus_state ) )
        in
        Transition_frontier.Diff.Mutant.hash acc_hash diff mutant
    | Update_root {root; scan_state; pending_coinbase} ->
        let new_root_data = (root, scan_state, pending_coinbase) in
        let old_root_data =
          Logger.trace t.logger !"Getting old root data" ~module_:__MODULE__
            ~location:__LOC__ ;
          let root, scan_state, pending_coinbase =
            Transition_storage.get t.transition_storage ~logger:t.logger
              ~location:__LOC__ Transition_storage.Schema.Root
          in
          { Transition_frontier.Diff.Mutant.Root.Poly.root
          ; scan_state
          ; pending_coinbase }
        in
        Logger.trace t.logger !"Setting old root data" ~module_:__MODULE__
          ~location:__LOC__ ;
        Transition_storage.set t.transition_storage ~key:Root
          ~data:new_root_data ;
        Logger.trace t.logger
          !"Finished setting old root data"
          ~module_:__MODULE__ ~location:__LOC__ ;
        Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:
            [ ( "mutant"
              , Transition_frontier.Diff.Mutant.value_to_yojson diff
                  old_root_data ) ]
          "Worker root update mutant" ;
        Transition_frontier.Diff.Mutant.hash acc_hash diff old_root_data

  module For_tests = struct
    let transition_storage {transition_storage; _} = transition_storage
  end
end

module Make_async (Inputs : Intf.Worker_inputs) = struct
  include Make (Inputs)

  let handle_diff t acc_hash diff_mutant =
    Deferred.Or_error.return (handle_diff t acc_hash diff_mutant)
end
