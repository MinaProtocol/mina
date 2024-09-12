(** Origin of dirtiness, i.e. data that is not saved on disk yet *)

type t = [ `Cache_hit | `Generated_something | `Locally_generated ]

val ( + ) : t -> t -> t
