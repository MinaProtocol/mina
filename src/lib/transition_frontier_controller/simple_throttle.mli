type t

val allocate : t -> [> `Start_immediately | `Wait of unit Async.Ivar.t ]

val deallocate : t -> unit

val create : int -> t
