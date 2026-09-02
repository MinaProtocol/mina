(* Rosetta error-envelope and transport-exception formatting.  See
   [errors.mli] for contract.  The goal is to produce one-line human
   messages that are safe to splat into a [{"error": "..."}] JSON field:
   no raw OCaml exception syntax, no giant HTTP bodies. *)

open Core

let max_body_chars = 500

(* Collapse every run of whitespace, newlines included, into one space.
   A reverse proxy answers with a multi-line HTML page, and [errors.mli]
   promises a message that is safe to put on one log line or in a JSON
   [error] field. *)
let single_line s =
  String.split_on_chars s ~on:[ ' '; '\t'; '\n'; '\r' ]
  |> List.filter ~f:(fun part -> not (String.is_empty part))
  |> String.concat ~sep:" "

let truncate s =
  let s = single_line s in
  if String.length s <= max_body_chars then s
  else String.sub s ~pos:0 ~len:max_body_chars ^ "... (truncated)"

(* The [message] of a Rosetta error envelope
   ({"code":_,"message":_,"retriable":_,...}).  We decode only that one
   field, and tolerate an envelope that omits the other required fields,
   because the sole purpose here is to recover a readable message from
   whatever the server sent -- a strict decode would throw the message
   away over an unrelated missing field. *)
module Envelope = struct
  type t = { message : string } [@@deriving of_yojson { strict = false }]
end

let try_parse_envelope body =
  match Or_error.try_with (fun () -> Yojson.Safe.from_string body) with
  | Error _ ->
      None
  | Ok json -> (
      match Envelope.of_yojson json with
      | Ok envelope ->
          Some envelope.Envelope.message
      | Error _ ->
          None )

let format_http_body ~status ~body =
  match try_parse_envelope body with
  | Some msg ->
      (* [truncate], not just [single_line]: Mina's Rosetta propagates
         Postgres and GraphQL errors into [message], so the envelope can
         carry as much text as a raw body. *)
      sprintf "HTTP %d: %s" status (truncate msg)
  | None ->
      if String.is_empty (String.strip body) then sprintf "HTTP %d" status
      else sprintf "HTTP %d: %s" status (truncate body)

let format_exn ~url exn =
  let url_s = Uri.to_string url in
  match exn with
  | Core_unix.Unix_error (Core_unix.ECONNREFUSED, _, _) ->
      sprintf "connection refused to %s" url_s
  | Core_unix.Unix_error (Core_unix.ETIMEDOUT, _, _) ->
      sprintf "timeout connecting to %s" url_s
  | Core_unix.Unix_error (Core_unix.ENETUNREACH, _, _) ->
      sprintf "network unreachable to %s" url_s
  | Core_unix.Unix_error (Core_unix.EHOSTUNREACH, _, _) ->
      sprintf "host unreachable to %s" url_s
  | Core_unix.Unix_error (Core_unix.ECONNRESET, _, _) ->
      sprintf "connection reset by %s" url_s
  | Core_unix.Unix_error (err, _, _) ->
      sprintf "request to %s failed: %s" url_s (Core_unix.Error.message err)
  | Failure m ->
      sprintf "request to %s failed: %s" url_s m
  | _ ->
      (* Last-resort fallback for exceptions we haven't pattern-matched
         above. Keep the message generic so user-visible output never
         leaks raw OCaml exception constructor syntax. *)
      sprintf "request to %s failed" url_s

let%test_unit "format_http_body parses Rosetta envelope" =
  let body =
    {|{"code":4,"message":"Network doesn't exist","details":{"x":1}}|}
  in
  [%test_eq: string]
    (format_http_body ~status:500 ~body)
    "HTTP 500: Network doesn't exist"

let%test_unit "format_http_body falls back to truncated body on non-envelope" =
  let body = "Internal Server Error" in
  [%test_eq: string]
    (format_http_body ~status:500 ~body)
    "HTTP 500: Internal Server Error"

let%test_unit "format_http_body truncates very long bodies" =
  let body = String.make (max_body_chars + 100) 'x' in
  let rendered = format_http_body ~status:502 ~body in
  [%test_pred: string] (String.is_substring ~substring:"truncated") rendered

let%test_unit "format_http_body truncates a long envelope message" =
  let message = String.make (max_body_chars + 100) 'x' in
  let body = Yojson.Safe.to_string (`Assoc [ ("message", `String message) ]) in
  [%test_pred: string]
    (String.is_substring ~substring:"truncated")
    (format_http_body ~status:500 ~body)

let%test_unit "format_http_body renders a multi-line body on one line" =
  let body = "<html>\n<head><title>502 Bad Gateway</title></head>\n</html>" in
  let rendered = format_http_body ~status:502 ~body in
  [%test_pred: string] (fun s -> not (String.contains s '\n')) rendered ;
  [%test_pred: string]
    (String.is_substring ~substring:"502 Bad Gateway")
    rendered

let%test_unit "format_http_body handles empty body" =
  [%test_eq: string] (format_http_body ~status:504 ~body:"") "HTTP 504"

let%test_unit "format_exn ECONNREFUSED is readable" =
  let url = Uri.of_string "http://localhost:9999" in
  let exn =
    Core_unix.Unix_error (Core_unix.ECONNREFUSED, "connect", "127.0.0.1:9999")
  in
  [%test_eq: string] (format_exn ~url exn)
    "connection refused to http://localhost:9999"

let%test_unit "format_exn never leaks OCaml Unix_error syntax" =
  let url = Uri.of_string "http://example.invalid" in
  let exn = Core_unix.Unix_error (Core_unix.ECONNREFUSED, "connect", "x") in
  let s = format_exn ~url exn in
  [%test_pred: string]
    (fun s -> not (String.is_substring s ~substring:"Unix_error"))
    s ;
  [%test_pred: string]
    (fun s -> not (String.is_substring s ~substring:"Unix."))
    s

let%test_unit "format_exn handles ETIMEDOUT" =
  let url = Uri.of_string "http://slow.example" in
  let exn = Core_unix.Unix_error (Core_unix.ETIMEDOUT, "connect", "x") in
  [%test_eq: string] (format_exn ~url exn)
    "timeout connecting to http://slow.example"
