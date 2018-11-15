(** Parsing and interpretation of opam files *)

open! Stdune

open OpamParserTypes

(** Type of opam files *)
type t = opamfile

(** Load a file *)
val load : Path.t -> t

(** Extracts a field *)
val get_field : t -> string -> value option
