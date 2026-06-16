(* HTTP core for the Rosetta client library.  See [http.mli]. *)

open Core_kernel
open Async

type t =
  { base_uri : Uri.t; blockchain : string; network : string; timeout : float }

let default_blockchain = "mina"

let default_network = "testnet"

let default_timeout = 5.0

let create ~base_uri ?(blockchain = default_blockchain)
    ?(network = default_network) ?(timeout = default_timeout) () =
  { base_uri; blockchain; network; timeout }

let base_uri t = t.base_uri

let blockchain t = t.blockchain

let network t = t.network

let timeout t = t.timeout

let network_identifier t =
  `Assoc
    [ ("blockchain", `String t.blockchain); ("network", `String t.network) ]

let join_uri base path =
  let s = Uri.to_string base in
  let s = String.rstrip ~drop:(Char.equal '/') s in
  let path = String.lstrip ~drop:(Char.equal '/') path in
  Uri.of_string (s ^ "/" ^ path)

let pretty j = Yojson.Safe.pretty_to_string j

let compact j = Yojson.Safe.to_string j

(* Common envelope for HTTP requests: enforces [t.timeout], folds all
   transport/decode failures into the error channel, and renders any
   error via [Errors] so callers never see raw OCaml exception text. *)
let with_request t ~uri ~make_req ~describe =
  let req =
    Deferred.Or_error.try_with ~here:[%here] ~extract_exn:true (fun () ->
        let%bind response, body_pipe = make_req () in
        let%map body_str = Cohttp_async.Body.to_string body_pipe in
        (response, body_str) )
  in
  match%bind Async.with_timeout (Time.Span.of_sec t.timeout) req with
  | `Timeout ->
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

let post_json t ~path ~body =
  let uri = join_uri t.base_uri path in
  let headers =
    Cohttp.Header.of_list
      [ ("Content-Type", "application/json"); ("Accept", "application/json") ]
  in
  let body_str = Yojson.Safe.to_string body in
  with_request t ~uri ~describe:"POST" ~make_req:(fun () ->
      Cohttp_async.Client.post ~headers
        ~body:(Cohttp_async.Body.of_string body_str)
        uri )

let get_json t ~path =
  let uri = join_uri t.base_uri path in
  let headers = Cohttp.Header.of_list [ ("Accept", "application/json") ] in
  with_request t ~uri ~describe:"GET" ~make_req:(fun () ->
      Cohttp_async.Client.get ~headers uri )

let%test_unit "with_request times out stalled response body" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let t =
        create ~base_uri:(Uri.of_string "http://localhost") ~timeout:0.01 ()
      in
      let uri = join_uri (base_uri t) "/slow" in
      let body_reader, _body_writer = Pipe.create () in
      let response = Cohttp_async.Response.make ~status:`OK () in
      let body = Cohttp_async.Body.of_pipe body_reader in
      match%map
        with_request t ~uri ~describe:"GET" ~make_req:(fun () ->
            Deferred.return (response, body) )
      with
      | Ok json ->
          failwith
            ( "expected stalled response body to time out, got "
            ^ Yojson.Safe.to_string json )
      | Error e ->
          [%test_pred: string]
            (String.is_substring ~substring:"timeout after")
            (Error.to_string_hum e) )
