(** Batch of Polynomial Commitment Scheme *)

type ('a, 'm) t

val empty : ('a, Nat.z) t

val map : ('a, 'm) t -> f:('a -> 'b) -> ('b, 'm) t

val pow : one:'f -> mul:('f -> 'f -> 'f) -> 'f -> int -> 'f

val num_bits : int -> int

val combine_split_commitments :
     (_, 'm) t
  -> scale_and_add:(acc:'g_acc -> xi:'f -> 'g -> 'g_acc)
  -> init:('g -> 'g_acc option)
  -> xi:'f
  -> reduce_without_degree_bound:('without_degree_bound -> 'g list)
  -> reduce_with_degree_bound:('with_degree_bound -> 'g list)
  -> ('without_degree_bound, 'n) Vector.t
  -> ('with_degree_bound, 'm) Vector.t
  -> 'g_acc

val combine_split_evaluations :
     mul_and_add:(acc:'f_ -> xi:'f_ -> 'f -> 'f_)
  -> init:('f -> 'f_)
  -> xi:'f_
  -> 'f array list
  -> 'f_
