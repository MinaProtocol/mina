open Core
open Coda_base
open Async

module Make (Inputs : Intf.Worker_inputs) : sig
  open Inputs

  include
    Intf.Worker
    with type external_transition := External_transition.Stable.Latest.t
     and type scan_state := Staged_ledger.Scan_state.t
     and type consensus_local_state := Consensus.Local_state.t
     and type state_hash := State_hash.t
     and type frontier := Transition_frontier.t
     and type root_snarked_ledger := Ledger.Db.t
     and type breadcrumb := Transition_frontier.Breadcrumb.t
     and type hash := Diff_hash.t
     and type diff := State_hash.t Diff_mutant.E.t
end = struct
  open Inputs

  module Transition_storage = struct
    module Schema = Transition_database_schema.Make (Inputs)
    include Rocksdb.Serializable.GADT.Make (Schema)
  end

  type t = {transition_storage: Transition_storage.t; logger: Logger.t}

  let create ?directory_name ~logger () =
    let directory =
      match directory_name with
      | None -> Uuid.to_string (Uuid.create ())
      | Some name -> name
    in
    let transition_storage = Transition_storage.create ~directory in
    {transition_storage; logger}

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
              "Could not retrieve external transition: $hash !" ;
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
    Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
      ~metadata:
        [ ("hash", State_hash.to_yojson hash)
        ; ("parent_hash", State_hash.to_yojson parent_hash) ]
      "Added transition $hash and $parent_hash !" ;
    External_transition.consensus_state parent_transition

  let handle_diff (t : t) acc_hash (E diff : State_hash.t Diff_mutant.E.t) =
    let log ~location diff mutant =
      Debug_assert.debug_assert
      @@ fun () ->
      Logger.trace ~module_:__MODULE__ ~location t.logger
        ~metadata:[("diff_response", Diff_mutant.yojson_of_value diff mutant)]
        "Worker processed diff_mutant and created mutant: $diff_response"
    in
    match diff with
    | New_frontier
        ({With_hash.hash= first_root_hash; data= first_root}, scan_state) ->
        Transition_storage.Batch.with_batch t.transition_storage
          ~f:(fun batch ->
            Transition_storage.Batch.set batch ~key:Root
              ~data:(first_root_hash, scan_state) ;
            Transition_storage.Batch.set batch
              ~key:(Transition first_root_hash) ~data:(first_root, []) ;
            log ~location:__LOC__ diff () ;
            Diff_mutant.hash ~f:State_hash.to_bytes acc_hash diff () )
    | Add_transition transition_with_hash ->
        Transition_storage.Batch.with_batch t.transition_storage
          ~f:(fun batch ->
            let mutant =
              apply_add_transition (t, batch) transition_with_hash
            in
            log ~location:__LOC__ diff mutant ;
            Diff_mutant.hash ~f:State_hash.to_bytes acc_hash diff mutant )
    | Remove_transitions removed_transitions ->
        let mutant =
          Transition_storage.Batch.with_batch t.transition_storage
            ~f:(fun batch ->
              List.map removed_transitions ~f:(fun state_hash ->
                  let removed_transition, _ = get t (Transition state_hash) in
                  Transition_storage.Batch.remove batch
                    ~key:(Transition state_hash) ;
                  External_transition.consensus_state removed_transition ) )
        in
        log ~location:__LOC__ diff mutant ;
        Diff_mutant.hash ~f:State_hash.to_bytes acc_hash diff mutant
    | Update_root new_root_data ->
        (* We can get the serialized root_data from the database and then hash it, rather than using `Transition_storage.get` to deserialize the data and then hash it again which is slower *)
        let old_root_data =
          Transition_storage.get_raw t.transition_storage
            ~key:Transition_storage.Schema.Root
          |> Option.value_exn
        in
        let bin =
          [%bin_type_class:
            State_hash.Stable.Latest.t
            * Staged_ledger.Scan_state.Stable.Latest.t]
        in
        let serialized_new_root_data =
          Bin_prot.Utils.bin_dump bin.writer new_root_data
        in
        Transition_storage.set_raw t.transition_storage ~key:Root
          ~data:serialized_new_root_data ;
        Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
          "Worker updated root" ;
        let diff_contents_hash =
          Diff_hash.merge acc_hash
            (serialized_new_root_data |> Bigstring.to_string)
        in
        Diff_hash.merge diff_contents_hash
          (old_root_data |> Bigstring.to_string)

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

  let with_worker ~directory_name ~logger ~f =
    let transition_storage =
      Transition_storage.create ~directory:directory_name
    in
    let worker = {transition_storage; logger} in
    let result = f worker in
    Transition_storage.close transition_storage ;
    result

  let deserialize ({transition_storage= _; logger} as t) ~root_snarked_ledger
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

  module For_tests = struct
    module Transition_storage = Transition_storage

    let transition_storage {transition_storage; _} = transition_storage
  end
end
