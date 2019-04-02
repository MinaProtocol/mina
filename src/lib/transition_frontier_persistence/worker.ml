open Core
open Coda_base
open Async

module Make (Inputs : Intf.Worker_inputs) : sig
  open Inputs

  include
    Intf.Worker
    with type hash := Diff_hash.t
     and type diff := State_hash.t Diff_mutant.E.t
end = struct
  open Inputs
  module Transition_storage = Make_transition_storage (Inputs)

  type t = {transition_storage: Transition_storage.t; logger: Logger.t}

  let create ?directory_name ~logger () =
    let directory =
      match directory_name with
      | None -> Uuid.to_string (Uuid.create ())
      | Some name -> name
    in
    let transition_storage = Transition_storage.create ~directory in
    {transition_storage; logger}

  let close {transition_storage; _} =
    Transition_storage.close transition_storage

  let apply_add_transition ({transition_storage; logger}, batch)
      With_hash.({hash; data= external_transition}) =
    let open Transition_storage.Schema in
    let parent_hash = External_transition.parent_hash external_transition in
    let parent_transition, children_hashes =
      Transition_storage.get transition_storage ~logger
        (Transition parent_hash) ~location:__LOC__
    in
    Transition_storage.Batch.set batch ~key:(Transition hash)
      ~data:(external_transition, []) ;
    Transition_storage.Batch.set batch ~key:(Transition parent_hash)
      ~data:(parent_transition, hash :: children_hashes) ;
    Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
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
                  let removed_transition, _ =
                    Transition_storage.get ~logger:t.logger
                      t.transition_storage (Transition state_hash)
                  in
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
end

module Make_async (Inputs : Intf.Worker_inputs) = struct
  include Make (Inputs)

  let handle_diff t acc_hash diff_mutant =
    Deferred.Or_error.return (handle_diff t acc_hash diff_mutant)
end
