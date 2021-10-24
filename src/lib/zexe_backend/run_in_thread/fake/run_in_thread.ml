let run_in_thread f = Async_kernel.Deferred.return (f ())
