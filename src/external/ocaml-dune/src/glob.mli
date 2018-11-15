open! Stdune
open Import

type t

val decode : t Stanza.Decoder.t

val test : t -> string -> bool

val filter : t -> string list -> string list

val empty : t

val of_re : Re.t -> t
