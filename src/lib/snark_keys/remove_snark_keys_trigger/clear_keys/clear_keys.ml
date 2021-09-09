open Core
open Async

let () =
  Out_channel.write_all "remove_keys_trigger.ml" ~data:"" ;
  let dir = Cache_dir.autogen_path in
  match Core.Sys.is_directory dir with
  | `Yes ->
      File_system.clear_dir dir |> Deferred.don't_wait_for
  | `No | `Unknown ->
      ()
