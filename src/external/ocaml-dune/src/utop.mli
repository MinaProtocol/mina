(** Utop rules *)

open! Stdune

val utop_exe : string
(** Return the name of the utop target inside a directory where some
    libraries are defined. *)

val is_utop_dir : Path.t -> bool

val setup : Super_context.t -> dir:Path.t -> unit
