(* This is temporary until we decide to switch over fully to "super catchup".

   Normal catchup does not maintain enough state on its own to decide whether a long catchup job is in progress.
   Thus, we have the frontier hold onto a "catchup hash tree" which contains information about which nodes are
   involved in catchup jobs.

   Super catchup maintains an explicit tree of blocks that are involved in catchup, which contains enough information
   to decide whether a long catchup job is in progress, and so we do not need a separate tree of hashes.
*)

type t = Full of Full_catchup_tree.t

let max_catchup_chain_length : t -> int = function
  | Full t ->
      Full_catchup_tree.max_catchup_chain_length t

let frontier_added (t : t) breadcrumb ~root_moved : unit =
  match t with
  | Full t ->
      Full_catchup_tree.frontier_added t breadcrumb ~root_moved

let create t ~logger ~root =
  match t with `Super -> Full (Full_catchup_tree.create ~logger ~root)
