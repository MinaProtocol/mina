
let () =
  let name = Filename.basename Sys.argv.(0) in
  Printf.printf "Executing priv as %s\n" name;
  let path =
    match Sys.getenv "PATH" with
    | exception Not_found -> "<empty>"
    | s ->
      let paths = Path_lexer.dune_paths s in
      String.concat "\n\t" paths
  in
  Printf.printf "PATH:\n\t%s\n" path
