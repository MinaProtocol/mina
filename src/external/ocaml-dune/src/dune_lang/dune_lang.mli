open! Stdune
(** Parsing of s-expressions.

    This library is internal to dune and guarantees no API stability.*)

module Atom : sig
  type t = private A of string [@@unboxed]

  val is_valid : t -> Syntax.t -> bool

  val of_string : string -> t
  val to_string : t -> string

  val of_int : int -> t
  val of_float : float -> t
  val of_bool : bool -> t
  val of_int64 : Int64.t -> t
  val of_digest : Digest.t -> t
end

module Syntax : sig
  type t = Jbuild | Dune

  val of_basename : string -> t option
end

type syntax = Syntax.t = Jbuild | Dune

module Template : sig
  type var_syntax = Dollar_brace | Dollar_paren | Percent

  type var =
    { loc: Loc.t
    ; name: string
    ; payload: string option
    ; syntax: var_syntax
    }

  type part =
    | Text of string
    | Var of var

  type t =
    { quoted: bool
    ; parts: part list
    ; loc: Loc.t
    }

  val string_of_var : var -> string

  val to_string : t -> syntax:syntax -> string

  val remove_locs : t -> t
end

(** The S-expression type *)
type t =
  | Atom of Atom.t
  | Quoted_string of string
  | List of t list
  | Template of Template.t

val atom : string -> t
(** [atom s] convert the string [s] to an Atom.
    @raise Invalid_argument if [s] does not satisfy [Atom.is_valid s]. *)

val atom_or_quoted_string : string -> t

val unsafe_atom_of_string : string -> t

(** Serialize a S-expression *)
val to_string : t -> syntax:syntax -> string

(** Serialize a S-expression using indentation to improve readability *)
val pp : syntax -> Format.formatter -> t -> unit

(** Serialization that never fails because it quotes atoms when necessary
    TODO remove this once we have a proper sexp type *)
val pp_quoted : Format.formatter -> t -> unit

(** Same as [pp ~syntax:Dune], but split long strings. The formatter
    must have been prepared with [prepare_formatter]. *)
val pp_split_strings : Format.formatter -> t -> unit

(** Prepare a formatter for [pp_split_strings]. Additionaly the
    formatter escape newlines when the tags "makefile-action" or
    "makefile-stuff" are active. *)
val prepare_formatter : Format.formatter -> unit

(** Abstract syntax tree *)
module Ast : sig
  type sexp = t
  type t =
    | Atom of Loc.t * Atom.t
    | Quoted_string of Loc.t * string
    | Template of Template.t
    | List of Loc.t * t list

  val atom_or_quoted_string : Loc.t -> string -> t

  val loc : t -> Loc.t

  val remove_locs : t -> sexp
end with type sexp := t

val add_loc : t -> loc:Loc.t -> Ast.t

module Parse_error : sig
  type t

  val loc     : t -> Loc.t
  val message : t -> string
end

(** Exception raised in case of a parsing error *)
exception Parse_error of Parse_error.t

module Lexer : sig
  module Token : sig
    type t =
      | Atom          of Atom.t
      | Quoted_string of string
      | Lparen
      | Rparen
      | Sexp_comment
      | Eof
      | Template of Template.t
  end

  type t = Lexing.lexbuf -> Token.t

  val token : t
  val jbuild_token : t

  val of_syntax : syntax -> t
end

module Parser : sig
  module Mode : sig
    type 'a t =
      | Single      : Ast.t t
      | Many        : Ast.t list t
      | Many_as_one : Ast.t t
  end

  val parse
    :  mode:'a Mode.t
    -> ?lexer:Lexer.t
    -> Lexing.lexbuf
    -> 'a
end

val parse_string
  :  fname:string
  -> mode:'a Parser.Mode.t
  -> ?lexer:Lexer.t
  -> string
  -> 'a

module Encoder : sig
  type sexp = t
  include Sexp_intf.Combinators with type 'a t = 'a -> t

  val record : (string * sexp) list -> sexp

  type field

  val field
    :  string
    -> 'a t
    -> ?equal:('a -> 'a -> bool)
    -> ?default:'a
    -> 'a
    -> field
  val field_o : string -> 'a t-> 'a option -> field

  val record_fields : field list t

  val unknown : _ t
end with type sexp := t

module Decoder : sig
  type ast = Ast.t =
    | Atom of Loc.t * Atom.t
    | Quoted_string of Loc.t * string
    | Template of Template.t
    | List of Loc.t * ast list

  type hint =
    { on: string
    ; candidates: string list
    }

  exception Decoder of Loc.t * string * hint option

  (** Monad producing a value of type ['a] by parsing an input
      composed of a sequence of S-expressions.

      The input can be seen either as a plain sequence of
      S-expressions or a list of fields. The ['kind] parameter
      indicates how the input is seen:

      - with {['kind = [values]]}, the input is seen as an ordered
      sequence of S-expressions

      - with {['kind = [fields]]}, the input is seen as an unordered
      sequence of fields

      A field is a S-expression of the form: [(<atom> <values>...)]
      where [atom] is a plain atom, i.e. not a quoted string and not
      containing variables. [values] is a sequence of zero, one or more
      S-expressions.

      It is possible to switch between the two mode at any time using
      the appropriate combinator. Some primitives can be used in both
      mode while some are specific to one mode.  *)
  type ('a, 'kind) parser

  type values
  type fields

  type 'a t             = ('a, values) parser
  type 'a fields_parser = ('a, fields) parser

  (** [parse parser context sexp] parse a S-expression using the
      following parser. The input consist of a single
      S-expression. [context] allows to pass extra information such as
      versions to individual parsers. *)
  val parse : 'a t -> Univ_map.t -> ast -> 'a

  val return : 'a -> ('a, _) parser
  val (>>=) : ('a, 'k) parser -> ('a -> ('b, 'k) parser) -> ('b, 'k) parser
  val (>>|) : ('a, 'k) parser -> ('a -> 'b) -> ('b, 'k) parser
  val (>>>) : (unit, 'k) parser -> ('a, 'k) parser -> ('a, 'k) parser
  val map : ('a, 'k) parser -> f:('a -> 'b) -> ('b, 'k) parser
  val try_ : ('a, 'k) parser -> (exn -> ('a, 'k) parser) -> ('a, 'k) parser

  (** Access to the context *)
  val get : 'a Univ_map.Key.t -> ('a option, _) parser
  val set : 'a Univ_map.Key.t -> 'a -> ('b, 'k) parser -> ('b, 'k) parser
  val get_all : (Univ_map.t, _) parser
  val set_many : Univ_map.t -> ('a, 'k) parser -> ('a, 'k) parser

  (** Return the location of the list currently being parsed. *)
  val loc : (Loc.t, _) parser

  (** End of sequence condition. Uses [then_] if there are no more
      S-expressions to parse, [else_] otherwise. *)
  val if_eos : then_:('a, 'b) parser -> else_:('a, 'b) parser -> ('a, 'b) parser

  (** If the next element of the sequence is a list, parse it with
      [then_], otherwise parse it with [else_]. *)
  val if_list
    :  then_:'a t
    -> else_:'a t
    -> 'a t

  (** If the next element of the sequence is of the form [(:<name>
      ...)], use [then_] to parse [...]. Otherwise use [else_]. *)
  val if_paren_colon_form
    :  then_:(Loc.t * string -> 'a) t
    -> else_:'a t
    -> 'a t

  (** Expect the next element to be the following atom. *)
  val keyword : string -> unit t

  (** {[match_keyword [(k1, t1); (k2, t2); ...] ~fallback]} inspects
     the next element of the input sequence. If it is an atom equal to
     one of [k1], [k2], ... then the corresponding parser is used to
     parse the rest of the sequence. Other [fallback] is used. *)
  val match_keyword
    :  (string * 'a t) list
    -> fallback:'a t
    -> 'a t

  (** Use [before] to parse elements until the keyword is
      reached. Then use [after] to parse the rest. *)
  val until_keyword
    :  string
    -> before:'a t
    -> after:'b t
    -> ('a list * 'b option) t

  (** What is currently being parsed. The second argument is the atom
      at the beginnig of the list when inside a [sum ...] or [field
      ...]. *)
  type kind =
    | Values of Loc.t * string option
    | Fields of Loc.t * string option
  val kind : (kind, _) parser

  (** [repeat t] use [t] to consume all remaning elements of the input
      until the end of sequence is reached. *)
  val repeat : 'a t -> 'a list t

  (** Capture the rest of the input for later parsing *)
  val capture : ('a t -> 'a) t

  (** [enter t] expect the next element of the input to be a list and
      parse its contents with [t]. *)
  val enter : 'a t -> 'a t

  (** [fields fp] converts the rest of the current input to a list of
      fields and parse them with [fp]. This operation fails if one the
      S-expression in the input is not of the form [(<atom>
      <values>...)] *)
  val fields : 'a fields_parser -> 'a t

  (** [record fp = enter (fields fp)] *)
  val record : 'a fields_parser -> 'a t

  (** Consume the next element of the input as a string, int, char, ... *)
  include Sexp_intf.Combinators with type 'a t := 'a t

  (** Unparsed next element of the input *)
  val raw : ast t

  (** Inspect the next element of the input without consuming it *)
  val peek : ast option t

  (** Same as [peek] but fail if the end of input is reached *)
  val peek_exn : ast t

  (** Consume and ignore the next element of the input *)
  val junk : unit t

  (** Ignore all the rest of the input *)
  val junk_everything : (unit, _) parser

  (** [plain_string f] expects the next element of the input to be a
      plain string, i.e. either an atom or a quoted string, but not a
      template nor a list. *)
  val plain_string : (loc:Loc.t -> string -> 'a) -> 'a t

  val fix : ('a t -> 'a t) -> 'a t

  val of_sexp_error
    :  ?hint:hint
    -> Loc.t
    -> string
    -> _
  val of_sexp_errorf
    :  ?hint:hint
    -> Loc.t
    -> ('a, unit, string, 'b) format4
    -> 'a

  val no_templates
    : ?hint:hint
    -> Loc.t
    -> ('a, unit, string, 'b) format4
    -> 'a

  val located : ('a, 'k) parser -> (Loc.t * 'a, 'k) parser

  val enum : (string * 'a) list -> 'a t

  (** Parser that parse a S-expression of the form [(<atom> <s-exp1>
      <s-exp2> ...)] or [<atom>]. [<atom>] is looked up in the list and
      the remaining s-expressions are parsed using the corresponding
      list parser. *)
  val sum : (string * 'a t) list -> 'a t

  (** Check the result of a list parser, and raise a properly located
      error in case of failure. *)
  val map_validate
    :  'a fields_parser
    -> f:('a -> ('b, string) Result.t)
    -> 'b fields_parser

  (** {3 Parsing record fields} *)

  val field
    :  string
    -> ?default:'a
    -> ?on_dup:(Univ_map.t -> string -> Ast.t list -> unit)
    -> 'a t
    -> 'a fields_parser
  val field_o
    :  string
    -> ?on_dup:(Univ_map.t -> string -> Ast.t list -> unit)
    -> 'a t
    -> 'a option fields_parser

  val field_b
    :  ?check:(unit t)
    -> ?on_dup:(Univ_map.t -> string -> Ast.t list -> unit)
    -> string
    -> bool fields_parser

  val field_o_b
    :  ?check:(unit t)
    -> ?on_dup:(Univ_map.t -> string -> Ast.t list -> unit)
    -> string
    -> bool option fields_parser

  (** A field that can appear multiple times *)
  val multi_field
    :  string
    -> 'a t
    -> 'a list fields_parser

  (** Default value for [on_dup]. It fails with an appropriate error
      message. *)
  val field_present_too_many_times : Univ_map.t -> string -> Ast.t list -> _

  module Let_syntax : sig
    val ( $ ) : ('a -> 'b, 'k) parser -> ('a, 'k) parser -> ('b, 'k) parser
    val const : 'a -> ('a, _) parser
  end
end

module type Conv = sig
  type t
  val decode : t Decoder.t
  val encode : t Encoder.t
end

val to_sexp : t Sexp.Encoder.t

module Io : sig
  val load : ?lexer:Lexer.t -> Path.t -> mode:'a Parser.Mode.t -> 'a
end
