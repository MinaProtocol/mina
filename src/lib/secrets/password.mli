open Async

val read_hidden_line : string -> Bytes.t Deferred.t

val hidden_line_or_env : string -> env:string -> Bytes.t Deferred.t
