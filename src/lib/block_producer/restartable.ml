open Async

type ('data, 'a) t =
  { mutable task : (unit Ivar.t * ('a, unit) Interruptible.t) option
  ; f : cancel:unit Ivar.t -> 'data -> ('a, unit) Interruptible.t
  }

let create ~task = { task = None; f = task }

let cancel t =
  match t.task with
  | Some (cancel, _) ->
      if Ivar.is_full cancel then
        [%log' error (Logger.create ())] "Ivar.fill bug is here!" ;
      Ivar.fill cancel () ;
      t.task <- None
  | None ->
      ()

let restart t data =
  cancel t ;
  let cancel = Ivar.create () in
  let interruptible =
    Interruptible.finally (t.f ~cancel data) ~f:(fun () -> t.task <- None)
  in
  t.task <- Some (cancel, interruptible) ;
  interruptible