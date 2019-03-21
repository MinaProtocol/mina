open Core
open Coda_base
open Async
open Protocols

module type S = sig
  type external_transition_verified

  type staged_ledger

  type scan_state

  type state_hash

  type frontier

  type root_snarked_ledger

  type transition_storage

  type root_storage

  type frontier_diff

  (* TODO: Diff_mutant will be a GADT that represents how it adds an
     external_transition into it's frontier and how transitions are added and
     removed when the root moves *)
  type diff_mutant

  type t

  val set_transition : t -> state_hash -> external_transition_verified -> unit

  val set_root : t -> state_hash -> scan_state -> unit Deferred.t

  val remove_transitions : t -> state_hash list -> unit

  val create :
       logger:Logger.t
    -> root_snarked_ledger:root_snarked_ledger
    -> transition_storage:transition_storage
    -> root_storage:root_storage
    -> t

  val deserialize :
       t
    -> consensus_local_state:Consensus.Local_state.t
    -> frontier Deferred.Or_error.t

  (* TODO: This will do all the writes *)
  val handle_diff : t -> frontier_diff -> diff_mutant
end

module Make (Inputs : Inputs.S) : sig
  open Inputs

  include
    S
    with type external_transition_verified := External_transition.Verified.t
     and type staged_ledger := Staged_ledger.t
     and type scan_state := Staged_ledger.Scan_state.t
     and type state_hash := State_hash.t
     and type frontier := Transition_frontier.t
     and type frontier_diff :=
                External_transition.Verified.t
                Coda_transition_frontier.Transition_frontier_diff.t
     and type root_snarked_ledger := Ledger.Db.t
     and type transition_storage := Transition_storage.t
    (* TODO: Change type when Diff_mutant gets added *)
     and type diff_mutant := unit
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

  let set_transition {transition_storage; _} state_hash external_transition =
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

  let remove_transitions {transition_storage; _} state_hashes =
    Transition_storage.set_batch transition_storage ~remove_keys:state_hashes
      ~update_pairs:[]

  let lift_or_error deferred_x =
    let%map x = deferred_x in
    Or_error.return x

  let parent_hash transition =
    let open External_transition.Verified in
    let protocol_state = protocol_state transition in
    External_transition.Protocol_state.(previous_state_hash protocol_state)

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

  let handle_diff = failwith "handle_diff: Need to Implement"
end
