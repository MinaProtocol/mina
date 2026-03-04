(** Client module for the node-status mock server.

    Manages the lifecycle (start / health-check / query / stop) of the
    [mina-node-status-mock-server] subprocess and provides helpers for
    retrieving the collected payloads it receives from the Mina daemon. *)

open Core
open Async

(* ------------------------------------------------------------------
   Executor — locates the mock-server binary via the standard
   AutoDetect mechanism (dune _build → debian package → dune exec).
   ------------------------------------------------------------------ *)

module Paths = struct
  let dune_name = "src/test/node_status_mock_server/node_status_mock_server.exe"

  let official_name = "mina-node-status-mock-server"
end

module Executor = Executor.Make (Paths)

(* ------------------------------------------------------------------
   HTTP helpers — thin wrappers around [Cohttp_async.Client].
   ------------------------------------------------------------------ *)

(** [get_string url] performs a GET request and returns the response body. *)
let get_string url =
  let%bind resp, body = Cohttp_async.Client.get (Uri.of_string url) in
  let%bind body_str = Cohttp_async.Body.to_string body in
  let status_code = Cohttp.Code.code_of_status (Cohttp.Response.status resp) in
  if Int.equal status_code 200 then Deferred.return body_str
  else failwithf "GET %s failed with HTTP %d: %s" url status_code body_str ()

(** [get_json_string_list url] GETs [url], parses the response as a JSON
    array of strings, and returns them as an OCaml list. *)
let get_json_string_list url =
  let%bind body_str = get_string url in
  let json = Yojson.Safe.from_string body_str in
  match json with
  | `List items ->
      let strings =
        List.map items ~f:(function
          | `String s ->
              s
          | _ ->
              failwithf
                "Expected JSON array of strings from %s, but found non-string \
                 element"
                url () )
      in
      Deferred.return strings
  | _ ->
      failwithf "Expected JSON array of strings from %s" url ()

(* ------------------------------------------------------------------
   Public API
   ------------------------------------------------------------------ *)

type t = { port : int; process : Process.t }

(** [start ~port] launches the mock server on [port] as a background process. *)
let start ~port =
  let%bind _, process =
    Executor.run_in_background Executor.default
      ~args:[ "--port"; string_of_int port ]
      ()
  in
  Deferred.return { port; process }

(** [health_check ~port ?retries ?delay ()] polls [GET /health] until the
    server responds, retrying up to [retries] times with [delay] seconds
    between attempts. *)
let health_check ~port ?(retries = 30) ?(delay = 1.0) () =
  let url = sprintf "http://localhost:%d/health" port in
  let rec go remaining =
    match%bind Monitor.try_with (fun () -> get_string url) with
    | Ok _ ->
        Deferred.unit
    | Error _ ->
        if remaining > 0 then
          let%bind () = after (Time.Span.of_sec delay) in
          go (remaining - 1)
        else failwith "Mock server health check timed out"
  in
  go retries

(** [collected_status ~port] returns all node-status payloads received so far. *)
let collected_status ~port =
  get_json_string_list (sprintf "http://localhost:%d/collected-status" port)

(** [collected_errors ~port] returns all node-error payloads received so far. *)
let collected_errors ~port =
  get_json_string_list (sprintf "http://localhost:%d/collected-errors" port)

(** [stop t] kills the mock-server process. *)
let stop t =
  let%map result = Utils.force_kill t.process in
  Or_error.ok_exn result
