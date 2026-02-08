(** Dune S-expression AST, pretty-printing, parsing,
    and structural comparison. *)

(** {1 AST} *)

type t = Atom of string | List of t list | Comment of string

(** {1 Construction helpers} *)

val atom : string -> t

val list : t list -> t

(** [name @: children] is [List (Atom name :: children)]. *)
val ( @: ) : string -> t list -> t

(** {1 Pretty-printing} *)

(** Pretty-print a single s-expression. *)
val pp : Format.formatter -> t -> unit

(** Pretty-print a list of top-level stanzas, separated by
    blank lines. *)
val pp_toplevel : Format.formatter -> t list -> unit

(** Render top-level stanzas to a string. *)
val to_string : t list -> string

(** {1 Parsing} *)

(** Parse dune-style s-expressions from a string.
    Handles atoms, quoted strings, and ;-comments. *)
val parse_string : string -> t list

(** [parse_file path] reads and parses a dune file. *)
val parse_file : string -> t list

(** {1 Structural comparison} *)

(** Remove comment nodes. Returns [None] for pure comments. *)
val strip_comments : t -> t option

(** Structural equality, ignoring comments. *)
val equal : t -> t -> bool

(** Compare two lists of stanzas, ignoring comments and
    whitespace differences. *)
val equal_stanzas : t list -> t list -> bool

(** [diff a b] returns [None] if equal, or [Some description]
    of the first difference found. *)
val diff : t -> t -> string option
