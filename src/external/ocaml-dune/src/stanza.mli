(** Stanza in dune/jbuild files *)

open! Stdune

type t = ..

module Parser : sig
  (** Type of stanza parser.

      Each stanza in a configuration file might produce several values
      of type [t], hence the [t list] here. *)
  type nonrec t = string * t list Dune_lang.Decoder.t
end

(** Syntax identifier for the Dune language. [(0, X)] correspond to
    the Jbuild language while versions from [(1, 0)] correspond to the
    Dune one. *)
val syntax : Syntax.t

module File_kind : sig
  type t = Dune_lang.syntax = Jbuild | Dune

  val of_syntax : Syntax.Version.t -> t
end

(** Whether we are parsing a [jbuild] or [dune] file. *)
val file_kind : unit -> (File_kind.t, _) Dune_lang.Decoder.parser

(** Overlay for [Dune_lang.Decoder] where lists and records don't require
   an extra level of parentheses in Dune files.

    Additionally, [field_xxx] functions only warn about duplicated
    fields in jbuild files, for backward compatibility. *)
module Decoder : sig
  include module type of struct include Dune_lang.Decoder end

  val record : 'a fields_parser -> 'a t
  val list : 'a t -> 'a list t

  val field
    :  string
    -> ?default:'a
    -> 'a t
    -> 'a fields_parser
  val field_o
    :  string
    -> 'a t
    -> 'a option fields_parser

  val field_b
    :  ?check:(unit t)
    -> string
    -> bool fields_parser

  val field_o_b
    :  ?check:(unit t)
    -> string
    -> bool option fields_parser

  (** Nop in dune files and [enter t] in jbuild files. Additionally it
      displays a nice error messages when parentheses are used in dune
      files. *)
  val parens_removed_in_dune : 'a t -> 'a t

  (** Use a different parser depending on the syntax in the current file.
      If the syntax version is strictly less than `(1, 0)`, use `jbuild`.
      Otherwise use `dune`. *)
  val switch_file_kind :
   jbuild:('a, 'b) parser ->
   dune:('a, 'b) parser ->
   ('a, 'b) parser
end
