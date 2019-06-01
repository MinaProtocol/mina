open Core_kernel

type read_write

type read_only

type _ flag = Read_write : read_write flag | Read_only : read_only flag

type 'a t_ = {mutable a: 'a; mutable on_update: 'a -> unit; mutable dirty: bool}

type ('flag, 'a) t = 'a t_ constraint 'flag = _ flag

let create ~(f : 'a -> 'b) x : (_ flag, 'b) t =
  {a= f x; on_update= Fn.ignore; dirty= false}

let get (t : (_ flag, 'a) t) =
  if t.dirty then (
    t.dirty <- false ;
    (t.a, `Different) )
  else (t.a, `Same)

let update (t : (read_write flag, 'a) t) a =
  t.a <- a ;
  t.dirty <- true ;
  t.on_update a

let on_update (t : (_ flag, 'a) t) ~f =
  t.on_update <- (fun a -> t.on_update a ; f a)

let read_only t = {a= t.a; on_update= t.on_update; dirty= t.dirty}
