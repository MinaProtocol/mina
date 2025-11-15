open Core

module Make () : Common.Database = struct
  type t = { root : string }

  let name = "multi_file"

  let create directory = Unix.mkdir_p directory ; { root = directory }

  let close _t = ()

  (* Get block number from key ID *)
  let block_of_key key = key / Common.keys_per_block

  (* Get offset within block from key ID *)
  let offset_of_key key = key mod Common.keys_per_block

  (* Get file path for a block *)
  let block_path t block_num =
    Filename.concat t.root (Printf.sprintf "%d.block" block_num)

  (* Calculate byte offset within file for a key *)
  let byte_offset_of_key key = offset_of_key key * Common.value_size

  let set_block t ~block_num values =
    let path = block_path t block_num in
    (* Concatenate all values and write in a single operation *)
    let concatenated = String.concat ~sep:"" values in
    Out_channel.write_all path ~data:concatenated

  let get t ~key =
    let block_num = block_of_key key in
    let path = block_path t block_num in

    match Sys.file_exists path with
    | `Yes ->
        let byte_offset = byte_offset_of_key key in
        Some
          (In_channel.with_file path ~binary:true ~f:(fun ic ->
               In_channel.seek ic (Int64.of_int byte_offset) ;
               let buffer = Bytes.create Common.value_size in
               In_channel.really_input_exn ic ~buf:buffer ~pos:0
                 ~len:Common.value_size ;
               Bytes.to_string buffer ) )
    | _ ->
        None

  let remove_block t ~block_num =
    let path = block_path t block_num in
    (* Delete the entire block file *)
    match Sys.file_exists path with `Yes -> Unix.unlink path | _ -> ()
end
