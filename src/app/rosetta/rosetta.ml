open Core
open Async

let router ~graphql_uri route body =
  match route with
  | "network" :: tl ->
      Network.router tl body ~graphql_uri
  | _ ->
      Deferred.return (Error `Page_not_found)

let callback ~graphql_uri ~body _ req =
  let uri = Cohttp_async.Request.uri req in
  let%bind body = Cohttp_async.Body.to_string body in
  printf "Route: %s\n" (Uri.path uri) ;
  let route = List.tl_exn (String.split ~on:'/' (Uri.path uri)) in
  let%bind result =
    match Yojson.Safe.from_string body with
    | body ->
        router route body ~graphql_uri
    | exception Yojson.Json_error "Blank input data" ->
        router route `Null ~graphql_uri
    | exception Yojson.Json_error err ->
        Error (Errors.create ("Error parsing JSON body (" ^ err ^ ")"))
        |> Deferred.return
  in
  match result with
  | Ok json ->
      Cohttp_async.Server.respond_string
        (Yojson.Safe.to_string json)
        ~headers:(Cohttp.Header.of_list [("Content-Type", "application/json")])
  | Error `Page_not_found ->
      Cohttp_async.Server.respond (Cohttp.Code.status_of_code 404)
  | Error (`Error error) ->
      Cohttp_async.Server.respond_string
        ~status:(Cohttp.Code.status_of_code 500)
        (Yojson.Safe.to_string (Models.Error.to_yojson error))
        ~headers:(Cohttp.Header.of_list [("Content-Type", "application/json")])

let start port =
  let%map _ =
    Cohttp_async.Server.create ~on_handler_error:`Raise
      (Async.Tcp.Where_to_listen.bind_to Localhost (On_port port))
      (callback ~graphql_uri:(Uri.of_string "http://localhost:3085/graphql"))
  in
  printf "Started server on port %d\n" port

let () =
  let _ = start 8000 in
  never_returns (Scheduler.go ())
