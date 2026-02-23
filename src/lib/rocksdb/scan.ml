open Core

module Hex_util = struct
  (* Converts Bigstring to hex string *)
  let to_hex bs =
    Bigstring.to_string bs
    |> String.concat_map ~f:(fun c -> sprintf "%02x" (Char.to_int c))

  (* Converts hex string to Bigstring *)
  let of_hex hex_str =
    let hex_str = String.strip hex_str in
    let len = String.length hex_str in
    if len % 2 <> 0 then failwithf "Invalid hex string length %d" len () ;
    let bs = Bigstring.create (len / 2) in
    for i = 0 to (len / 2) - 1 do
      let byte_str = String.sub hex_str ~pos:(i * 2) ~len:2 in
      let byte = Int.of_string ("0x" ^ byte_str) in
      Bigstring.set_int8_exn bs ~pos:i byte
    done ;
    bs
end

let dump ~db_path ~text_file () =
  Out_channel.with_file text_file ~f:(fun oc ->
      let db = Database.create db_path in
      Exn.protect
        ~f:(fun () ->
          let kv_pairs = Database.to_alist db in
          List.iter kv_pairs ~f:(fun (k, v) ->
              Printf.fprintf oc "%s : %s\n" (Hex_util.to_hex k)
                (Hex_util.to_hex v) ) ;
          Out_channel.flush oc ;
          printf "Dump complete: %s\n" text_file )
        ~finally:(fun () -> Database.close db) )

let restore ~db_path ~text_file () =
  In_channel.with_file text_file ~f:(fun ic ->
      let db = Database.create db_path in
      let chunk_size = 256 in
      let buffer = ref [] in
      let process_batch () =
        if not (List.is_empty !buffer) then (
          Database.set_batch db ?remove_keys:None ~key_data_pairs:!buffer ;
          buffer := [] )
      in
      Exn.protect
        ~f:(fun () ->
          In_channel.iter_lines ic ~f:(fun line ->
              try
                Scanf.sscanf line "%s : %s" (fun k_hex v_hex ->
                    let key = Hex_util.of_hex k_hex in
                    let data = Hex_util.of_hex v_hex in
                    buffer := (key, data) :: !buffer ) ;
                if List.length !buffer >= chunk_size then process_batch ()
              with e ->
                failwithf "Can't parse data line `%s` in dump file: %s" line
                  (Exn.to_string e) () ) ;
          process_batch () ;
          printf "Restore complete: %s\n%!" db_path )
        ~finally:(fun () -> Database.close db) )
