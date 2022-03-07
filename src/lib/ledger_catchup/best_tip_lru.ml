open Core
open Mina_base
open Mina_transition

type elt =
  ( External_transition.Initial_validated.t
  , State_body_hash.t list * External_transition.t )
  Proof_carrying_data.t

let max_size = 16

module Q = Hash_queue.Make (State_hash)

let t = Q.create ()

let add (x : elt) =
  let h =
    ( Proof_carrying_data.data x
    |> External_transition.Initial_validated.state_hashes )
      .state_hash
  in
  if not (Q.mem t h) then (
    if Q.length t >= max_size then ignore (Q.dequeue_front t : elt option) ;
    Q.enqueue_back_exn t h x )
  else ignore (Q.lookup_and_move_to_back t h : elt option)

let get h = Q.lookup t h
