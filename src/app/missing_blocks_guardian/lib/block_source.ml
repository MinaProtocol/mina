(* block_source.ml -- which block file to ask for, and how many times.

   The transports are {!Http_source} and {!Directory_source}; everything to
   do with sockets, status codes and the filesystem lives there. *)

open Core
open Async

type t =
  | Http of Uri.t  (** base URL, no trailing slash *)
  | Directory of string  (** base directory, no trailing slash *)

let strip_trailing_slashes = String.rstrip ~drop:(Char.equal '/')

let create raw =
  let raw = String.strip raw in
  if String.is_empty raw then
    Or_error.error_string "the precomputed blocks URL is empty"
  else
    let uri = Uri.of_string raw in
    match Option.map (Uri.scheme uri) ~f:String.lowercase with
    | Some ("http" | "https") ->
        if Option.is_none (Uri.host uri) then
          Or_error.errorf "the precomputed blocks URL %S has no host" raw
        else
          Ok (Http (Uri.with_path uri (strip_trailing_slashes (Uri.path uri))))
    | Some "file" ->
        (* Accept both "file:///dir" and the authority-less "file:/dir" that
           [Uri.make ~scheme:"file" ~path] produces. *)
        let path = strip_trailing_slashes (Uri.path uri) in
        if String.is_empty path then
          Or_error.errorf "the file URL %S has no path" raw
        else Ok (Directory path)
    | Some scheme ->
        Or_error.errorf
          "unsupported scheme %S in the precomputed blocks URL %S. Supported \
           schemes are http, https and file (a bare path is read as a local \
           directory)"
          scheme raw
    | None ->
        (* A bare path, taken as written: see the interface. *)
        Ok (Directory (strip_trailing_slashes raw))

let location t ~name =
  match t with
  | Http uri ->
      Uri.to_string (Uri.with_path uri (Uri.path uri ^ "/" ^ name))
  | Directory dir ->
      Filename.concat dir name

let block_file_name ~network ~height ~state_hash =
  sprintf "%s-%d-%s.json" network height state_hash

let fetch_once t ~name ~timeout =
  match t with
  | Http uri ->
      Http_source.get uri ~name ~timeout
  | Directory dir ->
      Directory_source.read dir ~name

let fetch t ~name ~timeout ~retries ~retry_delay ~logger =
  let rec go attempt =
    match%bind fetch_once t ~name ~timeout with
    | Ok json ->
        Deferred.return (Ok json)
    | Error failure when not (Fetch_error.is_retriable failure) ->
        Deferred.return (Error (Fetch_error.to_error failure))
    | Error failure ->
        let err = Fetch_error.to_error failure in
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
    let ok_exn = Or_error.ok_exn

    let%test "https base URL keeps its path and drops the trailing slash" =
      String.equal
        (location
           (ok_exn (create "https://example.com/blocks/"))
           ~name:"net-3-hash.json" )
        "https://example.com/blocks/net-3-hash.json"

    let%test "an authority-less file URL is read as a directory" =
      String.equal
        (location (ok_exn (create "file:/tmp/out")) ~name:"b.json")
        "/tmp/out/b.json"

    let%test "file URL is read as a directory" =
      String.equal
        (location (ok_exn (create "file:///tmp/out")) ~name:"b.json")
        "/tmp/out/b.json"

    let%test "a bare path is read as a directory" =
      String.equal
        (location (ok_exn (create "/tmp/out")) ~name:"b.json")
        "/tmp/out/b.json"

    let%test "a bare path with a space is not percent encoded" =
      String.equal
        (location (ok_exn (create "/tmp/mina blocks")) ~name:"b.json")
        "/tmp/mina blocks/b.json"

    let%test "an unsupported scheme is rejected" =
      Or_error.is_error (create "gs://some-bucket/blocks")

    let%test "block file names carry the network prefix and the height" =
      String.equal
        (block_file_name ~network:"devnet" ~height:42 ~state_hash:"3NAbc")
        "devnet-42-3NAbc.json"
  end )
