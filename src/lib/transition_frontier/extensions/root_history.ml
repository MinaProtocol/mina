open Core_kernel
open Mina_base
open Frontier_base
module Queue = Hash_queue.Make (State_hash)

module T = struct
  type t =
    { history : Root_data.Historical.t Queue.t
    ; capacity : int
    ; mutable current_root : Root_data.Historical.t
    ; mutable protocol_states_for_root_scan_state :
        Full_frontier.Protocol_states_for_root_scan_state.t
    }

  type view = t

  let name = "root_registry"

  let create ~logger:_ frontier =
    let capacity = 2 * Full_frontier.max_length frontier in
    let history = Queue.create () in
    let current_root =
      Root_data.Historical.of_breadcrumb (Full_frontier.root frontier)
    in
    let t =
      { history
      ; capacity
      ; current_root
      ; protocol_states_for_root_scan_state =
          Full_frontier.protocol_states_for_root_scan_state frontier
      }
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
          ~new_scan_state:(Root_data.Historical.scan_state new_oldest_root)
          ~old_root_state:
            ( transition oldest_root |> Mina_block.Validated.forget
            |> With_hash.map ~f:(fun block ->
                   block |> Mina_block.header
                   |> Mina_block.Header.protocol_state ) )
        |> List.map ~f:(fun s -> State_hash.With_state_hashes.(state_hash s, s))
        |> State_hash.Map.of_alist_exn
      in
      t.protocol_states_for_root_scan_state <- new_protocol_states_map ) ;
    assert (
      [%equal: [ `Ok | `Key_already_present ]] `Ok
        (Queue.enqueue_back t.history
           (Mina_block.Validated.state_hash @@ transition t.current_root)
           t.current_root ) ) ;
    t.current_root <- new_root

  let handle_diffs root_history frontier diffs_with_mutants =
    let open Diff.Full.With_mutant in
    let should_produce_view =
      List.exists diffs_with_mutants ~f:(function
        (* TODO: send full diffs to extensions to avoid extra lookups in frontier *)
        | E (Root_transitioned { new_root; _ }, _) -> (
            let state_hash =
              (Root_data.Limited.Stable.Latest.hashes new_root).state_hash
            in
            match Full_frontier.find frontier state_hash with
            | Some breadcrumb ->
                enqueue root_history
                  (Root_data.Historical.of_breadcrumb breadcrumb) ;
                true
            | None ->
                failwithf "root_history: new root %s not found in frontier"
                  (State_hash.to_base58_check state_hash)
                  () )
        | E _ ->
            false )
    in
    Option.some_if should_produce_view root_history
end

include T
module Broadcasted = Functor.Make_broadcasted (T)

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

let protocol_states_for_scan_state t state_hash =
  let history = t.history in
  let lookup_in_scan_states hash =
    let%map.Option state_with_hash =
      State_hash.Map.find t.protocol_states_for_root_scan_state hash
    in
    With_hash.data state_with_hash
  in
  let lookup_in_root_history hash =
    Option.map ~f:Root_data.Historical.protocol_state
      (Queue.lookup t.history hash)
  in
  let lookup hash =
    match lookup_in_root_history hash with
    | Some value ->
        Some value
    | None ->
        lookup_in_scan_states hash
  in
  let open Option.Let_syntax in
  let%bind data = Queue.lookup history state_hash in
  let required_state_hashes =
    Root_data.Historical.required_state_hashes data |> State_hash.Set.to_list
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

let get_staged_ledger_aux_and_pending_coinbases_at_hash t state_hash :
    Frontier_base.Network_types
    .Get_staged_ledger_aux_and_pending_coinbases_at_hash_result
    .Data
    .Stable
    .Latest
    .t
    option =
  let%bind.Option root = lookup t state_hash in
  let%map.Option scan_state_protocol_states =
    protocol_states_for_scan_state t state_hash
  in
  Root_data.Historical.
    ( scan_state root
    , staged_ledger_target_ledger_hash root
    , pending_coinbase root
    , scan_state_protocol_states )
