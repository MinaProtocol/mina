(** HTTP entrypoint for [mina-graphql-mock].

    Mirrors [src/test/node_status_mock_server/node_status_mock_server.ml]
    for the Cohttp_async wiring, then routes [POST /graphql] through
    [Graphql_async.Schema.execute] against [Mock_schema.schema] with the
    persona threaded as context.

    Routes:
    - [POST /graphql] — execute a GraphQL query against the mock
    - [GET  /health]  — readiness probe, returns [200 OK]
*)

open Core
open Async

let json_headers =
  Cohttp.Header.of_list [ ("Content-Type", "application/json") ]

let respond_json ?(status = `OK) body =
  Cohttp_async.Server.respond_string ~status ~headers:json_headers body

(** Parse a [POST /graphql] body. Real daemon supports both
    [application/json] and [application/graphql]; v0.1 accepts JSON only
    and falls back to assuming the whole body is the query string. *)
let parse_request ~headers ~body_str =
  let content_type =
    Cohttp.Header.get headers "Content-Type"
    |> Option.value ~default:"application/json"
  in
  match content_type with
  | "application/graphql" ->
      Ok (body_str, None, None)
  | _ -> (
      try
        let json = Yojson.Safe.from_string body_str in
        let query =
          Yojson.Safe.Util.(json |> member "query" |> to_string)
        in
        let variables =
          Yojson.Safe.Util.(json |> member "variables" |> to_option to_assoc)
          |> Option.map ~f:(fun pairs ->
                 List.map pairs ~f:(fun (k, v) ->
                     (k, Yojson.Basic.from_string (Yojson.Safe.to_string v)) ) )
        in
        let op_name =
          Yojson.Safe.Util.(json |> member "operationName" |> to_option to_string)
        in
        Ok (query, variables, op_name)
      with exn -> Error (Exn.to_string exn) )

(** Execute a parsed GraphQL request against the mock schema. *)
let execute ~persona (query, variables, _op_name) =
  match Graphql_parser.parse query with
  | Error msg ->
      return
        (`Assoc
          [ ( "errors"
            , `List [ `Assoc [ ("message", `String msg) ] ] )
          ] )
  | Ok parsed -> (
      let%map result =
        Graphql_async.Schema.execute Mock_schema.schema persona
          ?variables parsed
      in
      match result with
      | Ok (`Response json) ->
          (* graphql-async returns `Yojson.Basic.t`; widen to `Safe`. *)
          (json :> Yojson.Safe.t)
      | Ok (`Stream _) ->
          (* Subscriptions out of scope for v0.1 over plain HTTP. *)
          `Assoc
            [ ( "errors"
              , `List
                  [ `Assoc
                      [ ( "message"
                        , `String
                            "subscriptions not supported by mina-graphql-mock"
                        )
                      ]
                  ] )
            ]
      | Error err -> (err :> Yojson.Safe.t) )

let make_handler ~persona =
  fun ~body _sock req ->
   let uri = Cohttp.Request.uri req in
   let meth = Cohttp.Request.meth req in
   let path = Uri.path uri in
   let lift x = `Response x in
   match (meth, path) with
   | `GET, "/health" ->
       Cohttp_async.Server.respond_string ~status:`OK "OK" >>| lift
   | `POST, "/graphql" -> (
       let%bind body_str = Cohttp_async.Body.to_string body in
       match parse_request ~headers:(Cohttp.Request.headers req) ~body_str with
       | Error msg ->
           respond_json ~status:`Bad_request
             (Yojson.Safe.to_string
                (`Assoc
                  [ ( "errors"
                    , `List [ `Assoc [ ("message", `String msg) ] ] )
                  ] ) )
           >>| lift
       | Ok parsed ->
           let%bind result = execute ~persona parsed in
           respond_json (Yojson.Safe.to_string result) >>| lift )
   | _ ->
       Cohttp_async.Server.respond_string ~status:`Not_found "Not found"
       >>| lift

let command =
  Command.async
    ~summary:"Canned-persona Mina daemon GraphQL mock server"
    (let%map_open.Command port =
       flag "--port" (required int) ~doc:"PORT Port to listen on"
     and persona_path =
       flag "--persona" (optional string)
         ~doc:"PATH Persona JSON file (defaults to bundled persona.json)"
     in
     fun () ->
       let path =
         Option.value persona_path
           ~default:"src/test/daemon/graphql_mock/persona.json"
       in
       let persona = Persona.load_exn path in
       let%bind _server =
         Cohttp_async.Server.create_expert
           ~on_handler_error:
             (`Call
               (fun _net exn ->
                 eprintf "graphql_mock error: %s\n" (Exn.to_string exn) ) )
           (Async.Tcp.Where_to_listen.of_port port)
           (make_handler ~persona)
       in
       printf "mina-graphql-mock listening on port %d (persona: %s)\n" port path ;
       Deferred.never () )

let () = Command.run command
