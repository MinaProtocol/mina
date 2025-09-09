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
    -> feature_flags:Opt.Flag.t Plonk_types.Features.Full.t
    -> num_chunks:int
    -> max_proofs_verified:(module Nat.Add.Intf with type n = 'a)
    -> Import.Domains.t Promise.t

  val f :
       ('a, 'b, 'c) Full_signature.t
    -> 'd
    -> ('e, 'b) Hlist.Length.t
    -> feature_flags:Opt.Flag.t Plonk_types.Features.Full.t
    -> num_chunks:int
    -> max_proofs_verified:(module Nat.Add.Intf with type n = 'a)
    -> Import.Domains.t
end
[@@warning "-67"]
