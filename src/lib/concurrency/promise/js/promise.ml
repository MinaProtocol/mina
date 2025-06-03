type 'a t

external run_in_thread : (unit -> 'a) -> 'a t = "deferred_run"

let block_on_async_exn (_ : unit -> 'a t) : 'a =
  failwith "You can't block on async execution in JS"

external map : 'a t -> f:('a -> 'b) -> 'b t = "deferred_map"

external bind : 'a t -> f:('a -> 'b t) -> 'b t = "deferred_bind"

external upon : 'a t -> ('a -> unit) -> unit = "deferred_upon"

external upon_exn : 'a t -> ('a -> unit) -> unit = "deferred_upon_exn"

external is_determined : 'a t -> bool = "deferred_is_determined"

external peek : 'a t -> 'a option = "deferred_peek"

external value_exn : 'a t -> 'a = "deferred_value_exn"

external return : 'a -> 'a t = "deferred_return"

external create : (('a -> unit) -> unit) -> 'a t = "deferred_create"

let to_deferred promise =
  let module Ivar = Async_kernel.Ivar in
  let ivar = Ivar.create () in
  upon_exn promise (fun x -> Ivar.fill ivar x) ;
  Ivar.read ivar

include Base.Monad.Make (struct
  type nonrec 'a t = 'a t

  let map = `Custom map

  let bind = bind

  let return = return
end)
