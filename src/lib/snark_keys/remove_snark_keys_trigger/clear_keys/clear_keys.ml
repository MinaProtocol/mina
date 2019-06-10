open Core

let () =
  Out_channel.write_all "remove_keys_trigger.ml" ~data:"" ;
  let dir = Cache_dir.autogen_path in
  match Sys.is_directory dir with
  | `Yes ->
      List.iter (Sys.ls_dir dir) ~f:(fun p -> Sys.remove (dir ^/ p))
  | `No | `Unknown ->
      ()
