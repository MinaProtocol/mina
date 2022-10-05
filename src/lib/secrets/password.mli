open Async

val read_hidden_line : error_help_message:string -> string -> Bytes.t Deferred.t

val hidden_line_or_env :
  ?error_help_message:string -> string -> env:string -> Bytes.t Deferred.t
