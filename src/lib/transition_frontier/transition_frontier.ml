(** This module glues together the various components that compose
*  the transition frontier, wrapping high-level initialization
*  logic as well as gluing together the logic for adding items
*  to the frontier *)

open Core_kernel
open Async_kernel
open Coda_base
open Coda_transition

(* [new] TODO: rework abstraction so that a transition frontier can be
*   "migrated" to another state, retaining the open instances of the
*   persistent root and persistent frontier while chucking out the
*   old extensions and full frontier. Currently, the bootstrap
*   controller has to close the instances before immediately
*   reopening them. *)

include Frontier_base

module Full_frontier = Full_frontier
module Extensions = Extensions

let genesis_root_data ~logger ~verifier ~snarked_ledger =
  let open Root_data in
  let snarked_ledger_hash =
    Frozen_ledger_hash.of_ledger_hash (Ledger.Db.merkle_root snarked_ledger)
  in
  let pending_coinbase_collection =
    Or_error.ok_exn (Pending_coinbase.create ())
  in
  let%map staged_ledger =
    Staged_ledger.of_scan_state_and_ledger ~logger ~verifier
      ~snarked_ledger_hash
      ~ledger:(Ledger.of_database snarked_ledger)
      ~scan_state:(Staged_ledger.Scan_state.empty ())
      ~pending_coinbase_collection
    >>| Or_error.ok_exn
  in
  {transition= External_transition.genesis; staged_ledger}

module Breadcrumb = Full_frontier.Breadcrumb
module Diff = Full_frontier.Diff
module Hash = Full_frontier.Hash

module Inputs_with_full_frontier = struct
  include Inputs
  module Frontier = Full_frontier
end

module Extensions = Extensions.Make (Inputs_with_full_frontier)
module Persistent_root = Persistent_root.Make (Inputs_with_full_frontier)

module Inputs_with_extensions = struct
  include Inputs_with_full_frontier
  module Extensions = Extensions
end

module Persistent_frontier = Persistent_frontier.Make (Inputs_with_extensions)

type config =
  { logger: Logger.t
  ; verifier: Verifier.t
  ; consensus_local_state: Consensus.Data.Local_state.t }

(* TODO: refactor persistent frontier sync into an extension *)
type t =
  { full_frontier: Full_frontier.t
  ; persistent_root: Persistent_root.t
  ; persistent_root_instance: Persistent_root.Instance.t
  ; persistent_frontier: Persistent_frontier.t
        (* [new] TODO: !important -- this instance should only be owned by the sync process, as once the sync worker is an RPC worker, only that process can have an open connection the the database *)
  ; persistent_frontier_instance: Persistent_frontier.Instance.t
  ; extensions: Extensions.t }

let load_from_persistence_and_start config ~persistent_root
    ~persistent_root_instance ~persistent_frontier
    ~persistent_frontier_instance =
  let open Deferred.Result.Let_syntax in
  let root_identifier =
    match
      Persistent_root.Instance.load_root_identifier persistent_root_instance
    with
    | Some root_identifier ->
        root_identifier
    | None ->
        failwith
          "not persistent root identifier found (should have been written \
           already)"
  in
  let%bind () =
    Deferred.return
      ( Persistent_frontier.Instance.fast_forward
          persistent_frontier_instance root_identifier
      |> Result.map_error ~f:(function
           | `Sync_cannot_be_running ->
               `Failure "sync job is already running on persistent frontier"
           | `Bootstrap_required ->
               `Bootstrap_required
           | `Failure msg ->
               Logger.fatal config.logger ~module_:__MODULE__
                 ~location:__LOC__
                 ~metadata:
                   [ ( "target_root"
                     , Full_frontier.Root_identifier.Stable.Latest.to_yojson
                         root_identifier ) ]
                 "Unable to fast forward persistent frontier: %s" msg ;
               `Failure msg ) )
  in
  let%bind full_frontier, extensions =
    Deferred.map
      (Persistent_frontier.Instance.load_full_frontier
         persistent_frontier_instance
         ~root_ledger:
           (Persistent_root.Instance.snarked_ledger persistent_root_instance)
         ~consensus_local_state:config.consensus_local_state)
      ~f:
        (Result.map_error ~f:(function
          | `Sync_cannot_be_running ->
              `Failure "sync job is already running on persistent frontier"
          | `Failure _ as err ->
              err ))
  in
  let%bind () =
    Deferred.return
      ( Persistent_frontier.Instance.start_sync persistent_frontier_instance
      |> Result.map_error ~f:(function
           | `Sync_cannot_be_running ->
               `Failure "sync job is already running on persistent frontier"
           | `Not_found _ as err ->
               `Failure (Persistent_frontier.Db.Error.not_found_message err) )
      )
  in
  { full_frontier
  ; persistent_root
  ; persistent_root_instance
  ; persistent_frontier
  ; persistent_frontier_instance
  ; extensions }

(* TODO: re-add `Bootstrap_required support or redo signature *)
let rec load :
       ?retry_with_fresh_db:bool
    -> config
    -> persistent_root:Persistent_root.t
    -> persistent_frontier:Persistent_frontier.t
    -> ( t
       , [> `Bootstrap_required
         | `Persistent_frontier_malformed
         | `Failure of string ] )
       Deferred.Result.t =
 fun ?(retry_with_fresh_db = true) config ~persistent_root
     ~persistent_frontier ->
  let open Deferred.Let_syntax in
  (* TODO: #3053 *)
  (* let persistent_root = Persistent_root.create ~logger:config.logger ~directory:config.persistent_root_directory in *)
  let continue ~persistent_root_instance ~persistent_frontier_instance =
    load_from_persistence_and_start config ~persistent_root
      ~persistent_root_instance ~persistent_frontier
      ~persistent_frontier_instance
  in
  let persistent_root_instance =
    Persistent_root.create_instance_exn persistent_root
  in
  let persistent_frontier_instance =
    Persistent_frontier.create_instance_exn persistent_frontier
  in
  let reset_and_continue () =
    let%bind root_data =
      genesis_root_data ~logger:config.logger ~verifier:config.verifier
        ~snarked_ledger:
          (Persistent_root.Instance.snarked_ledger persistent_root_instance)
    in
    let%bind () =
      Persistent_frontier.Instance.destroy persistent_frontier_instance
    in
    let%bind () =
      Persistent_frontier.reset_database_exn persistent_frontier ~root_data
    in
    Persistent_root.Instance.destroy persistent_root_instance ;
    let%bind () = Persistent_root.reset_to_genesis_exn persistent_root in
    continue
      ~persistent_root_instance:
        (Persistent_root.create_instance_exn persistent_root)
      ~persistent_frontier_instance:
        (Persistent_frontier.create_instance_exn persistent_frontier)
  in
  match
    Persistent_frontier.Instance.check_database persistent_frontier_instance
  with
  | Error `Not_initialized ->
      (* [new] TODO: this case can be optimized to not create the
         * database twice through rocks -- currently on clean bootup,
         * this code path will reinitialize the rocksdb twice *)
      Logger.info config.logger ~module_:__MODULE__ ~location:__LOC__
        "persistent frontier database does not exist" ;
      reset_and_continue ()
  | Error `Invalid_version ->
      Logger.info config.logger ~module_:__MODULE__ ~location:__LOC__
        "persistent frontier database out of date" ;
      reset_and_continue ()
  | Error (`Corrupt err) ->
      Logger.error config.logger ~module_:__MODULE__ ~location:__LOC__
        "Persistent frontier database is corrupt: %s"
        (Persistent_frontier.Db.Error.message err) ;
      if retry_with_fresh_db then (
        (* should retry be on by default? this could be unnecessarily destructive *)
        Logger.info config.logger ~module_:__MODULE__ ~location:__LOC__
          "destroying old persistent frontier database " ;
        let%bind () =
          Persistent_frontier.Instance.destroy persistent_frontier_instance
        in
        Persistent_root.Instance.destroy persistent_root_instance ;
        let%bind () =
          Persistent_frontier.destroy_database_exn persistent_frontier
        in
        load config ~persistent_root ~persistent_frontier
          ~retry_with_fresh_db:false
        >>| Result.map_error ~f:(function
              | `Persistent_frontier_malformed ->
                  `Failure
                    "failed to destroy and create new persistent frontier \
                     database"
              | err ->
                  err ) )
      else return (Error `Persistent_frontier_malformed)
  | Ok () ->
      continue ~persistent_root_instance ~persistent_frontier_instance

(* The persistent root and persistent frontier as safe to ignore here
 * because their lifecycle is longer than the transition frontier's *)
let close
    { full_frontier
    ; persistent_root= _safe_to_ignore_1
    ; persistent_root_instance
    ; persistent_frontier= _safe_to_ignore_2
    ; persistent_frontier_instance
    ; extensions } =
  let%map () =
    Persistent_frontier.Instance.destroy persistent_frontier_instance
  in
  Persistent_root.Instance.destroy persistent_root_instance ;
  Extensions.close extensions ;
  Full_frontier.close full_frontier

let persistent_root {persistent_root; _} = persistent_root

let persistent_frontier {persistent_frontier; _} = persistent_frontier

let root_snarked_ledger {persistent_root_instance; _} =
  Persistent_root.Instance.snarked_ledger persistent_root_instance

let add_breadcrumb_exn t breadcrumb =
  let open Deferred.Let_syntax in
  let old_hash = Full_frontier.hash t.full_frontier in
  let diffs = Full_frontier.calculate_diffs t.full_frontier breadcrumb in
  let (`New_root new_root_identifier) =
    Full_frontier.apply_diffs t.full_frontier diffs
  in
  Option.iter new_root_identifier
    ~f:
      (Persistent_root.Instance.set_root_identifier
         t.persistent_root_instance) ;
  let diffs =
    List.map diffs ~f:Diff.(fun (Full.E.E diff) -> Lite.E.E (to_lite diff))
  in
  let%bind sync_result =
    Persistent_frontier.Instance.notify_sync t.persistent_frontier_instance
      ~diffs
      ~hash_transition:
        {source= old_hash; target= Full_frontier.hash t.full_frontier}
  in
  sync_result
  |> Result.map_error ~f:(fun `Sync_must_be_running ->
         Failure
           "cannot add breadcrumb because persistent frontier sync job is \
            not running -- this indicates that transition frontier \
            initialization has not been performed correctly" )
  |> Result.ok_exn ;
  Extensions.notify t.extensions ~frontier:t.full_frontier ~diffs

let snark_pool_refcount_pipe t =
  Extensions.Broadcast.Snark_pool_refcount.reader
    t.extensions.snark_pool_refcount

type best_tip_diff = Extensions.Best_tip_diff.view =
  { new_user_commands: User_command.t list
  ; removed_user_commands: User_command.t list }

let best_tip_diff_pipe t =
  Extensions.Broadcast.Best_tip_diff.reader t.extensions.best_tip_diff

let wait_for_transition t hash =
  let open Extensions in
  let registry =
    Broadcast.Transition_registry.original t.extensions.transition_registry
  in
  Transition_registry.register registry hash

let oldest_breadcrumb_in_history {full_frontier; _} =
  let open Extensions in
  let root_history =
    Broadcast.Root_history.original t.extensions.root_history
  in
  Root_history.oldest root_history

let max_length = max_length

let all_user_commands t = Breadcrumb.all_user_commands (all_breadcrumbs t)

module For_tests = struct
  (* [new] TODO: !important -- patch identity pipe out, this is a very nasty abstraction leak *)
  let identity_pipe t =
    Extensions.Broadcast.Identity.reader t.extensions.identity

  let apply_diff _ = failwith "TODO"

  let root_history_is_empty _ = failwith "TODO"

  let root_history_mem _ = failwith "TODO"

  let root_snarked_ledger _ = failwith "TODO"
end
