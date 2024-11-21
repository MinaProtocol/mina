(** Batch of Polynomial Commitment Scheme *)

type ('a, 'n, 'm) t

val map : ('a, 'n, 'm) t -> f:('a -> 'b) -> ('b, 'n, 'm) t

val pow : one:'f -> mul:('f -> 'f -> 'f) -> 'f -> int -> 'f

val num_bits : int -> int

val create :
     without_degree_bound:'n Nat.t
  -> with_degree_bound:('a, 'm) Vector.t
  -> ('a, 'n, 'm) t

val combine_commitments :
     (int, 'n, 'm) t
  -> scale:('g -> 'f -> 'g)
  -> add:('g -> 'g -> 'g)
  -> polyscale:'f
  -> ('g, 'n) Vector.t
  -> ('g * 'g, 'm) Vector.t
  -> 'g

val combine_evaluations :
     (int, 'n, 'm) t
  -> crs_max_degree:int
  -> mul:('f -> 'f -> 'f)
  -> add:('f -> 'f -> 'f)
  -> one:'f
  -> evaluation_point:'f
  -> polyscale:'f
  -> ('f, 'n) Vector.t
  -> ('f, 'm) Vector.t
  -> 'f

val combine_evaluations' :
     ('a, 'n, 'm) t
  -> shifted_pow:('a -> 'f -> 'f)
  -> mul:('f -> 'f -> 'f)
  -> add:('f -> 'f -> 'f)
  -> one:'f
  -> evaluation_point:'f
  -> polyscale:'f
  -> ('f, 'n) Vector.t
  -> ('f, 'm) Vector.t
  -> 'f

val combine_split_commitments :
     (_, 'n, 'm) t
  -> scale_and_add:(acc:'g_acc -> polyscale:'f -> 'g -> 'g_acc)
  -> init:('g -> 'g_acc option)
  -> polyscale:'f
  -> reduce_without_degree_bound:('without_degree_bound -> 'g list)
  -> reduce_with_degree_bound:('with_degree_bound -> 'g list)
  -> ('without_degree_bound, 'n) Vector.t
  -> ('with_degree_bound, 'm) Vector.t
  -> 'g_acc

val combine_split_evaluations :
     mul_and_add:(acc:'f_ -> polyscale:'f_ -> 'f -> 'f_)
  -> init:('f -> 'f_)
  -> polyscale:'f_
  -> 'f array list
  -> 'f_
