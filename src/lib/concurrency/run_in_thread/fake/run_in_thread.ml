open Async_kernel

let run_in_thread f = Deferred.return (f ())

let block_on_async_exn f =
  let res = f () in
  match Async_kernel.Deferred.peek res with
  | Some res ->
      res
  | None ->
      failwith
        "block_on_async_exn: Cannot block thread, and the deferred computation \
         did not resolve immediately."
