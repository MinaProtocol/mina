open Core_kernel
open Frontier_base

module T = struct
  type t = unit

  type view = Breadcrumb.t list

  let create ~logger:_ frontier = ((), [ Full_frontier.root frontier ])

  let handle_diffs () _frontier diffs_with_mutants =
    let open Diff.Full.With_mutant in
    let new_nodes =
      List.filter_map diffs_with_mutants ~f:(function
        | E (New_node (Full breadcrumb), _) ->
            Some breadcrumb
        | _ ->
            None )
    in
    Option.some_if (not @@ List.is_empty new_nodes) new_nodes
end

include T
module Broadcasted = Functor.Make_broadcasted (T)
