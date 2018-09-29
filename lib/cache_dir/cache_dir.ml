open Core

let autogen_path = Filename.temp_dir_name ^/ "cli_cache_dir"

let manual_install_path = "/var/lib/coda"

let possible_paths base =
  List.map [manual_install_path; autogen_path] ~f:(fun d -> d ^/ base)
