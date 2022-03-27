type tt = Z | S of t

and t = tt Core_kernel.Lazy.t

val to_int : t -> int

val take : t -> int -> [ `Failed_after of int | `Ok ]

val at_least : t -> Core_kernel__Int.t -> bool

val min : t list -> tt
