type ('a, 'n, 'm) t

val map: ('a, 'n, 'm) t -> f:('a -> 'b) -> ('b, 'n, 'm) t

val pow : one:'f
  -> mul:('f -> 'f -> 'f)
  -> add:('f -> 'f -> 'f)
  -> 'f
  -> int
  -> 'f

val create :
     without_degree_bound:'n Nat.t
  -> with_degree_bound:('a, 'm) Vector.t
  -> ('a, 'n, 'm) t

val combine_commitments :
     (int, 'n , 'm) t
  -> scale:('g -> 'f -> 'g)
  -> add:('g -> 'g -> 'g)
  -> xi:'f
  -> ('g, 'n ) Vector.t
  -> ('g * 'g, 'm) Vector.t
  -> 'g

val combine_evaluations :
     (int, 'n , 'm) t
  -> crs_max_degree:int
  -> mul:('f -> 'f -> 'f)
  -> add:('f -> 'f -> 'f)
  -> one:'f
  -> evaluation_point:'f
  -> xi:'f
  -> ('f, 'n ) Vector.t
  -> ('f, 'm) Vector.t
  -> 'f

val combine_evaluations' :
     ('a, 'n , 'm) t
  -> shifted_pow:('a -> 'f -> 'f)
  -> mul:('f -> 'f -> 'f)
  -> add:('f -> 'f -> 'f)
  -> one:'f
  -> evaluation_point:'f
  -> xi:'f
  -> ('f, 'n ) Vector.t
  -> ('f, 'm) Vector.t
  -> 'f
