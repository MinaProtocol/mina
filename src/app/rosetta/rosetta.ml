open Core_kernel
open Async

let router ~graphql_uri ~db route body =
  match route with
  | "network" :: tl ->
      Network.router db tl body ~graphql_uri
  | _ ->
      Deferred.return (Error `Page_not_found)

let server_handler ~db ~graphql_uri ~body _ req =
  let uri = Cohttp_async.Request.uri req in
  let%bind body = Cohttp_async.Body.to_string body in
  printf "Route: %s\n" (Uri.path uri) ;
  let route = List.tl_exn (String.split ~on:'/' (Uri.path uri)) in
  let%bind result =
    match Yojson.Safe.from_string body with
    | body ->
        router route body ~db ~graphql_uri
    | exception Yojson.Json_error "Blank input data" ->
        router route `Null ~db ~graphql_uri
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

let required_uri =
  Command.Param.(required (Command.Arg_type.map string ~f:Uri.of_string))

let command =
  let open Command.Let_syntax in
  let%map_open archive_uri =
    flag "archive-uri"
      ~doc:"Postgres connection string URI corresponding to archive node"
      required_uri
  and graphql_uri =
    flag "graphql-uri" ~doc:"URI of Coda GraphQL endpoint to connect to"
      required_uri
  and port = flag "port" ~doc:"Port to expose Rosetta server" (required int) in
  let open Deferred.Let_syntax in
  fun () ->
    match%bind Caqti_async.connect archive_uri with
    | Error e ->
        (* TODO: Convert to using Logger module when converted to new yojson *)
        eprintf "Failed to connect to postgresql database, see error: %s"
          (Caqti_error.show e) ;
        Deferred.unit
    | Ok db ->
        let%map _ =
          Cohttp_async.Server.create ~on_handler_error:`Raise
            (Async.Tcp.Where_to_listen.bind_to Localhost (On_port port))
            (server_handler ~db ~graphql_uri)
        in
        printf "Started server on port %d\n" port

let () =
  Command.run
    (Command.async ~summary:"Run Rosetta process on top of Coda" command)
