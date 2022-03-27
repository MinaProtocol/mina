type t = Dirty.t Lazy.t

val generate_or_load : t -> Dirty.t

val ( + ) : t -> t -> t
