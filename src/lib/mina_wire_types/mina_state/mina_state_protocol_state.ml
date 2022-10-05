open Utils

module Types = struct
  module type S = sig
    module Body : sig
      module Poly : sig
        module V1 : sig
          type ('a, 'b, 'c, 'd) t
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
  end
end

module M = struct
  module Body = struct
    module Poly = struct
      module V1 = struct
        type ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t =
          { genesis_state_hash : 'state_hash
          ; blockchain_state : 'blockchain_state
          ; consensus_state : 'consensus_state
          ; constants : 'constants
          }
      end
    end
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
