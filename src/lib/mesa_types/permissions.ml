(* The permissions of the Mesa era, which store a transaction version
   alongside the [set_verification_key] authorization. *)

open Core_kernel
module Auth_required = Mina_base.Permissions.Auth_required

module Poly = struct
  [%%versioned
  module Stable = struct
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
      [@@deriving equal, sexp, yojson]
    end
  end]
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      ( Auth_required.Stable.V2.t
      , Mina_numbers.Txn_version.Stable.V1.t )
      Poly.Stable.V2.t
    [@@deriving equal, sexp, yojson]

    let to_latest = Fn.id
  end
end]

let to_current
    ({ edit_state
     ; access
     ; send
     ; receive
     ; set_delegate
     ; set_permissions
     ; set_verification_key
     ; set_zkapp_uri
     ; edit_action_state
     ; set_token_symbol
     ; increment_nonce
     ; set_voting_for
     ; set_timing
     } :
      Stable.V2.t ) : Mina_base.Permissions.Stable.Latest.t =
  { edit_state
  ; access
  ; send
  ; receive
  ; set_delegate
  ; set_permissions
  ; set_verification_key = fst set_verification_key
  ; set_zkapp_uri
  ; edit_action_state
  ; set_token_symbol
  ; increment_nonce
  ; set_voting_for
  ; set_timing
  }
