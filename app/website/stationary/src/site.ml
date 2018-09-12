open Core
open Async

type t =
  { filesystems : File_system.t list }

let create filesystems = { filesystems }

let build { filesystems } ~dst =
  match%bind Sys.file_exists dst with
  | `No ->
    let dirname, basename = Filename.split dst in
    File_system.build ~dst:dirname
      (File_system.directory basename filesystems)

  | `Yes | `Unknown ->
    failwithf "Directory or file %s exists or you do not have permission to write it"
      dst ()
;;
