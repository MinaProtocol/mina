include Async_kernel.Deferred

let run_in_thread f = Run_in_thread.run_in_thread f

let block_on_async_exn f = Run_in_thread.block_on_async_exn f
