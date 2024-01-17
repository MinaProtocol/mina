open Core

module TempDir = struct
  type t = { prefix : string; root : string }

  let create dir prefix =
    let root = Filename.temp_dir ~in_dir:dir prefix "" in
    { prefix; root }

  let create_in_temp prefix =
    let root = Filename.temp_dir ~in_dir:"/tmp" prefix "" in
    { prefix; root }

  let path t file =
    let path = Printf.sprintf "%s/%s" t.root file in
    path
end
