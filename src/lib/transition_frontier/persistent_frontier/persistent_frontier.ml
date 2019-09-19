open Async_kernel
open Core
open Coda_base
open Coda_state
open Coda_transition
open Frontier_base
module Database = Database

let construct_staged_ledger_at_root ~logger ~verifier ~root_ledger
    ~root_transition ~root =
  let open Root_data.Minimal.Stable.Latest in
  let snarked_ledger_hash =
    External_transition.Validated.blockchain_state root_transition
    |> Blockchain_state.snarked_ledger_hash
  in
  (* [new] TODO: !important -- make mask off root ledger and apply all scan state transactions to it *)
  Staged_ledger.of_scan_state_and_ledger ~logger ~verifier ~snarked_ledger_hash
    ~ledger:(Ledger.of_database root_ledger)
    ~scan_state:root.scan_state
    ~pending_coinbase_collection:root.pending_coinbase

(* [new] TODO: create a reusable singleton factory abstraction *)
module rec Instance_type : sig
  type t =
    {db: Database.t; mutable sync: Sync.t option; factory: Factory_type.t}
end =
  Instance_type

and Factory_type : sig
  type t =
    { logger: Logger.t
    ; directory: string
    ; verifier: Verifier.t
    ; mutable instance: Instance_type.t option }
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
    {db; sync= None; factory}

  let assert_no_sync t =
    if Option.is_some t.sync then Error `Sync_cannot_be_running else Ok ()

  let assert_sync t ~f =
    match t.sync with
    | None ->
        return (Error `Sync_must_be_running)
    | Some sync ->
        f sync

  let start_sync t =
    let open Result.Let_syntax in
    let%bind () = assert_no_sync t in
    let%map base_hash = Database.get_frontier_hash t.db in
    t.sync <- Some (Sync.create ~logger:t.factory.logger ~base_hash ~db:t.db)

  let stop_sync t =
    let open Deferred.Let_syntax in
    assert_sync t ~f:(fun sync ->
        let%map () = Sync.close sync in
        t.sync <- None ;
        Ok () )

  let notify_sync t ~diffs ~hash_transition =
    assert_sync t ~f:(fun sync ->
        Sync.notify sync ~diffs ~hash_transition ;
        Deferred.Result.return () )

  let destroy t =
    let open Deferred.Let_syntax in
    let%map () =
      if Option.is_some t.sync then
        stop_sync t
        >>| Fn.compose Result.ok_or_failwith
              (Result.map_error ~f:(Fn.const "impossible"))
      else return ()
    in
    Database.close t.db ;
    t.factory.instance <- None

  let factory {factory; _} = factory

  let check_database t = Database.check t.db

  let fast_forward t target_root :
      (unit, [> `Failure of string | `Bootstrap_required]) Result.t =
    let open Root_identifier.Stable.Latest in
    let open Result.Let_syntax in
    let%bind () = assert_no_sync t in
    (* TODO: don't swallow up underlying error in lift_error *)
    let lift_error r msg = Result.map_error r ~f:(Fn.const (`Failure msg)) in
    let%bind root =
      lift_error (Database.get_root t.db) "failed to get root hash"
    in
    if State_hash.equal root.hash target_root.state_hash then
      (* If the target hash is already the root hash, no fast forward required, but we should check the frontier hash. *)
      let%bind frontier_hash =
        lift_error
          (Database.get_frontier_hash t.db)
          "failed to get frontier hash"
      in
      (* TODO: gracefully recover from this state *)
      Result.ok_if_true
        (Frontier_hash.equal frontier_hash target_root.frontier_hash)
        ~error:
          (`Failure
            "already at persistent root, but frontier hash did not match")
    else Error `Bootstrap_required

  let load_full_frontier t ~root_ledger ~consensus_local_state ~max_length =
    let open Deferred.Result.Let_syntax in
    let downgrade_transition transition :
        External_transition.Almost_validated.t =
      let transition, _ = External_transition.Validated.erase transition in
      External_transition.Validation.wrap transition
      |> External_transition.skip_time_received_validation
           `This_transition_was_not_received_via_gossip
      |> External_transition.skip_proof_validation
           `This_transition_was_generated_internally
      |> External_transition.skip_delta_transition_chain_validation
           `This_transition_was_not_received_via_gossip
      (* TODO: add new variant for loaded from persistence *)
      |> External_transition.skip_frontier_dependencies_validation
           `This_transition_belongs_to_a_detached_subtree
    in
    let%bind () = Deferred.return (assert_no_sync t) in
    (* read basic information from the database *)
    let%bind root, root_transition, best_tip, base_hash =
      (let open Result.Let_syntax in
      let%bind root = Database.get_root t.db in
      let%bind root_transition = Database.get_transition t.db root.hash in
      let%bind best_tip = Database.get_best_tip t.db in
      let%map base_hash = Database.get_frontier_hash t.db in
      (root, root_transition, best_tip, base_hash))
      |> Result.map_error ~f:(fun err ->
             `Failure (Database.Error.not_found_message err) )
      |> Deferred.return
    in
    Printf.printf
      !"genesis: %s\nroot transition: %s\nsnarked ledger db: %s\n%!"
      ( Ledger.merkle_root (Lazy.force Genesis_ledger.t)
      |> Ledger_hash.to_yojson |> Yojson.Safe.to_string )
      ( External_transition.Validated.protocol_state root_transition
      |> Protocol_state.blockchain_state
      |> Blockchain_state.snarked_ledger_hash |> Frozen_ledger_hash.to_yojson
      |> Yojson.Safe.to_string )
      ( Ledger.Db.merkle_root root_ledger
      |> Ledger_hash.to_yojson |> Yojson.Safe.to_string ) ;
    (* construct the root staged ledger in memory *)
    let%bind root_staged_ledger =
      let open Deferred.Let_syntax in
      match%map
        construct_staged_ledger_at_root ~logger:t.factory.logger
          ~verifier:t.factory.verifier ~root_ledger ~root_transition ~root
      with
      | Error err ->
          Error (`Failure (Error.to_string_hum err))
      | Ok staged_ledger ->
          Ok staged_ledger
    in
    (* initialize the new in memory frontier and extensions *)
    let frontier =
      Full_frontier.create ~logger:t.factory.logger ~base_hash
        ~root_data:
          {transition= root_transition; staged_ledger= root_staged_ledger}
        ~root_ledger ~consensus_local_state ~max_length
    in
    let%bind extensions =
      Deferred.map
        (Extensions.create ~logger:t.factory.logger frontier)
        ~f:Result.return
    in
    let apply_diff diff =
      let (`New_root _) = Full_frontier.apply_diffs frontier [diff] in
      Extensions.notify extensions ~frontier ~diffs:[Diff.Full.E.to_lite diff]
      |> Deferred.map ~f:Result.return
    in
    (* crawl through persistent frontier and load transitions into in memory frontier *)
    let%bind () =
      Deferred.map
        (Database.crawl_successors t.db root.hash
           ~init:(Full_frontier.root frontier) ~f:(fun parent transition ->
             let%bind breadcrumb =
               Breadcrumb.build ~logger:t.factory.logger
                 ~verifier:t.factory.verifier
                 ~trust_system:(Trust_system.null ()) ~parent
                 ~transition:(downgrade_transition transition)
                 ~sender:None
             in
             let%map () = apply_diff Diff.(E (New_node (Full breadcrumb))) in
             breadcrumb ))
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
                `Failure (Database.Error.not_found_message err) ))
    in
    let%map () = apply_diff Diff.(E (Best_tip_changed best_tip)) in
    (* reset the frontier hash at the end so it matches the persistent frontier hash (for future sanity checks) *)
    Full_frontier.set_hash_unsafe frontier (`I_promise_this_is_safe base_hash) ;
    (frontier, extensions)
end

type t = Factory_type.t

let create ~logger ~verifier ~directory =
  {logger; verifier; directory; instance= None}

let destroy_database_exn t =
  assert (t.instance = None) ;
  File_system.remove_dir t.directory

let create_instance_exn t =
  assert (t.instance = None) ;
  let instance = Instance.create t in
  t.instance <- Some instance ;
  instance

let with_instance_exn t ~f =
  let instance = create_instance_exn t in
  let x = f instance in
  let%map () = Instance.destroy instance in
  x

let reset_database_exn t ~root_data =
  let open Root_data in
  let open Deferred.Let_syntax in
  Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
    ~metadata:
      [ ( "state_hash"
        , State_hash.to_yojson
            (External_transition.Validated.state_hash root_data.transition) )
      ]
    "Resetting transition frontier database to new root" ;
  let%bind () = destroy_database_exn t in
  with_instance_exn t ~f:(fun instance ->
      Database.initialize instance.db ~root_data ~base_hash:Frontier_hash.empty ;
      (* TODO: remove, this is only a temp sanity check *)
      Database.check instance.db
      |> Result.map_error ~f:(function
           | `Invalid_version ->
               "invalid version"
           | `Not_initialized ->
               "not initialized"
           | `Corrupt err ->
               Database.Error.message err )
      |> Result.ok_or_failwith )
