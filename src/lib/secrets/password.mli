open Async

val default_password_env : string

val read_hidden_line : string -> Bytes.t Deferred.t

val read : string -> bytes Deferred.t

val hidden_line_or_env : string -> env:string -> Bytes.t Deferred.t
