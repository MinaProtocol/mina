type (_, _) t =
  | PC : ('g1, < g1 : 'g1 ; .. >) t
  | Scalar : ('s, < scalar : 's ; .. >) t
  | Without_degree_bound
      : ( 'g1 Pickles_types.Plonk_types.Poly_comm.Without_degree_bound.t
        , < g1 : 'g1 ; .. > )
        t
  | With_degree_bound
      : ( 'g1_opt Pickles_types.Plonk_types.Poly_comm.With_degree_bound.t
        , < g1_opt : 'g1_opt ; .. > )
        t
  | Field : ('field, < base_field : 'field ; .. >) t
  | ( :: ) : ('a, 'e) t * ('b, 'e) t -> ('a * 'b, 'e) t
