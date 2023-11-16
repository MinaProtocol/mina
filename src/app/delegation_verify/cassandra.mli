open Async

type 'a parser = Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or

val select :
     ?executable:string
  -> keyspace:string
  -> parse:'a parser
  -> fields:string list
  -> ?where:string
  -> string
  -> 'a list Deferred.Or_error.t

val update :
     ?executable:string
  -> keyspace:string
  -> table:string
  -> where:string
  -> (string * string) list
  -> unit Deferred.Or_error.t
