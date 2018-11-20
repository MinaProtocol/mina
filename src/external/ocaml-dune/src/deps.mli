open! Import

(** An abstract value representing dependencies, like paths or environment
    variables. *)
type t

(** {1} Constructors *)

(** No dependencies - neutral element for [union]. *)
val empty : t

(** Merge dependencies. *)
val union : t -> t -> t

(** Specialized version of [union] that only returns path dependencies. *)
val path_union : t -> t -> Path.Set.t

(** [path_diff a b] returns paths dependencies in [a] but not in [b]. *)
val path_diff : t -> t -> Path.Set.t

(** Add a path dependency. *)
val add_path : t -> Path.t -> t

(** Add several path dependencies. *)
val add_paths : t -> Path.Set.t -> t

(** Add a dependency to an environment variable. *)
val add_env_var : t -> string -> t

(** {1} Deconstructors *)

(** [trace t] is an abstract value that is guaranteed to change if the set of
    dependencies denoted by t changes, modulo hash collisions. *)
val trace : t -> Env.t -> (string * string) list

(** Return the path dependencies only. *)
val paths : t -> Path.Set.t

(** Serializer. *)
val to_sexp : t -> Dune_lang.t
