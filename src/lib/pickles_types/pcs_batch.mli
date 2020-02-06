type ('n, 'm) t

val create :
     without_degree_bound:'n Nat.t
  -> with_degree_bound:(int, 'm) Vector.t
  -> ('n, 'm) t

val combine_commitments :
     ('n Nat.s, 'm) t
  -> scale:('g -> 'f -> 'g)
  -> add:('g -> 'g -> 'g)
  -> xi:'f
  -> ('g, 'n Nat.s) Vector.t
  -> ('g * 'g, 'm) Vector.t
  -> 'g

val combine_evaluations :
     ('n Nat.s, 'm) t
  -> crs_max_degree:int
  -> mul:('f -> 'f -> 'f)
  -> add:('f -> 'f -> 'f)
  -> one:'f
  -> evaluation_point:'f
  -> xi:'f
  -> ('f, 'n Nat.s) Vector.t
  -> ('f, 'm) Vector.t
  -> 'f
