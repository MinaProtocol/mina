(* download.ml -- fetch one block file by http, https or file URL *)

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

(* Saves [url] as [file]. An HTTP body is saved whatever its status. *)
let fetch ~url ~file =
  let url = Uri.of_string url in
  Monitor.try_with_or_error (fun () ->
      match Uri.scheme url with
      | Some ("http" | "https") ->
          let%bind _response, body =
            Cohttp_async.Client.get ?ssl_config:(ssl_config url) url
          in
          let%bind body = Cohttp_async.Body.to_string body in
          Writer.save file ~contents:body
      | Some "file" ->
          let%bind contents = Reader.file_contents (Uri.path url) in
          Writer.save file ~contents
      | scheme ->
          failwithf "URL scheme not supported: %s"
            (Option.value scheme ~default:"none")
            () )
