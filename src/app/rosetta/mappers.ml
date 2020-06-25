open Core_kernel
open Async

let parse res = Deferred.return (Result.map_error ~f:Errors.create res)

let sql res =
  Deferred.Result.map_error
    ~f:(fun e -> Errors.create (Caqti_error.show e))
    res
