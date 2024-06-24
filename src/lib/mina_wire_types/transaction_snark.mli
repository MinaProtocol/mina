open Utils

module Types : sig
  module type S = sig
    module V2 : S0
  end
end

module type Concrete = sig
  module Proof : sig
    module V2 : sig
      type t = Pickles.Proof.Proofs_verified_2.V2.t
    end
  end

  module V2 : sig
    type t =
      { statement : Mina_state.Snarked_ledger_state.With_sok.V2.t
      ; proof : Proof.V2.t
      }
  end
end

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with module V2 = M.V2
