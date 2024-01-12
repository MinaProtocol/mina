open Async_kernel
open Core
open Mina_base
open Mina_state
open Mina_block
open Frontier_base
module Database = Database

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

exception Invalid_genesis_state_hash of Mina_block.Validated.t

let construct_staged_ledger_at_root ~(precomputed_values : Precomputed_values.t)
    ~root_ledger ~root_transition ~root ~protocol_states ~logger =
  let open Deferred.Or_error.Let_syntax in
  let open Root_data.Minimal in
  let blockchain_state =
    root_transition |> Mina_block.Validated.forget |> With_hash.data
    |> Mina_block.header |> Mina_block.Header.protocol_state
    |> Protocol_state.blockchain_state
  in
  let pending_coinbases = pending_coinbase root in
  let scan_state = scan_state root in
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
  let mask = Mina_ledger.Ledger.of_database root_ledger in
  let local_state = Blockchain_state.snarked_local_state blockchain_state in
  let staged_ledger_hash =
    Blockchain_state.staged_ledger_hash blockchain_state
  in
  let%bind staged_ledger =
    Staged_ledger.of_scan_state_pending_coinbases_and_snarked_ledger_unchecked
      ~snarked_local_state:local_state ~snarked_ledger:mask ~scan_state
      ~constraint_constants:precomputed_values.constraint_constants
      ~pending_coinbases
      ~expected_merkle_root:(Staged_ledger_hash.ledger_hash staged_ledger_hash)
      ~get_state
  in
  let is_genesis =
    Mina_block.Validated.header root_transition
    |> Header.protocol_state |> Protocol_state.consensus_state
    |> Consensus.Data.Consensus_state.is_genesis_state
  in
  let constructed_staged_ledger_hash = Staged_ledger.hash staged_ledger in
  if
    is_genesis
    || Staged_ledger_hash.equal staged_ledger_hash
         constructed_staged_ledger_hash
  then Deferred.return (Ok staged_ledger)
  else
    Deferred.return
      (Or_error.errorf
         !"Constructed staged ledger %{sexp: Staged_ledger_hash.t} did not \
           match the staged ledger hash in the protocol state %{sexp: \
           Staged_ledger_hash.t}"
         constructed_staged_ledger_hash staged_ledger_hash )

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
    t.sync <-
      Some
        (Sync.create ~constraint_constants ~logger:t.factory.logger
           ~time_controller:t.factory.time_controller ~db:t.db
           ~persistent_root_instance )

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

  let get_root_transition t =
    let open Result.Let_syntax in
    Database.get_root_hash t.db
    >>= Database.get_transition t.db
    |> Result.map_error ~f:Database.Error.message

  let fast_forward t target_root :
      (unit, [> `Failure of string | `Bootstrap_required ]) Result.t =
    let open Root_identifier.Stable.Latest in
    let open Result.Let_syntax in
    let%bind () = assert_no_sync t in
    let lift_error r msg = Result.map_error r ~f:(Fn.const (`Failure msg)) in
    let%bind root =
      lift_error (Database.get_root t.db) "failed to get root hash"
    in
    let root_hash = Root_data.Minimal.hash root in
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

  let load_full_frontier t ~context:(module Context : CONTEXT) ~root_ledger
      ~consensus_local_state ~max_length ~ignore_consensus_local_state
      ~persistent_root_instance =
    let open Context in
    let validate genesis_state_hash (b, v) =
      let f h = Validation.with_body h (Mina_block.body @@ With_hash.data b) in
      Validation.validate_genesis_protocol_state ~genesis_state_hash
        (With_hash.map ~f:Mina_block.header b, v)
      |> Result.map ~f
    in
    let downgrade_transition transition genesis_state_hash :
        ( Mina_block.almost_valid_block
        , [> `Invalid_genesis_protocol_state ] )
        Result.t =
      (* we explicitly re-validate the genesis protocol state here to prevent X-version bugs *)
      transition |> Mina_block.Validated.remember
      |> Validation.reset_staged_ledger_diff_validation
      |> Validation.reset_genesis_protocol_state_validation
      |> validate genesis_state_hash
    in
    let%bind.Deferred.Result () = Deferred.return (assert_no_sync t) in
    let not_found_failure err =
      `Failure (Database.Error.not_found_message err)
    in
    (* read basic information from the database *)
    let%bind.Deferred.Result ( root
                             , root_transition
                             , best_tip
                             , protocol_states
                             , root_hash ) =
      (let open Result.Let_syntax in
      let%bind root = Database.get_root t.db in
      let root_hash = Root_data.Minimal.hash root in
      let%bind root_transition = Database.get_transition t.db root_hash in
      let%bind best_tip = Database.get_best_tip t.db in
      let%map protocol_states =
        Database.get_protocol_states_for_root_scan_state t.db
      in
      (root, root_transition, best_tip, protocol_states, root_hash))
      |> Result.map_error ~f:not_found_failure
      |> Deferred.return
    in
    let root_genesis_state_hash =
      root_transition |> Mina_block.Validated.forget |> With_hash.data
      |> Mina_block.header |> Mina_block.Header.protocol_state
      |> Protocol_state.genesis_state_hash
    in
    let failure_of_error err = `Failure (Error.to_string_hum err) in
    (* construct the root staged ledger in memory *)
    let%bind.Deferred.Result root_staged_ledger =
      construct_staged_ledger_at_root ~precomputed_values ~root_ledger
        ~root_transition ~root ~protocol_states ~logger:t.factory.logger
      >>| Result.map_error ~f:failure_of_error
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
        ~root_ledger:
          (Mina_ledger.Ledger.Any_ledger.cast
             (module Mina_ledger.Ledger.Db)
             root_ledger )
        ~consensus_local_state ~max_length ~persistent_root_instance
    in
    let%bind.Deferred.Result extensions =
      Extensions.create ~logger:t.factory.logger frontier >>| Result.return
    in
    let apply_diff diff =
      [%log internal] "Apply_full_frontier_diffs" ;
      let (`New_root_and_diffs_with_mutants (_, diffs_with_mutants)) =
        Full_frontier.apply_diffs frontier [ diff ]
          ~has_long_catchup_job:(lazy false)
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
    in
    let map_crawl_error = function
      | `Crawl_error `Invalid_genesis_protocol_state ->
          `Failure "invalid genesis protocol state"
      | `Crawl_error (`Invalid_body_reference as err)
      | `Crawl_error (`Invalid_staged_ledger_diff _ as err)
      | `Crawl_error (`Staged_ledger_application_failed _ as err) ->
          let msg =
            match Breadcrumb.simplify_breadcrumb_building_error err with
            | `Verifier_error e ->
                "verifier error: " ^ Error.to_string_hum e
            | `Invalid (e, _) ->
                "invalid: " ^ Error.to_string_hum e
          in
          `Failure
            ("error rebuilding transition frontier from persistence: " ^ msg)
      | `Not_found _ as err ->
          not_found_failure err
    in
    let crawl_do parent transition =
      let%bind.Deferred.Result transition =
        Deferred.return
          (downgrade_transition transition root_genesis_state_hash)
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
      let%bind.Deferred.Result breadcrumb =
        Breadcrumb.build_no_reporting ~skip_staged_ledger_verification:`All
          ~logger:t.factory.logger ~precomputed_values
          ~verifier:t.factory.verifier ~parent ~transition
          ~get_completed_work:(Fn.const None) ~transition_receipt_time:None ()
      in
      let%map.Deferred.Result () =
        apply_diff Diff.(E (New_node (Full breadcrumb)))
      in
      [%log internal] "Breadcrumb_integrated" ;
      breadcrumb
    in
    (* crawl through persistent frontier and load transitions into in memory frontier *)
    let%bind.Deferred.Result res =
      Database.crawl_successors t.db root_hash ~f:crawl_do
        ~init:(Full_frontier.root frontier)
      >>| Result.map_error ~f:map_crawl_error
    in
    let%map.Deferred.Result () =
      apply_diff Diff.(E (Best_tip_changed best_tip))
    in
    (frontier, extensions)
end

type t = Factory_type.t

let create ~logger ~verifier ~time_controller ~directory =
  { logger; verifier; time_controller; directory; instance = None }

let destroy_database_exn t =
  assert (Option.is_none t.instance) ;
  File_system.remove_dir t.directory

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
      Debug_assert.debug_assert (fun () ->
          ignore
            ( Database.check instance.db ~genesis_state_hash
              |> Result.map_error ~f:(function
                   | `Invalid_version ->
                       "invalid version"
                   | `Not_initialized ->
                       "not initialized"
                   | `Genesis_state_mismatch _ ->
                       "genesis state mismatch"
                   | `Corrupt err ->
                       Database.Error.message err )
              |> Result.ok_or_failwith
              : Frozen_ledger_hash.t ) ) )
