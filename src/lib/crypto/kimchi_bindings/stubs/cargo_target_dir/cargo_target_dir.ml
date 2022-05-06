let () =
  let yojson = Yojson.Safe.from_string (read_line ()) in
  match Yojson.Safe.Util.member "target_directory" yojson with
  | `String dir ->
      print_string dir
  | _ ->
      failwith "Unexpected value"
