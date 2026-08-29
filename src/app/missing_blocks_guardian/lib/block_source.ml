(* block_source.ml -- where precomputed/extensional block files are fetched
   from, and every check that has to pass before the bytes are handed to the
   archive processor.

   The bash guardian this app replaces did

     curl -sO "${PRECOMPUTED_BLOCKS_URL}/${FILE}"

   and looked only at curl's exit status.  [curl -s] reports success for a
   404: it writes the bucket's XML or HTML error page to the block file, which
   then reaches [mina-archive-blocks] and fails there with a JSON parse error
   that names neither the URL nor the HTTP status.  Every check below exists to
   turn that class of silent failure into one accurate message. *)

open Core
open Async

type t =
  | Http of Uri.t  (** base URL, no trailing slash *)
  | Directory of string  (** base directory, no trailing slash *)

(** A fetch that failed.  [Permanent] must not be retried: the block is not
    there, and asking again cannot change that.  [Transient] may be retried. *)
type failure = Permanent of Error.t | Transient of Error.t

let strip_trailing_slashes = String.rstrip ~drop:(Char.equal '/')

let create uri =
  let unsupported scheme =
    Or_error.errorf
      "unsupported scheme %S in the precomputed blocks URL %S. Supported \
       schemes are http, https and file (a bare path is read as a local \
       directory)"
      scheme (Uri.to_string uri)
  in
  match Uri.scheme uri with
  | Some ("http" | "https") ->
      if Option.is_none (Uri.host uri) then
        Or_error.errorf "the precomputed blocks URL %S has no host"
          (Uri.to_string uri)
      else Ok (Http (Uri.with_path uri (strip_trailing_slashes (Uri.path uri))))
  | Some "file" ->
      let path = strip_trailing_slashes (Uri.path uri) in
      if String.is_empty path then
        Or_error.errorf "the file URL %S has no path" (Uri.to_string uri)
      else Ok (Directory path)
  | Some scheme ->
      unsupported scheme
  | None ->
      let path = strip_trailing_slashes (Uri.to_string uri) in
      if String.is_empty path then
        Or_error.error_string "the precomputed blocks URL is empty"
      else Ok (Directory path)

(** Full location of one block file, for logs and error messages. *)
let location t ~name =
  match t with
  | Http uri ->
      Uri.to_string (Uri.with_path uri (Uri.path uri ^ "/" ^ name))
  | Directory dir ->
      Filename.concat dir name

(** Name of the block file holding the block at [height] with [state_hash].
    This is the layout the archive block buckets use and the one
    [mina-extract-blocks --include-block-height-in-name] writes. *)
let block_file_name ~network ~height ~state_hash =
  sprintf "%s-%d-%s.json" network height state_hash

(* Bucket error pages are HTML or XML and can be long.  Show enough to
   recognise them without flooding the log. *)
let snippet_length = 200

let snippet body =
  let cleaned =
    String.map body ~f:(fun c ->
        if Char.is_print c || Char.equal c ' ' then c else ' ' )
    |> String.strip
  in
  if String.length cleaned <= snippet_length then cleaned
  else String.prefix cleaned snippet_length ^ "..."

let parse_json ~where body =
  if String.is_empty (String.strip body) then
    Error
      (Permanent
         (Error.createf "%s is empty. Expected a JSON encoded block." where) )
  else
    match Yojson.Safe.from_string body with
    | json ->
        Ok json
    | exception Yojson.Json_error msg ->
        Error
          (Permanent
             (Error.createf
                "%s is not valid JSON (%s). The first %d bytes of what was \
                 read are: %s"
                where msg snippet_length (snippet body) ) )

let fetch_http uri ~name ~timeout =
  let url = Uri.with_path uri (Uri.path uri ^ "/" ^ name) in
  let url_string = Uri.to_string url in
  let get () =
    let%bind response, body = Cohttp_async.Client.get url in
    let%map body = Cohttp_async.Body.to_string body in
    (response, body)
  in
  match%bind
    Monitor.try_with ~here:[%here] ~extract_exn:true (fun () ->
        Clock_ns.with_timeout timeout (get ()) )
  with
  | Error exn ->
      (* DNS failure, connection refused, TLS failure, connection reset.  All
         may succeed on a later attempt. *)
      return
        (Error
           (Transient
              (Error.createf "could not GET %s: %s" url_string
                 (Exn.to_string exn) ) ) )
  | Ok `Timeout ->
      return
        (Error
           (Transient
              (Error.createf "GET %s timed out after %s" url_string
                 (Time_ns.Span.to_string_hum timeout) ) ) )
  | Ok (`Result (response, body)) -> (
      let status = Cohttp.Response.status response in
      let code = Cohttp.Code.code_of_status status in
      match status with
      | #Cohttp.Code.success_status ->
          let content_type =
            Cohttp.Header.get (Cohttp.Response.headers response) "content-type"
          in
          (* A bucket that serves an error page with a 200 is rare but not
             impossible; the JSON parse below is what actually rejects it, and
             the content type makes the reason obvious in the message. *)
          let where =
            match content_type with
            | Some ct when not (String.is_substring ct ~substring:"json") ->
                sprintf "the response to GET %s (content-type: %s)" url_string
                  ct
            | _ ->
                sprintf "the response to GET %s" url_string
          in
          return (parse_json ~where body)
      | `Not_found ->
          return
            (Error
               (Permanent
                  (Error.createf
                     "block file %s is not in the bucket: GET %s returned 404. \
                      Check that PRECOMPUTED_BLOCKS_URL \
                      (--precomputed-blocks-url) and MINA_NETWORK (--network) \
                      name the bucket and network this archive was built from, \
                      and that the bucket holds blocks this far back."
                     name url_string ) ) )
      | #Cohttp.Code.redirection_status ->
          (* Redirects are not followed, exactly as [curl] without [-L] did not
             follow them.  Naming the target is more useful than following it
             silently to somewhere else. *)
          let location =
            Option.value
              (Cohttp.Header.get (Cohttp.Response.headers response) "location")
              ~default:"(no Location header)"
          in
          return
            (Error
               (Permanent
                  (Error.createf
                     "GET %s was redirected with HTTP %d to %s. Redirects are \
                      not followed; set --precomputed-blocks-url \
                      (PRECOMPUTED_BLOCKS_URL) to the URL the blocks are \
                      actually served from."
                     url_string code location ) ) )
      | `Forbidden | `Unauthorized ->
          return
            (Error
               (Permanent
                  (Error.createf
                     "access to %s was refused: HTTP %d %s. The bucket is not \
                      public, or the credentials in use cannot read it. \
                      Response body: %s"
                     url_string code
                     (Cohttp.Code.reason_phrase_of_code code)
                     (snippet body) ) ) )
      | _ when Cohttp.Code.is_server_error code ->
          return
            (Error
               (Transient
                  (Error.createf "GET %s returned HTTP %d %s. Response body: %s"
                     url_string code
                     (Cohttp.Code.reason_phrase_of_code code)
                     (snippet body) ) ) )
      | _ ->
          return
            (Error
               (Permanent
                  (Error.createf "GET %s returned HTTP %d %s. Response body: %s"
                     url_string code
                     (Cohttp.Code.reason_phrase_of_code code)
                     (snippet body) ) ) ) )

let fetch_file dir ~name =
  let path = Filename.concat dir name in
  match%bind
    Monitor.try_with ~here:[%here] ~extract_exn:true (fun () ->
        Reader.file_contents path )
  with
  | Ok body ->
      return (parse_json ~where:(sprintf "the file %s" path) body)
  | Error exn -> (
      match%map Sys.file_exists path with
      | `No ->
          Error
            (Permanent
               (Error.createf
                  "block file %s does not exist. Check that the block source \
                   directory %s holds blocks this far back and that the \
                   network prefix is right."
                  path dir ) )
      | `Yes | `Unknown ->
          Error
            (Permanent
               (Error.createf "could not read block file %s: %s" path
                  (Exn.to_string exn) ) ) )

let fetch_once t ~name ~timeout =
  match t with
  | Http uri ->
      fetch_http uri ~name ~timeout
  | Directory dir ->
      fetch_file dir ~name

(** Fetch one block file and return its JSON.  Retries only failures that can
    plausibly succeed on a second attempt; a 404 or a malformed body fails
    immediately, because retrying it only delays the real message. *)
let fetch t ~name ~timeout ~retries ~retry_delay ~logger =
  let rec go attempt =
    match%bind fetch_once t ~name ~timeout with
    | Ok json ->
        Deferred.Or_error.return json
    | Error (Permanent err) ->
        Deferred.return (Error err)
    | Error (Transient err) ->
        if attempt >= retries then
          Deferred.return
            (Error
               (Error.tag err
                  ~tag:(sprintf "giving up after %d attempts" (attempt + 1)) )
            )
        else (
          [%log warn] "Retrying download of $block_file after a transient error"
            ~metadata:
              [ ("block_file", `String name)
              ; ("attempt", `Int (attempt + 1))
              ; ("attempts_allowed", `Int (retries + 1))
              ; ("error", `String (Error.to_string_hum err))
              ] ;
          let%bind () = Clock_ns.after retry_delay in
          go (attempt + 1) )
  in
  go 0

let%test_module "block source" =
  ( module struct
    let uri = Uri.of_string

    let ok_exn = Or_error.ok_exn

    let%test "https base URL keeps its path and drops the trailing slash" =
      String.equal
        (location
           (ok_exn (create (uri "https://example.com/blocks/")))
           ~name:"net-3-hash.json" )
        "https://example.com/blocks/net-3-hash.json"

    let%test "file URL is read as a directory" =
      String.equal
        (location (ok_exn (create (uri "file:///tmp/out"))) ~name:"b.json")
        "/tmp/out/b.json"

    let%test "a bare path is read as a directory" =
      String.equal
        (location (ok_exn (create (uri "/tmp/out"))) ~name:"b.json")
        "/tmp/out/b.json"

    let%test "an unsupported scheme is rejected" =
      Or_error.is_error (create (uri "gs://some-bucket/blocks"))

    let%test "block file names carry the network prefix and the height" =
      String.equal
        (block_file_name ~network:"devnet" ~height:42 ~state_hash:"3NAbc")
        "devnet-42-3NAbc.json"

    let%test "an HTML error page is not accepted as a block" =
      match
        parse_json ~where:"the response" "<?xml version=\"1.0\"?><Error/>"
      with
      | Error (Permanent _) ->
          true
      | _ ->
          false

    let%test "an empty body is not accepted as a block" =
      match parse_json ~where:"the response" "   " with
      | Error (Permanent _) ->
          true
      | _ ->
          false

    let%test "a JSON body is accepted" =
      match parse_json ~where:"the response" "{\"a\":1}" with
      | Ok _ ->
          true
      | _ ->
          false
  end )
