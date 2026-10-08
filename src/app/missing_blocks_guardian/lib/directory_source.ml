(* directory_source.ml -- block files in a local directory. *)

open Core
open Async

(** base directory, no trailing slash *)
type t = string

let location directory ~name = Filename.concat directory name

let fetch directory ~name ~timeout:_ =
  let path = location directory ~name in
  match%bind
    Monitor.try_with ~here:[%here] ~extract_exn:true (fun () ->
        Reader.file_contents path )
  with
  | Ok body ->
      return (Block_payload.of_string ~name ~location:path body)
  | Error exn -> (
      (* absent and unreadable call for different fixes *)
      match%map Sys.file_exists path with
      | `No ->
          Error (Fetch_error.file_missing ~path ~directory)
      | `Yes | `Unknown ->
          Error (Fetch_error.file_unreadable ~path ~exn) )
