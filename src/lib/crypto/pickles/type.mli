type (_, _) t =
  | PC : ('g1, < g1 : 'g1 ; .. >) t  (** Polynomial commitment *)
  | Scalar : ('s, < scalar : 's ; .. >) t
      (** Scalar, used for challenges for instance *)
  | Without_degree_bound
      : ( 'g1 Pickles_types.Plonk_types.Poly_comm.Without_degree_bound.t
        , < g1 : 'g1 ; .. > )
        t  (** Polynomials *)
  | With_degree_bound
      : ( 'g1_opt Pickles_types.Plonk_types.Poly_comm.With_degree_bound.t
        , < g1_opt : 'g1_opt ; .. > )
        t  (** Polynomial *)
  | Field : ('field, < base_field : 'field ; .. >) t  (** Field element *)
  | ( :: ) : ('a, 'e) t * ('b, 'e) t -> ('a * 'b, 'e) t
      (** Concatenate two elements of this type as a list *)
