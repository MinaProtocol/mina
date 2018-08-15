open Core

module type S = sig
  type t [@@deriving sexp, bin_io, hash, eq, compare]

  include Hashable.S with type t := t

  val depth : t -> int

  val parent : t -> t Or_error.t

  val child : t -> [`Left | `Right] -> t Or_error.t

  val child_exn : t -> [`Left | `Right] -> t

  val parent_exn : t -> t

  val dirs_from_root : t -> [`Left | `Right] list

  val root : t
end
