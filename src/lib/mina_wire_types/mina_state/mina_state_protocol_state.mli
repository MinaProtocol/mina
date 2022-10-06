open Utils

module Types : sig
  module type S = sig
    module Body : sig
      module Poly : sig
        module V1 : sig
          type ('a, 'b, 'c, 'd) t
        end
      end

      module Value : sig
        module V2 : sig
          type t =
            ( Mina_base_state_hash.V1.t
            , Mina_state_blockchain_state.Value.V2.t
            , Consensus.Data.Consensus_state.Value.V1.t
            , Mina_base_protocol_constants_checked.Value.V1.t )
            Poly.V1.t
        end
      end
    end
  end
end

module type Concrete = sig
  module Body : sig
    module Poly : sig
      module V1 : sig
        type ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t =
          { genesis_state_hash : 'state_hash
          ; blockchain_state : 'blockchain_state
          ; consensus_state : 'consensus_state
          ; constants : 'constants
          }
      end
    end

    module Value : sig
      module V2 : sig
        type t =
          ( Mina_base_state_hash.V1.t
          , Mina_state_blockchain_state.Value.V2.t
          , Consensus.Data.Consensus_state.Value.V1.t
          , Mina_base_protocol_constants_checked.Value.V1.t )
          Poly.V1.t
      end
    end
  end
end

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with module Body = M.Body
