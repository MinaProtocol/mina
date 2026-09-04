open Core
open Async

let autogen_path = Filename.temp_dir_name ^/ "coda_cache_dir"

let s3_install_path = Filename.temp_dir_name ^/ "s3_cache_dir"

let s3_keys_bucket_prefix =
  Option.value
    (Sys.getenv "MINA_LEDGER_S3_BUCKET")
    ~default:"https://s3-us-west-2.amazonaws.com/snark-keys-ro.o1test.net"

let manual_install_path = "/var/lib/coda"

(* Homebrew's prefix on Intel and on Apple Silicon. Both are listed
   unconditionally rather than asking [brew --prefix]: these are read-only
   lookup paths and a nonexistent one is simply skipped, whereas the query
   costs a subprocess at module initialization on every platform, Linux
   included. *)
let brew_install_paths = [ "/usr/local/var/coda"; "/opt/homebrew/var/coda" ]

let cache =
  let dir d w = Key_cache.Spec.On_disk { directory = d; should_write = w } in
  ( [ dir manual_install_path false ]
  @ List.map brew_install_paths ~f:(fun d -> dir d false) )
  @ [ dir s3_install_path false
    ; dir autogen_path true
    ; Key_cache.Spec.S3
        { bucket_prefix = s3_keys_bucket_prefix
        ; install_path = s3_install_path
        }
    ]

let env_path =
  match Sys.getenv "MINA_KEYS_PATH" with
  | Some path ->
      path
  | None ->
      manual_install_path

let possible_paths base =
  List.map
    ( (env_path :: brew_install_paths)
    @ [ s3_install_path; autogen_path; manual_install_path ] )
    ~f:(fun d -> d ^/ base)

(* Certificate verification.

   conduit-async performs none of it by default, and the pieces it does offer
   are not enough on their own: [Conduit_async.V2.Ssl.Config.verify_certificate]
   only checks that a peer certificate exists and parses, and async_ssl's
   [hostname] argument merely sets the SNI extension -- it never asks OpenSSL
   to check the name, since [X509_VERIFY_PARAM_set1_host] is not bound.

   So the two halves are done explicitly: [Verify_peer] makes OpenSSL validate
   the chain against the CA store during the handshake, and the name is matched
   against the certificate here. Everything fails closed. *)
module Tls = struct
  (* OpenSSL's built-in CA paths are baked in when it is compiled, which is not
     necessarily where the certificates live on the machine running the daemon
     -- a Nix-built binary is the usual way to end up pointing at a directory
     that does not exist. Setting either of these overrides them; leaving both
     unset keeps OpenSSL's defaults, since async_ssl only calls
     [SSL_CTX_set_default_verify_paths] when neither is given. *)
  let ca_file = Sys.getenv "MINA_SSL_CA_FILE"

  let ca_path = Sys.getenv "MINA_SSL_CA_DIR"

  (* RFC 6125 name matching, deliberately strict:

     - subjectAltName only. The deprecated fall back to the subject's common
       name is the classic way this check is defeated, so a certificate
       without a matching SAN is rejected even if its CN would have matched.
     - A wildcard has to be the whole leftmost label, it matches exactly one
       label, and it may not stand in for a public suffix, so the rest of the
       pattern must itself contain a dot.
     - Comparison is ASCII case-insensitive. Names are compared as given, so
       an internationalized host has to be an A-label already, and an address
       literal will simply fail to match. *)
  let name_matches ~host pattern =
    let host = String.lowercase host and pattern = String.lowercase pattern in
    match String.chop_prefix pattern ~prefix:"*." with
    | None ->
        String.equal host pattern
    | Some rest -> (
        String.contains rest '.'
        &&
        match String.lsplit2 host ~on:'.' with
        | Some (label, host_rest) ->
            (not (String.is_empty label)) && String.equal host_rest rest
        | None ->
            false )

  let%test_unit "name_matches" =
    let check expected ~host pattern =
      [%test_result: bool] ~expect:expected (name_matches ~host pattern)
    in
    check true ~host:"example.com" "example.com" ;
    check true ~host:"EXAMPLE.com" "example.COM" ;
    check false ~host:"example.com" "other.com" ;
    check false ~host:"evil.example.com" "example.com" ;
    (* A wildcard covers exactly one label, and only the leftmost one. *)
    check true ~host:"a.example.com" "*.example.com" ;
    check false ~host:"a.b.example.com" "*.example.com" ;
    check false ~host:"example.com" "*.example.com" ;
    (* Not a whole label, and not a public suffix. *)
    check false ~host:"foo.example.com" "f*.example.com" ;
    check false ~host:"example.com" "*.com" ;
    check false ~host:"example.com" "*"

  let verify ~host connection =
    Deferred.return
    @@
    match Async_ssl.Ssl.Connection.peer_certificate connection with
    | None | Some (Error _) ->
        false
    | Some (Ok certificate) ->
        Async_ssl.Ssl.Certificate.subject_alt_names certificate
        |> List.exists ~f:(name_matches ~host)

  let config ~host =
    Conduit_async.V2.Ssl.Config.create ?ca_file ?ca_path ~hostname:host
      ~verify_modes:[ Async_ssl.Ssl.Verify_mode.Verify_peer ]
      ~verify:(verify ~host) ()
end

let load_from_s3 s3_bucket_prefix s3_install_path ~logger =
  let%bind () = Unix.mkdir ~p:() (Filename.dirname s3_install_path) in
  Deferred.map ~f:Result.join
  @@ Monitor.try_with ~here:[%here] (fun () ->
      let each_uri (uri_string, file_path) =
        let open Deferred.Let_syntax in
        [%log trace] "Downloading file from S3: $url to $local_file_path"
          ~metadata:
            [ ("url", `String uri_string)
            ; ("local_file_path", `String file_path)
            ] ;
        let uri = Uri.of_string uri_string in
        let host =
          match Uri.host uri with
          | Some host ->
              host
          | None ->
              failwithf "Cannot download %s: no host in URL" uri_string ()
        in
        let%bind response, body =
          Cohttp_async.Client.get ~ssl_config:(Tls.config ~host) uri
        in
        let status = Cohttp.Response.status response in
        let%bind () =
          if Cohttp.Code.(is_success (code_of_status status)) then
            (* Opened only on success, so a failed download leaves no
               truncated file behind. *)
            Writer.with_file file_path ~f:(fun writer ->
                Writer.transfer writer
                  (Cohttp_async.Body.to_pipe body)
                  (Writer.write writer) )
          else
            let%bind () = Cohttp_async.Body.drain body in
            failwithf "Download of %s failed: HTTP %s" uri_string
              (Cohttp.Code.string_of_status status)
              ()
        in
        [%log trace] "Download finished"
          ~metadata:
            [ ("url", `String uri_string)
            ; ("local_file_path", `String file_path)
            ] ;
        Deferred.return (Result.return ())
      in
      each_uri (s3_bucket_prefix, s3_install_path) )
  |> Deferred.Result.map_error ~f:Error.of_exn
