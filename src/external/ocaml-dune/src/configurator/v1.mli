type t

val create
  :  ?dest_dir:string
  -> ?ocamlc:string
  -> ?log:(string -> unit)
  -> string (** name, such as library name *)
  -> t

(** Return the value associated to a variable in the output of [ocamlc -config] *)
val ocaml_config_var     : t -> string -> string option
val ocaml_config_var_exn : t -> string -> string

(** [c_test t ?c_flags ?link_flags c_code] try to compile and link the C code given in
    [c_code]. Return whether compilation was successful. *)
val c_test
  :  t
  -> ?c_flags:   string list (** default: [] *)
  -> ?link_flags:string list (** default: [] *)
  -> string
  -> bool

module C_define : sig
  module Type : sig
    type t =
      | Switch (** defined/undefined *)
      | Int
      | String
  end

  module Value : sig
    type t =
      | Switch of bool
      | Int    of int
      | String of string
  end

  (** Import some #define from the given header files. For instance:

      {[
        # C.C_define.import c ~includes:"caml/config.h" ["ARCH_SIXTYFOUR", Switch];;
        - (string * Configurator.C_define.Value.t) list = ["ARCH_SIXTYFOUR", Switch true]
      ]}
  *)
  val import
    :  t
    -> ?prelude: string
    (** Define extra code be used with extracting values below. Note that the
        compiled code is never executed. *)
    -> ?c_flags:   string list
    -> includes:   string list
    -> (string * Type.t ) list
    -> (string * Value.t) list

  (** Generate a C header file containing the following #define. [protection_var] is used
      to enclose the file with:

      {[
        #ifndef BLAH
        #define BLAH
        ...
        #endif
      ]}

      If not specified, it is inferred from the name given to [create] and the
      filename. *)
  val gen_header_file
    :  t
    -> fname:string
    -> ?protection_var:string
    -> (string * Value.t) list -> unit
end

module Pkg_config : sig
  type configurator = t
  type t

  (** Returns [None] if pkg-config is not installed *)
  val get : configurator -> t option

  type package_conf =
    { libs   : string list
    ; cflags : string list
    }

  (** Returns [None] if [package] is not available *)
  val query : t -> package:string -> package_conf option
end with type configurator := t

module Flags : sig

  val write_sexp : string -> string list -> unit
  (** [write_sexp fname s] writes the list of strings [s] to the file [fname] in
      an appropriate format so that it can used in jbuild files with [(:include
      [fname])]. *)

  val write_lines : string -> string list -> unit
  (** [write_lines fname s] writes the list of string [s] to the file [fname]
      with one line per string so that it can be used in Dune action rules with
      [%{read-lines:<path>}]. *)

  val extract_comma_space_separated_words : string -> string list
  (** [extract_comma_space_separated_words s] returns a list of words in
      [s] that are separated by a newline, tab, space or comma character. *)

  val extract_blank_separated_words : string -> string list
  (** [extract_blank_separated_words s] returns a list of words in [s]
      that are separated by a tab or space character. *)

  val extract_words : string -> is_word_char:(char -> bool) -> string list
  (** [extract_words s ~is_word_char] will split the string [s] into
      a list of words.  A valid word character is defined by the [is_word_char]
      predicate returning true and anything else is considered a separator.
      Any blank words are filtered out of the results. *)
end

(** Typical entry point for configurator programs *)
val main
  :  ?args:(Arg.key * Arg.spec * Arg.doc) list
  -> name:string
  -> (t -> unit)
  -> unit

(** Abort execution. If raised from within [main], the argument of [die] is printed as
    [Error: <message>]. *)
val die : ('a, unit, string, 'b) format4 -> 'a
