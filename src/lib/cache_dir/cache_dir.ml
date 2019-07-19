open Core

let autogen_path = Filename.temp_dir_name ^/ "coda_cache_dir"

let manual_install_path = "/var/lib/coda"

let brew_install_path = "/usr/local/var/coda"

let possible_paths base =
  List.map [manual_install_path; brew_install_path; autogen_path] ~f:(fun d ->
      d ^/ base )
