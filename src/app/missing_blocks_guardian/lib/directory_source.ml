(* directory_source.ml -- reading one block file from a local directory.

   The filesystem counterpart of {!Http_source}: it reads the bytes and says
   why they are not a block, and nothing more. *)

open Core
open Async

let read directory ~name =
  let path = Filename.concat directory name in
  match%bind
    Monitor.try_with ~here:[%here] ~extract_exn:true (fun () ->
        Reader.file_contents path )
  with
  | Ok body ->
      return (Block_payload.of_string ~where:(sprintf "the file %s" path) body)
  | Error exn -> (
      (* A file that is absent and one that is present but unreadable call for
         different fixes, so they are reported apart. *)
      match%map Sys.file_exists path with
      | `No ->
          Error (Fetch_error.file_missing ~path ~directory)
      | `Yes | `Unknown ->
          Error (Fetch_error.file_unreadable ~path ~exn) )
