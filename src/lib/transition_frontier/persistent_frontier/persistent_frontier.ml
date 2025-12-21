open Async_kernel
open Core
open Mina_base
open Mina_state
open Mina_block
open Frontier_base
module Database = Database
module Root_ledger = Mina_ledger.Root

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val proof_cache_db : Proof_cache_tag.cache_db

  val signature_kind : Mina_signature_kind.t
end

exception Invalid_genesis_state_hash of Mina_block.Validated.t

let construct_staged_ledger_at_root ~proof_cache_db
    ~(precomputed_values : Precomputed_values.t) ~root_ledger ~root_transition
    ~(root : Root_data.Minimal.Serializable_type.t) ~protocol_states ~logger
    ~signature_kind =
  let blockchain_state =
    root_transition |> Mina_block.Validated.forget |> With_hash.data
    |> Mina_block.header |> Mina_block.Header.protocol_state
    |> Protocol_state.blockchain_state
  in
  let pending_coinbases, scan_state_unwrapped =
    Root_data.Minimal.Serializable_type.Stable.Latest.
      (pending_coinbase root, scan_state root)
  in
  let protocol_states_map =
    List.fold protocol_states ~init:State_hash.Map.empty
      ~f:(fun acc protocol_state ->
        Map.add_exn acc ~key:(Protocol_state.hashes protocol_state).state_hash
          ~data:protocol_state )
  in
  let get_state hash =
    match Map.find protocol_states_map hash with
    | None ->
        [%log error]
          ~metadata:[ ("state_hash", State_hash.to_yojson hash) ]
          "Protocol state (for scan state transactions) for $state_hash not \
           found when loading persisted transition frontier" ;
        Or_error.errorf
          !"Protocol state (for scan state transactions) for \
            %{sexp:State_hash.t} not found when loading persisted transition \
            frontier"
          hash
    | Some protocol_state ->
        Ok protocol_state
  in
  let mask = Root_ledger.as_masked root_ledger in
  let local_state = Blockchain_state.snarked_local_state blockchain_state in
  let staged_ledger_hash =
    Blockchain_state.staged_ledger_hash blockchain_state
  in
  let scan_state =
    Staged_ledger.Scan_state.write_all_proofs_to_disk ~signature_kind
      ~proof_cache_db
    @@ Staged_ledger.Scan_state.Serializable_type.to_raw_serializable
         scan_state_unwrapped
  in
  Staged_ledger.of_scan_state_pending_coinbases_and_snarked_ledger_unchecked
    ~snarked_local_state:local_state ~snarked_ledger:mask ~scan_state
    ~constraint_constants:precomputed_values.constraint_constants ~logger
    ~pending_coinbases
    ~expected_merkle_root:(Staged_ledger_hash.ledger_hash staged_ledger_hash)
    ~get_state ~signature_kind

module rec Instance_type : sig
  type t =
    { db : Database.t; mutable sync : Sync.t option; factory : Factory_type.t }
end =
  Instance_type

and Factory_type : sig
  type t =
    { logger : Logger.t
    ; directory : string
    ; verifier : Verifier.t
    ; time_controller : Block_time.Controller.t
    ; signature_kind : Mina_signature_kind.t
    ; mutable instance : Instance_type.t option
    }
end =
  Factory_type

open Instance_type
open Factory_type

module Instance = struct
  type t = Instance_type.t

  let create factory =
    let db =
      Database.create ~logger:factory.logger ~directory:factory.directory
    in
    { db; sync = None; factory }

  let assert_no_sync t =
    if Option.is_some t.sync then Error `Sync_cannot_be_running else Ok ()

  let assert_sync t ~f =
    match t.sync with
    | None ->
        return (Error `Sync_must_be_running)
    | Some sync ->
        f sync

  let start_sync ~constraint_constants t ~persistent_root_instance =
    let open Result.Let_syntax in
    let%map () = assert_no_sync t in
    let dequeue_snarked_ledger () =
      Persistent_root.Instance.dequeue_snarked_ledger persistent_root_instance
    in
    t.sync <-
      Some
        (Sync.create ~constraint_constants ~logger:t.factory.logger
           ~time_controller:t.factory.time_controller ~db:t.db
           ~dequeue_snarked_ledger )

  let stop_sync t =
    let open Deferred.Let_syntax in
    assert_sync t ~f:(fun sync ->
        let%map () = Sync.close sync in
        t.sync <- None ;
        Ok () )

  let notify_sync t ~diffs =
    assert_sync t ~f:(fun sync ->
        Sync.notify sync ~diffs ; Deferred.Result.return () )

  let destroy t =
    let open Deferred.Let_syntax in
    [%log' trace t.factory.logger]
      "Destroying transition frontier persistence instance" ;
    let%map () =
      if Option.is_some t.sync then
        stop_sync t
        >>| Fn.compose Result.ok_or_failwith
              (Result.map_error ~f:(Fn.const "impossible"))
      else return ()
    in
    Database.close t.db ;
    t.factory.instance <- None

  let factory { factory; _ } = factory

  let check_database t = Database.check t.db

  let get_root_transition ~signature_kind ~proof_cache_db t =
    let open Result.Let_syntax in
    Database.get_root_hash t.db
    >>= Database.get_transition t.db ~signature_kind ~proof_cache_db
    |> Result.map_error ~f:Database.Error.message

  let fast_forward t target_root :
      (unit, [> `Failure of string | `Bootstrap_required ]) Result.t =
    let open Root_identifier.Stable.Latest in
    let open Result.Let_syntax in
    let%bind () = assert_no_sync t in
    let lift_error r msg = Result.map_error r ~f:(Fn.const (`Failure msg)) in
    let%bind root_hash =
      lift_error (Database.get_root_hash t.db) "failed to get root hash"
    in
    if State_hash.equal root_hash target_root.state_hash then
      (* If the target hash is already the root hash, no fast forward required, but we should check the frontier hash. *)
      Ok ()
    else (
      [%log' warn t.factory.logger]
        ~metadata:
          [ ("current_root", State_hash.to_yojson root_hash)
          ; ("target_root", State_hash.to_yojson target_root.state_hash)
          ]
        "Cannot fast forward persistent frontier's root: bootstrap is required \
         ($current_root --> $target_root)" ;
      Error `Bootstrap_required )

  let validate genesis_state_hash (b, v) =
    Validation.validate_genesis_protocol_state ~genesis_state_hash
      (With_hash.map ~f:Mina_block.header b, v)
    |> Result.map
         ~f:(Fn.flip Validation.with_body (Mina_block.body @@ With_hash.data b))

  let downgrade_transition transition genesis_state_hash :
      ( Mina_block.almost_valid_block
      , [ `Invalid_genesis_protocol_state ] )
      Result.t =
    (* we explicitly re-validate the genesis protocol state here to prevent X-version bugs *)
    transition |> Mina_block.Validated.remember
    |> Validation.reset_staged_ledger_diff_validation
    |> Validation.reset_genesis_protocol_state_validation
    |> validate genesis_state_hash

  let apply_diff ~logger ~frontier ~extensions ~ignore_consensus_local_state
      ~root_ledger diff =
    [%log internal] "Apply_full_frontier_diffs" ;
    let (`New_root_and_diffs_with_mutants (_, diffs_with_mutants)) =
      Full_frontier.apply_diffs frontier [ diff ] ~has_long_catchup_job:false
        ~enable_epoch_ledger_sync:
          ( if ignore_consensus_local_state then `Disabled
          else `Enabled root_ledger )
    in
    [%log internal] "Apply_full_frontier_diffs_done" ;
    [%log internal] "Notify_frontier_extensions" ;
    let%map.Deferred result =
      Extensions.notify extensions ~logger ~frontier ~diffs_with_mutants
    in
    [%log internal] "Notify_frontier_extensions_done" ;
    Result.return result

  let load_transition ~root_genesis_state_hash ~logger ~precomputed_values t
      ~parent transition =
    let%bind.Deferred.Result transition =
      match downgrade_transition transition root_genesis_state_hash with
      | Ok t ->
          Deferred.Result.return t
      | Error `Invalid_genesis_protocol_state ->
          Error (`Fatal_error (Invalid_genesis_state_hash transition))
          |> Deferred.return
    in
    let state_hash =
      (With_hash.hash @@ Mina_block.Validation.block_with_hash transition)
        .state_hash
    in
    Internal_tracing.with_state_hash state_hash
    @@ fun () ->
    [%log internal] "@block_metadata"
      ~metadata:
        [ ( "blockchain_length"
          , Mina_numbers.Length.to_yojson
            @@ Mina_block.(blockchain_length (Validation.block transition)) )
        ] ;
    [%log internal] "Loaded_transition_from_storage" ;
    (* we're loading transitions from persistent storage,
       don't assign a timestamp
    *)
    let transition_receipt_time = None in
    Breadcrumb.build ~skip_staged_ledger_verification:`All
      ~logger:t.factory.logger ~precomputed_values ~verifier:t.factory.verifier
      ~trust_system:(Trust_system.null ()) ~parent ~transition
      ~get_completed_work:(Fn.const None) ~sender:None ~transition_receipt_time
      ()

  let set_best_tip ~logger ~frontier ~extensions ~ignore_consensus_local_state
      ~root_ledger best_tip_hash =
    apply_diff ~logger ~frontier ~extensions ~ignore_consensus_local_state
      ~root_ledger (E (Best_tip_changed best_tip_hash))

  let load_full_frontier t ~context:(module Context : CONTEXT) ~root_ledger
      ~consensus_local_state ~max_length ~ignore_consensus_local_state
      ~persistent_root_instance ?max_frontier_depth () =
    let open Context in
    let open Deferred.Result.Let_syntax in
    let%bind () = Deferred.return (assert_no_sync t) in
    (* read basic information from the database *)
    let%bind root, root_transition, best_tip, protocol_states, root_hash =
      (let open Result.Let_syntax in
      let%bind root = Database.get_root t.db in
      let root_hash =
        Root_data.Minimal.Serializable_type.Stable.Latest.hash root
      in
      let%bind root_transition =
        Database.get_transition t.db ~signature_kind ~proof_cache_db root_hash
      in
      let%bind best_tip = Database.get_best_tip t.db in
      let%map protocol_states =
        Database.get_protocol_states_for_root_scan_state t.db
      in
      (root, root_transition, best_tip, protocol_states, root_hash))
      |> Result.map_error ~f:(fun err ->
             `Failure (Database.Error.not_found_message err) )
      |> Deferred.return
    in
    let root_genesis_state_hash =
      root_transition |> Mina_block.Validated.forget |> With_hash.data
      |> Mina_block.header |> Mina_block.Header.protocol_state
      |> Protocol_state.genesis_state_hash
    in
    (* construct the root staged ledger in memory *)
    let%bind root_staged_ledger =
      let open Deferred.Let_syntax in
      match%map
        construct_staged_ledger_at_root ~proof_cache_db ~precomputed_values
          ~root_ledger ~root_transition ~root ~protocol_states
          ~signature_kind:t.factory.signature_kind ~logger:t.factory.logger
      with
      | Error err ->
          Error (`Failure (Error.to_string_hum err))
      | Ok staged_ledger ->
          Ok staged_ledger
    in
    (* initialize the new in memory frontier and extensions *)
    let frontier =
      Full_frontier.create
        ~context:(module Context)
        ~time_controller:t.factory.time_controller
        ~root_data:
          { transition = root_transition
          ; staged_ledger = root_staged_ledger
          ; protocol_states =
              List.map protocol_states
                ~f:(With_hash.of_data ~hash_data:Protocol_state.hashes)
          }
        ~root_ledger:(Root_ledger.as_unmasked root_ledger)
        ~consensus_local_state ~max_length ~persistent_root_instance
    in
    let%bind extensions =
      Deferred.map
        (Extensions.create ~logger:t.factory.logger frontier)
        ~f:Result.return
    in
    let visit parent transition =
      let%bind breadcrumb =
        load_transition ~root_genesis_state_hash ~logger ~precomputed_values t
          ~parent transition
      in
      let%map () =
        apply_diff ~logger ~frontier ~extensions ~ignore_consensus_local_state
          ~root_ledger (E (New_node (Full breadcrumb)))
      in
      [%log internal] "Breadcrumb_integrated" ;
      breadcrumb
    in
    (* crawl through persistent frontier and load transitions into in memory frontier *)
    let%map () =
      Deferred.map
        (Database.crawl_successors ~signature_kind ~proof_cache_db t.db
           ?max_depth:max_frontier_depth root_hash
           ~init:(Full_frontier.root frontier)
           ~f:visit )
        ~f:
          (Result.map_error ~f:(function
            | `Crawl_error err ->
                let msg =
                  match err with
                  | `Fatal_error exn ->
                      "fatal error -- " ^ Exn.to_string exn
                  | `Invalid_staged_ledger_diff err
                  | `Invalid_staged_ledger_hash err ->
                      "staged ledger diff application failed -- "
                      ^ Error.to_string_hum err
                in
                `Failure
                  ( "error rebuilding transition frontier from persistence: "
                  ^ msg )
            | `Not_found _ as err ->
                `Failure (Database.Error.not_found_message err) ) )
    in
    (root_ledger, best_tip, frontier, extensions)
end

type t = Factory_type.t

let create ~logger ~verifier ~time_controller ~directory ~signature_kind =
  { logger
  ; verifier
  ; time_controller
  ; directory
  ; signature_kind
  ; instance = None
  }

let destroy_database_exn t =
  assert (Option.is_none t.instance) ;
  Mina_stdlib_unix.File_system.remove_dir t.directory

let create_instance_exn t =
  assert (Option.is_none t.instance) ;
  let instance = Instance.create t in
  t.instance <- Some instance ;
  instance

let with_instance_exn t ~f =
  let instance = create_instance_exn t in
  let x = f instance in
  let%map () = Instance.destroy instance in
  x

let reset_database_exn t ~root_data ~genesis_state_hash =
  let open Root_data.Limited in
  let open Deferred.Let_syntax in
  let root_transition = transition root_data in
  [%log' info t.logger]
    ~metadata:
      [ ( "state_hash"
        , State_hash.to_yojson
          @@ Mina_block.Validated.state_hash root_transition )
      ]
    "Resetting transition frontier database to new root" ;
  let%bind () = destroy_database_exn t in
  with_instance_exn t ~f:(fun instance ->
      Database.initialize instance.db ~root_data ;
      (* sanity check database after initialization on debug builds *)
      assert (
        match Database.check instance.db ~genesis_state_hash with
        | Ok _ ->
            true
        | Error reason ->
            let string_of_reason = function
              | `Invalid_version ->
                  "invalid version"
              | `Not_initialized ->
                  "not initialized"
              | `Genesis_state_mismatch _ ->
                  "genesis state mismatch"
              | `Corrupt err ->
                  Database.Error.message err
            in
            failwith (string_of_reason reason) ) )
