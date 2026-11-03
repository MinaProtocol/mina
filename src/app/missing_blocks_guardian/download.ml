(* download.ml -- check a bucket and fetch one block file by http, https or
   file URL *)

open Core
open Async

(* RFC 6125 name matching: a leading "*" stands for one whole label. *)
let host_matches ~host name =
  let host = String.lowercase host and name = String.lowercase name in
  match String.chop_prefix name ~prefix:"*." with
  | None ->
      String.equal host name
  | Some suffix -> (
      match String.lsplit2 host ~on:'.' with
      | Some (label, rest) ->
          (not (String.is_empty label)) && String.equal rest suffix
      | None ->
          false )

(* The default TLS client checks only the certificate chain. This also checks
   that the certificate SAN (subject alternative name) list contains the
   host. *)
let ssl_config url =
  Option.map (Uri.host url) ~f:(fun host ->
      Conduit_async.V2.Ssl.Config.create ~hostname:host
        ~verify:(fun connection ->
          return
            ( match Async_ssl.Ssl.Connection.peer_certificate connection with
            | Some (Ok certificate) ->
                List.exists
                  (Async_ssl.Ssl.Certificate.subject_alt_names certificate)
                  ~f:(host_matches ~host)
            | Some (Error _) | None ->
                false ) )
        () )

(* Runs [f] and returns its failure as a short text: the message of a
   Failure, or the exception, without the backtrace that the Async monitor
   adds. *)
let try_with f =
  match%map Monitor.try_with ~extract_exn:true f with
  | Ok value ->
      Ok value
  | Error (Failure text) ->
      Error (Error.of_string text)
  | Error exn ->
      Error (Error.of_exn exn)

(* Saves [url] as [file]. An HTTP response that is not a success is an
   error, so that an error page is never saved as a block. *)
let fetch ~url ~file =
  let url = Uri.of_string url in
  try_with (fun () ->
      match Uri.scheme url with
      | Some ("http" | "https") ->
          let%bind response, body =
            Cohttp_async.Client.get ?ssl_config:(ssl_config url) url
          in
          let status = Cohttp.Response.status response in
          if Cohttp.Code.is_success (Cohttp.Code.code_of_status status) then
            let%bind body = Cohttp_async.Body.to_string body in
            Writer.save file ~contents:body
          else
            let%bind () = Cohttp_async.Body.drain body in
            failwithf "HTTP %s" (Cohttp.Code.string_of_status status) ()
      | Some "file" ->
          let%bind contents = Reader.file_contents (Uri.path url) in
          Writer.save file ~contents
      | scheme ->
          failwithf "URL scheme not supported: %s"
            (Option.value scheme ~default:"none")
            () )

(* Checks that the bucket at [url] answers. An HTTP bucket exists when its
   root answers with any status but 404: a public listing is 200, a private
   bucket is 403, and Google Cloud Storage and S3 answer 404 for a bucket
   that does not exist. A file bucket is a directory. *)
let probe ~url =
  let root = Uri.of_string (url ^ "/") in
  try_with (fun () ->
      match Uri.scheme root with
      | Some ("http" | "https") -> (
          let%bind response, body =
            Cohttp_async.Client.get ?ssl_config:(ssl_config root) root
          in
          let%map () = Cohttp_async.Body.drain body in
          match Cohttp.Response.status response with
          | `Not_found ->
              failwithf "HTTP 404 Not Found for %s, the bucket does not exist"
                (Uri.to_string root) ()
          | _ ->
              () )
      | Some "file" -> (
          match%map Sys.is_directory (Uri.path root) with
          | `Yes ->
              ()
          | `No | `Unknown ->
              failwithf "%s is not a directory" (Uri.path root) () )
      | scheme ->
          failwithf "URL scheme not supported: %s"
            (Option.value scheme ~default:"none")
            () )
