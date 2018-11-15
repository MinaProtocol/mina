open Import

(** Setup automatic format rules for the given dir.
    If tools like ocamlformat are not available in $PATH, just display an error
    message when the alias is built. *)
val gen_rules:
  Super_context.t
  -> Dune_file.Auto_format.t
  -> dir:Path.t
  -> unit
