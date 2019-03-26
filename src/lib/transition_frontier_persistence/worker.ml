open Core
open Coda_base
open Async

module Make (Inputs : Intf.Worker_inputs) : sig
  open Inputs

  include
    Intf.Worker
    with type external_transition := External_transition.Stable.Latest.t
     and type scan_state := Staged_ledger.Scan_state.t
     and type state_hash := State_hash.t
     and type frontier := Transition_frontier.t
     and type root_snarked_ledger := Ledger.Db.t
     and type transition_storage := Transition_storage.t
     and type hash := Diff_hash.t
     and type 'a diff := 'a Diff_mutant.t
end = struct
  open Inputs

  type t =
    { transition_storage: Transition_storage.t
    ; root_snarked_ledger: Ledger.Db.t
    ; logger: Logger.t }

  let create ~logger ~root_snarked_ledger ~transition_storage =
    {transition_storage; root_snarked_ledger; logger}

  let consensus_state =
    Fn.compose
      (Binable.to_string (module Consensus.Consensus_state.Value.Stable.V1))
      External_transition.consensus_state

  let get (type a) t ?(location = __LOC__)
      (key : a Transition_storage.Schema.t) : a =
    match Transition_storage.get t.transition_storage ~key with
    | Some value -> value
    | None -> (
        let log_error = Logger.error t.logger ~module_:__MODULE__ ~location in
        match key with
        | Transition hash ->
            log_error
              ~metadata:[("hash", State_hash.to_yojson hash)]
              "Could not retrieve external transition: $hash" ;
            raise (Not_found_s ([%sexp_of: State_hash.t] hash))
        | Root ->
            log_error "Could not retrieve root" ;
            failwith "Could not retrieve root" )

  let apply_add_transition (t, batch)
      With_hash.({hash; data= external_transition}) =
    let open Transition_storage.Schema in
    let parent_hash = External_transition.parent_hash external_transition in
    let parent_transition, children_hashes =
      get t (Transition parent_hash) ~location:__LOC__
    in
    Transition_storage.Batch.set batch ~key:(Transition hash)
      ~data:(external_transition, []) ;
    Transition_storage.Batch.set batch ~key:(Transition parent_hash)
      ~data:(parent_transition, hash :: children_hashes) ;
    consensus_state parent_transition

  let atomic_move_root ({transition_storage; _} as t)
      (Diff_mutant.Move_root
        {best_tip; removed_transitions; new_root; new_scan_state}) =
    let open Transition_storage.Schema in
    Transition_storage.Batch.with_batch transition_storage ~f:(fun batch ->
        let old_root_data =
          Transition_storage.get_raw transition_storage ~key:Root
          |> Option.value_exn ~message:"Unable to retrieve old root"
          |> Bigstring.to_string
        in
        Transition_storage.Batch.set batch ~key:Root
          ~data:(new_root, new_scan_state) ;
        let parent = apply_add_transition (t, batch) best_tip in
        let removed_transitions =
          List.map removed_transitions ~f:(fun state_hash ->
              let removed_transition, _ = get t (Transition state_hash) in
              let consensus_state = consensus_state removed_transition in
              Transition_storage.Batch.remove batch
                ~key:(Transition state_hash) ;
              consensus_state )
        in
        {Diff_mutant.Move_root.parent; removed_transitions; old_root_data} )

  let apply_diff (type mutant) t (diff : mutant Diff_mutant.t) : mutant =
    match diff with
    | Move_root request -> atomic_move_root t (Diff_mutant.Move_root request)
    | Add_transition transition_with_hash ->
        Transition_storage.Batch.with_batch t.transition_storage
          ~f:(fun batch -> apply_add_transition (t, batch) transition_with_hash
        )

  let handle_diff (t : t) acc_hash diff_mutant =
    let mutant = apply_diff t diff_mutant in
    Diff_mutant.hash acc_hash diff_mutant mutant

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

  let deserialize ({transition_storage= _; root_snarked_ledger; logger} as t)
      ~consensus_local_state =
    let open Transition_storage.Schema in
    let state_hash, scan_state = get t Root in
    let get_verified_transition state_hash =
      let transition, root_successor_hashes = get t (Transition state_hash) in
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
      ({With_hash.data= verified_transition; hash= state_hash}, children_hashes)
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
    transition_frontier
end
