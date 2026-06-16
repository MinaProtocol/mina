(* Rosetta error-envelope and transport-exception formatting.  See
   [errors.mli] for contract.  The goal is to produce one-line human
   messages that are safe to splat into a [{"error": "..."}] JSON field:
   no raw OCaml exception syntax, no giant HTTP bodies. *)

open Core_kernel

(* Use [Core.Unix] for the [Unix.Unix_error] constructor (Core_kernel
   shadows Unix).  Aliased locally so the pattern-match syntax stays
   natural. *)
module Unix = Core.Unix

let max_body_chars = 500

let truncate s =
  if String.length s <= max_body_chars then s
  else String.sub s ~pos:0 ~len:max_body_chars ^ "... (truncated)"

let try_parse_envelope body =
  match Or_error.try_with (fun () -> Yojson.Safe.from_string body) with
  | Error _ ->
      None
  | Ok (`Assoc fields) ->
      List.Assoc.find fields ~equal:String.equal "message"
      |> Option.bind ~f:(function `String s -> Some s | _ -> None)
  | Ok _ ->
      None

let format_http_body ~status ~body =
  match try_parse_envelope body with
  | Some msg ->
      sprintf "HTTP %d: %s" status msg
  | None ->
      if String.is_empty (String.strip body) then sprintf "HTTP %d" status
      else sprintf "HTTP %d: %s" status (truncate body)

let format_exn ~url exn =
  let url_s = Uri.to_string url in
  match exn with
  | Unix.Unix_error (Unix.ECONNREFUSED, _, _) ->
      sprintf "connection refused to %s" url_s
  | Unix.Unix_error (Unix.ETIMEDOUT, _, _) ->
      sprintf "timeout connecting to %s" url_s
  | Unix.Unix_error (Unix.ENETUNREACH, _, _) ->
      sprintf "network unreachable to %s" url_s
  | Unix.Unix_error (Unix.EHOSTUNREACH, _, _) ->
      sprintf "host unreachable to %s" url_s
  | Unix.Unix_error (Unix.ECONNRESET, _, _) ->
      sprintf "connection reset by %s" url_s
  | Unix.Unix_error (err, _, _) ->
      sprintf "request to %s failed: %s" url_s (Unix.Error.message err)
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

let%test_unit "format_http_body handles empty body" =
  [%test_eq: string] (format_http_body ~status:504 ~body:"") "HTTP 504"

let%test_unit "format_exn ECONNREFUSED is readable" =
  let url = Uri.of_string "http://localhost:9999" in
  let exn = Unix.Unix_error (Unix.ECONNREFUSED, "connect", "127.0.0.1:9999") in
  [%test_eq: string] (format_exn ~url exn)
    "connection refused to http://localhost:9999"

let%test_unit "format_exn never leaks OCaml Unix_error syntax" =
  let url = Uri.of_string "http://example.invalid" in
  let exn = Unix.Unix_error (Unix.ECONNREFUSED, "connect", "x") in
  let s = format_exn ~url exn in
  [%test_pred: string]
    (fun s -> not (String.is_substring s ~substring:"Unix_error"))
    s ;
  [%test_pred: string]
    (fun s -> not (String.is_substring s ~substring:"Unix."))
    s

let%test_unit "format_exn handles ETIMEDOUT" =
  let url = Uri.of_string "http://slow.example" in
  let exn = Unix.Unix_error (Unix.ETIMEDOUT, "connect", "x") in
  [%test_eq: string] (format_exn ~url exn)
    "timeout connecting to http://slow.example"
