type t = string
include module type of struct include StringLabels end with type t := t

val equal : t -> t -> bool
val compare : t -> t -> Ordering.t

val break : t -> pos:int -> t * t

val is_empty : t -> bool
val is_prefix : t -> prefix:t -> bool
val is_suffix : t -> suffix:t -> bool

val take : t -> int -> t
val drop : t -> int -> t
val split_n : t -> int -> t * t

val drop_prefix : t -> prefix:t -> t option
val drop_suffix : t -> suffix:t -> t option

(** These only change ASCII characters *)
val capitalize   : t -> t
val uncapitalize : t -> t
val uppercase    : t -> t
val lowercase    : t -> t

val index : t -> char -> int option

val extract_words : t -> is_word_char:(char -> bool) -> t list
val extract_comma_space_separated_words : t -> t list
val extract_blank_separated_words : t -> t list

val lsplit2 : t -> on:char -> (t * t) option
val lsplit2_exn : t -> on:char -> t * t
val rsplit2 : t -> on:char -> (t * t) option

val split : t -> on:char -> t list
val split_lines : t -> t list

(** Escace ONLY double quotes. {!escape} also escapes '\n',... and
    transforms all chars above '~' into '\xxx' which is not suitable
    for UTF-8 strings. *)
val escape_double_quote : t -> t

(** Return the length of the longest string in the list *)
val longest : string list -> int
val longest_map : 'a list -> f:('a -> string) -> int

val longest_prefix : t list -> t

val exists : t -> f:(char -> bool) -> bool
val for_all : t -> f:(char -> bool) -> bool

(** [maybe_quoted s] is [s] if [s] doesn't need escaping according to OCaml
    lexing conventions and [sprintf "%S" s] otherwise. *)
val maybe_quoted : t -> t

(** Produces: "x, y and z" *)
val enumerate_and : string list -> string

(** Produces: "x, y or z" *)
val enumerate_or  : string list -> string

module Set : Set.S with type elt = t
module Map : sig
  include Map.S with type key = t

  val pp : (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a t -> unit
end
module Table : Hashtbl.S with type key = t
