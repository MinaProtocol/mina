module Auth_required = struct
  module V2 = struct
    type t = None | Either | Proof | Signature | Impossible
  end
end

module Poly = struct
  module V2 = struct
    type 'controller t =
      { edit_state : 'controller
      ; send : 'controller
      ; receive : 'controller
      ; set_delegate : 'controller
      ; set_permissions : 'controller
      ; set_verification_key : 'controller
      ; set_zkapp_uri : 'controller
      ; edit_sequence_state : 'controller
      ; set_token_symbol : 'controller
      ; increment_nonce : 'controller
      ; set_voting_for : 'controller
      }
  end
end

module V2 = struct
  type t = Auth_required.V2.t Poly.V2.t
end
