(** Minimal client for the daemon's ITN GraphQL server.

    The ITN endpoint requires every request to carry an [Authorization] header
    of the form

      [Signature <pubkey-b64> <sig-b64>]                       (unsequenced)
      [Signature <pubkey-b64> <sig-b64> ; Sequencing <uuid> <n>] (sequenced)

    where the Ed25519 signature is over a message whose layout matches
    [src/app/cli/src/init/graphql_internal.ml]:

      unsequenced:  body                                       (used by [auth])
      sequenced:    seq_no_hi :: seq_no_lo :: uuid :: body

    The unsequenced form is only valid for the [auth] query — every other
    request must be sequenced and the [n] must match the daemon's expected
    sequence number for the signer.

    This module wraps signing and posting so test code (and any future
    automation tooling that talks to the ITN endpoint) doesn't have to
    reinvent the wire format each time. *)

open Core
open Async

let default_path = "/graphql"

let default_timeout = Time.Span.of_sec 30.

let make_uri ?(host = "localhost") ?(scheme = "http") ?(path = default_path)
    ~port () =
  Uri.make ~scheme ~host ~port ~path ()

(** [unsequenced_auth_header ~privkey ~pubkey_b64 ~body] signs [body] verbatim
    with [privkey] and returns the value to put in the [Authorization]
    header.  Use for the initial [auth] query. *)
let unsequenced_auth_header ~privkey ~pubkey_b64 ~body =
  let signature = Itn_crypto.sign ~key:privkey body in
  sprintf "Signature %s %s" pubkey_b64 signature

(** [sequenced_auth_header ~privkey ~pubkey_b64 ~uuid ~seq_no ~body] builds the
    [Authorization] header for a sequenced request.  The signed message is
    [<seq_no_hi><seq_no_lo><uuid><body>] to match the daemon's verifier.

    Raises [Invalid_argument] if [seq_no] is outside the UInt16 range — the
    daemon's sequence-number type is [Unsigned.UInt16], so anything else is
    necessarily a client bug. *)
let sequenced_auth_header ~privkey ~pubkey_b64 ~uuid ~seq_no ~body =
  if seq_no < 0 || seq_no > 0xffff then
    invalid_argf "Itn_graphql_client: seq_no %d out of UInt16 range" seq_no () ;
  let seq_no_lo = seq_no land 0xff |> Char.of_int_exn in
  let seq_no_hi = (seq_no lsr 8) land 0xff |> Char.of_int_exn in
  let msg = sprintf "%c%c%s%s" seq_no_hi seq_no_lo uuid body in
  let signature = Itn_crypto.sign ~key:privkey msg in
  sprintf "Signature %s %s ; Sequencing %s %d" pubkey_b64 signature uuid seq_no

let auth_query =
  {|{"query":"{ auth { serverUuid signerSequenceNumber } }","variables":null}|}

(** [post ~uri ~auth_header ~body] POSTs [body] to [uri] with the supplied
    [Authorization] header.  Cohttp exceptions and a missing response within
    [?timeout] are converted to [Or_error.t]. *)
let post ?(timeout = default_timeout) ~uri ~auth_header ~body () =
  let headers =
    Cohttp.Header.of_list
      [ ("Accept", "application/json")
      ; ("Content-Type", "application/json")
      ; ("Authorization", auth_header)
      ]
  in
  let do_post () =
    let%bind response, body_in =
      Cohttp_async.Client.post ~headers
        ~body:(Cohttp_async.Body.of_string body)
        uri
    in
    let%map body_str = Cohttp_async.Body.to_string body_in in
    let status =
      Cohttp.Code.code_of_status (Cohttp_async.Response.status response)
    in
    (status, body_str)
  in
  match%bind
    Async.Clock.with_timeout timeout
      (Monitor.try_with ~extract_exn:true do_post)
  with
  | `Timeout ->
      Deferred.Or_error.errorf "Itn_graphql_client: POST %s timed out"
        (Uri.to_string uri)
  | `Result (Ok r) ->
      Deferred.Or_error.return r
  | `Result (Error exn) ->
      Deferred.Or_error.errorf "Itn_graphql_client: POST %s failed: %s"
        (Uri.to_string uri) (Exn.to_string exn)

(** [probe ?timeout ~uri ()] sends a no-auth POST to [uri] just to confirm the
    ITN listener is bound — the daemon's [Authorization]-required check will
    reject the body, but a 401 means a real ITN server is on the wire.  Returns
    [`Ready] once *any* HTTP response comes back, [`Timeout] otherwise.

    Note: this only proves the port is bound and speaking HTTP.  Callers should
    follow up with a real [send_auth] handshake to confirm identity. *)
let probe ?(timeout = Time.Span.of_sec 60.) ~uri () =
  let deadline = Time.add (Time.now ()) timeout in
  let rec loop () =
    let attempt =
      Monitor.try_with ~extract_exn:true (fun () ->
          Cohttp_async.Client.post
            ~body:(Cohttp_async.Body.of_string auth_query)
            uri )
    in
    match%bind attempt with
    | Ok (_, body) ->
        let%map _ = Cohttp_async.Body.to_string body in
        `Ready
    | Error _ ->
        if Time.( >= ) (Time.now ()) deadline then Deferred.return `Timeout
        else
          let%bind () = after (Time.Span.of_sec 1.) in
          loop ()
  in
  loop ()

(** GraphQL custom scalars like [UInt16] serialise as a JSON string even
    though they hold an integer.  Accept either form so we don't get
    [Type_error] surprises if the encoding changes. *)
let json_int_or_string json =
  match json with
  | `Int n ->
      n
  | `String s ->
      Int.of_string s
  | other ->
      failwithf "expected int or stringified int, got %s"
        (Yojson.Safe.to_string other)
        ()

(** Parse a GraphQL response body into the [data] sub-tree, surfacing any
    server-side [errors] field as an [Or_error.t] failure.  GraphQL servers
    emit application-level errors with HTTP 200 + an [errors] key, so a status
    check is not enough to call the request a success. *)
let parse_graphql_data body =
  Or_error.try_with (fun () ->
      let open Yojson.Safe.Util in
      let json = Yojson.Safe.from_string body in
      ( match member "errors" json with
      | `Null ->
          ()
      | errors ->
          failwithf "GraphQL errors in response: %s"
            (Yojson.Safe.to_string errors)
            () ) ;
      member "data" json )

(** [send_auth ~uri ~privkey ~pubkey_b64] performs the [auth] handshake against
    [uri], returning the daemon's UUID + the next expected sequence number for
    this signer on success. *)
let send_auth ~uri ~privkey ~pubkey_b64 =
  let auth_header =
    unsequenced_auth_header ~privkey ~pubkey_b64 ~body:auth_query
  in
  match%map post ~uri ~auth_header ~body:auth_query () with
  | Error _ as e ->
      e
  | Ok (status, body) ->
      if status <> 200 then
        Or_error.errorf "ITN auth expected 200, got %d.  Body: %s" status body
      else
        let open Or_error.Let_syntax in
        let%bind data = parse_graphql_data body in
        Or_error.try_with (fun () ->
            let open Yojson.Safe.Util in
            let auth = data |> member "auth" in
            let uuid = auth |> member "serverUuid" |> to_string in
            let seq_no =
              auth |> member "signerSequenceNumber" |> json_int_or_string
            in
            (uuid, seq_no) )

(** [send_sequenced ~uri ~privkey ~pubkey_b64 ~uuid ~seq_no ~body] posts a
    sequenced GraphQL [body] against [uri] using the supplied identity and
    daemon-issued sequencing tokens.  Returns ([status_code], [response_body])
    on a successful HTTP exchange, or an error if the network call fails, the
    HTTP status is non-2xx, or the GraphQL body contains an [errors] field.

    Note: the daemon increments its internal counter on every successful
    sequenced request, so callers should bump their local [seq_no] after a
    success before sending the next query. *)
let send_sequenced ~uri ~privkey ~pubkey_b64 ~uuid ~seq_no ~body =
  let auth_header =
    sequenced_auth_header ~privkey ~pubkey_b64 ~uuid ~seq_no ~body
  in
  match%map post ~uri ~auth_header ~body () with
  | Error _ as e ->
      e
  | Ok (status, body) ->
      if status < 200 || status >= 300 then
        Or_error.errorf "ITN sequenced request expected 2xx, got %d.  Body: %s"
          status body
      else
        let open Or_error.Let_syntax in
        let%map _data = parse_graphql_data body in
        (status, body)
