(** Mock HTTP server for testing Mina daemon's node status/error reporting.

    The Mina daemon supports [--node-status-url] and [--node-error-url] CLI
    flags that cause it to periodically POST JSON payloads to an HTTP endpoint.
    This server collects those payloads so tests can later retrieve and validate
    them.

    Routes:
    - [POST /node-status]      — appends request body to the status collection
    - [POST /node-error]       — appends request body to the error collection
    - [GET  /collected-status] — returns all collected status payloads as a JSON array
    - [GET  /collected-errors] — returns all collected error payloads as a JSON array
    - [GET  /health]           — returns 200 OK (readiness probe) *)

open Core
open Async

(** Mutable collector that stores POST bodies in insertion order. *)
module Collector : sig
  type t

  val create : unit -> t

  (** Append a payload to the collection. *)
  val add : t -> string -> unit

  (** Return all collected payloads as a JSON array of strings,
      in the order they were received. *)
  val to_json_string : t -> string
end = struct
  type t = string Queue.t

  let create () = Queue.create ()

  let add t body = Queue.enqueue t body

  let to_json_string t =
    Queue.to_list t
    |> List.map ~f:(fun s -> `String s)
    |> (fun items -> `List items)
    |> Yojson.Safe.to_string
end

let json_headers =
  Cohttp.Header.of_list [ ("Content-Type", "application/json") ]

(** Respond with a plain-text 200 OK. *)
let respond_ok body = Cohttp_async.Server.respond_string ~status:`OK body

(** Respond with 200 and a JSON body. *)
let respond_json body =
  Cohttp_async.Server.respond_string ~status:`OK ~headers:json_headers body

(** Build the request handler for the given status and error collectors. *)
let make_handler ~status_collector ~error_collector ~body _sock req =
  let uri = Cohttp.Request.uri req in
  let meth = Cohttp.Request.meth req in
  let path = Uri.path uri in
  let lift x = `Response x in
  let collect_post collector =
    let%bind body_str = Cohttp_async.Body.to_string body in
    Collector.add collector body_str ;
    respond_ok "OK" >>| lift
  in
  match (meth, path) with
  | `POST, "/node-status" ->
      collect_post status_collector
  | `POST, "/node-error" ->
      collect_post error_collector
  | `GET, "/collected-status" ->
      respond_json (Collector.to_json_string status_collector) >>| lift
  | `GET, "/collected-errors" ->
      respond_json (Collector.to_json_string error_collector) >>| lift
  | `GET, "/health" ->
      respond_ok "OK" >>| lift
  | _ ->
      Cohttp_async.Server.respond_string ~status:`Not_found "Not found" >>| lift

let command =
  Command.async ~summary:"Mock HTTP server for node status/error reporting"
    (let%map_open.Command port =
       flag "--port" (required int) ~doc:"PORT Port to listen on"
     in
     fun () ->
       let status_collector = Collector.create () in
       let error_collector = Collector.create () in
       let%bind _server =
         Cohttp_async.Server.create_expert
           ~on_handler_error:
             (`Call (fun _net exn -> eprintf "Error: %s\n" (Exn.to_string exn)))
           (Async.Tcp.Where_to_listen.of_port port)
           (make_handler ~status_collector ~error_collector)
       in
       printf "Node status mock server listening on port %d\n" port ;
       Deferred.never () )

let () = Command.run command
