(** Represent the output of [ocamlc -config] and contents of [Makefile.config].

    This library is internal to dune and guarantees no API stability. *)

open! Stdune

(** Represent a parsed and interpreted output of [ocamlc -config] and
    contents of [Makefile.config]. *)
type t

val to_sexp : t Sexp.Encoder.t

module Prog_and_args : sig
  type t =
    { prog : string
    ; args : string list
    }
end

(** {1 Raw bindings} *)

(** Represent the parsed but uninterpreted output of [ocamlc -config]
    or contents of [Makefile.config]. *)
module Vars : sig
  type t = string String.Map.t

  (** Parse the output of [ocamlc -config] given as a list of lines. *)
  val of_lines : string list -> (t, string) Result.t
end

(** {1 Creation} *)

module Origin : sig
  type t =
    | Ocamlc_config
    | Makefile_config of Path.t
end

(** Interpret raw bindings (this function also loads the
    [Makefile.config] file in the stdlib directory). *)
val make : Vars.t -> (t, Origin.t * string) Result.t

(** {1 Query} *)

(** The following parameters match the variables in the output of
    [ocamlc -config] but are stable across versions of OCaml. *)

val version                  : t -> int * int * int
val version_string           : t -> string
val standard_library_default : t -> string
val standard_library         : t -> string
val standard_runtime         : t -> string
val ccomp_type               : t -> string
val c_compiler               : t -> string
val ocamlc_cflags            : t -> string list
val ocamlopt_cflags          : t -> string list
val bytecomp_c_compiler      : t -> Prog_and_args.t
val bytecomp_c_libraries     : t -> string list
val native_c_compiler        : t -> Prog_and_args.t
val native_c_libraries       : t -> string list
val cc_profile               : t -> string list
val architecture             : t -> string
val model                    : t -> string
val int_size                 : t -> int
val word_size                : t -> int
val system                   : t -> string
val asm                      : t -> Prog_and_args.t
val asm_cfi_supported        : t -> bool
val with_frame_pointers      : t -> bool
val ext_exe                  : t -> string
val ext_obj                  : t -> string
val ext_asm                  : t -> string
val ext_lib                  : t -> string
val ext_dll                  : t -> string
val os_type                  : t -> string
val default_executable_name  : t -> string
val systhread_supported      : t -> bool
val host                     : t -> string
val target                   : t -> string
val profiling                : t -> bool
val flambda                  : t -> bool
val spacetime                : t -> bool
val safe_string              : t -> bool
val exec_magic_number        : t -> string
val cmi_magic_number         : t -> string
val cmo_magic_number         : t -> string
val cma_magic_number         : t -> string
val cmx_magic_number         : t -> string
val cmxa_magic_number        : t -> string
val ast_impl_magic_number    : t -> string
val ast_intf_magic_number    : t -> string
val cmxs_magic_number        : t -> string
val cmt_magic_number         : t -> string
val natdynlink_supported     : t -> bool
val supports_shared_libraries : t -> bool
val windows_unicode          : t -> bool

(** {1 Values} *)

module Value : sig
  type t =
    | Bool          of bool
    | Int           of int
    | String        of string
    | Words         of string list
    | Prog_and_args of Prog_and_args.t

  val to_string : t -> string

  val to_sexp : t Sexp.Encoder.t
end

val to_list : t -> (string * Value.t) list
