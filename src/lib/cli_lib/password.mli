open Async

val read : string -> bytes Deferred.Or_error.t

val hidden_line_or_env : string -> env:string -> Bytes.t Deferred.Or_error.t
