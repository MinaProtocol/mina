Printf.printf "DUNE_FOO: %s\n%!"
  (match Sys.getenv "DUNE_FOO" with
   | s -> s
   | exception Not_found -> "<not found>");;
