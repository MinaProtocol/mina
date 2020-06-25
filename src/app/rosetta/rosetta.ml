open Core
open Async

let router uri body =
  match List.tl_exn (String.split ~on:'/' (Uri.path uri)) with
  | "network" :: tl ->
      Network.router tl body
  | _ ->
      Respond.error_404

let _ =
  let callback ~body _ req =
    let uri = Cohttp_async.Request.uri req in
    let%bind body = Cohttp_async.Body.to_string body in
    printf "Uri: %s\n" (Uri.path uri) ;
    match Yojson.Safe.from_string body with
    | body ->
        router uri body
    | exception Yojson.Json_error "Blank input data" ->
        router uri `Null
    | exception Yojson.Json_error err ->
        Respond.user_error ("Error JSON body (" ^ err ^ ")")
  in
  let%map _ =
    Cohttp_async.Server.create ~on_handler_error:`Raise
      (Async.Tcp.Where_to_listen.bind_to Localhost (On_port 8000))
      callback
  in
  print_endline "started server"

let () = never_returns (Scheduler.go ())
