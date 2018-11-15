open! Import

(** A simple wrapper around [Deps.t], where some dependencies are recorded as
    "rule deps" and other as "action deps". *)
type t

(** {1} Constructors *)

(** No dependencies. *)
val empty : t

(** Add a path as a rule dep. *)
val add_rule_path : t -> Path.t -> t

(** Add a set of paths as rule deps. *)
val add_rule_paths : t -> Path.Set.t -> t

(** Add a set of paths as action deps. *)
val add_action_paths : t -> Path.Set.t -> t

(** Add an environment variable as an action dep. *)
val add_action_env_var : t -> string -> t

(** {1} Deconstructors *)

(** Return the rule deps. *)
val rule_deps : t -> Deps.t

(** Return the action deps. *)
val action_deps : t -> Deps.t

(** Return the paths deps, both for the rule deps and the action deps . *)
val paths : t -> Path.Set.t
