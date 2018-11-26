open! Stdune
(** [Ordered_set_lang.t] is a sexp-based representation for an ordered list of strings,
    with some set like operations. *)

open Import

type t
val decode : t Dune_lang.Decoder.t

(** Return the location of the set. [loc standard] returns [None] *)
val loc : t -> Loc.t option

(** Value parsed from elements in the DSL *)
module type Value = sig
  type t
  type key
  val key : t -> key
end

module type Key = sig
  type t
  val compare : t -> t -> Ordering.t
  module Map : Map.S with type key = t
end

module type S = sig
  (** Evaluate an ordered set. [standard] is the interpretation of [:standard]
      inside the DSL. *)
  type value
  type 'a map

  val eval
    :  t
    -> parse:(loc:Loc.t -> string -> value)
    -> standard:value list
    -> value list

  (** Same as [eval] but the result is unordered *)
  val eval_unordered
    :  t
    -> parse:(loc:Loc.t -> string -> value)
    -> standard:value map
    -> value map
end

module Make(Key : Key)(Value : Value with type key = Key.t)
  : S with type value = Value.t
       and type 'a map = 'a Key.Map.t

(** same as [Make] but will retain the source location of the values in the
    evaluated results *)
module Make_loc (Key : Key)(Value : Value with type key = Key.t) : sig
  val eval
    :  t
    -> parse:(loc:Loc.t -> string -> Value.t)
    -> standard:Value.t list
    -> (Loc.t * Value.t) list

  (** Same as [eval] but the result is unordered *)
  val eval_unordered
    :  t
    -> parse:(loc:Loc.t -> string -> Value.t)
    -> standard:Value.t Key.Map.t
    -> (Loc.t * Value.t) Key.Map.t
end

val standard : t
val is_standard : t -> bool

val field
  :  ?default:t
  -> ?check:unit Dune_lang.Decoder.t
  -> string
  -> t Dune_lang.Decoder.fields_parser

module Unexpanded : sig
  type expanded = t
  type t

  include Dune_lang.Conv with type t := t
  val standard : t

  val of_strings : pos:string * int * int * int -> string list -> t

  val field
    :  ?default:t
    -> ?check:unit Dune_lang.Decoder.t
    -> string
    -> t Dune_lang.Decoder.fields_parser

  val has_special_forms : t -> bool

  (** List of files needed to expand this set *)
  val files
    : t
    -> f:(String_with_vars.t -> Path.t)
    -> Dune_lang.syntax * Path.Set.t

  (** Expand [t] using with the given file contents. [file_contents] is a map from
      filenames to their parsed contents. Every [(:include fn)] in [t] is replaced by
      [Map.find files_contents fn]. Every element is converted to a string using [f]. *)
  val expand
    :  t
    -> dir:Path.t
    -> files_contents:Dune_lang.Ast.t Path.Map.t
    -> f:(String_with_vars.t -> Value.t list)
    -> expanded

  type position = Pos | Neg

  (** Fold a function over all strings in a set. The callback receive
      whether the string is in position or negative position, i.e. on
      the left or right of a [\] operator. *)
  val fold_strings
    :  t
    -> init:'a
    -> f:(position -> String_with_vars.t -> 'a -> 'a)
    -> 'a
end with type expanded := t

module String : S with type value = string and type 'a map = 'a String.Map.t
