open Pickles_types

(* Module names below kept to document functor parameters, even though they are
   unused in the signature, hence the [@@warning "-67"] *)
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
    -> num_step_chunks:int
    -> feature_flags:Plonk_types.Opt.Flag.t Plonk_types.Features.t
    -> max_proofs_verified:(module Nat.Add.Intf with type n = 'a)
    -> Import.Domains.t

  val f :
       ('a, 'b, 'c) Full_signature.t
    -> 'd
    -> ('e, 'b) Hlist.Length.t
    -> num_step_chunks:int
    -> feature_flags:Plonk_types.Opt.Flag.t Plonk_types.Features.t
    -> max_proofs_verified:(module Nat.Add.Intf with type n = 'a)
    -> Import.Domains.Stable.V2.t
end
[@@warning "-67"]
