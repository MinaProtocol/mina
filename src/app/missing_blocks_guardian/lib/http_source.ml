(* http_source.ml -- reading one block file over HTTP.

   A block bucket answers a request for a block that is not there with an XML
   or HTML error page, under a 404 or sometimes under a 200.  Handing those
   bytes on as though they were a block moves the failure to the archive,
   which then reports a JSON parse error naming neither the URL nor the HTTP
   status.  Every branch of [classify] exists so that the response is judged
   here, where the URL and the status are still known. *)

open Core
open Async

let url_of base ~name = Uri.with_path base (Uri.path base ^ "/" ^ name)

(** Perform the GET, and stop it at [timeout].

    [interrupt] is handed to the client so that a timed out request is really
    torn down.  Wrapping the call in [with_timeout] alone abandons the
    deferred but leaves the socket and its reader open until the peer closes
    it, which in daemon mode leaks one connection per timed out attempt. *)
let request url ~timeout =
  let interrupt = Ivar.create () in
  let get () =
    let%bind response, body =
      Cohttp_async.Client.get ~interrupt:(Ivar.read interrupt) url
    in
    let%map body = Cohttp_async.Body.to_string body in
    (response, body)
  in
  Monitor.try_with ~here:[%here] ~extract_exn:true (fun () ->
      let%map result = Clock_ns.with_timeout timeout (get ()) in
      (match result with `Timeout -> Ivar.fill_if_empty interrupt () | _ -> ()) ;
      result )

(** Describe the response for a payload error message.  A content type that
    is not JSON does not by itself reject the response -- the parse does --
    but naming it makes the reason obvious. *)
let describe response ~location =
  match Cohttp.Header.get (Cohttp.Response.headers response) "content-type" with
  | Some ct when not (String.is_substring ct ~substring:"json") ->
      sprintf "the response to GET %s (content-type: %s)" location ct
  | _ ->
      sprintf "the response to GET %s" location

(** Turn one response into a block or the reason it is not one. *)
let classify response body ~name ~location =
  let status = Cohttp.Response.status response in
  let code = Cohttp.Code.code_of_status status in
  match status with
  | #Cohttp.Code.success_status ->
      Block_payload.of_string ~where:(describe response ~location) body
  | `Not_found ->
      Error (Fetch_error.not_found ~name ~location)
  | #Cohttp.Code.redirection_status ->
      (* Redirects are not followed, exactly as [curl] without [-L] did not
         follow them.  Naming the target is more useful than following it
         silently to somewhere else. *)
      let target =
        Option.value
          (Cohttp.Header.get (Cohttp.Response.headers response) "location")
          ~default:"(no Location header)"
      in
      Error (Fetch_error.redirected ~location ~code ~target)
  | `Forbidden | `Unauthorized ->
      Error (Fetch_error.access_refused ~location ~code ~body)
  | _ when Cohttp.Code.is_server_error code ->
      Error (Fetch_error.server_error ~location ~code ~body)
  | _ ->
      Error (Fetch_error.unexpected_status ~location ~code ~body)

let get base ~name ~timeout =
  let url = url_of base ~name in
  let location = Uri.to_string url in
  match%map request url ~timeout with
  | Error exn ->
      (* DNS failure, connection refused, TLS failure, connection reset.  All
         may succeed on a later attempt. *)
      Error (Fetch_error.connection_failed ~location ~exn)
  | Ok `Timeout ->
      Error (Fetch_error.timed_out ~location ~after:timeout)
  | Ok (`Result (response, body)) ->
      classify response body ~name ~location
