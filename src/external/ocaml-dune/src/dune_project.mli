open! Stdune
(** dune-project files *)

open Import

module Kind : sig
  type t =
    | Dune
    | Jbuilder
end

module Name : sig
  (** Invariants:
      - Named     s -> s <> "" and s does not contain '.' or '/'
      - Anonymous p -> p is a local path in the source tree
  *)
  type t = private
    | Named     of string
    | Anonymous of Path.t

  val compare : t -> t -> Ordering.t

  (** Convert to a string that is suitable for human readable messages *)
  val to_string_hum : t -> string

  val to_sexp : t Sexp.Encoder.t

  (** Convert to/from an encoded string that is suitable to use in filenames *)
  val to_encoded_string : t -> string
  val of_encoded_string : string -> t

  module Infix : Comparable.OPS with type t = t
end

module Project_file : sig
  type t
end

type t

val packages : t -> Package.t Package.Name.Map.t
val version : t -> string option
val name : t -> Name.t
val root : t -> Path.Local.t
val stanza_parser : t -> Stanza.t list Dune_lang.Decoder.t

module Lang : sig
  (** [register id stanzas_parser] register a new language. Users will
      select this language by writing:

      {[ (lang <name> <version>) ]}

      as the first line of their [dune-project] file. [stanza_parsers]
      defines what stanzas the user can write in [dune] files. *)
  val register : Syntax.t -> Stanza.Parser.t list -> unit
end

module Extension : sig
  type 'a t

  (** [register id parser] registers a new extension. Users will
      enable this extension by writing:

      {[ (using <name> <version> <args>) ]}

      in their [dune-project] file. [parser] is used to describe
      what [<args>] might be. *)
  val register
    :  ?experimental:bool
    -> Syntax.t
    -> ('a * Stanza.Parser.t list) Dune_lang.Decoder.t
    -> ('a -> Sexp.t)
    -> 'a t

  (** A simple version where the arguments are not used through
      [find_extension_args]. *)
  val register_simple
    :  ?experimental:bool
    -> Syntax.t
    -> Stanza.Parser.t list Dune_lang.Decoder.t
    -> unit
end

(** Load a project description from the following directory. [files]
    is the set of files in this directory. *)
val load : dir:Path.t -> files:String.Set.t -> t option

(** Read the [name] file from a dune-project file *)
val read_name : Path.t -> string option

(** "dune-project" *)
val filename : string

(** Represent the scope at the root of the workspace when the root of
    the workspace contains no [dune-project] or [<package>.opam] files. *)
val anonymous : t Lazy.t

(** Check that the dune-project file exists and create it otherwise. *)
val ensure_project_file_exists : t -> unit

(** Append the following text to the project file *)
val append_to_project_file : t -> string -> unit

(** Set the project we are currently parsing dune files for *)
val set : t -> ('a, 'k) Dune_lang.Decoder.parser -> ('a, 'k) Dune_lang.Decoder.parser
val get_exn : unit -> (t, 'k) Dune_lang.Decoder.parser

(** Find arguments passed to (using). [None] means that the extension was not
    written in dune-project. *)
val find_extension_args : t -> 'a Extension.t -> 'a option

val set_parsing_context : t -> 'a Dune_lang.Decoder.t -> 'a Dune_lang.Decoder.t
