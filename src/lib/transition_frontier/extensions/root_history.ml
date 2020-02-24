open Core_kernel
open Coda_base
open Coda_transition
open Frontier_base
module Queue = Hash_queue.Make (State_hash)

module T = struct
  type t =
    { history: Root_data.Historical.t Queue.t
    ; capacity: int
    ; mutable current_root: Root_data.Historical.t }

  type view = t

  let create ~logger:_ frontier =
    let capacity = 2 * Full_frontier.max_length frontier in
    let history = Queue.create () in
    let current_root =
      Root_data.Historical.of_breadcrumb (Full_frontier.root frontier)
    in
    let t = {history; capacity; current_root} in
    (t, t)

  let enqueue t new_root =
    if Queue.length t.history >= t.capacity then
      ignore (Queue.dequeue_front_exn t.history) ;
    assert (
      `Ok
      = Queue.enqueue_back t.history
          (External_transition.Validated.state_hash t.current_root.transition)
          t.current_root ) ;
    t.current_root <- new_root

  let handle_diffs root_history frontier diffs_with_mutants =
    let open Diff.Full.With_mutant in
    let should_produce_view =
      List.exists diffs_with_mutants ~f:(function
        (* TODO: send full diffs to extensions to avoid extra lookups in frontier *)
        | E (Root_transitioned {new_root; _}, _) ->
            let open Root_data.Minimal.Stable.Latest in
            Full_frontier.find_exn frontier new_root.hash
            |> Root_data.Historical.of_breadcrumb |> enqueue root_history ;
            true
        | E _ ->
            false )
    in
    Option.some_if should_produce_view root_history
end

include T
module Broadcasted = Functor.Make_broadcasted (T)

let lookup {history; _} = Queue.lookup history

let mem {history; _} = Queue.mem history

let most_recent {history; _} =
  (* unfortunately, there is not function to inspect the last element in the queue,
   * so we need to remove it and reinsert it instead *)
  let open Option.Let_syntax in
  let%map state_hash, breadcrumb = Queue.dequeue_back_with_key history in
  (* should never return `Key_already_present since we just removed it *)
  assert (`Ok = Queue.enqueue_back history state_hash breadcrumb) ;
  breadcrumb

let oldest {history; _} = Queue.first history

let is_empty {history; _} = Queue.is_empty history

let to_list {history; _} = Queue.to_list history
