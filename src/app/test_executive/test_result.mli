(* Function responsible to printout test results into stdout but also log all necessary data
   for post-mortem test result analysis. In order to allow easier navigation in log it uses
   'span' log type whit corresponding metadata attributes like stop and start to indicate which
   step of test result is performed
*)
val calculate_test_result :
     log_error_set:
       Integration_test_lib.Test_error.remote_error
       Integration_test_lib.Test_error.Set.t
  -> internal_error_set:
       Integration_test_lib.Test_error.internal_error
       Integration_test_lib.Test_error.Set.t
  -> logger:Logger.t
  -> int option Async_kernel__Types.Deferred.t
