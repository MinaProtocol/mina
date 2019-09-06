(** This module glues together the various components that compose
 *  the transition frontier, wrapping high-level initialization
 *  logic as well as gluing together the logic for adding items
 *  to the frontier *)

open Core_kernel
open Async_kernel
open Coda_base

module Inputs = Inputs

(* [new] TODO: rework abstraction so that a transition frontier can be
 *   "migrated" to another state, retaining the open instances of the
 *   persistent root and persistent frontier while chucking out the
 *   old extensions and full frontier. Currently, the bootstrap
 *   controller has to close the instances before immediately
 *   reopening them. *)
module Make (Inputs : Inputs.S) :
  Coda_intf.Transition_frontier_intf
  with type mostly_validated_external_transition :=
              ( [`Time_received] * Truth.true_t
              , [`Proof] * Truth.true_t
              , [`Frontier_dependencies] * Truth.true_t
              , [`Staged_ledger_diff] * Truth.false_t )
              Inputs.External_transition.Validation.with_transition
   and type external_transition_validated :=
              Inputs.External_transition.Validated.t
   and type staged_ledger_diff := Inputs.Staged_ledger_diff.t
   and type staged_ledger := Inputs.Staged_ledger.t
   and type transaction_snark_scan_state := Inputs.Staged_ledger.Scan_state.t
   and type verifier := Inputs.Verifier.t
   and type 'a transaction_snark_work_statement_table := 'a Inputs.Transaction_snark_work.Statement.Table.t = struct
  open Inputs

  module Full_frontier = Full_frontier.Make (Inputs)

  type root_identifier = Full_frontier.root_identifier =
    { state_hash: State_hash.t
    ; frontier_hash: Full_frontier.Hash.t }
  [@@deriving yojson]

  type root_data = Full_frontier.root_data =
    { transition: (External_transition.Validated.t, State_hash.t) With_hash.t
    ; staged_ledger: Staged_ledger.t }

  module Breadcrumb = Full_frontier.Breadcrumb
  module Diff = Full_frontier.Diff
  module Hash = Full_frontier.Hash

  module Inputs_with_full_frontier = struct
    include Inputs
    module Frontier = Full_frontier
  end

  module Persistent_root = Persistent_root.Make (Inputs_with_full_frontier)
  module Persistent_frontier = Persistent_frontier.Make (Inputs_with_full_frontier)
  module Extensions = Extensions.Make (Inputs_with_full_frontier)

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
    ; persistent_frontier_sync: Persistent_frontier.Sync.t
    ; extensions: Extensions.t }

  (* TODO: re-add `Bootstrap_required support or redo signature *)
  let load config ~persistent_root:persistent_root_factory ~persistent_frontier:persistent_frontier_factory =
    let open Deferred.Result.Let_syntax in
    (* TODO: #3053 *)
    (* let persistent_root = Persistent_root.create ~logger:config.logger ~directory:config.persistent_root_directory in *)
    let persistent_root = Persistent_root.create_instance_exn persistent_root_factory in
    let persistent_frontier = Persistent_frontier.create_instance_exn persistent_frontier_factory in
    let root_identifier = Persistent_root.Instance.load_root_identifier persistent_root in
    let%bind () =
      Deferred.return (
        Persistent_frontier.Instance.fast_forward persistent_frontier root_identifier
        |> Result.map_error ~f:(function
          | `Bootstrap_required -> `Bootstrap_required
          | `Failure msg ->
              Logger.fatal config.logger ~module_:__MODULE__ ~location:__LOC__
                ~metadata:[("target_root", Full_frontier.root_identifier_to_yojson root_identifier)]
                "Unable to fast forward persistent frontier: %s"
                msg;
              `Failure msg))
    in
    Persistent_frontier.Instance.load_full_frontier persistent_frontier
      ~root_ledger:(Persistent_root.Instance.snarked_ledger persistent_root)
      ~consensus_local_state:config.consensus_local_state


  (* [new] TODO *)
  let close {full_frontier=_TODO_1; persistent_root=_TODO_2; persistent_root_instance=_TODO_3; persistent_frontier=_TODO_4; persistent_frontier_instance=_TODO_5; persistent_frontier_sync=_TODO_6; extensions} =
    (* Full_frontier.close full_frontier; *)
    (* Persistent_frontier.Sync.close persistent_frontier_sync; *)
    Extensions.close extensions;
    failwith "TODO"

  let persistent_root {persistent_root; _} = persistent_root
  let persistent_frontier {persistent_frontier; _} = persistent_frontier

  let root_snarked_ledger {persistent_root_instance; _} =
    Persistent_root.Instance.snarked_ledger persistent_root_instance

  (*
  let create_genesis_root_data config =
    let open Full_frontier in
    let scan_state = Staged_ledger.Scan_state.empty () in
    let pending_coinbases = Or_error.ok_exn (Pending_coinbase.create ()) in
    let%map staged_ledger_or_error =
      Staged_ledger.of_scan_state_pending_coinbases_and_snarked_ledger
        ~logger:config.logger
        ~verifier:config.verifier
        ~scan_state
        ~snarked_ledger:Genesis_ledger.t
        ~expected_merkle_root:(Ledger.merkle_root Genesis_ledger.t)
        ~pending_coinbases
    in
    { transition= External_transition.genesis
    ; staged_ledger= Or_error.ok_exn staged_ledger_or_error }
  *)

  (*
  let create_clean config ~persistent_root =
    let persistent_frontier = Persistent_frontier.create ~logger:config.logger ~directory:config.persistent_frontier_directory in
    let%bind root_data = create_genesis_root_data config in
    (* TODO: I don't think this is necessary... *)
    (* Persistent_root.reset_to_genesis root_ledger; *)
    Persistent_frontier.clear persistent_frontier ~root_data;
    (* let full_frontier = Full_frontier.create ~logger:config.logger ~root_data ~root_ledger ~consensus_local_state:config.consensus_local_state in *)
    let full_frontier = Persistent_frontier.load_full_frontier persistent_frontier in
    let%bind persistent_frontier_sync = Persistent_frontier.Sync.create ~logger:config.logger persistent_frontier in
    let%map extensions = Extensions.create (Full_frontier.get_root full_frontier) in
    {full_frontier; persistent_frontier_sync; extensions}

  (* TODO: move logic *)
  (*
  let sync_persistence_and_load config ~root_ledger ~persistent_frontier =
    if
      Frozen_ledger_hash.equal
        (Persistent_frontier.get_root pers_frontier).snarked_ledger_hash
        (Root_ledger.merkle_root root_ledger)
    then (
      (* TODO: log error *)
      assert (
        Frontier_hash.equal
          (Persistent_frontier.get_frontier_hash pers_frontier)
          (Root_ledger.get_frontier_hash root_ledger));
      load config ~root_ledger ~persistent_frontier:pers_frontier)
    else (
      match Persistent_frontier.fast_forward_root pers_frontier ~target_root:(Root_ledger.get_root_state_hash root_ledger) with
      | Error (`Failure err) ->
          (* TODO: recover *)
          failwiths (Error.sexp_of_t err)
      | Error `Target_not_found ->
          failwith "TODO"
      | Ok () ->
          load config ~root_ledger ~persistent_frontier:pers_frontier)
  *)

  type persistent_load_error =
    [ `Not_initialized
    | `Corrupt of
        [ `Invalid_version
        | `Not_found of
            [ `Best_tip
            | `Best_tip_transition
            | `Frontier_hash
            | `Root
            | `Root_transition ] ]
    | `Target_not_found
    | `Invalid_frontier_hash
    | `Fatal of Error.t ]

  (* TODO: audit default/initialization of metadata from persistent root *)
  let attempt_persistent_load config ~persistent_root =
    let open Deferred.Let_syntax in
    let log_recoverable_error msg =
      Logger.warn config.logger
        ~module_:__MODULE__ ~location:__LOC__
        "failed to load transition frontier from disk: persistent frontier %s"
        msg
    in
    let log_fatal_error err =
      Logger.fatal config.logger
        ~module_:__MODULE__ ~location:__LOC__
        !"error while attempting to load transition frontier from disk: %{sexp: Error.t}"
        err;
      Error.raise err
    in
    let%bind persistent_root_state_hash = Persistent_root.load_state_hash persistent_root in
    let%bind persistent_root_frontier_hash = Persistent_root.load_frontier_hash persistent_root in
    let persistent_frontier = Persistent_frontier.create ~logger:config.logger ~directory:config.persistent_frontier_directory in
    let open Deferred.Result.Let_syntax in
    (* check persistent frontier and load full frontier if possible *)
    let%bind full_frontier =
      match
        let open Result.Let_syntax in
        let%bind () = (Persistent_frontier.check persistent_frontier :> (unit, persistent_load_error) Result.t) in
        (* TODO: do we even care about this check? *)
        let%bind persistent_frontier_root_hash = ((Persistent_frontier.get_root_hash persistent_frontier |> Result.map_error ~f:(fun x -> `Corrupt x)) :> (State_hash.t, persistent_load_error) Result.t) in
        if State_hash.equal persistent_root_state_hash persistent_frontier_root_hash then
          let%bind persistent_frontier_hash = ((Persistent_frontier.get_frontier_hash persistent_frontier |> Result.map_error ~f:(fun x -> `Corrupt x)) :> (Full_frontier.Hash.t, persistent_load_error) Result.t) in
          (Result.ok_if_true
            (Hash.equal persistent_root_frontier_hash persistent_frontier_hash)
            ~error:`Invalid_frontier_hash
          :> (unit, persistent_load_error) Result.t)
        else
          let%map () = (Persistent_frontier.fast_forward_root persistent_frontier ~target_root:persistent_root_state_hash :> (unit, persistent_load_error) Result.t) in
          Persistent_frontier.set_frontier_hash persistent_frontier persistent_root_frontier_hash
      with
      | Error `Not_initialized ->
          let open Deferred.Let_syntax in
          (* if the persistent frontier is no initialized, but we are at genesis, initialize with genesis *)
          log_recoverable_error "not initialized";
          if State_hash.equal persistent_root_state_hash (With_hash.hash Genesis_protocol_state.t) then (
            let%bind root_data = create_genesis_root_data config in
            Persistent_frontier.initialize persistent_frontier ~base_hash:persistent_root_frontier_hash ~root_data;
            Persistent_frontier.load_full_frontier persistent_frontier)
          else
            Deferred.return (Error `Bootstrap_required)
      | Error (`Corrupt _) ->
          (* TODO: report specific error *)
          log_recoverable_error "is corrupt";
          Persistent_frontier.clear persistent_root;
          Deferred.return (Error `Bootstrap_required)
      | Error `Target_not_found ->
          log_recoverable_error "is too out of date with persistent root";
          Persistent_frontier.clear persistent_root;
          Deferred.return (Error `Bootstrap_required)
      | Error `Invalid_frontier_hash ->
          log_recoverable_error "hash did not match persistent root's expected frontier hash";
          Persistent_frontier.clear persistent_root;
          Deferred.return (Error `Bootstrap_required)
      | Error (`Fatal err) ->
          log_fatal_error err
          (* Deferred.return (Error (`Fatal err))*)
      | Ok () ->
          Deferred.return (Persistent_frontier.load_full_frontier persistent_frontier)
    in
    let open Deferred.Let_syntax in
    let%bind persistent_frontier_sync = Persistent_frontier.Sync.create ~logger:config.logger persistent_frontier in
    let%map extensions = Extensions.create (Full_frontier.get_root full_frontier) in
    Ok {full_frontier; extensions; persistent_frontier_sync}

  (* TODO: extension reorg
  let create config =
    let {persistent_root; persistent_frontier; full_frontier} = initialize_state config in
    let root_history = Root_history.create () in
    let extensions = Extensions.create
      [ Persistent_root.extension persistent_root
      ; Persistent_frontier.extension persistent_frontier
      ; root_history
      ; snark_pool_refcount
      ; best_tip_diff
      ; transition_registry
      ; identity ]
    in
  *)

  let create config =
    let persistent_root = Persistent_root.create ~logger:config.logger ~directory:config.persistent_root_directory in
    if%bind Persistent_root.at_genesis persistent_root then
      let%map t = create_clean config ~persistent_root in
      Ok t
    else
      attempt_persistent_load config ~persistent_root
  *)

  (*
  let create_clean
    ~persistent_root:persistent_root_factory
    ~persistent_frontier:persistent_frontier_factory
    ~root_transition
    ~root_snarked_ledger =
    Persistent_root.reset persistent_root_factory ~root_snarked_ledger;
    Persistent_frontier.reset persistent_frontier_factory ~frontier_hash ~root_transition ~root_staged_ledger
  *)

  let add_breadcrumb_exn t breadcrumb =
    let open Deferred.Let_syntax in
    let old_hash = (Full_frontier.hash t.full_frontier) in
    let%bind diffs = Deferred.return @@ Full_frontier.calculate_diffs t.full_frontier breadcrumb in
    let%bind () = Deferred.return @@ Full_frontier.apply_diffs t.full_frontier diffs in
    let diffs = List.map diffs ~f:Diff.(fun (Full.E.E diff) -> Lite.E.E (to_lite diff)) in 
    Persistent_frontier.Sync.notify t.persistent_frontier_sync
      ~diffs
      ~hash_transition:{source= old_hash; target= Full_frontier.hash t.full_frontier};
    Extensions.notify t.extensions ~frontier:t.full_frontier ~diffs ()

  let snark_pool_refcount_pipe t =
    Extensions.Broadcast.Snark_pool_refcount.reader t.extensions.snark_pool_refcount

  type best_tip_diff = Extensions.Best_tip_diff.view =
    { new_user_commands: User_command.t list
    ; removed_user_commands: User_command.t list }

  let best_tip_diff_pipe t =
    Extensions.Broadcast.Best_tip_diff.reader t.extensions.best_tip_diff

  let wait_for_transition t hash =
    let open Extensions.Broadcast.Transition_registry in
    Extensions.Transition_registry.register t.extensions.t.transition_registry

  let max_length = max_length
  let logger {full_frontier; _} = Full_frontier.logger full_frontier
  let consensus_local_state {full_frontier; _} = Full_frontier.consensus_local_state full_frontier
  let equal {full_frontier=a; _} {full_frontier=b; _} = Full_frontier.equal a b
  let find {full_frontier; _} h = Full_frontier.find full_frontier h
  let find_exn {full_frontier; _} h = Full_frontier.find_exn full_frontier h
  let successors {full_frontier; _} b = Full_frontier.successors full_frontier b
  let successors_rec {full_frontier; _} b = Full_frontier.successors_rec full_frontier b
  let successor_hashes {full_frontier; _} b = Full_frontier.successor_hashes full_frontier b
  let successor_hashes_rec {full_frontier; _} b = Full_frontier.successor_hashes_rec full_frontier b
  let iter {full_frontier; _} ~f = Full_frontier.iter full_frontier ~f
  let hash_path {full_frontier; _} b = Full_frontier.hash_path full_frontier b
  let path_map {full_frontier; _} b ~f = Full_frontier.path_map full_frontier b ~f
  let all_breadcrumbs {full_frontier; _} = Full_frontier.all_breadcrumbs full_frontier
  let root {full_frontier; _} = Full_frontier.root full_frontier
  let root_length {full_frontier; _} = Full_frontier.root_length full_frontier
  let get_root {full_frontier; _} = Full_frontier.get_root full_frontier
  let get_root_exn {full_frontier; _} = Full_frontier.get_root_exn full_frontier
  let best_tip {full_frontier; _} = Full_frontier.best_tip full_frontier
  let best_tip_path_length_exn {full_frontier; _} = Full_frontier.best_tip_path_length_exn full_frontier
  let common_ancestor {full_frontier; _} a b = Full_frontier.common_ancestor full_frontier a b
  let visualize ~filename {full_frontier; _} = Full_frontier.visualize ~filename full_frontier
  let visualize_to_string {full_frontier; _} = Full_frontier.visualize_to_string full_frontier
  let shallow_copy_root_snarked_ledger {full_frontier; _} = Full_frontier.shallow_copy_root_snarked_ledger full_frontier

  (* [new] TODO: move root history specific functions somewhere else? *)
  let path_search t state_hash ~find ~f =
    let open Option.Let_syntax in
    let rec go state_hash =
      let%map breadcrumb = find t state_hash in
      let elem = f breadcrumb in
      match go (Breadcrumb.parent_hash breadcrumb) with
      | Some subresult ->
          Non_empty_list.cons elem subresult
      | None ->
          Non_empty_list.singleton elem
    in
    Option.map ~f:Non_empty_list.rev (go state_hash)

  let get_path_inclusively_in_root_history {extensions; _} state_hash ~f =
    let root_history =
      Extensions.Broadcast.Root_history.peek extensions.root_history
    in
    path_search root_history state_hash
      ~find:(fun root_history ->
        Extensions.Root_history.View.lookup root_history )
      ~f

  let root_history_path_map t state_hash ~f =
    let open Option.Let_syntax in
    match path_search t ~find ~f state_hash with
    | None ->
        get_path_inclusively_in_root_history t state_hash ~f
    | Some frontier_path ->
        let root_history_path =
          let%bind root_breadcrumb = get_root t in
          get_path_inclusively_in_root_history t
            (Breadcrumb.parent_hash root_breadcrumb)
            ~f
        in
        Some
          (Option.value_map root_history_path ~default:frontier_path
             ~f:(fun root_history ->
               Non_empty_list.append root_history frontier_path ))

  let find_in_root_history t hash =
    let root_history =
      Extensions.Broadcast.Root_history.peek t.extensions.root_history
    in
    Extensions.Root_history.View.lookup root_history hash

  module For_tests = struct
    let identity_pipe _ = failwith "TODO"
    let apply_diff _ = failwith "TODO"
    let root_history_is_empty _ = failwith "TODO"
    let root_history_mem _ = failwith "TODO"
    let root_snarked_ledger _ = failwith "TODO"
  end
end

include Make (struct
  module Verifier = Verifier
  module Ledger_proof = Ledger_proof
  module Transaction_snark_work = Transaction_snark_work
  module External_transition = Coda_transition.External_transition
  module Internal_transition = Coda_transition.Internal_transition
  module Staged_ledger_diff = Staged_ledger_diff
  module Staged_ledger = Staged_ledger

  let max_length = Consensus.Constants.k
end)
