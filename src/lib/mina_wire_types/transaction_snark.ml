open Utils

module Types = struct
  module type S = sig
    module V3 : S0
  end
end

module type Concrete = sig
  module Proof : sig
    module V3 : sig
      type t = Pickles.Proof.Proofs_verified_2.V3.t
    end
  end

  module V3 : sig
    type t =
      ( Mina_state.Snarked_ledger_state.With_sok.V2.t
      , Proof.V3.t )
      Proof_carrying_data.V1.t
  end
end

module M = struct
  module Proof = struct
    module V3 = struct
      type t = Pickles.Proof.Proofs_verified_2.V3.t
    end
  end

  module V3 = struct
    type t =
      ( Mina_state.Snarked_ledger_state.With_sok.V2.t
      , Proof.V3.t )
      Proof_carrying_data.V1.t
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
