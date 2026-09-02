(* HTTP core for the Rosetta client library.  See [http.mli]. *)

open Core
open Async

type t =
  { base_uri : Uri.t; blockchain : string; network : string; timeout : float }

(* Normalise the base URI once, here, rather than on every request: drop
   any trailing slash from its path so that appending an endpoint path
   (which always starts with "/") cannot produce a double slash.  Every
   other part of the URI -- scheme, userinfo, host, port, query,
   fragment, percent-encoding -- is left to [Uri]. *)
let normalize_base base_uri =
  Uri.with_path base_uri
    (String.rstrip ~drop:(Char.equal '/') (Uri.path base_uri))

let create ~base_uri ?(blockchain = Defaults.blockchain)
    ?(network = Defaults.network) ?(timeout = Defaults.http_timeout) () =
  { base_uri = normalize_base base_uri; blockchain; network; timeout }

let base_uri t = t.base_uri

let blockchain t = t.blockchain

let network t = t.network

let timeout t = t.timeout

let network_identifier t =
  Rosetta_models.Network_identifier.create t.blockchain t.network

(* Append an endpoint path to the (already normalised) base path.  A
   base URI may carry a path of its own -- a Rosetta server behind a
   reverse proxy at http://host/rosetta -- so the endpoint is appended to
   [Uri.path base] instead of replacing it. *)
let join_uri base path =
  let path = if String.is_prefix path ~prefix:"/" then path else "/" ^ path in
  Uri.with_path base (Uri.path base ^ path)

let pretty j = Yojson.Safe.pretty_to_string j

let compact j = Yojson.Safe.to_string j

(* One request/response exchange: enforces [t.timeout], folds all
   transport/decode failures into the error channel, and renders any
   error via [Errors] so callers never see raw OCaml exception text.

   Racing the deferred against [with_timeout] is not enough on its own:
   it stops us waiting, but leaves the socket open until the far end
   closes it, and [rosetta-healthcheck wait] is a probe loop, so one
   invocation against a sick server would pile up file descriptors.  Two
   levers close it instead:

   - [interrupt], which Cohttp passes to the TCP connect, so a connect
     that never completes is abandoned with its socket;
   - closing the response body's pipe, which is what Cohttp itself waits
     on before it closes the reader and writer (see [Pipe.closed] in
     cohttp-async's [Client.request]), so a response whose body stalls
     is torn down too.

   One case is left: a server that completes the TCP connect and then
   never sends a response line.  Cohttp-async 5.0.0 exposes no handle on
   that connection -- [Client.Connection.close] cannot preempt its own
   in-flight request either, because the throttle runs its [at_kill]
   only once the blocked job finishes -- so closing it would mean owning
   the transport here rather than using [Cohttp_async.Client].  The leak
   that remains is bounded by one run of a short-lived CLI and cannot
   reach the default descriptor limit at any usable --timeout/--interval
   pair. *)
let with_request t ~uri ~make_req ~describe =
  let timed_out = Ivar.create () in
  let body_pipe = Ivar.create () in
  let exchange () =
    let%bind response, body = make_req ~interrupt:(Ivar.read timed_out) in
    let pipe = Cohttp_async.Body.to_pipe body in
    Ivar.fill body_pipe pipe ;
    let%map chunks = Pipe.to_list pipe in
    (response, String.concat chunks)
  in
  let result =
    Deferred.Or_error.try_with ~here:[%here] ~extract_exn:true exchange
  in
  match%bind Async.with_timeout (Time_float.Span.of_sec t.timeout) result with
  | `Timeout ->
      Ivar.fill_if_empty timed_out () ;
      Option.iter (Ivar.peek body_pipe) ~f:Pipe.close_read ;
      Deferred.Or_error.errorf "timeout after %.1fs: %s %s" t.timeout describe
        (Uri.to_string uri)
  | `Result (Error e) ->
      let msg =
        match Error.to_exn e with exn -> Errors.format_exn ~url:uri exn
      in
      Deferred.Or_error.error_string msg
  | `Result (Ok (response, body_str)) -> (
      let status = Cohttp_async.Response.status response in
      let code = Cohttp.Code.code_of_status status in
      if code < 200 || code >= 300 then
        Deferred.Or_error.error_string
          (Errors.format_http_body ~status:code ~body:body_str)
      else
        match
          Or_error.try_with (fun () -> Yojson.Safe.from_string body_str)
        with
        | Ok j ->
            Deferred.Or_error.return j
        | Error _ ->
            Deferred.Or_error.errorf
              "invalid JSON response from %s (first 200 chars: %s)"
              (Uri.to_string uri)
              ( if String.length body_str > 200 then
                  String.sub body_str ~pos:0 ~len:200
                else body_str ) )

(* Every Rosetta endpoint answers JSON; only the ones we send a body to
   also need to declare the request's own content type.  [request_headers]
   is derived from [response_headers] so the shared Accept is stated once. *)
let response_headers = Cohttp.Header.init_with "Accept" "application/json"

let request_headers =
  Cohttp.Header.add response_headers "Content-Type" "application/json"

let post_json t ~path ~body =
  let uri = join_uri t.base_uri path in
  let body_str = Yojson.Safe.to_string body in
  with_request t ~uri ~describe:"POST" ~make_req:(fun ~interrupt ->
      Cohttp_async.Client.post ~interrupt ~headers:request_headers
        ~body:(Cohttp_async.Body.of_string body_str)
        uri )

let get_json t ~path =
  let uri = join_uri t.base_uri path in
  with_request t ~uri ~describe:"GET" ~make_req:(fun ~interrupt ->
      Cohttp_async.Client.get ~interrupt ~headers:response_headers uri )

(* Regression guard: when a response's body stalls, the timeout must
   close the connection, not merely stop waiting on it.  The server here
   sends a complete set of response headers promising 100 bytes and then
   sends nothing, so the only way its reader reaches EOF is if the client
   hangs up. *)
let%test_unit "a timed-out response body closes its connection" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let hung_up = Ivar.create () in
      let%bind server =
        Tcp.Server.create ~on_handler_error:`Ignore
          Tcp.Where_to_listen.of_port_chosen_by_os (fun _addr reader writer ->
            Writer.write writer "HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\n" ;
            let%bind () = Writer.flushed writer in
            let%map (_ : string) = Reader.contents reader in
            Ivar.fill_if_empty hung_up () )
      in
      let port = Tcp.Server.listening_on server in
      let t =
        create
          ~base_uri:(Uri.of_string (sprintf "http://127.0.0.1:%d" port))
          ~timeout:0.2 ()
      in
      let%bind result = post_json t ~path:"/stalled-body" ~body:(`Assoc []) in
      [%test_pred: string]
        (String.is_substring ~substring:"timeout after")
        ( match result with
        | Ok json ->
            "expected a timeout, got " ^ Yojson.Safe.to_string json
        | Error e ->
            Error.to_string_hum e ) ;
      let%bind () =
        match%map
          Async.with_timeout (Time_float.Span.of_sec 5.0) (Ivar.read hung_up)
        with
        | `Timeout ->
            failwith "the timed-out request left its connection open"
        | `Result () ->
            ()
      in
      Tcp.Server.close server )
