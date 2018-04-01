open Core
open Nanobit_base

module H = Hash_heap.Make(Transaction)

type t = Transaction.t H.t

let cmp (t1 : Transaction.t) (t2 : Transaction.t) =
  let c = Transaction.Fee.compare t2.payload.fee t1.payload.fee in
  (* todo: using transaction.compare is kind of a random way of assigning priority *)
  if c = 0
  then Transaction.compare t1 t2
  else c

let create () = H.create cmp

let add t x = ignore (H.push t ~key:x ~data:x)

let pop = H.pop

let remove = H.remove
