open Core
open Nanobit_base

type t = Transaction.t Fheap.t

let empty =
  let cmp (t1 : Transaction.t) (t2 : Transaction.t) =
    let c = Transaction.Fee.compare t2.payload.fee t1.payload.fee in
    (* TODO: Using Transaction.compare is kind of a random way of assigning priority *)
    if c = 0
    then Transaction.compare t1 t2
    else c
  in
  Fheap.create ~cmp

let add = Fheap.add

let pop = Fheap.pop

