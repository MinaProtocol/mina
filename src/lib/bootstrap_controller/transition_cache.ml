open Coda_base
open Core

(* Cache represents a graph. The key is a State_hash, which is the node in
   the graph, and the value is the children transitions of the node *)
module type S = sig
  type t

  type external_transition_verified

  type state_hash

  val create : unit -> t

  val add : t -> parent:state_hash -> external_transition_verified -> unit

  val data : t -> external_transition_verified list
end

module type Inputs_intf = Transition_frontier.Inputs_intf

module Make (Inputs : Inputs_intf) :
  S
  with type external_transition_verified :=
              Inputs.External_transition.Verified.t
   and type state_hash := State_hash.t = struct
  type t = Inputs.External_transition.Verified.t list State_hash.Table.t

  let create () = State_hash.Table.create ()

  let add (t : t) ~parent new_child =
    State_hash.Table.update t parent ~f:(function
      | None -> [new_child]
      | Some children ->
          if
            List.mem children new_child
              ~equal:Inputs.External_transition.Verified.equal
          then children
          else new_child :: children )

  let data t = State_hash.Table.data t |> List.concat
end
