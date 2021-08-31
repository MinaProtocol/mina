open Core_kernel
open Async_kernel

let build :
       (unit -> ('gql, 'e) Deferred.Result.t)
    -> unit
    -> ('gql, 'e) Deferred.Result.t =
 fun f ->
  let open Deferred.Result.Let_syntax in
  let cached_response : 'gql option ref = ref None in
  fun () ->
    match !cached_response with
    | None ->
        let%map r = f () in
        cached_response := Some r ;
        r
    | Some r ->
        Deferred.Result.return r
