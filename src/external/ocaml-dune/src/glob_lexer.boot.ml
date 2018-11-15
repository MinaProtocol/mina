(* We don't use globs in the bootstrap path to avoid avoid to include
   ocaml-re. This speeds up the bootstrap. *)

let parse_string _ = failwith "globs are not available during bootstrap"

(* To force the ordering during bootstrap *)
let _ = Dune_re.compile
