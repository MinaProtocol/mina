(* Origin of dirtiness *)

type t = [ `Cache_hit | `Generated_something | `Locally_generated ]

val ( + ) : t -> t -> t
