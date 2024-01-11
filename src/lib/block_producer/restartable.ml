open Async

type ('data, 'a) t =
  { mutable task : (unit Ivar.t * ('a, unit) Interruptible.t) option
  ; f : unit Ivar.t -> 'data -> ('a, unit) Interruptible.t
  }

let create ~task = { task = None; f = task }

let cancel t =
  match t.task with
  | Some (ivar, _) ->
      if Ivar.is_full ivar then
        [%log' error (Logger.create ())] "Ivar.fill bug is here!" ;
      Ivar.fill ivar () ;
      t.task <- None
  | None ->
      ()

let restart t data =
  cancel t ;
  let ivar = Ivar.create () in
  let interruptible =
    Interruptible.finally (t.f ivar data) ~f:(fun () -> t.task <- None)
  in
  t.task <- Some (ivar, interruptible) ;
  interruptible
