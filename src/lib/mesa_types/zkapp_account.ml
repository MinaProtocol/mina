(* The zkApp account of the Mesa era, which stores the zkApp version alongside
   the verification key rather than with it. *)

open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V3 = struct
      type ('app_state, 'vk, 'zkapp_version, 'field, 'slot, 'bool, 'zkapp_uri) t =
        { app_state : 'app_state
        ; verification_key : 'vk
        ; zkapp_version : 'zkapp_version
        ; action_state : 'field Pickles_types.Vector.Vector_5.Stable.V1.t
        ; last_action_slot : 'slot
        ; proved_state : 'bool
        ; zkapp_uri : 'zkapp_uri
        }
      [@@deriving equal, sexp, yojson]
    end
  end]
end

[%%versioned
module Stable = struct
  module V3 = struct
    type t =
      ( Mina_base.Zkapp_state.Value.Stable.V2.t
      , Mina_base.Verification_key_wire.Stable.V1.t option
      , Mina_numbers.Zkapp_version.Stable.V1.t
      , Mina_base.Zkapp_basic.F.Stable.V1.t
      , Mina_numbers.Global_slot_since_genesis.Stable.V1.t
      , bool
      , Mina_base.Zkapp_account.Zkapp_uri.Stable.V1.t )
      Poly.Stable.V3.t
    [@@deriving equal, sexp, yojson]

    let to_latest = Fn.id
  end
end]

let to_current
    ({ app_state
     ; verification_key
     ; zkapp_version
     ; action_state
     ; last_action_slot
     ; proved_state
     ; zkapp_uri
     } :
      Stable.V3.t ) : Mina_base.Zkapp_account.Stable.Latest.t =
  { app_state
  ; verification_key =
      Mina_base.Zkapp_account.Vk_with_version.of_flat ~zkapp_version
        verification_key
      |> Or_error.ok_exn
  ; action_state
  ; last_action_slot
  ; proved_state
  ; zkapp_uri
  }
