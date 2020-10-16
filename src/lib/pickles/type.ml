open Pickles_types.Dlog_plonk_types.Poly_comm

type (_, _) t =
  | PC : ('g1, < g1: 'g1 ; .. >) t
  | Scalar : ('s, < scalar: 's ; .. >) t
  | Without_degree_bound : ('g1 Without_degree_bound.t, < g1: 'g1 ; .. >) t
  | With_degree_bound
      : ('g1_opt With_degree_bound.t, < g1_opt: 'g1_opt ; .. >) t
  | ( :: ) : ('a, 'e) t * ('b, 'e) t -> ('a * 'b, 'e) t

let degree_bounded_pc = PC :: PC
