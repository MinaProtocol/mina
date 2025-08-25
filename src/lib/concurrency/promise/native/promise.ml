include Async_kernel.Deferred

let run_in_thread f = Run_in_thread.run_in_thread f

let block_on_async_exn f = Run_in_thread.block_on_async_exn f

let create f =
  let module Ivar = Async_kernel.Ivar in
  let ivar = Ivar.create () in
  f (fun x -> Ivar.fill_if_empty ivar x) ;
  Ivar.read ivar

let to_deferred p = p
