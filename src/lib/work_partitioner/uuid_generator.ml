open Core_kernel

type t = { reusable_uuids : int Queue.t; mutable last_uuid : int }

let create () = { reusable_uuids = Queue.create (); last_uuid = 0 }

let next_uuid (t : t) : int =
  match Queue.dequeue t.reusable_uuids with
  | Some uuid ->
      uuid
  | None ->
      t.last_uuid <- t.last_uuid + 1 ;
      t.last_uuid

let recycle_uuid (t : t) (uuid : int) = Queue.enqueue t.reusable_uuids uuid
