open Pickles.Impls.Step.Internal_Basic

type 'a t

include Core_kernel.Monad.S with type 'a t := 'a t

val lift2 : ('a -> 'b -> 'c) -> 'a t -> 'b t -> 'c t

(** Applicative bind, similar to Haskell's notation for applicative functors
 Avoid using it with map, use lift2 *)
val ( <*> ) : ('a -> 'b) t -> 'a t -> 'b t

val evaluate : 'a t -> 'a

val hash : init:field Oracle.State.t -> field array -> field t

val hash_batch :
  ([ `State of field Oracle.State.t ] * field array) list -> field list t

val map_list : f:('a -> 'b t) -> 'a list -> 'b list t

val fold_right : f:('e -> 'acc -> 'acc t) -> init:'acc -> 'e list -> 'acc t
