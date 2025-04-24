open Core_kernel
open Mina_base
open Mina_transaction
open Pipe_lib
open Network_pool

module State = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Pending | Included | Unknown [@@deriving equal, sexp, compare]

      let to_latest = Fn.id
    end
  end]

  let to_string = function
    | Pending ->
        "PENDING"
    | Included ->
        "INCLUDED"
    | Unknown ->
        "UNKOWN"
end

(* TODO: this is extremely expensive as implemented and needs to be replaced with an extension *)
let get_status ~frontier_broadcast_pipe ~transaction_pool cmd =
  let resource_pool = Transaction_pool.resource_pool transaction_pool in
  match Broadcast_pipe.Reader.peek frontier_broadcast_pipe with
  | None ->
      State.Unknown
  | Some transition_frontier ->
      let best_tip_path =
        Transition_frontier.best_tip_path transition_frontier
      in
      let in_breadcrumb breadcrumb =
        breadcrumb |> Transition_frontier.Breadcrumb.validated_transition
        |> Mina_block.Validated.valid_commands
        |> List.exists ~f:(fun { data = found; _ } ->
               let found' = User_command.forget_check found in
               User_command.equal_ignoring_proofs_and_hashes cmd found' )
      in
      if List.exists ~f:in_breadcrumb best_tip_path then State.Included
      else if
        List.exists ~f:in_breadcrumb
          (Transition_frontier.all_breadcrumbs transition_frontier)
      then State.Pending
      else if
        Transaction_pool.Resource_pool.member resource_pool
          (Transaction_hash.hash_command cmd)
      then State.Pending
      else State.Unknown

