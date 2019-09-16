open Async_kernel
open Core
open Coda_base
open Coda_state

module Make (Inputs : Inputs.With_extensions_intf) = struct
  open Inputs

  module Db = Database.Make (Inputs)
  module Sync = Sync.Make (struct
    include Inputs
    module Db = Db
  end)

  let construct_staged_ledger_at_root ~logger ~verifier ~root_ledger ~root_transition ~root =
    let open Frontier.Diff.Minimal_root_data.Stable.Latest in
    let snarked_ledger_hash =
      External_transition.Validated.protocol_state root_transition
      |> Protocol_state.blockchain_state
      |> Blockchain_state.snarked_ledger_hash
    in
    (* [new] TODO: !important -- make mask off root ledger and apply all scan state transactions to it *)
    Staged_ledger.of_scan_state_and_ledger
      ~logger ~verifier
      ~snarked_ledger_hash
      ~ledger:(Ledger.of_database root_ledger)
      ~scan_state:root.scan_state
      ~pending_coinbase_collection:root.pending_coinbase

  (* [new] TODO: create a reusable singleton factory abstraction *)
  module rec Instance_type : sig
    type t =
      { db: Db.t
      ; mutable sync: Sync.t option
      ; factory: Factory_type.t }
  end = Instance_type
  and Factory_type : sig
    type t =
      { logger: Logger.t
      ; directory: string
      ; verifier: Verifier.t
      ; mutable instance: Instance_type.t option }
  end = Factory_type

  open Instance_type
  open Factory_type

  module Instance = struct
    type t = Instance_type.t

    let create factory =
      let db = Db.create ~logger:factory.logger ~directory:factory.directory in
      {db; sync= None; factory}

    let assert_no_sync t =
      if Option.is_some t.sync then
        Error `Sync_cannot_be_running
      else
        Ok ()

    let assert_sync t ~f =
      match t.sync with
      | None -> return (Error `Sync_must_be_running)
      | Some sync -> f sync

    let start_sync t =
      let open Result.Let_syntax in
      let%bind () = assert_no_sync t in
      let%map base_hash = Db.get_frontier_hash t.db in
      t.sync <- Some (Sync.create ~logger:t.factory.logger ~base_hash ~db:t.db)

    let stop_sync t =
      let open Deferred.Let_syntax in
      assert_sync t ~f:(fun sync ->
        let%map () = Sync.close sync in
        t.sync <- None;
        Ok ())

    let notify_sync t ~diffs ~hash_transition =
      assert_sync t ~f:(fun sync ->
        Sync.notify sync ~diffs ~hash_transition;
        Deferred.Result.return ())

    let destroy t =
      let open Deferred.Let_syntax in
      let%map () =
        if Option.is_some t.sync then
          stop_sync t
          >>| Fn.compose Result.ok_or_failwith (Result.map_error ~f:(Fn.const "impossible"))
        else
          return ()
      in
      Db.close t.db;
      t.factory.instance <- None

    let factory {factory; _} = factory

    let check_database t =
      Db.check t.db

    let fast_forward t target_root : (unit, [> `Failure of string | `Bootstrap_required]) Result.t =
      let open Frontier.Root_identifier.Stable.Latest in
      let open Result.Let_syntax in
      let%bind () = assert_no_sync t in
      (* TODO: don't swallow up underlying error in lift_error *)
      let lift_error r msg = Result.map_error r ~f:(Fn.const (`Failure msg)) in
      let%bind root = lift_error (Db.get_root t.db) "failed to get root hash" in
      if State_hash.equal root.hash target_root.state_hash then
        (* If the target hash is already the root hash, no fast forward required, but we should check the frontier hash. *)
        let%bind frontier_hash = lift_error (Db.get_frontier_hash t.db) "failed to get frontier hash" in
        (* TODO: gracefully recover from this state *)
        Result.ok_if_true (Frontier.Hash.equal frontier_hash target_root.frontier_hash)
          ~error:(`Failure "already at persistent root, but frontier hash did not match")
      else
        Error `Bootstrap_required
        (*
        match Db.get_transition t.db target_root with
        | Error ->
            (* If the target hash is not in the persistent frontier, then the full frontier is unrecoverable from the persistent copy and a bootstrap is required. *)
            Error `Bootstrap_required
        | Ok target_root_transition  ->
            (* If the target hash is in the persistent frontier, repeatedly move the root forward to the target. *)
            let%bind staged_ledger = load_staged_ledger root in
            let%bind path = Db.path_from_root (External_transition.Validated.previous_state_hash target_root_transition) in
            (* [new] TODO: batch all of this into one transaction, don't write staged ledger each time *)
            let%bind _ =
              Result.List.fold path ~init:(root.hash, staged_ledger) ~f:(fun (prev_hash, prev_staged_ledger) hash ->
                let%bind transition = lift_error (Db.get_transition prev_hash) "database malformed -- failed to get transition" in
                let%bind arcs = lift_error (Db.get_arcs prev_hash) "database malformed -- failed to get transition arcs" in
                let staged_ledger =
                  Staged_ledger.apply_diff
                    ~logger:t.factory.logger
                    ~verifier:t.factory.verifier
                    ~inplace:true
                    prev_staged_ledger
                    (External_transition.Validated.staged_ledger_diff transition)
                in
                let garbage = List.filter arcs ~f:(Fn.compose not (State_hash.equal hash)) in
                let new_root =
                  { hash
                  ; scan_state= Staged_ledger.scan_state staged_ledger
                  ; pending_coinbase= Staged_ledger.pending_coinbase staged_ledger }
                in
                let%map () = Db.move_root ~new_root ~garbage in
                (hash, staged_ledger))
            in
            ()
          *)

    let load_full_frontier t ~root_ledger ~consensus_local_state =
      let open Deferred.Result.Let_syntax in
      let wrap_transition protocol_state = With_hash.of_data ~hash_data:(Fn.compose Protocol_state.hash protocol_state) in
      let downgrade_transition transition =
        External_transition.Validated.forget_validation transition
        |> wrap_transition External_transition.protocol_state
        |> External_transition.Validation.wrap
        |> External_transition.skip_time_received_validation `This_transition_was_not_received_via_gossip
        |> External_transition.skip_proof_validation `This_transition_was_generated_internally (* TODO: add new variant for loaded from persistence *)
        |> External_transition.skip_frontier_dependencies_validation `This_transition_belongs_to_a_detached_subtree
      in
      let%bind () = Deferred.return (assert_no_sync t) in
      (* read basic information from the database *)
      let%bind root, root_transition, best_tip, base_hash =
        ( let open Result.Let_syntax in
          let%bind root = Db.get_root t.db in
          let%bind root_transition = Db.get_transition t.db root.hash in
          let%bind best_tip = Db.get_best_tip t.db in
          let%map base_hash = Db.get_frontier_hash t.db in
          (root, root_transition, best_tip, base_hash))
        |> Result.map_error ~f:(fun err -> `Failure (Db.Error.not_found_message err))
        |> Deferred.return
      in
      Printf.printf !"genesis: %s\nroot transition: %s\nsnarked ledger db: %s\n%!"
        ( Ledger.merkle_root Genesis_ledger.t
        |> Ledger_hash.to_yojson
        |> Yojson.Safe.to_string)
        (External_transition.Validated.protocol_state root_transition
        |> Protocol_state.blockchain_state
        |> Blockchain_state.snarked_ledger_hash
        |> Frozen_ledger_hash.to_yojson
        |> Yojson.Safe.to_string)
        (Ledger.Db.merkle_root root_ledger
        |> Ledger_hash.to_yojson
        |> Yojson.Safe.to_string);
      (* construct the root staged ledger in memory *)
      let%bind root_staged_ledger =
        let open Deferred.Let_syntax in
        match%map
          construct_staged_ledger_at_root
            ~logger:t.factory.logger
            ~verifier:t.factory.verifier
            ~root_ledger
            ~root_transition
            ~root
        with
        | Error err -> Error (`Failure (Error.to_string_hum err))
        | Ok staged_ledger -> Ok staged_ledger
      in
      (* initialize the new in memory frontier and extensions *)
      let frontier =
        Frontier.create
          ~logger:t.factory.logger
          ~base_hash
          ~root_data:{transition= wrap_transition External_transition.Validated.protocol_state root_transition; staged_ledger= root_staged_ledger}
          ~root_ledger
          ~consensus_local_state
      in
      let root_breadcrumb = Frontier.root frontier in
      let%bind extensions =
        Deferred.map
          (Extensions.create root_breadcrumb)
          ~f:Result.return
      in
      let apply_diff diff =
        let `New_root _ = Frontier.apply_diffs frontier [diff] in
        Extensions.notify extensions ~frontier ~diffs:[Frontier.Diff.Full.E.to_lite diff]
        |> Deferred.map ~f:Result.return
      in
      (* crawl through persistent frontier and load transitions into in memory frontier *)
      let%bind () =
        Deferred.map
          (Db.crawl_successors t.db root.hash ~init:root_breadcrumb ~f:(fun parent transition ->
            let%bind breadcrumb =
              Frontier.Breadcrumb.build
                ~logger:t.factory.logger
                ~verifier:t.factory.verifier
                ~trust_system:(Trust_system.null ())
                ~parent
                ~transition:(downgrade_transition transition)
                ~sender:None
            in
            let%map () = apply_diff Frontier.Diff.(E (New_node (Full breadcrumb))) in
            breadcrumb))
          ~f:(Result.map_error ~f:(function
            | `Crawl_error err ->
                let msg = match err with
                  | `Fatal_error exn -> "fatal error -- " ^ Exn.to_string exn
                  | `Invalid_staged_ledger_diff err
                  | `Invalid_staged_ledger_hash err ->
                      "staged ledger diff application failed -- " ^ Error.to_string_hum err
                in
                `Failure ("error rebuilding transition frontier from persistence: " ^ msg)
            | `Not_found _ as err -> `Failure (Db.Error.not_found_message err)))
      in
      let%map () = apply_diff Frontier.Diff.(E (Best_tip_changed best_tip)) in
      (* reset the frontier hash at the end so it matches the persistent frontier hash (for future sanity checks) *)
      Frontier.set_hash_unsafe frontier (`I_promise_this_is_safe base_hash);
      (frontier, extensions)
  end
  
  type t = Factory_type.t

  let create ~logger ~verifier ~directory =
    {logger; verifier; directory; instance= None}

  let destroy_database_exn t =
    assert (t.instance = None);
    File_system.remove_dir t.directory

  let create_instance_exn t =
    assert (t.instance = None);
    let instance = Instance.create t in
    t.instance <- Some instance;
    instance

  let with_instance_exn t ~f =
    let instance = create_instance_exn t in
    let x = f instance in
    let%map () = Instance.destroy instance in
    x

  let reset_database_exn t ~root_data =
    let open Frontier.Root_data in
    let open With_hash in
    let open Deferred.Let_syntax in
    Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
      ~metadata:[("state_hash", State_hash.to_yojson root_data.transition.hash)]
      "Resetting transition frontier database to new root";
    let%bind () = destroy_database_exn t in
    with_instance_exn t ~f:(fun instance ->
      Db.initialize instance.db ~root_data ~base_hash:Frontier.Hash.empty;
      (* TODO: remove, this is only a temp sanity check *)
      Db.check instance.db
      |> Result.map_error ~f:(function
        | `Invalid_version -> "invalid version"
        | `Not_initialized -> "not initialized"
        | `Corrupt err -> Db.Error.message err)
      |> Result.ok_or_failwith)
end
