open Core
open Coda_base
open Async

module Make (Inputs : Intf.Inputs) : sig
  open Inputs

  include
    Intf.S
    with type external_transition_verified := External_transition.Verified.t
     and type scan_state := Staged_ledger.Scan_state.t
     and type state_hash := State_hash.t
     and type frontier := Transition_frontier.t
     and type root_snarked_ledger := Ledger.Db.t
     and type transition_storage := Transition_storage.t
     and type hash := Digestif.sha256_ctx
end = struct
  open Inputs

  type root_storage =
    { path: String.t
    ; controller:
        (State_hash.t * Staged_ledger.Scan_state.t) Root_storage.Controller.t
    }

  type t =
    { transition_storage: Transition_storage.t
    ; root_snarked_ledger: Ledger.Db.t
    ; root_storage: root_storage
    ; logger: Logger.t }

  let create ~logger ~root_snarked_ledger ~transition_storage ~root_storage =
    {transition_storage; root_snarked_ledger; root_storage; logger}

  let set_transition {transition_storage; _}
      {With_hash.hash= state_hash; data= external_transition} =
    Transition_storage.set transition_storage ~key:state_hash
      ~data:(External_transition.of_verified external_transition)

  let set_root t state_hash scan_state =
    Root_storage.store t.root_storage.controller t.root_storage.path
      (state_hash, scan_state)

  let to_verified transition =
    (* We read a transition that was already verified before it was written to disk *)
    let (`I_swear_this_is_safe_see_my_comment verified_transition) =
      External_transition.to_verified transition
    in
    verified_transition

  let read_transition {transition_storage; _} state_hash =
    Option.map
      (Transition_storage.get transition_storage ~key:state_hash)
      ~f:to_verified

  let read_root {root_storage; _} =
    Deferred.Result.map_error
      (Root_storage.load root_storage.controller root_storage.path)
      ~f:(function
      | `Checksum_no_match -> Error.of_string "Checksum did not match"
      | `IO_error e -> Error.createf !"IO_error: %s" (Error.to_string_hum e)
      | `No_exist -> Error.createf !"File %s does not exist" root_storage.path )

  let lift_or_error deferred_x =
    let%map x = deferred_x in
    Or_error.return x

  module Batch = struct
    let set_transition batch
        {With_hash.hash= state_hash; data= external_transition} =
      Transition_storage.Batch.set batch ~key:state_hash
        ~data:(External_transition.of_verified external_transition)

    let remove_transition batch state_hash =
      Transition_storage.Batch.remove batch ~key:state_hash
  end

  let parent_hash transition =
    let open External_transition.Verified in
    let protocol_state = protocol_state transition in
    External_transition.Protocol_state.(previous_state_hash protocol_state)

  module Frontier_diff = struct
    type add_transition =
      (External_transition.Verified.t, State_hash.t) With_hash.t

    type move_root =
      { best_tip: (External_transition.Verified.t, State_hash.t) With_hash.t
      ; removed_transitions: State_hash.Stable.Latest.t list
      ; new_root: State_hash.Stable.Latest.t
      ; new_scan_state: Staged_ledger.Scan_state.Stable.Latest.t }

    type t = Add_transition of add_transition | Move_root of move_root
  end

  module Diff_mutant = struct
    type move_root =
      { parent: State_body_hash.t
      ; removed_transitions: State_body_hash.t list
      ; old_root: State_hash.Stable.Latest.t
      ; old_scan_state: Staged_ledger.Scan_state.Stable.Latest.t }

    type _ t =
      | Add_transition : Frontier_diff.add_transition -> State_body_hash.t t
      | Move_root : Frontier_diff.move_root -> move_root t

    let hash (type mutant) acc_hash (t : mutant t) (mutant : mutant) =
      let merge string acc = Digestif.SHA256.feed_string acc string in
      match (t, mutant) with
      | Add_transition _, parent_hash ->
          merge (State_body_hash.to_bytes parent_hash) acc_hash
      | Move_root _, {parent; removed_transitions; old_root; old_scan_state} ->
          let acc_hash = merge (State_body_hash.to_bytes parent) acc_hash in
          List.fold removed_transitions ~init:acc_hash
            ~f:(fun acc_hash removed_hash ->
              merge (State_body_hash.to_bytes removed_hash) acc_hash )
          |> merge (State_hash.to_bytes old_root)
          |> merge
               ( Staged_ledger.Scan_state.hash old_scan_state
               |> Staged_ledger_aux_hash.to_bytes )
  end

  let protocol_state_body_hash transition =
    let open External_transition in
    transition |> of_verified |> protocol_state |> Protocol_state.body
    |> Protocol_state.Body.hash

  let apply_add_transition t
      (With_hash.({hash; data= external_transition}) as transition_with_hash)
      ~write =
    let open Result.Let_syntax in
    let parent_hash = parent_hash external_transition in
    let%map parent_transition =
      Result.of_option
        (read_transition t parent_hash)
        ~error:
          (Error.createf
             !"Could not find parent (%{sexp:State_hash.t}) of transition \
               %{sexp:State_hash.t}"
             parent_hash hash)
    in
    write transition_with_hash ;
    protocol_state_body_hash parent_transition

  (* We would like the operation for moving a root to be atomic to avoid phantom
     write and having our persistent data to be left in a weird state. To do this, we
     first write our data new root data into a temp file. Then, we add the best
     tip and remove old transitions in batch manner in transition_storage.
     Afterwards, we requickly rename our file of the new root_data as the old
     file *)
  let atomic_move_root
      ( {transition_storage; root_snarked_ledger= _; root_storage; logger= _}
      as t )
      {Frontier_diff.best_tip; removed_transitions; new_root; new_scan_state} =
    let open Deferred.Or_error.Let_syntax in
    let temp_location = root_storage.path ^ ".temp" in
    let%bind old_root, old_scan_state = read_root t in
    let%bind () = lift_or_error @@ set_root t new_root new_scan_state in
    Deferred.return
      (let open Result.Let_syntax in
      let%map response =
        Transition_storage.Batch.with_batch transition_storage ~f:(fun batch ->
            let%map parent =
              apply_add_transition t best_tip
                ~write:(Batch.set_transition batch)
            in
            let removed_transitions =
              List.map removed_transitions ~f:(fun state_hash ->
                  let removed_transition =
                    read_transition t state_hash |> Option.value_exn
                  in
                  let body_hash =
                    protocol_state_body_hash removed_transition
                  in
                  Batch.remove_transition batch state_hash ;
                  body_hash )
            in
            {Diff_mutant.parent; removed_transitions; old_root; old_scan_state}
        )
      in
      (* HACK: We would like to have this synchronous and not context switch to
          another task by the async scheduler because we would like the original
          file of the root data to updated as quickly as possible. Renaming a
          file should be very fast so it's okay to wait for a bit *)
      Core.Sys.rename temp_location root_storage.path ;
      response)

  let apply_diff (type mutant) t (diff : mutant Diff_mutant.t) :
      mutant Deferred.Or_error.t =
    match diff with
    | Move_root request -> atomic_move_root t request
    | Add_transition
        (transition_with_hash :
          (External_transition.Verified.t, State_hash.t) With_hash.t) ->
        Deferred.return
        @@ apply_add_transition t transition_with_hash
             ~write:(set_transition t)

  let handle_diff (t : t) acc_hash (frontier_diff : Frontier_diff.t) =
    let open Deferred.Or_error.Let_syntax in
    let compute_hash diff_mutant =
      let%map mutant = apply_diff t diff_mutant in
      Diff_mutant.hash acc_hash diff_mutant mutant
    in
    match frontier_diff with
    | Add_transition transition ->
        compute_hash (Diff_mutant.Add_transition transition)
    | Move_root move_root -> compute_hash (Diff_mutant.Move_root move_root)

  let directly_add_breadcrumb ~logger transition_frontier transition_with_hash
      parent =
    let open Deferred.Or_error.Let_syntax in
    let%bind child_breadcrumb =
      Deferred.Result.map_error
        (Transition_frontier.Breadcrumb.build ~logger ~parent
           ~transition_with_hash) ~f:(function
        | `Fatal_error exn ->
            Error.createf !"Adding Breadcrumb Error: %s" (Exn.to_string exn)
        | `Validation_error error ->
            Error.createf "Validating Breadcrumb Error: %s"
              (Error.to_string_hum error) )
    in
    let%map () =
      Transition_frontier.add_breadcrumb_exn transition_frontier
        child_breadcrumb
      |> lift_or_error
    in
    child_breadcrumb

  let rec add_breadcrumb ~logger ~in_memory_transition_storage
      transition_frontier
      ({With_hash.hash= _; data= external_transition} as transition_with_hash)
      =
    let open Deferred.Or_error.Let_syntax in
    let parent_hash = parent_hash external_transition in
    match Transition_frontier.find transition_frontier parent_hash with
    | Some parent ->
        directly_add_breadcrumb ~logger transition_frontier
          transition_with_hash parent
    | None ->
        let%bind parent_external_transition =
          match Hashtbl.find in_memory_transition_storage parent_hash with
          | Some parent_external_transition ->
              Deferred.Or_error.return parent_external_transition
          | None ->
              Deferred.Or_error.errorf
                !"Parent transition %{sexp:State_hash.t} does not exist in \
                  the transition storage"
                parent_hash
        in
        let parent_external_transition_with_hash =
          {With_hash.hash= parent_hash; data= parent_external_transition}
        in
        let%bind parent =
          add_breadcrumb ~logger ~in_memory_transition_storage
            transition_frontier parent_external_transition_with_hash
        in
        directly_add_breadcrumb ~logger transition_frontier
          parent_external_transition_with_hash parent

  let staged_ledger_hash transition =
    let open External_transition.Verified in
    let protocol_state = protocol_state transition in
    Coda_base.Staged_ledger_hash.ledger_hash
      External_transition.Protocol_state.(
        Blockchain_state.staged_ledger_hash @@ blockchain_state protocol_state)

  let deserialize
      ({transition_storage; root_snarked_ledger; root_storage; logger} as t)
      ~consensus_local_state =
    let open Deferred.Or_error.Let_syntax in
    let%bind state_hash, scan_state =
      Deferred.Result.map_error
        (Root_storage.load root_storage.controller root_storage.path)
        ~f:(function
        | `Checksum_no_match -> Error.of_string "Checksum did not match"
        | `IO_error e -> Error.createf !"IO_error: %s" (Error.to_string_hum e)
        | `No_exist ->
            Error.createf !"File %s does not exist" root_storage.path )
    in
    let%bind root_transition =
      Deferred.return
        (let open Or_error.Let_syntax in
        let%map verified_transition =
          Result.of_option
            (read_transition t state_hash)
            ~error:
              (Error.createf
                 !"Could not find root transition %{sexp:State_hash.t}"
                 state_hash)
        in
        {With_hash.data= verified_transition; hash= state_hash})
    in
    let%bind root_staged_ledger =
      Staged_ledger.of_scan_state_and_snarked_ledger ~scan_state
        ~snarked_ledger:(Ledger.of_database root_snarked_ledger)
        ~expected_merkle_root:
          (staged_ledger_hash @@ With_hash.data root_transition)
    in
    let%bind transition_frontier =
      lift_or_error
      @@ Transition_frontier.create ~logger ~consensus_local_state
           ~root_transition ~root_snarked_ledger ~root_staged_ledger
    in
    let hashed_transitions =
      List.map (Transition_storage.to_alist transition_storage)
        ~f:(fun (hash, external_transition) ->
          {With_hash.hash; data= to_verified external_transition} )
    in
    let in_memory_transition_storage = State_hash.Table.create () in
    List.iter hashed_transitions ~f:(fun {With_hash.hash; data} ->
        State_hash.Table.add_exn in_memory_transition_storage ~key:hash ~data
    ) ;
    let%map () =
      Deferred.Or_error.List.iter hashed_transitions
        ~f:(fun ({With_hash.hash= state_hash; data= _} as transition_with_hash)
           ->
          match Transition_frontier.find transition_frontier state_hash with
          | Some _ -> Deferred.Or_error.return ()
          | None ->
              add_breadcrumb ~logger ~in_memory_transition_storage
                transition_frontier transition_with_hash
              |> Deferred.Or_error.ignore )
    in
    transition_frontier
end
