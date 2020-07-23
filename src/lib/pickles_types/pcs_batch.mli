type ('a, 'n, 'm) t

val map : ('a, 'n, 'm) t -> f:('a -> 'b) -> ('b, 'n, 'm) t

val pow : one:'f -> mul:('f -> 'f -> 'f) -> 'f -> int -> 'f

val create :
     without_degree_bound:'n Nat.t
  -> with_degree_bound:('a, 'm) Vector.t
  -> ('a, 'n, 'm) t

val combine_commitments :
     (int, 'n, 'm) t
  -> scale:('g -> 'f -> 'g)
  -> add:('g -> 'g -> 'g)
  -> xi:'f
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
  -> xi:'f
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
  -> xi:'f
  -> ('f, 'n) Vector.t
  -> ('f, 'm) Vector.t
  -> 'f

open Dlog_marlin_types.Poly_comm

val combine_split_commitments :
     (_, 'n, 'm) t
  -> scale_and_add:(acc:'g_acc -> xi:'f -> 'g -> 'g_acc)
  -> init:('g -> 'g_acc)
  -> xi:'f
  -> ('g Without_degree_bound.t, 'n) Vector.t
  -> ('g With_degree_bound.t, 'm) Vector.t
  -> 'g_acc

val combine_split_evaluations :
     ('a, 'n, 'm) t
  -> shifted_pow:('a -> 'f_ -> 'f_)
  -> mul:('f -> 'f_ -> 'f)
  -> mul_and_add:(acc:'f_ -> xi:'f_ -> 'f -> 'f_)
  -> evaluation_point:'f_
  -> init:('f -> 'f_)
  -> last:('f array -> 'f)
  -> xi:'f_
  -> ('f array, 'n) Vector.t
  -> ('f array, 'm) Vector.t
  -> 'f_
