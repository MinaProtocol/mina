open Core

let autogen_path = Filename.temp_dir_name ^/ "coda_cache_dir"

let manual_install_path = "/var/lib/coda"

let brew_install_path =
  match
    let p = Unix.open_process_in "brew --prefix 2>/dev/null" in
    let r = In_channel.input_lines p in
    (r, Unix.close_process_in p)
  with
  | brew :: _, Ok () ->
      brew ^ "/var/coda"
  | _ ->
      "/usr/local/var/coda"

let possible_paths base =
  List.map [manual_install_path; brew_install_path; autogen_path] ~f:(fun d ->
      d ^/ base )
