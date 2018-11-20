(** Compilation contexts *)

(** jbuild supports two different kind of contexts:

    - the default context, which correspond to the environment jbuild is run, i.e. it
    takes [ocamlc] and other tools from the [PATH] and the ocamlfind configuration where
    it can find it

    - opam switch contexts, where one opam switch correspond to one context

    each context is built into a sub-directory of Path.build_dir (usually _build):

    - _build/default for the default context
    - _build/<switch> for other contexts

    jbuild is able to build simultaneously against several contexts. In particular this
    allow for simple cross-compilation: when an executable running on the host is needed,
    it is obtained by looking in another context.
*)

open! Stdune
open! Import

module Kind : sig
  module Opam : sig
    type t =
      { root   : string option
      ; switch : string
      }
  end
  type t = Default | Opam of Opam.t
end

module Env_nodes : sig
  type t =
    { context: Dune_env.Stanza.t option
    ; workspace: Dune_env.Stanza.t option
    }
end

type t =
  { name : string
  ; kind : Kind.t

  ; profile : string

  ; (** [true] if this context is used for the .merlin files *)
    merlin : bool

  ; (** If this context is a cross-compilation context, you need another context for
        building tools used for the compilation that run on the host. *)
    for_host : t option

  ; (** [false] if a user explicitly listed this context in the workspace.
        Controls whether we add artifacts from this context @install *)
    implicit : bool

  ; (** Directory where artifact are stored, for instance "_build/default" *)
    build_dir : Path.t

  ; (** env node that this context was initialized with *)
    env_nodes : Env_nodes.t

  ; (** [PATH] *)
    path : Path.t list

  ; (** [OCAML_TOPLEVEL_PATH] *)
    toplevel_path : Path.t option

  ; (** Ocaml bin directory with all ocaml tools *)
    ocaml_bin  : Path.t
  ; ocaml      : Path.t
  ; ocamlc     : Path.t
  ; ocamlopt   : Path.t option
  ; ocamldep   : Path.t
  ; ocamlmklib : Path.t

  ; (** Environment variables *)
    env : Env.t

  ; findlib : Findlib.t
  ; findlib_toolchain : string option

  ; (** Misc *)
    arch_sixtyfour : bool

  ; opam_var_cache : (string, string) Hashtbl.t

  ; (** Native dynlink *)
    natdynlink_supported : Dynlink_supported.By_the_os.t

  ; ocaml_config            : Ocaml_config.t
  ; version_string          : string
  ; version                 : Ocaml_version.t
  ; stdlib_dir              : Path.t
  ; ccomp_type              : string
  ; c_compiler              : string
  ; ocamlc_cflags           : string list
  ; ocamlopt_cflags         : string list
  ; bytecomp_c_libraries    : string list
  ; native_c_libraries      : string list
  ; cc_profile              : string list
  ; architecture            : string
  ; system                  : string
  ; ext_obj                 : string
  ; ext_asm                 : string
  ; ext_lib                 : string
  ; ext_dll                 : string
  ; ext_exe                 : string
  ; os_type                 : string
  ; default_executable_name : string
  ; host                    : string
  ; target                  : string
  ; flambda                 : bool
  ; exec_magic_number       : string
  ; cmi_magic_number        : string
  ; cmo_magic_number        : string
  ; cma_magic_number        : string
  ; cmx_magic_number        : string
  ; cmxa_magic_number       : string
  ; ast_impl_magic_number   : string
  ; ast_intf_magic_number   : string
  ; cmxs_magic_number       : string
  ; cmt_magic_number        : string

  ; supports_shared_libraries : Dynlink_supported.By_the_os.t

  ; which_cache             : (string, Path.t option) Hashtbl.t
  }

val to_sexp : t -> Sexp.t

(** Compare the context names *)
val compare : t -> t -> Ordering.t

val create : env:Env.t -> Workspace.t -> t list Fiber.t

val which : t -> string -> Path.t option

val opam_config_var : t -> string -> string option Fiber.t

val install_prefix : t -> Path.t Fiber.t
val install_ocaml_libdir : t -> Path.t option Fiber.t

(** Return the compiler needed for this compilation mode *)
val compiler : t -> Mode.t -> Path.t option

(** The best compilation mode for this context *)
val best_mode : t -> Mode.t

(** [\["-g"\]] if [!Clflags.g] and [\[\]] otherwise *)
val cc_g : t -> string list

val name : t -> string
