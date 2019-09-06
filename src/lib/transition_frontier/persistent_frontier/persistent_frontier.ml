open Async_kernel
open Core_kernel
open Coda_base
open Coda_state

module Make (Inputs : Inputs.With_base_frontier_intf) = struct
  open Inputs

  module Db = Database.Make (Inputs)
  module Sync = Sync.Make (struct
    include Inputs
    module Db = Db
  end)

  let construct_staged_ledger_at_root ~logger ~verifier ~root_ledger ~root_transition ~root =
    let open Frontier.Diff in
    let snarked_ledger_hash =
      External_transition.Validated.protocol_state root_transition
      |> Protocol_state.blockchain_state
      |> Blockchain_state.snarked_ledger_hash
    in
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
      ; factory: Factory_type.t }
  end = Instance_type
  and Factory_type : sig
    type t =
      { logger: Logger.t
      ; directory: string
      ; verifier: Verifier.t
      ; mutable instance: Instance_type.t option }
  end = Factory_type

  module Instance = struct
    type t = Instance_type.t
    open Instance_type

    let create ~logger ~directory factory =
      {db = Db.create ~logger ~directory; factory}

    let destroy t =
      Db.close t.db;
      t.factory.instance <- None

    let factory {factory; _} = factory

    let reset t ~root_data = Db.reset t.db ~root_data

    let fast_forward t target_root : (unit, [> `Failure of string | `Bootstrap_required]) Result.t =
      let open Frontier in
      let open Result.Let_syntax in
      (* TODO: don't swallow up underlying error in lift_error *)
      let lift_error r msg = Result.map_error r ~f:(Fn.const (`Failure msg)) in
      let%bind root = lift_error (Db.get_root t.db) "failed to get root hash" in
      if State_hash.equal root.hash target_root.state_hash then
        (* If the target hash is already the root hash, no fast forward required, but we should check the frontier hash. *)
        let%bind frontier_hash = lift_error (Db.get_frontier_hash t.db) "failed to get frontier hash" in
        (* TODO: gracefully recover from this state *)
        Result.ok_if_true (Hash.equal frontier_hash target_root.frontier_hash)
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
      (* initialize the new in memory frontier *)
      let frontier =
        Frontier.create
          ~logger:t.factory.logger
          ~base_hash
          ~root_data:{transition= wrap_transition External_transition.Validated.protocol_state root_transition; staged_ledger= root_staged_ledger}
          ~root_ledger
          ~consensus_local_state
      in
      (* crawl through persistent frontier and load transitions into in memory frontier *)
      let%map () =
        Deferred.map
          (Db.crawl_successors t.db root.hash ~init:(Frontier.root frontier) ~f:(fun parent transition ->
            let%map breadcrumb =
              Frontier.Breadcrumb.build
                ~logger:t.factory.logger
                ~verifier:t.factory.verifier
                ~trust_system:(Trust_system.null ())
                ~parent
                ~transition:(downgrade_transition transition)
                ~sender:None
            in
            Frontier.apply_diffs frontier [Frontier.Diff.(E (New_node (Full breadcrumb)))];
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
      Frontier.apply_diffs frontier [Frontier.Diff.(E (Best_tip_changed best_tip))];
      (* reset the frontier hash at the end so it matches the persistent frontier hash (for future sanity checks) *)
      Frontier.set_hash_unsafe frontier (`I_promise_this_is_safe base_hash);
      frontier
  end
  
  type t = Factory_type.t
  open Factory_type

  let create ~logger ~verifier ~directory =
    {logger; verifier; directory; instance= None}

  let create_instance_exn t =
    assert (t.instance = None);
    let instance = Instance.create ~logger:t.logger ~directory:t.directory t in
    t.instance <- Some instance;
    instance

  let with_instance_exn t ~f =
    let instance = create_instance_exn t in
    let x = f instance in
    Instance.destroy instance;
    x
end
