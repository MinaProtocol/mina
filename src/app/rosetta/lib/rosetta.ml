open Core_kernel
open Async
open Rosetta_lib

let router ~graphql_uri ~db ~logger route body =
  match route with
  | "network" :: tl ->
      Network.router tl body ~db ~graphql_uri ~logger
  | "account" :: tl ->
      Account.router tl body ~db ~graphql_uri ~logger
  | "mempool" :: tl ->
      Mempool.router tl body ~db ~graphql_uri ~logger
  | "block" :: tl ->
      Block.router tl body ~db ~graphql_uri ~logger
  | "construction" :: tl ->
      Construction.router tl body ~graphql_uri ~logger
  | _ ->
      Deferred.return (Error `Page_not_found)

let server_handler ~db ~graphql_uri ~logger ~body _ req =
  let uri = Cohttp_async.Request.uri req in
  let%bind body = Cohttp_async.Body.to_string body in
  let route = List.tl_exn (String.split ~on:'/' (Uri.path uri)) in
  let%bind result =
    match Yojson.Safe.from_string body with
    | body ->
        router route body ~db ~graphql_uri ~logger
    | exception Yojson.Json_error "Blank input data" ->
        router route `Null ~db ~graphql_uri ~logger
    | exception Yojson.Json_error err ->
        Errors.create ~context:"JSON in request malformed"
          (`Json_parse (Some err))
        |> Deferred.Result.fail |> Errors.Lift.wrap
  in
  match result with
  | Ok json ->
      Cohttp_async.Server.respond_string
        (Yojson.Safe.to_string json)
        ~headers:(Cohttp.Header.of_list [("Content-Type", "application/json")])
  | Error `Page_not_found ->
      Cohttp_async.Server.respond (Cohttp.Code.status_of_code 404)
  | Error (`App app_error) ->
      let error = Errors.erase app_error in
      let metadata = [("error", Rosetta_models.Error.to_yojson error)] in
      [%log warn] ~metadata "Error response: $error" ;
      Cohttp_async.Server.respond_string
        ~status:(Cohttp.Code.status_of_code 500)
        (Yojson.Safe.to_string (Rosetta_models.Error.to_yojson error))
        ~headers:(Cohttp.Header.of_list [("Content-Type", "application/json")])

let command =
  let open Command.Let_syntax in
  let%map_open archive_uri =
    flag "archive-uri"
      ~doc:"Postgres connection string URI corresponding to archive node"
      Cli.required_uri
  and graphql_uri =
    flag "graphql-uri" ~doc:"URI of Coda GraphQL endpoint to connect to"
      Cli.required_uri
  and log_json =
    flag "log-json" ~doc:"Print log output as JSON (default: plain text)"
      no_arg
  and log_level =
    flag "log-level" ~doc:"Set log level (default: Info)" Cli.log_level
  and port = flag "port" ~doc:"Port to expose Rosetta server" (required int) in
  let open Deferred.Let_syntax in
  fun () ->
    let logger = Logger.create () in
    Cli.logger_setup log_json log_level ;
    match%bind Caqti_async.connect archive_uri with
    | Error e ->
        [%log error]
          ~metadata:[("error", `String (Caqti_error.show e))]
          "Failed to connect to postgresql database. Error: $error" ;
        Deferred.unit
    | Ok db ->
        let%bind server =
          Cohttp_async.Server.create ~on_handler_error:`Raise
            (Async.Tcp.Where_to_listen.bind_to All_addresses (On_port port))
            (server_handler ~db ~graphql_uri ~logger)
        in
        [%log info]
          ~metadata:[("port", `Int port)]
          "Rosetta process running on http://localhost:$port" ;
        Cohttp_async.Server.close_finished server
