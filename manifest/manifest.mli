(** Mina manifest system.

    Inspired by the Tezos/Octez manifest
    (https://gitlab.com/tezos/tezos/-/tree/master/manifest).

    Generates dune files from centralized OCaml declarations. *)

(** {1 PPX presets} *)
module Ppx : sig
  type t

  val minimal : t
  (** ppx_version *)

  val standard : t
  (** ppx_version ppx_jane *)

  val mina : t
  (** ppx_mina ppx_version ppx_jane *)

  val mina_rich : t
  (** ppx_mina ppx_version ppx_jane ppx_deriving.std
      ppx_deriving_yojson *)

  val snarky : t
  (** ppx_jane ppx_deriving.eq *)

  val custom : string list -> t
  (** Custom PPX list, emitted in the order given. *)

  val extend : t -> string list -> t
  (** [extend preset extras] appends [extras] to [preset]. *)
end

(** {1 Dependencies} *)

type dep

val opam : string -> dep
(** External (opam) dependency. *)

val local : string -> dep
(** Internal (local) dependency. *)

(** {1 Library registration} *)

val library :
  ?internal_name:string ->
  ?path:string ->
  ?synopsis:string ->
  ?deps:dep list ->
  ?ppx:Ppx.t ->
  ?kind:string ->
  ?inline_tests:bool ->
  ?inline_tests_bare:bool ->
  ?inline_tests_deps:string list ->
  ?no_instrumentation:bool ->
  ?flags:Dune_s_expr.t list ->
  ?library_flags:string list ->
  ?modules:string list ->
  ?modules_without_implementation:string list ->
  ?virtual_modules:string list ->
  ?default_implementation:string ->
  ?implements:string ->
  ?foreign_stubs:(string * string list) ->
  ?c_library_flags:string list ->
  ?preprocessor_deps:string list ->
  ?ppx_runtime_libraries:string list ->
  ?wrapped:bool ->
  ?enabled_if:string ->
  ?js_of_ocaml:Dune_s_expr.t ->
  ?opam_deps:string list ->
  ?extra_stanzas:Dune_s_expr.t list ->
  string ->
  unit

val private_library :
  ?path:string ->
  ?synopsis:string ->
  ?deps:dep list ->
  ?ppx:Ppx.t ->
  ?kind:string ->
  ?inline_tests:bool ->
  ?inline_tests_bare:bool ->
  ?inline_tests_deps:string list ->
  ?no_instrumentation:bool ->
  ?flags:Dune_s_expr.t list ->
  ?library_flags:string list ->
  ?modules:string list ->
  ?modules_without_implementation:string list ->
  ?virtual_modules:string list ->
  ?default_implementation:string ->
  ?implements:string ->
  ?foreign_stubs:(string * string list) ->
  ?c_library_flags:string list ->
  ?preprocessor_deps:string list ->
  ?ppx_runtime_libraries:string list ->
  ?wrapped:bool ->
  ?enabled_if:string ->
  ?js_of_ocaml:Dune_s_expr.t ->
  ?opam_deps:string list ->
  ?extra_stanzas:Dune_s_expr.t list ->
  string ->
  unit

(** {1 Executable registration} *)

val executable :
  ?package:string ->
  ?internal_name:string ->
  ?path:string ->
  ?deps:dep list ->
  ?ppx:Ppx.t ->
  ?modules:string list ->
  ?modes:string list ->
  ?flags:Dune_s_expr.t list ->
  ?link_flags:string list ->
  ?bisect_sigterm:bool ->
  ?no_instrumentation:bool ->
  ?forbidden_libraries:string list ->
  ?enabled_if:string ->
  ?opam_deps:string list ->
  ?extra_stanzas:Dune_s_expr.t list ->
  string ->
  unit

val private_executable :
  ?package:string ->
  ?path:string ->
  ?deps:dep list ->
  ?ppx:Ppx.t ->
  ?modules:string list ->
  ?modes:string list ->
  ?flags:Dune_s_expr.t list ->
  ?link_flags:string list ->
  ?bisect_sigterm:bool ->
  ?no_instrumentation:bool ->
  ?forbidden_libraries:string list ->
  ?enabled_if:string ->
  ?opam_deps:string list ->
  ?extra_stanzas:Dune_s_expr.t list ->
  string ->
  unit

(** {1 Test registration} *)

val test :
  ?package:string ->
  ?path:string ->
  ?deps:dep list ->
  ?ppx:Ppx.t ->
  ?modules:string list ->
  ?flags:Dune_s_expr.t list ->
  ?no_instrumentation:bool ->
  ?extra_stanzas:Dune_s_expr.t list ->
  string ->
  unit

(** {1 File-level stanzas} *)

val file_stanzas :
  path:string ->
  Dune_s_expr.t list ->
  unit
(** Register raw stanzas for a dune file (e.g. [(env ...)]
    stanzas). These are emitted verbatim alongside any
    library/executable stanzas for the same path. *)

(** {1 Generation} *)

val reset : unit -> unit
(** Clear all registered targets. *)

val check_mode : bool ref
(** When [true], compare without writing files. *)

type check_result =
  { path : string
  ; status : [ `Ok | `Differs of string option | `New ]
  }

val check : unit -> check_result list
(** Compare all registered targets against existing dune files.
    Returns one result per dune file. Does not write anything. *)

val generate : unit -> unit
(** Walk all registered targets, write dune files, and verify
    structural equivalence with existing files.
    In check mode, only compare without writing. *)
