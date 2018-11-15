(** Dependency path *)

open! Stdune

module Entry : sig
  type t =
    | Path of Path.t
    | Alias of Path.t
    | Library of Path.t * Lib_name.t
    | Preprocess of Lib_name.t list
    | Loc of Loc.t

  val to_string : t -> string
  val pp : Format.formatter -> t -> unit
end

module Entries : sig
  type t = Entry.t list

  val pp : Format.formatter -> t -> unit
end

(** Re-raise an exception and augment it's dependency path with the
    given entry. The raised exception will be wrapped. *)
val reraise : exn -> Entry.t -> _

(** Extend the required_by stack of an exception *)
val prepend_exn : exn -> Entry.t -> exn

(** Extract a wrapped exception *)
val unwrap_exn : exn -> exn * Entry.t list option
