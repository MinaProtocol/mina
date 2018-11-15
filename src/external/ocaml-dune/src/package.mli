(** Information about a package defined in the workspace *)

open! Stdune

module Name : sig
  type t

  val of_string : string -> t

  val opam_fn : t -> string

  val version_fn : t -> string

  include Interned.S with type t := t

  val decode : t Dune_lang.Decoder.t

  module Infix : Comparable.OPS with type t = t
end

type t =
  { name                   : Name.t
  ; path                   : Path.t
  ; version_from_opam_file : string option
  }

val opam_file : t -> Path.t

val meta_file : t -> Path.t
