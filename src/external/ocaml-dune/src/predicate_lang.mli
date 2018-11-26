open! Stdune

type t

val decode : t Stanza.Decoder.t

val empty : t

val filter : t -> standard:t -> string list Lazy.t -> string list

val of_glob : Glob.t -> t

val union : t list -> t

val of_string_set : String.Set.t -> t
