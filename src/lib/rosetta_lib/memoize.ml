open Core_kernel
open Async_kernel

let ignores_args : ('a -> 'b) -> 'a -> 'b =
 fun f ->
  let cached : 'b option ref = ref None in
  match !cached with
  | None ->
      fun a ->
        let b = f a in
        cached := Some b ;
        b
  | Some b ->
      fun _a -> b

let build :
       (graphql_uri:Uri.t -> unit -> ('gql, 'e) Deferred.Result.t)
    -> graphql_uri:Uri.t
    -> unit
    -> ('gql, 'e) Deferred.Result.t =
 fun f ->
  let open Deferred.Result.Let_syntax in
  let cached_response : 'gql option ref = ref None in
  fun ~graphql_uri () ->
    match !cached_response with
    | None ->
        let%map r = f ~graphql_uri () in
        cached_response := Some r ;
        r
    | Some r ->
        Deferred.Result.return r
