open Core_kernel

type t = { reusable_ids : int Queue.t; mutable last_id : int }

let create () = { reusable_ids = Queue.create (); last_id = 0 }

let next_id (t : t) : int =
  match Queue.dequeue t.reusable_ids with
  | Some id ->
      id
  | None ->
      t.last_id <- t.last_id + 1 ;
      t.last_id

let recycle_id (t : t) (id : int) = Queue.enqueue t.reusable_ids id
