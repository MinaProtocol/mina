(* http_client.ml -- one GET with a timeout. Knows nothing about blocks. *)

open Core
open Async

type response =
  { status : Cohttp.Code.status_code; headers : Cohttp.Header.t; body : string }

(** [interrupt] is handed to the client so that a timed out request is torn
    down. [with_timeout] alone abandons the deferred but leaves the socket
    open until the peer closes it, one leaked connection per timeout. *)
let get url ~timeout =
  let interrupt = Ivar.create () in
  let request () =
    let%bind response, body =
      Cohttp_async.Client.get ~interrupt:(Ivar.read interrupt) url
    in
    let%map body = Cohttp_async.Body.to_string body in
    { status = Cohttp.Response.status response
    ; headers = Cohttp.Response.headers response
    ; body
    }
  in
  match%map
    Monitor.try_with ~here:[%here] ~extract_exn:true (fun () ->
        Clock_ns.with_timeout timeout (request ()) )
  with
  | Error exn ->
      `Failed exn
  | Ok `Timeout ->
      Ivar.fill_if_empty interrupt () ;
      `Timeout
  | Ok (`Result response) ->
      `Ok response

let header response name = Cohttp.Header.get response.headers name
