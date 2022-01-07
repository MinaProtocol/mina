(** Can only be used Linearly, you will miss updates if you have two consumers *)

type read_write

type read_only

type _ flag = Read_write : read_write flag | Read_only : read_only flag

type 'a t_

type ('flag, 'a) t = 'a t_ constraint 'flag = _ flag

val create : f:('a -> 'b) -> 'a -> (read_write flag, 'b) t

val get : (_ flag, 'a) t -> 'a * [> `Different | `Same ]

val update : (read_write flag, 'a) t -> 'a -> unit

val on_update : (_ flag, 'a) t -> f:('a -> unit) -> unit

val read_only : (read_write flag, 'a) t -> (read_only flag, 'a) t
