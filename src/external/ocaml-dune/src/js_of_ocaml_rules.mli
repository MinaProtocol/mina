(** Generate rules for js_of_ocaml *)

open! Stdune
open Import
open Dune_file

val build_cm
  :  Compilation_context.t
  -> js_of_ocaml:Js_of_ocaml.t
  -> src:Path.t
  -> target:Path.t
  -> (unit, Action.t) Build.t list

val build_exe
  :  Compilation_context.t
  -> js_of_ocaml:Js_of_ocaml.t
  -> src:Path.t
  -> (Path.t list * string list, Action.t) Build.t list

val setup_separate_compilation_rules
  :  Super_context.t
  -> string list
  -> unit

val standard : Super_context.t -> string list
