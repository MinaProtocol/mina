type t

val allocate :
     ?priority:[ `High | `Low | `Medium ]
  -> t
  -> [> `Start_immediately | `Wait of unit Async.Ivar.t ]

val deallocate : t -> unit

val create : int -> t
