open Core_kernel
open Mina_base
open Frontier_base
module Queue = Hash_queue.Make (State_hash)

type t =
  { history : Root_data.Historical.t Queue.t
  ; capacity : int
  ; mutable current_root : Root_data.Historical.t
  ; mutable protocol_states_for_root_scan_state :
      Full_frontier.Protocol_states_for_root_scan_state.t
  }

let lookup { history; _ } = Queue.lookup history

let mem { history; _ } = Queue.mem history

(** Looks up values by key using the lookup function and returns
   obtained values in reverse order or None if any of the lookups fail *)
let lookup_all_reversed ~lookup =
  List.fold_until ~init:[] ~finish:Option.some ~f:(fun acc key ->
      match lookup key with
      | Some value ->
          Continue (value :: acc)
      | None ->
          Stop None )

let protocol_states_for_scan_state ~protocol_states_for_root_scan_state ~history
    required_state_hashes =
  let lookup_in_scan_states hash =
    let%map.Option state_with_hash =
      State_hash.Map.find protocol_states_for_root_scan_state hash
    in
    With_hash.data state_with_hash
  in
  let lookup_in_root_history hash =
    Option.map ~f:Root_data.Historical.protocol_state
      (Queue.lookup history hash)
  in
  let lookup hash =
    match lookup_in_root_history hash with
    | Some value ->
        Some value
    | None ->
        lookup_in_scan_states hash
  in
  lookup_all_reversed ~lookup required_state_hashes

let most_recent { history; _ } =
  (* unfortunately, there is not function to inspect the last element in the queue,
   * so we need to remove it and reinsert it instead *)
  let open Option.Let_syntax in
  let%map state_hash, breadcrumb = Queue.dequeue_back_with_key history in
  (* should never return `Key_already_present since we just removed it *)
  assert (
    [%equal: [ `Ok | `Key_already_present ]] `Ok
      (Queue.enqueue_back history state_hash breadcrumb) ) ;
  breadcrumb

let oldest { history; _ } = Queue.first history

let is_empty { history; _ } = Queue.is_empty history

let to_list { history; _ } = Queue.to_list history

let staged_ledger_aux_and_pending_coinbases_of_breadcrumb
    ~protocol_states_for_root_scan_state ~history breadcrumb =
  let staged_ledger = Breadcrumb.staged_ledger breadcrumb in
  let scan_state = Staged_ledger.scan_state staged_ledger in
  let required_state_hashes =
    Staged_ledger.Scan_state.required_state_hashes scan_state
    |> State_hash.Set.to_list
  in
  let%map.Option scan_state_protocol_states =
    protocol_states_for_scan_state ~protocol_states_for_root_scan_state ~history
      required_state_hashes
  in
  let pending_coinbase =
    Staged_ledger.pending_coinbase_collection staged_ledger
  in
  let staged_ledger_target_ledger_hash =
    Breadcrumb.staged_ledger_hash breadcrumb |> Staged_ledger_hash.ledger_hash
  in
  let data =
    ( scan_state
    , staged_ledger_target_ledger_hash
    , pending_coinbase
    , scan_state_protocol_states )
  in
  let module Data =
    Network_types.Staged_ledger_aux_and_pending_coinbases.Data.Stable.Latest
  in
  (* Cache in frontier and return tag *)
  State_hash.File_storage.append_values_exn (Breadcrumb.state_hash breadcrumb)
    ~f:(fun writer ->
      State_hash.File_storage.write_value writer (module Data) data )

let historical_of_breadcrumb ~protocol_states_for_root_scan_state ~history
    breadcrumb =
  let cached_opt =
    Breadcrumb.staged_ledger_aux_and_pending_coinbases_cached breadcrumb
  in
  let%map.Option staged_ledger_aux_and_pending_coinbases =
    match cached_opt with
    | Some value ->
        Some value
    | None ->
        staged_ledger_aux_and_pending_coinbases_of_breadcrumb
          ~protocol_states_for_root_scan_state ~history breadcrumb
  in
  let scan_state =
    Staged_ledger.scan_state (Breadcrumb.staged_ledger breadcrumb)
  in
  let required_state_hashes =
    Staged_ledger.Scan_state.required_state_hashes scan_state
  in
  Root_data.Historical.create
    ~block_tag:(Breadcrumb.block_tag breadcrumb)
    ~staged_ledger_aux_and_pending_coinbases ~required_state_hashes
    ~protocol_state_with_hashes:
      (Breadcrumb.protocol_state_with_hashes breadcrumb)

module T = struct
  type view = t

  let name = "root_registry"

  let create ~logger:_ frontier =
    let capacity = 2 * Full_frontier.max_length frontier in
    let history = Queue.create () in
    let protocol_states_for_root_scan_state =
      Full_frontier.protocol_states_for_root_scan_state frontier
    in
    let current_root =
      historical_of_breadcrumb ~protocol_states_for_root_scan_state ~history
        (Full_frontier.root frontier)
      |> Option.value_exn
           ~message:"root_history: can't compute historical for root"
    in
    let t =
      { history; capacity; current_root; protocol_states_for_root_scan_state }
    in
    (t, t)

  let enqueue t new_root =
    let open Root_data.Historical in
    ( if Queue.length t.history >= t.capacity then
      let oldest_root = Queue.dequeue_front_exn t.history in
      (*Update the protocol states required for scan state at the new root*)
      let _new_oldest_hash, new_oldest_root =
        Queue.first_with_key t.history |> Option.value_exn
      in
      let new_protocol_states_map =
        Full_frontier.Protocol_states_for_root_scan_state
        .protocol_states_for_next_root_scan_state
          t.protocol_states_for_root_scan_state
          ~next_root_required_hashes:
            ( Root_data.Historical.required_state_hashes new_oldest_root
            |> State_hash.Set.to_list )
          ~old_root_state:(protocol_state_with_hashes oldest_root)
        |> List.map ~f:(fun s -> State_hash.With_state_hashes.(state_hash s, s))
        |> State_hash.Map.of_alist_exn
      in
      t.protocol_states_for_root_scan_state <- new_protocol_states_map ) ;
    assert (
      [%equal: [ `Ok | `Key_already_present ]] `Ok
        (Queue.enqueue_back t.history
           ( State_hash.With_state_hashes.state_hash
           @@ protocol_state_with_hashes t.current_root )
           t.current_root ) ) ;
    t.current_root <- new_root

  let handle_diffs root_history frontier diffs_with_mutants =
    let open Diff.Full.With_mutant in
    let should_produce_view =
      List.exists diffs_with_mutants ~f:(function
        (* TODO: send full diffs to extensions to avoid extra lookups in frontier *)
        | E (Root_transitioned { new_root = { state_hash; _ }; _ }, _) ->
            let breadcrumb =
              Full_frontier.find frontier state_hash
              |> Option.value_exn
                   ~message:
                     (sprintf "root_history: new root %s not found in frontier"
                        (State_hash.to_base58_check state_hash) )
            in
            let historical =
              historical_of_breadcrumb
                ~protocol_states_for_root_scan_state:
                  root_history.protocol_states_for_root_scan_state
                ~history:root_history.history breadcrumb
              |> Option.value_exn
                   ~message:
                     (sprintf
                        "root_history: can't compute historical for new root %s"
                        (State_hash.to_base58_check state_hash) )
            in
            enqueue root_history historical ;
            true
        | E _ ->
            false )
    in
    Option.some_if should_produce_view root_history
end

include T

module Broadcasted = Functor.Make_broadcasted (struct
  type nonrec t = t

  include T
end)
