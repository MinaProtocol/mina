open Import

(** Reformat a dune file. [None] corresponds to stdin/stdout. *)
val format_file :
  input:Path.t option ->
  output:Path.t option ->
  unit
