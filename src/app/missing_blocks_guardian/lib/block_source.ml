(* block_source.ml -- where the block files are, which one to ask for, and
   how many times. *)

open Core
open Async

(** What a block source does; {!Http_source} and {!Directory_source} differ
    only in how. *)
module type Transport = sig
  type t

  val location : t -> name:string -> string

  val fetch :
       t
    -> name:string
    -> timeout:Time_ns.Span.t
    -> (Yojson.Safe.t, Fetch_error.t) Result.t Deferred.t
end

type transport =
  | Transport : (module Transport with type t = 'a) * 'a -> transport

type t = { transport : transport; network : string }

let strip_trailing_slashes = String.rstrip ~drop:(Char.equal '/')

let http uri =
  Transport
    ( (module Http_source)
    , Uri.with_path uri (strip_trailing_slashes (Uri.path uri)) )

let directory path =
  Transport ((module Directory_source), strip_trailing_slashes path)

let transport_of_url raw =
  let uri = Uri.of_string raw in
  match Option.map (Uri.scheme uri) ~f:String.lowercase with
  | Some ("http" | "https") ->
      if Option.is_none (Uri.host uri) then
        Or_error.errorf "the precomputed blocks URL %S has no host" raw
      else Ok (http uri)
  | Some "file" ->
      (* both "file:///dir" and the authority-less "file:/dir" *)
      if String.is_empty (strip_trailing_slashes (Uri.path uri)) then
        Or_error.errorf "the file URL %S has no path" raw
      else Ok (directory (Uri.path uri))
  | Some scheme ->
      Or_error.errorf
        "unsupported scheme %S in the precomputed blocks URL %S. Supported \
         schemes are http, https and file (a bare path is read as a local \
         directory)"
        scheme raw
  | None ->
      (* a bare path, taken as written, so a space is not percent-encoded *)
      Ok (directory raw)

let create ~network raw =
  let raw = String.strip raw in
  if String.is_empty raw then
    Or_error.error_string "the precomputed blocks URL is empty"
  else
    Or_error.map (transport_of_url raw) ~f:(fun transport ->
        { transport; network } )

let file_name t ~height ~state_hash =
  sprintf "%s-%d-%s.json" t.network height state_hash

let location { transport = Transport ((module T), source); _ } ~name =
  T.location source ~name

let fetch_once { transport = Transport ((module T), source); _ } ~name ~timeout
    =
  T.fetch source ~name ~timeout

(** Fetch [name], retrying a transient failure up to [retries] times. *)
let fetch t ~name ~timeout ~retries ~retry_delay ~logger =
  let rec attempt n =
    match%bind fetch_once t ~name ~timeout with
    | Ok json ->
        return (Ok json)
    | Error failure when not (Fetch_error.is_retriable failure) ->
        return (Error (Fetch_error.to_error failure))
    | Error failure when n >= retries ->
        return
          (Error
             (Error.tag
                (Fetch_error.to_error failure)
                ~tag:(sprintf "giving up after %d attempts" (n + 1)) ) )
    | Error failure ->
        [%log warn] "Retrying download of $block_file after a transient error"
          ~metadata:
            [ ("block_file", `String name)
            ; ("attempt", `Int (n + 1))
            ; ("attempts_allowed", `Int (retries + 1))
            ; ( "error"
              , `String (Error.to_string_hum (Fetch_error.to_error failure)) )
            ] ;
        let%bind () = Clock_ns.after retry_delay in
        attempt (n + 1)
  in
  attempt 0

let%test_module "block source" =
  ( module struct
    let ok_exn = Or_error.ok_exn

    let%test "https base URL keeps its path and drops the trailing slash" =
      String.equal
        (location
           (ok_exn (create ~network:"devnet" "https://example.com/blocks/"))
           ~name:"net-3-hash.json" )
        "https://example.com/blocks/net-3-hash.json"

    let%test "an authority-less file URL is read as a directory" =
      String.equal
        (location
           (ok_exn (create ~network:"devnet" "file:/tmp/out"))
           ~name:"b.json" )
        "/tmp/out/b.json"

    let%test "file URL is read as a directory" =
      String.equal
        (location
           (ok_exn (create ~network:"devnet" "file:///tmp/out"))
           ~name:"b.json" )
        "/tmp/out/b.json"

    let%test "a bare path is read as a directory" =
      String.equal
        (location (ok_exn (create ~network:"devnet" "/tmp/out")) ~name:"b.json")
        "/tmp/out/b.json"

    let%test "a bare path with a space is not percent encoded" =
      String.equal
        (location
           (ok_exn (create ~network:"devnet" "/tmp/mina blocks"))
           ~name:"b.json" )
        "/tmp/mina blocks/b.json"

    let%test "an unsupported scheme is rejected" =
      Or_error.is_error (create ~network:"devnet" "gs://some-bucket/blocks")

    let%test "block file names carry the network prefix and the height" =
      String.equal
        (file_name
           (ok_exn (create ~network:"devnet" "/tmp/out"))
           ~height:42 ~state_hash:"3NAbc" )
        "devnet-42-3NAbc.json"
  end )
