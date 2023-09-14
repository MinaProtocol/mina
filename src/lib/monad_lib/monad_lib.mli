open Core_kernel

module State : module type of State

module Make_ext : functor (M : Monad.S) -> sig
  type 'a t = 'a M.t

  val fold_m : f:('a -> 'b -> 'a t) -> init:'a -> 'b list -> 'a t

  val map_m : f:('a -> 'b t) -> 'a list -> 'b list t

  val concat_map_m : f:('a -> 'b list t) -> 'a list -> 'b list t

  val iter_m : f:('a -> unit t) -> 'a list -> unit t
end

module Make_ext2 : functor (M : Monad.S2) -> sig
  type ('a, 'b) t = ('a, 'b) M.t

  val fold_m : f:('a -> 'b -> ('a, 'c) t) -> init:'a -> 'b list -> ('a, 'c) t

  val map_m : f:('a -> ('b, 'c) t) -> 'a list -> ('b list, 'c) t

  val concat_map_m : f:('a -> ('b list, 'c) t) -> 'a list -> ('b list, 'c) t

  val iter_m : f:('a -> (unit, 'b) t) -> 'a list -> (unit, 'b) t
end
