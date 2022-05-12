open Async_kernel
open Core
open Mina_base
open Mina_state
open Mina_block
open Frontier_base
module Database = Database

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
  let local_state =
    Blockchain_state.registers blockchain_state |> Registers.local_state
  in
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

  let load_full_frontier t ~root_ledger ~consensus_local_state ~max_length
      ~ignore_consensus_local_state ~precomputed_values
      ~persistent_root_instance =
    let open Deferred.Result.Let_syntax in
    let downgrade_transition transition genesis_state_hash :
        ( Mina_block.almost_valid_block
        , [ `Invalid_genesis_protocol_state ] )
        Result.t =
      (* we explicitly re-validate the genesis protocol state here to prevent X-version bugs *)
      transition |> Mina_block.Validated.remember
      |> Validation.reset_staged_ledger_diff_validation
      |> Validation.reset_genesis_protocol_state_validation
      |> Validation.validate_genesis_protocol_state ~genesis_state_hash
    in
    let%bind () = Deferred.return (assert_no_sync t) in
    (* read basic information from the database *)
    let%bind root, root_transition, best_tip, protocol_states, root_hash =
      (let open Result.Let_syntax in
      let%bind root = Database.get_root t.db in
      let root_hash = Root_data.Minimal.hash root in
      let%bind root_transition = Database.get_transition t.db root_hash in
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
        construct_staged_ledger_at_root ~precomputed_values ~root_ledger
          ~root_transition ~root ~protocol_states ~logger:t.factory.logger
      with
      | Error err ->
          Error (`Failure (Error.to_string_hum err))
      | Ok staged_ledger ->
          Ok staged_ledger
    in
    (* initialize the new in memory frontier and extensions *)
    let frontier =
      Full_frontier.create ~logger:t.factory.logger
        ~time_controller:t.factory.time_controller
        ~root_data:
          { transition = External_transition.Validated.lift root_transition
          ; staged_ledger = root_staged_ledger
          ; protocol_states =
              List.map protocol_states
                ~f:(With_hash.of_data ~hash_data:Protocol_state.hashes)
          }
        ~root_ledger:
          (Mina_ledger.Ledger.Any_ledger.cast
             (module Mina_ledger.Ledger.Db)
             root_ledger )
        ~consensus_local_state ~max_length ~precomputed_values
        ~persistent_root_instance
    in
    let%bind extensions =
      Deferred.map
        (Extensions.create ~logger:t.factory.logger frontier)
        ~f:Result.return
    in
    let apply_diff diff =
      let (`New_root_and_diffs_with_mutants (_, diffs_with_mutants)) =
        Full_frontier.apply_diffs frontier [ diff ] ~has_long_catchup_job:false
          ~enable_epoch_ledger_sync:
            ( if ignore_consensus_local_state then `Disabled
            else `Enabled root_ledger )
      in
      Extensions.notify extensions ~frontier ~diffs_with_mutants
      |> Deferred.map ~f:Result.return
    in
    (* crawl through persistent frontier and load transitions into in memory frontier *)
    let%bind () =
      Deferred.map
        (Database.crawl_successors t.db root_hash
           ~init:(Full_frontier.root frontier) ~f:(fun parent transition ->
             let%bind transition =
               match
                 downgrade_transition transition root_genesis_state_hash
               with
               | Ok t ->
                   Deferred.Result.return t
               | Error `Invalid_genesis_protocol_state ->
                   Error (`Fatal_error (Invalid_genesis_state_hash transition))
                   |> Deferred.return
             in
             (* we're loading transitions from persistent storage,
                don't assign a timestamp
             *)
             let transition_receipt_time = None in
             let%bind breadcrumb =
               Breadcrumb.build ~skip_staged_ledger_verification:`All
                 ~logger:t.factory.logger ~precomputed_values
                 ~verifier:t.factory.verifier
                 ~trust_system:(Trust_system.null ()) ~parent ~transition
                 ~sender:None ~transition_receipt_time ()
             in
             let%map () = apply_diff Diff.(E (New_node (Full breadcrumb))) in
             breadcrumb ) )
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
    let%map () = apply_diff Diff.(E (Best_tip_changed best_tip)) in
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
          @@ Mina_block.Validated.state_hash
               (External_transition.Validated.lower root_transition) )
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
