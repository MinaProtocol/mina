open Core

module Make () : Common.Database = struct
  type t = { root : string }

  let name = "single_file"

  let create directory = Unix.mkdir_p directory ; { root = directory }

  let close _t = ()

  let key_path t key = Filename.concat t.root (Printf.sprintf "%d.val" key)

  let set_block t ~block_num values =
    let start_key = block_num * Common.keys_per_block in
    List.iteri values ~f:(fun i value ->
        let key = start_key + i in
        Out_channel.write_all (key_path t key) ~data:value )

  let get t ~key =
    let path = key_path t key in
    match Sys.file_exists path with
    | `Yes ->
        Some (In_channel.read_all path)
    | _ ->
        None

  let remove_block t ~block_num =
    let start_key = block_num * Common.keys_per_block in
    for i = 0 to Common.keys_per_block - 1 do
      let key = start_key + i in
      let path = key_path t key in
      match Sys.file_exists path with `Yes -> Unix.unlink path | _ -> ()
    done
end
