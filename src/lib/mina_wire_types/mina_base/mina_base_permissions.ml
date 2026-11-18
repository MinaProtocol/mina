module Auth_required = struct
  module V2 = struct
    type t = None | Either | Proof | Signature | Impossible
  end
end

module Poly = struct
  module V2 = struct
    type ('controller, 'txn_version) t =
      { edit_state : 'controller
      ; access : 'controller
      ; send : 'controller
      ; receive : 'controller
      ; set_delegate : 'controller
      ; set_permissions : 'controller
      ; set_verification_key : 'controller * 'txn_version
      ; set_zkapp_uri : 'controller
      ; edit_action_state : 'controller
      ; set_token_symbol : 'controller
      ; increment_nonce : 'controller
      ; set_voting_for : 'controller
      ; set_timing : 'controller
      }
  end
end

module V2 = struct
  type t = (Auth_required.V2.t, Mina_numbers.Txn_version.V1.t) Poly.V2.t
end

module V3 = struct
  type t = (Auth_required.V2.t, Mina_numbers.Txn_version.V1.t) Poly.V2.t
end

module Update = struct
  module V1 = struct
    type t =
      { edit_state : Auth_required.V2.t
      ; access : Auth_required.V2.t
      ; send : Auth_required.V2.t
      ; receive : Auth_required.V2.t
      ; set_delegate : Auth_required.V2.t
      ; set_permissions : Auth_required.V2.t
      ; set_verification_key : Auth_required.V2.t * Mina_numbers.Txn_version.V1.t
      ; set_zkapp_uri : Auth_required.V2.t
      ; edit_action_state : Auth_required.V2.t
      ; set_token_symbol : Auth_required.V2.t
      ; increment_nonce : Auth_required.V2.t
      ; set_voting_for : Auth_required.V2.t
      ; set_timing : Auth_required.V2.t
      }
  end
end
