open Core_kernel
open Async

let create ?(code = 400) ?(retriable = true) message =
  `Error {Models.Error.code= Int32.of_int_exn code; message; retriable}

let map_parse res = Deferred.return (Result.map_error ~f:create res)

let map_sql res =
  Deferred.Result.map_error
    ~f:(fun e -> sprintf "SQL failure: %s" (Caqti_error.show e) |> create)
    res
