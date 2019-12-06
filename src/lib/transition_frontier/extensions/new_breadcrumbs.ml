open Core_kernel
open Frontier_base

module T = struct
  type t = unit

  type view = Breadcrumb.t list

  let create ~logger:_ frontier = ((), [Full_frontier.root frontier])

  let handle_diffs () _frontier diffs =
    let open Diff in
    let new_nodes =
      List.filter_map diffs ~f:(function
        | Full.E.E (New_node (Full breadcrumb)) ->
            Some breadcrumb
        | _ ->
            None )
    in
    Option.some_if (not @@ List.is_empty new_nodes) new_nodes
end

include T
module Broadcasted = Functor.Make_broadcasted (T)
