open Core
open Mina_base
open Mina_transition

type elt =
  ( Mina_block.initial_valid_block
  , State_body_hash.t list * Mina_block.t )
  Proof_carrying_data.t

let max_size = 16

module Q = Hash_queue.Make (State_hash)

let t = Q.create ()

let add (x : elt) =
  let h =
    Proof_carrying_data.data x |> Validation.block_with_hash
    |> State_hash.With_state_hashes.state_hash
  in
  if not (Q.mem t h) then (
    if Q.length t >= max_size then ignore (Q.dequeue_front t : elt option) ;
    Q.enqueue_back_exn t h x )
  else ignore (Q.lookup_and_move_to_back t h : elt option)

let get h = Q.lookup t h
