open Printf

let process_line =
  let path_re = Str.regexp {|^\([SB]\) /.+/lib/\(.+\)$|} in
  let ppx_re = Str.regexp {|^FLG -ppx '/.+/\.ppx/\(.+\)$|} in
  fun line ->
    line
    |> Str.replace_first path_re {|\1 $LIB_PREFIX/lib/\2|}
    |> Str.global_replace ppx_re {|FLG -ppx '$PPX/\1|}

let () =
  let files = ref [] in
  let anon s = files := s :: !files in
  let usage = sprintf "%s [FILES]" (Filename.basename Sys.executable_name) in
  Arg.parse [] anon usage;
  List.iter (fun f ->
    Printf.printf "# Processing %s\n" f;
    let ch = open_in f in
    let rec loop () =
      match input_line ch with
      | exception End_of_file -> ()
      | line -> print_endline (process_line line); loop () in
    loop ();
    close_in ch
  ) !files
