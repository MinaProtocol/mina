module type Config_intf = sig
  val headers : string Core.String.Map.t

  val preprocess_variables_string : string -> string
end

val make_local_uri : int -> Core_kernel__.Import.string -> Uri.t

module type S = sig
  val query_or_error :
       < parse : Yojson.Basic.t -> 'response
       ; query : string
       ; variables : Yojson.Basic.t >
    -> int
    -> 'response Async.Deferred.Or_error.t

  val query :
       < parse : Yojson.Basic.t -> 'response
       ; query : string
       ; variables : Yojson.Basic.t >
    -> int
    -> 'response Async.Deferred.t
end

val graphql_error_to_string : Yojson.Basic.t -> string

module Connection_error : sig
  type t = [ `Failed_request of Core.Error.t | `Graphql_error of Core.Error.t ]

  val ok_exn :
       [< `Failed_request of string | `Graphql_error of string ]
    -> 'a Async_unix__.Import.Deferred.t

  val to_error :
    [< `Failed_request of string | `Graphql_error of string ] -> Core.Error.t
end

module Make : functor (Config : Config_intf) -> sig
  val query :
       < parse : Yojson.Basic.t -> 'a
       ; query : string
       ; variables : Yojson.Basic.t
       ; .. >
    -> Uri.t
    -> ( 'a
       , [> `Failed_request of string | `Graphql_error of string ] )
       Async_kernel__Deferred_result.t

  val query_exn :
       < parse : Yojson.Basic.t -> 'a
       ; query : string
       ; variables : Yojson.Basic.t
       ; .. >
    -> Uri.t
    -> 'a Async.Deferred.t
end
