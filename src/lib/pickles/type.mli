type (_, _) t =
  (* Polynomial commitment *)
  | PC : ('g1, < g1 : 'g1 ; .. >) t
  (* Scalar, used for challenges for instance *)
  | Scalar : ('s, < scalar : 's ; .. >) t
  (* Polynomials *)
  | Without_degree_bound
      : ( 'g1 Pickles_types.Plonk_types.Poly_comm.Without_degree_bound.t
        , < g1 : 'g1 ; .. > )
        t
  | With_degree_bound
      : ( 'g1_opt Pickles_types.Plonk_types.Poly_comm.With_degree_bound.t
        , < g1_opt : 'g1_opt ; .. > )
        t
  (* Field element *)
  | Field : ('field, < base_field : 'field ; .. >) t
  (* Concatenate two elements of this type as a list *)
  | ( :: ) : ('a, 'e) t * ('b, 'e) t -> ('a * 'b, 'e) t
