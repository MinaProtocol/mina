open Core
open Async

let autogen_path = Filename.temp_dir_name ^/ "coda_cache_dir"

let manual_install_path = "/var/lib/coda"

let brew_install_path =
  match
    Thread_safe.block_on_async_exn (fun () ->
        Process.run ~prog:"brew" ~args:["--prefix"] () )
  with
  | Ok brew ->
      brew ^ "/var"
  | _ ->
      "/usr/local/var"

let possible_paths base =
  List.map [manual_install_path; brew_install_path; autogen_path] ~f:(fun d ->
      d ^/ base )
