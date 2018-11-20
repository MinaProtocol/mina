(** OCaml flags *)

open! Stdune

type t

val make
  :  flags          : Ordered_set_lang.Unexpanded.t
  -> ocamlc_flags   : Ordered_set_lang.Unexpanded.t
  -> ocamlopt_flags : Ordered_set_lang.Unexpanded.t
  -> default:t
  -> eval:(Ordered_set_lang.Unexpanded.t
           -> standard:(unit, string list) Build.t
           -> (unit, string list) Build.t)
  -> t

val default : profile:string -> t

val empty : t

val of_list : string list -> t

val get : t -> Mode.t -> (unit, string list) Build.t
val get_for_cm : t -> cm_kind:Cm_kind.t -> (unit, string list) Build.t

val append_common : t -> string list -> t
val prepend_common : string list -> t -> t

val common : t -> (unit, string list) Build.t

val dump : t -> (unit, Dune_lang.t list) Build.t
