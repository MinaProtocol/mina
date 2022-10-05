open Mina_base
open Core
open Network_peer

(* Cache represents a graph. The key is a State_hash, which is the node in
   the graph, and the value is the children transitions of the node *)

type t =
  Mina_block.initial_valid_block Envelope.Incoming.t list State_hash.Table.t

let create () = State_hash.Table.create ()

let add (t : t) ~parent new_child =
  State_hash.Table.update t parent ~f:(function
    | None ->
        [ new_child ]
    | Some children ->
        if
          List.mem children new_child ~equal:(fun e1 e2 ->
              let state_hash e =
                Envelope.Incoming.data e
                |> Mina_block.Validation.block_with_hash
                |> State_hash.With_state_hashes.state_hash
              in
              State_hash.equal (state_hash e1) (state_hash e2) )
        then children
        else new_child :: children )

let data t =
  let collected_transitions = State_hash.Table.data t |> List.concat in
  assert (
    List.length collected_transitions
    = List.length (List.stable_dedup collected_transitions) ) ;
  collected_transitions
