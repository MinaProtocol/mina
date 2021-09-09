open Core_kernel
open Async
open Rosetta_lib

let router ~graphql_uri ~pool ~logger route body =
  let open Deferred.Result.Let_syntax in
  let get_graphql_uri_or_error () =
    match graphql_uri with
    | None ->
        Deferred.Result.fail (`App (Errors.create `Graphql_uri_not_set))
    | Some graphql_uri ->
        Deferred.Result.return graphql_uri
  in
  let with_db f =
    let%bind pool = Lazy.force pool in
    Caqti_async.Pool.use (fun db -> f ~db) pool
    |> Deferred.Result.map_error ~f:(function
         | `App e ->
             `App e
         | `Page_not_found ->
             `Page_not_found
         | `Exception exn ->
             `Exception exn
         | `Connect_failed _e ->
             `App (Errors.create (`Sql "Connect failed"))
         | `Connect_rejected _e ->
             `App (Errors.create (`Sql "Connect rejected"))
         | `Post_connect _e ->
             `App (Errors.create (`Sql "Post connect error")) )
  in
  try
    match route with
    | "network" :: tl ->
        let%bind graphql_uri = get_graphql_uri_or_error () in
        Network.router tl body ~graphql_uri ~logger ~with_db
    | "account" :: tl ->
        let%bind graphql_uri = get_graphql_uri_or_error () in
        Account.router tl body ~graphql_uri ~logger ~with_db
    | "mempool" :: tl ->
        let%bind graphql_uri = get_graphql_uri_or_error () in
        Mempool.router tl body ~graphql_uri ~logger
    | "block" :: tl ->
        let%bind graphql_uri = get_graphql_uri_or_error () in
        Block.router tl body ~graphql_uri ~logger ~with_db
    | "construction" :: tl ->
        Construction.router tl body ~get_graphql_uri_or_error ~logger
    | _ ->
        Deferred.return (Error `Page_not_found)
  with exn -> Deferred.return (Error (`Exception exn))

let server_handler ~pool ~graphql_uri ~logger ~body _sock req =
  let uri = Cohttp_async.Request.uri req in
  let%bind body = Cohttp_async.Body.to_string body in
  let route = List.tl_exn (String.split ~on:'/' (Uri.path uri)) in
  let%bind result =
    match Yojson.Safe.from_string body with
    | body ->
        router route body ~pool ~graphql_uri ~logger
    | exception Yojson.Json_error "Blank input data" ->
        router route `Null ~pool ~graphql_uri ~logger
    | exception Yojson.Json_error err ->
        Errors.create ~context:"JSON in request malformed"
          (`Json_parse (Some err))
        |> Deferred.Result.fail |> Errors.Lift.wrap
  in
  let lift x = `Response x in
  let respond_500 error =
    Cohttp_async.Server.respond_string
      ~status:(Cohttp.Code.status_of_code 500)
      (Yojson.Safe.to_string (Rosetta_models.Error.to_yojson error))
      ~headers:(Cohttp.Header.of_list [("Content-Type", "application/json")])
    >>| lift
  in
  match result with
  | Ok json ->
      Cohttp_async.Server.respond_string
        (Yojson.Safe.to_string json)
        ~headers:(Cohttp.Header.of_list [("Content-Type", "application/json")])
      >>| lift
  | Error `Page_not_found ->
      Cohttp_async.Server.respond (Cohttp.Code.status_of_code 404) >>| lift
  | Error (`Exception exn) ->
      let exn_str = Exn.to_string_mach exn in
      [%log warn]
        ~metadata:[("exception", `String exn_str)]
        "Exception when processing request" ;
      let error = Errors.create (`Exception exn_str) |> Errors.erase in
      respond_500 error
  | Error (`App app_error) ->
      let error = Errors.erase app_error in
      let metadata = [("error", Rosetta_models.Error.to_yojson error)] in
      [%log warn] ~metadata "Error response: $error" ;
      respond_500 error

let command =
  let open Command.Let_syntax in
  let%map_open archive_uri =
    flag "--archive-uri" ~aliases:["archive-uri"]
      ~doc:"Postgres connection string URI corresponding to archive node"
      Cli.optional_uri
  and graphql_uri =
    flag "--graphql-uri" ~aliases:["graphql-uri"]
      ~doc:"URI of Coda GraphQL endpoint to connect to" Cli.optional_uri
  and log_json =
    flag "--log-json" ~aliases:["log-json"]
      ~doc:"Print log output as JSON (default: plain text)" no_arg
  and log_level =
    flag "--log-level" ~aliases:["log-level"]
      ~doc:"Set log level (default: Info)" Cli.log_level
  and port =
    flag "--port" ~aliases:["port"] ~doc:"Port to expose Rosetta server"
      (required int)
  in
  let open Deferred.Let_syntax in
  fun () ->
    let logger = Logger.create () in
    Cli.logger_setup log_json log_level ;
    let pool =
      lazy
        (let open Deferred.Result.Let_syntax in
        let%bind archive_uri =
          match archive_uri with
          | None ->
              Deferred.Result.fail
                (`App (Errors.create (`Sql "No archive URI set")))
          | Some archive_uri ->
              Deferred.Result.return archive_uri
        in
        match Caqti_async.connect_pool ~max_size:128 archive_uri with
        | Error e ->
            [%log error]
              ~metadata:[("error", `String (Caqti_error.show e))]
              "Failed to create a caqti pool to postgres. Error: $error" ;
            Deferred.Result.fail (`App (Errors.create (`Sql "Connect failed")))
        | Ok pool ->
            Deferred.Result.return pool)
    in
    let%bind server =
      Cohttp_async.Server.create_expert ~max_connections:128
        ~on_handler_error:
          (`Call
            (fun _net exn ->
              [%log error]
                "Exception while handling Rosetta server request: $error"
                ~metadata:
                  [ ("error", `String (Exn.to_string_mach exn))
                  ; ("context", `String "rest_server") ] ))
        (Async.Tcp.Where_to_listen.bind_to All_addresses (On_port port))
        (server_handler ~pool ~graphql_uri ~logger)
    in
    [%log info]
      ~metadata:[("port", `Int port)]
      "Rosetta process running on http://localhost:$port" ;
    Cohttp_async.Server.close_finished server
