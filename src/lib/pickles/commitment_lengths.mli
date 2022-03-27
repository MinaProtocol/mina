val generic' :
     h:< size : 'a ; .. >
  -> sub:('a -> 'b -> 'c)
  -> add:'d
  -> mul:('b -> 'c -> 'a)
  -> of_int:(int -> 'b)
  -> ceil_div_max_degree:('a -> 'a)
  -> 'a Pickles_types.Dlog_plonk_types.Evals.t

val generic :
     ('a -> f:(Core_kernel.Int.t -> int) -> 'a)
  -> h:'a
  -> max_degree:Core_kernel.Int.t
  -> 'a Pickles_types.Dlog_plonk_types.Evals.t

val of_domains :
     Import.Domains.t
  -> max_degree:Core_kernel.Int.t
  -> int Pickles_types.Dlog_plonk_types.Evals.t

val of_domains_vector :
     (Import.Domains.t, 'a) Pickles_types.Vector.t
  -> max_degree:Core_kernel.Int.t
  -> (Core_kernel.Int.t, 'a) Pickles_types.Vector.t
     Pickles_types.Dlog_plonk_types.Evals.t
