(** Mina manifest system.

    Inspired by the Tezos/Octez manifest
    (https://gitlab.com/tezos/tezos/-/tree/master/manifest).

    Generates dune files from centralized OCaml declarations. *)

(** {1 PPX presets} *)
module Ppx : sig
  type t

  (** ppx_version *)
  val minimal : t

  (** ppx_version ppx_jane *)
  val standard : t

  (** ppx_mina ppx_version ppx_jane *)
  val mina : t

  (** ppx_mina ppx_version ppx_jane ppx_deriving.std
      ppx_deriving_yojson *)
  val mina_rich : t

  (** ppx_jane ppx_deriving.eq *)
  val snarky : t

  (** Custom PPX list, emitted in the order given. *)
  val custom : string list -> t

  (** [extend preset extras] appends [extras] to [preset]. *)
  val extend : t -> string list -> t
end

(** {1 Dependencies} *)

type dep

(** External (opam) dependency. *)
val opam : string -> dep

(** Internal (local) dependency. *)
val local : string -> dep

(** Submodule dependency (e.g. snarky).
    Like [local] at the dune level, but semantically distinct:
    the library comes from a git submodule with its own
    dune-project and is not managed by the manifest. *)
val submodule : string -> dep

(** {1 Library registration} *)

val library :
     ?internal_name:string
  -> ?path:string
  -> ?synopsis:string
  -> ?deps:dep list
  -> ?ppx:Ppx.t
  -> ?kind:string
  -> ?inline_tests:bool
  -> ?inline_tests_bare:bool
  -> ?inline_tests_deps:string list
  -> ?bisect_sigterm:bool
  -> ?no_instrumentation:bool
  -> ?modes:string list
  -> ?flags:Dune_s_expr.t list
  -> ?library_flags:string list
  -> ?modules:string list
  -> ?modules_exclude:string list
  -> ?modules_without_implementation:string list
  -> ?virtual_modules:string list
  -> ?default_implementation:string
  -> ?implements:string
  -> ?foreign_stubs:string * string list
  -> ?c_library_flags:string list
  -> ?preprocessor_deps:string list
  -> ?ppx_runtime_libraries:string list
  -> ?wrapped:bool
  -> ?enabled_if:string
  -> ?js_of_ocaml:Dune_s_expr.t
  -> ?opam_deps:string list
  -> ?extra_stanzas:Dune_s_expr.t list
  -> string
  -> dep

val private_library :
     ?path:string
  -> ?synopsis:string
  -> ?deps:dep list
  -> ?ppx:Ppx.t
  -> ?kind:string
  -> ?inline_tests:bool
  -> ?inline_tests_bare:bool
  -> ?inline_tests_deps:string list
  -> ?bisect_sigterm:bool
  -> ?no_instrumentation:bool
  -> ?modes:string list
  -> ?flags:Dune_s_expr.t list
  -> ?library_flags:string list
  -> ?modules:string list
  -> ?modules_exclude:string list
  -> ?modules_without_implementation:string list
  -> ?virtual_modules:string list
  -> ?default_implementation:string
  -> ?implements:string
  -> ?foreign_stubs:string * string list
  -> ?c_library_flags:string list
  -> ?preprocessor_deps:string list
  -> ?ppx_runtime_libraries:string list
  -> ?wrapped:bool
  -> ?enabled_if:string
  -> ?js_of_ocaml:Dune_s_expr.t
  -> ?opam_deps:string list
  -> ?extra_stanzas:Dune_s_expr.t list
  -> string
  -> dep

(** {1 Executable registration} *)

val executable :
     ?package:string
  -> ?internal_name:string
  -> ?path:string
  -> ?deps:dep list
  -> ?ppx:Ppx.t
  -> ?modules:string list
  -> ?modes:string list
  -> ?flags:Dune_s_expr.t list
  -> ?link_flags:string list
  -> ?bisect_sigterm:bool
  -> ?no_instrumentation:bool
  -> ?forbidden_libraries:string list
  -> ?preprocessor_deps:string list
  -> ?enabled_if:string
  -> ?opam_deps:string list
  -> ?extra_stanzas:Dune_s_expr.t list
  -> string
  -> unit

val private_executable :
     ?package:string
  -> ?path:string
  -> ?deps:dep list
  -> ?ppx:Ppx.t
  -> ?modules:string list
  -> ?modes:string list
  -> ?flags:Dune_s_expr.t list
  -> ?link_flags:string list
  -> ?bisect_sigterm:bool
  -> ?no_instrumentation:bool
  -> ?forbidden_libraries:string list
  -> ?preprocessor_deps:string list
  -> ?enabled_if:string
  -> ?opam_deps:string list
  -> ?extra_stanzas:Dune_s_expr.t list
  -> string
  -> unit

(** {1 Test registration} *)

val test :
     ?package:string
  -> ?path:string
  -> ?deps:dep list
  -> ?ppx:Ppx.t
  -> ?modules:string list
  -> ?flags:Dune_s_expr.t list
  -> ?file_deps:string list
  -> ?enabled_if:string
  -> ?no_instrumentation:bool
  -> ?extra_stanzas:Dune_s_expr.t list
  -> string
  -> unit

(** {1 File-level stanzas} *)

(** Register raw stanzas for a dune file (e.g. [(env ...)]
    stanzas). These are emitted verbatim alongside any
    library/executable stanzas for the same path. *)
val file_stanzas : path:string -> Dune_s_expr.t list -> unit

(** {1 Generation} *)

(** Clear all registered targets. *)
val reset : unit -> unit

(** When [true], compare without writing files. *)
val check_mode : bool ref

type check_result =
  { path : string; status : [ `Ok | `Differs of string option | `New ] }

(** Compare all registered targets against existing dune files.
    Returns one result per dune file. Does not write anything. *)
val check : unit -> check_result list

(** Walk all registered targets, write dune files, and verify
    structural equivalence with existing files.
    In check mode, only compare without writing. *)
val generate : unit -> unit
