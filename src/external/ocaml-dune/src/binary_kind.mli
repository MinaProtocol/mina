(** Linking modes for binaries *)

open! Stdune

type t =
  | C
  | Exe
  | Object
  | Shared_object

include Dune_lang.Conv with type t := t

val all : t list

val pp : Format.formatter -> t -> unit
