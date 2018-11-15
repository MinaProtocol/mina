(** Simple rules: user, copy_files, alias *)

open! Stdune
open Import
open Dune_file

(** Interpret a [(rule ...)] stanza and return the targets it produces. *)
val user_rule
  :  Super_context.t
  -> ?extra_bindings:Pform.Map.t
  -> dir:Path.t
  -> scope:Scope.t
  -> Rule.t
  -> Path.t list

(** Interpret a [(copy_files ...)] stanza and return the targets it produces. *)
val copy_files
  :  Super_context.t
  -> dir:Path.t
  -> scope:Scope.t
  -> src_dir:Path.t
  -> Copy_files.t
  -> Path.t list

(** Interpret an [(alias ...)] stanza. *)
val alias
  :  Super_context.t
  -> ?extra_bindings:Pform.Map.t
  -> dir:Path.t
  -> scope:Scope.t
  -> Alias_conf.t
  -> unit
