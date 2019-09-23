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
module Hash = Frontier_hash
module Full_frontier = Full_frontier
module Extensions = Extensions
module Persistent_root = Persistent_root
module Persistent_frontier = Persistent_frontier

let global_max_length = Consensus.Constants.k

type config =
  { logger: Logger.t
  ; verifier: Verifier.t
  ; consensus_local_state: Consensus.Data.Local_state.t }

(* TODO: refactor persistent frontier sync into an extension *)
type t =
  { config: config
  ; full_frontier: Full_frontier.t
  ; persistent_root: Persistent_root.t
  ; persistent_root_instance: Persistent_root.Instance.t
  ; persistent_frontier: Persistent_frontier.t
        (* [new] TODO: !important -- this instance should only be owned by the sync process, as once the sync worker is an RPC worker, only that process can have an open connection the the database *)
  ; persistent_frontier_instance: Persistent_frontier.Instance.t
  ; extensions: Extensions.t }

let genesis_root_data =
  lazy
    (let open Root_data.Limited.Stable.Latest in
    let transition = Lazy.force External_transition.genesis in
    let scan_state = Staged_ledger.Scan_state.empty () in
    let pending_coinbase = Or_error.ok_exn (Pending_coinbase.create ()) in
    {transition; scan_state; pending_coinbase})

let load_from_persistence_and_start config ~max_length ~persistent_root
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
      ( Persistent_frontier.Instance.fast_forward persistent_frontier_instance
          root_identifier
      |> Result.map_error ~f:(function
           | `Sync_cannot_be_running ->
               `Failure "sync job is already running on persistent frontier"
           | `Bootstrap_required ->
               `Bootstrap_required
           | `Failure msg ->
               Logger.fatal config.logger ~module_:__MODULE__ ~location:__LOC__
                 ~metadata:
                   [ ( "target_root"
                     , Root_identifier.Stable.Latest.to_yojson root_identifier
                     ) ]
                 "Unable to fast forward persistent frontier: %s" msg ;
               `Failure msg ) )
  in
  let%bind full_frontier, extensions =
    Deferred.map
      (Persistent_frontier.Instance.load_full_frontier
         persistent_frontier_instance ~max_length
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
  let%map () =
    Deferred.return
      ( Persistent_frontier.Instance.start_sync persistent_frontier_instance
      |> Result.map_error ~f:(function
           | `Sync_cannot_be_running ->
               `Failure "sync job is already running on persistent frontier"
           | `Not_found _ as err ->
               `Failure
                 (Persistent_frontier.Database.Error.not_found_message err) )
      )
  in
  { config
  ; full_frontier
  ; persistent_root
  ; persistent_root_instance
  ; persistent_frontier
  ; persistent_frontier_instance
  ; extensions }

(* TODO: re-add `Bootstrap_required support or redo signature *)
let rec load_with_max_length :
       max_length:int
    -> ?retry_with_fresh_db:bool
    -> config
    -> persistent_root:Persistent_root.t
    -> persistent_frontier:Persistent_frontier.t
    -> ( t
       , [> `Bootstrap_required
         | `Persistent_frontier_malformed
         | `Failure of string ] )
       Deferred.Result.t =
 fun ~max_length ?(retry_with_fresh_db = true) config ~persistent_root
     ~persistent_frontier ->
  let open Deferred.Let_syntax in
  (* TODO: #3053 *)
  (* let persistent_root = Persistent_root.create ~logger:config.logger ~directory:config.persistent_root_directory in *)
  let continue persistent_frontier_instance =
    let persistent_root_instance =
      Persistent_root.create_instance_exn persistent_root
    in
    load_from_persistence_and_start config ~max_length ~persistent_root
      ~persistent_root_instance ~persistent_frontier
      ~persistent_frontier_instance
  in
  let persistent_frontier_instance =
    Persistent_frontier.create_instance_exn persistent_frontier
  in
  let reset_and_continue () =
    let%bind () =
      Persistent_frontier.Instance.destroy persistent_frontier_instance
    in
    let%bind () =
      Persistent_frontier.reset_database_exn persistent_frontier
        ~root_data:(Lazy.force genesis_root_data)
    in
    let%bind () = Persistent_root.reset_to_genesis_exn persistent_root in
    continue (Persistent_frontier.create_instance_exn persistent_frontier)
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
        (Persistent_frontier.Database.Error.message err) ;
      if retry_with_fresh_db then (
        (* should retry be on by default? this could be unnecessarily destructive *)
        Logger.info config.logger ~module_:__MODULE__ ~location:__LOC__
          "destroying old persistent frontier database " ;
        let%bind () =
          Persistent_frontier.Instance.destroy persistent_frontier_instance
        in
        let%bind () =
          Persistent_frontier.destroy_database_exn persistent_frontier
        in
        load_with_max_length ~max_length config ~persistent_root
          ~persistent_frontier ~retry_with_fresh_db:false
        >>| Result.map_error ~f:(function
              | `Persistent_frontier_malformed ->
                  `Failure
                    "failed to destroy and create new persistent frontier \
                     database"
              | err ->
                  err ) )
      else return (Error `Persistent_frontier_malformed)
  | Ok () ->
      continue persistent_frontier_instance

let load = load_with_max_length ~max_length:global_max_length

(* The persistent root and persistent frontier as safe to ignore here
 * because their lifecycle is longer than the transition frontier's *)
let close
    { config= {logger; _}
    ; full_frontier
    ; persistent_root= _safe_to_ignore_1
    ; persistent_root_instance
    ; persistent_frontier= _safe_to_ignore_2
    ; persistent_frontier_instance
    ; extensions } =
  Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
    "Closing transition frontier" ;
  let%map () =
    Persistent_frontier.Instance.destroy persistent_frontier_instance
  in
  Persistent_root.Instance.destroy persistent_root_instance ;
  Extensions.close extensions ;
  Full_frontier.close full_frontier

let persistent_root {persistent_root; _} = persistent_root

let persistent_frontier {persistent_frontier; _} = persistent_frontier

let extensions {extensions; _} = extensions

let root_snarked_ledger {persistent_root_instance; _} =
  Persistent_root.Instance.snarked_ledger persistent_root_instance

let add_breadcrumb_exn t breadcrumb =
  let open Deferred.Let_syntax in
  let old_hash = Full_frontier.hash t.full_frontier in
  let diffs = Full_frontier.calculate_diffs t.full_frontier breadcrumb in
  Logger.trace t.config.logger ~module_:__MODULE__ ~location:__LOC__
    ~metadata:
      [ ( "best_tip_hash"
        , State_hash.to_yojson
            (Breadcrumb.state_hash @@ Full_frontier.best_tip t.full_frontier)
        )
      ; ( "n"
        , `Int (List.length @@ Full_frontier.all_breadcrumbs t.full_frontier)
        ) ]
    "PRE: ($best_tip_hash, $n)" ;
  Logger.trace t.config.logger ~module_:__MODULE__ ~location:__LOC__
    ~metadata:
      [ ( "diffs"
        , `List
            (List.map diffs ~f:(fun (Diff.Full.E.E diff) -> Diff.to_yojson diff))
        ) ]
    "Applying diffs: $diffs" ;
  let (`New_root new_root_identifier) =
    Full_frontier.apply_diffs t.full_frontier diffs
  in
  Option.iter new_root_identifier
    ~f:
      (Persistent_root.Instance.set_root_identifier t.persistent_root_instance) ;
  Logger.trace t.config.logger ~module_:__MODULE__ ~location:__LOC__
    ~metadata:
      [ ( "best_tip_hash"
        , State_hash.to_yojson
            (Breadcrumb.state_hash @@ Full_frontier.best_tip t.full_frontier)
        )
      ; ( "n"
        , `Int (List.length @@ Full_frontier.all_breadcrumbs t.full_frontier)
        ) ]
    "POST: ($best_tip_hash, $n)" ;
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
           "cannot add breadcrumb because persistent frontier sync job is not \
            running -- this indicates that transition frontier initialization \
            has not been performed correctly" )
  |> Result.ok_exn ;
  Extensions.notify t.extensions ~frontier:t.full_frontier ~diffs

(* proxy full frontier functions *)
include struct
  open Full_frontier

  let proxy1 f {full_frontier; _} = f full_frontier

  let proxy2 f {full_frontier= x; _} {full_frontier= y; _} = f x y

  let max_length = proxy1 max_length

  let consensus_local_state = proxy1 consensus_local_state

  let all_breadcrumbs = proxy1 all_breadcrumbs

  let visualize ~filename = proxy1 (visualize ~filename)

  let visualize_to_string = proxy1 visualize_to_string

  (* TODO: better name *)
  let iter = proxy1 iter

  let common_ancestor = proxy1 common_ancestor

  (* reduce sucessors functions (probably remove hashes special case *)
  let successors = proxy1 successors

  let successors_rec = proxy1 successors_rec

  let successor_hashes = proxy1 successor_hashes

  let successor_hashes_rec = proxy1 successor_hashes_rec

  (* TODO: remove? *)
  let hash_path = proxy1 hash_path

  let best_tip = proxy1 best_tip

  let root = proxy1 root

  let find = proxy1 find

  (* TODO: find -> option externally, find_exn internally *)
  let find_exn = proxy1 find_exn

  (* TODO: is this an abstraction leak? *)
  let root_length = proxy1 root_length

  (* TODO: probably shouldn't be an `_exn` function *)
  let best_tip_path = proxy1 best_tip_path

  let best_tip_path_length_exn = proxy1 best_tip_path_length_exn

  (* TODO: should this be nested under For_tests? should never be used in production *)
  let equal = proxy2 equal

  (* TODO: remove? what is this for? *)
  let shallow_copy_root_snarked_ledger =
    proxy1 shallow_copy_root_snarked_ledger

  (* why can't this one be proxied? *)
  let path_map {full_frontier; _} breadcrumb ~f =
    path_map full_frontier breadcrumb ~f
end

module For_tests = struct
  let load_with_max_length = load_with_max_length
end
