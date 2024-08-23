open Async

type 'a parser = Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or

type conf

val make_conf : ?executable:string -> keyspace:string -> conf

val select :
     conf:conf
  -> parse:'a parser
  -> fields:string list
  -> ?where:string
  -> string
  -> 'a list Deferred.Or_error.t

val update :
     conf:conf
  -> table:string
  -> where:string
  -> (string * string) list
  -> unit Deferred.Or_error.t
