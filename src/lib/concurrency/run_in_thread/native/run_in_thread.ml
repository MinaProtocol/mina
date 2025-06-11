let run_in_thread f = Async.In_thread.run f

let block_on_async_exn f = Async.Thread_safe.block_on_async_exn f
