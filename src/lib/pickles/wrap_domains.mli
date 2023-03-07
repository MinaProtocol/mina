open Pickles_types

module Make
    (A : Poly_types.T0)
    (A_value : Poly_types.T0)
    (Ret_var : Poly_types.T0)
    (Ret_value : Poly_types.T0)
    (Auxiliary_var : Poly_types.T0)
    (Auxiliary_value : Poly_types.T0) : sig
  val f_debug :
       ('a, 'b, 'c) Full_signature.t
    -> 'd
    -> ('e, 'b) Hlist.Length.t
    -> feature_flags:Plonk_types.Opt.Flag.t Plonk_types.Features.t
    -> max_proofs_verified:(module Nat.Add.Intf with type n = 'a)
    -> Import.Domains.t

  val f :
       ('a, 'b, 'c) Full_signature.t
    -> 'd
    -> ('e, 'b) Hlist.Length.t
    -> feature_flags:Plonk_types.Opt.Flag.t Plonk_types.Features.t
    -> max_proofs_verified:(module Nat.Add.Intf with type n = 'a)
    -> Import.Domains.Stable.V2.t
end
