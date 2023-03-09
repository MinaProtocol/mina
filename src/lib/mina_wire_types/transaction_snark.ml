open Utils

module Types = struct
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

module M = struct
  module Proof = struct
    module V2 = struct
      type t = Pickles.Proof.Proofs_verified_2.V2.t
    end
  end

  module V2 = struct
    type t =
      { statement : Mina_state.Snarked_ledger_state.With_sok.V2.t
      ; proof : Proof.V2.t
      }
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
