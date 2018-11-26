(** An expander is able to expand any dune template.
    It has two modes of expansion:

    1. Static. In this mode it will only expand variables that do not introduce
       dependncies

    2. Dynamic. In this mode, the expander will record dependencies that are
       introduced by forms it has failed to expand. Later, these dependenceis
       can be filled for a full expansion.*)
open Stdune

type t

val bindings : t -> Pform.Map.t
val scope : t -> Scope.t
val dir : t -> Path.t

val make
  :  scope:Scope.t
  -> context:Context.t
  -> artifacts:Artifacts.t
  -> artifacts_host:Artifacts.t
  -> cxx_flags:string list
  -> t

val set_env : t -> var:string -> value:string -> t

val hide_env : t -> var:string -> t

val set_dir : t -> dir:Path.t -> t

val set_scope : t -> scope:Scope.t -> t

val set_artifacts
  :  t
  -> artifacts:Artifacts.t
  -> artifacts_host:Artifacts.t
  -> t

val add_bindings : t -> bindings:Pform.Map.t -> t

val extend_env : t -> env:Env.t -> t

type var_expander =
  (Value.t list, Pform.Expansion.t) result option String_with_vars.expander

val expand
  :  t
  -> mode:'a String_with_vars.Mode.t
  -> template:String_with_vars.t
  -> 'a

val expand_path : t -> String_with_vars.t -> Path.t

val expand_str : t -> String_with_vars.t -> string

module Resolved_forms : sig
  type t

  (* Failed resolutions *)
  val failures : t -> Import.fail list

  (* All "name" for %{lib:name:...}/%{lib-available:name} forms *)
  val lib_deps : t -> Lib_deps_info.t

  (* Static deps from %{...} variables. For instance %{exe:...} *)
  val sdeps    : t -> Path.Set.t

  (* Dynamic deps from %{...} variables. For instance %{read:...} *)
  val ddeps    : t -> (unit, Value.t list) Build.t String.Map.t

  val empty : unit -> t
end

type targets =
  | Static of Path.t list
  | Infer
  | Alias

val with_record_deps
  :  t
  -> Resolved_forms.t
  -> read_package:(Package.t -> (unit, string option) Build.t)
  -> dep_kind:Lib_deps_info.Kind.t
  -> targets_written_by_user:targets
  -> map_exe:(Path.t -> Path.t)
  -> t

val with_record_no_ddeps
  :  t
  -> Resolved_forms.t
  -> dep_kind:Lib_deps_info.Kind.t
  -> map_exe:(Path.t -> Path.t)
  -> t

val add_ddeps_and_bindings
  :  t
  -> dynamic_expansions:Value.t list String.Map.t
  -> deps_written_by_user:Path.t Bindings.t
  -> t

val expand_var_exn : t -> Value.t list option String_with_vars.expander

val expand_and_eval_set
  :  t
  -> Ordered_set_lang.Unexpanded.t
  -> standard:(unit, string list) Build.t
  -> (unit, string list) Build.t
