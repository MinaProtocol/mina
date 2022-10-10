(* Undocumented *)

module Make
    (A : Pickles_types.Poly_types.T0)
    (A_value : Pickles_types.Poly_types.T0)
    (Ret_var : Pickles_types.Poly_types.T0)
    (Ret_value : Pickles_types.Poly_types.T0)
    (Auxiliary_var : Pickles_types.Poly_types.T0)
    (Auxiliary_value : Pickles_types.Poly_types.T0) : sig
  module I :
      module type of
        Inductive_rule.T (A) (A_value) (Ret_var) (Ret_value) (Auxiliary_var)
          (Auxiliary_value)

  val f_debug :
       ('a, 'b, 'c) Full_signature.t
    -> 'd
    -> ('e, 'b) Pickles_types.Hlist.Length.t
    -> self:'f
    -> choices:'g
    -> max_proofs_verified:(module Pickles_types.Nat.Add.Intf with type n = 'a)
    -> Import.Domains.t

  val f :
       ('a, 'b, 'c) Full_signature.t
    -> 'd
    -> ('e, 'b) Pickles_types.Hlist.Length.t
    -> self:'f
    -> choices:'g
    -> max_proofs_verified:(module Pickles_types.Nat.Add.Intf with type n = 'a)
    -> Import.Domains.Stable.V2.t
end
