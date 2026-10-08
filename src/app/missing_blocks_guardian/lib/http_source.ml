(* http_source.ml -- block files served over HTTP. Every answer is judged
   here, where the URL and the status are still known. *)

open Core
open Async

(** base URL, no trailing slash *)
type t = Uri.t

let location base ~name =
  Uri.to_string (Uri.with_path base (Uri.path base ^ "/" ^ name))

(* naming a content type that is not JSON makes a payload error obvious *)
let describe (response : Http_client.response) ~location =
  match Http_client.header response "content-type" with
  | Some ct when not (String.is_substring ct ~substring:"json") ->
      sprintf "the response to GET %s (content-type: %s)" location ct
  | _ ->
      sprintf "the response to GET %s" location

let classify (response : Http_client.response) ~name ~location =
  let code = Cohttp.Code.code_of_status response.status in
  let body = response.body in
  match response.status with
  | #Cohttp.Code.success_status ->
      Block_payload.of_string ~name ~location:(describe response ~location) body
  | `Not_found ->
      Error
        (Fetch_error.block_missing ~name ~location ~answer:"GET returned 404")
  | #Cohttp.Code.redirection_status ->
      (* not followed: naming the target is more useful than going there *)
      let target =
        Option.value
          (Http_client.header response "location")
          ~default:"(no Location header)"
      in
      Error (Fetch_error.redirected ~location ~code ~target)
  | `Forbidden | `Unauthorized ->
      Error (Fetch_error.access_refused ~location ~code ~body)
  | _ when Cohttp.Code.is_server_error code ->
      Error (Fetch_error.server_error ~location ~code ~body)
  | _ ->
      Error (Fetch_error.unexpected_status ~location ~code ~body)

let fetch base ~name ~timeout =
  let location = location base ~name in
  match%map Http_client.get (Uri.of_string location) ~timeout with
  | `Failed exn ->
      Error (Fetch_error.connection_failed ~location ~exn)
  | `Timeout ->
      Error (Fetch_error.timed_out ~location ~after:timeout)
  | `Ok response ->
      classify response ~name ~location
