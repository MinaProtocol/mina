(** Dune files that are installed on the system *)

open! Stdune

val load : Path.t -> Dune_file.Sub_system_info.t Sub_system_name.Map.t
val gen
  : dune_version:Syntax.Version.t
  -> (Syntax.Version.t * Dune_lang.t) Sub_system_name.Map.t
  -> Dune_lang.t
