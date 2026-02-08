(** Dune S-expression AST, pretty-printing, parsing,
    and structural comparison. *)

(** {1 AST} *)

type t =
  | Atom of string
  | List of t list
  | Comment of string

(** {1 Construction helpers} *)

val atom : string -> t
val list : t list -> t
val ( @: ) : string -> t list -> t
(** [name @: children] is [List (Atom name :: children)]. *)

(** {1 Pretty-printing} *)

val pp : Format.formatter -> t -> unit
(** Pretty-print a single s-expression. *)

val pp_toplevel : Format.formatter -> t list -> unit
(** Pretty-print a list of top-level stanzas, separated by
    blank lines. *)

val to_string : t list -> string
(** Render top-level stanzas to a string. *)

(** {1 Parsing} *)

val parse_string : string -> t list
(** Parse dune-style s-expressions from a string.
    Handles atoms, quoted strings, and ;-comments. *)

val parse_file : string -> t list
(** [parse_file path] reads and parses a dune file. *)

(** {1 Structural comparison} *)

val strip_comments : t -> t option
(** Remove comment nodes. Returns [None] for pure comments. *)

val equal : t -> t -> bool
(** Structural equality, ignoring comments. *)

val equal_stanzas : t list -> t list -> bool
(** Compare two lists of stanzas, ignoring comments and
    whitespace differences. *)

val diff : t -> t -> string option
(** [diff a b] returns [None] if equal, or [Some description]
    of the first difference found. *)
