open Mina_base
open Core
open Mina_transition
open Network_peer

(* Cache represents a graph. The key is a State_hash, which is the node in
   the graph, and the value is the children transitions of the node *)

type t =
  External_transition.Initial_validated.t Envelope.Incoming.t list
  State_hash.Table.t

let create () = State_hash.Table.create ()

let add (t : t) ~parent new_child =
  State_hash.Table.update t parent ~f:(function
    | None ->
        [ new_child ]
    | Some children ->
        if
          List.mem children new_child ~equal:(fun e1 e2 ->
              State_hash.equal
                ( Envelope.Incoming.data e1
                |> External_transition.Initial_validated.state_hashes )
                  .state_hash
                ( Envelope.Incoming.data e2
                |> External_transition.Initial_validated.state_hashes )
                  .state_hash)
        then children
        else new_child :: children)

let data t =
  let collected_transitions = State_hash.Table.data t |> List.concat in
  assert (
    List.length collected_transitions
    = List.length (List.stable_dedup collected_transitions) ) ;
  collected_transitions
