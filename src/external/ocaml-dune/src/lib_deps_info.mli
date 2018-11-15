(** Tracking of library dependencies *)

(** This module implements tracking of external library dependencies,
    for [dune external-lib-deps] *)

open! Stdune

module Kind : sig
  type t =
    | Optional
    | Required

  val merge : t -> t -> t

  val of_optional : bool -> t
end

type t = Kind.t Lib_name.Map.t

val merge : t -> t -> t
