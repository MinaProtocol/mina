(* The zkApp account update of the Mesa era. It differs from the current one
   only in the permissions its update sets, which store a transaction version
   alongside the [set_verification_key] authorization. *)

open Core_kernel
module F = Mina_base.Zkapp_basic.F
module Set_or_keep = Mina_base.Zkapp_basic.Set_or_keep
module Public_key = Signature_lib.Public_key

module Update = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { app_state :
            F.Stable.V1.t Set_or_keep.Stable.V1.t
            Mina_base.Zkapp_state.V.Stable.V2.t
        ; delegate : Public_key.Compressed.Stable.V1.t Set_or_keep.Stable.V1.t
        ; verification_key :
            Mina_base.Verification_key_wire.Stable.V1.t Set_or_keep.Stable.V1.t
        ; permissions : Permissions.Stable.V2.t Set_or_keep.Stable.V1.t
        ; zkapp_uri :
            Mina_base.Zkapp_account.Zkapp_uri.Stable.V1.t
            Set_or_keep.Stable.V1.t
        ; token_symbol :
            Mina_base.Account.Token_symbol.Stable.V1.t Set_or_keep.Stable.V1.t
        ; timing :
            Mina_base.Account_update.Update.Timing_info.Stable.V1.t
            Set_or_keep.Stable.V1.t
        ; voting_for : Mina_base.State_hash.Stable.V1.t Set_or_keep.Stable.V1.t
        }
      [@@deriving equal, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  let to_current
      ({ app_state
       ; delegate
       ; verification_key
       ; permissions
       ; zkapp_uri
       ; token_symbol
       ; timing
       ; voting_for
       } :
        Stable.V2.t ) : Mina_base.Account_update.Update.Stable.Latest.t =
    { app_state
    ; delegate
    ; verification_key
    ; permissions = Set_or_keep.map permissions ~f:Permissions.to_current
    ; zkapp_uri
    ; token_symbol
    ; timing
    ; voting_for
    }
end

module Body = struct
  module B = Mina_base.Account_update.Body

  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { public_key : Public_key.Compressed.Stable.V1.t
        ; token_id : Mina_base.Token_id.Stable.V2.t
        ; update : Update.Stable.V2.t
        ; balance_change :
            ( Currency.Amount.Stable.V1.t
            , Sgn.Stable.V1.t )
            Currency.Signed_poly.Stable.V1.t
        ; increment_nonce : bool
        ; events : B.Events'.Stable.V1.t
        ; actions : B.Actions'.Stable.V1.t
        ; call_data : F.Stable.V1.t
        ; preconditions : Mina_base.Account_update.Preconditions.Stable.V2.t
        ; use_full_commitment : bool
        ; implicit_account_creation_fee : bool
        ; may_use_token : Mina_base.Account_update.May_use_token.Stable.V1.t
        ; authorization_kind :
            Mina_base.Account_update.Authorization_kind.Stable.V1.t
        }
      [@@deriving equal, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  let to_current
      ({ public_key
       ; token_id
       ; update
       ; balance_change
       ; increment_nonce
       ; events
       ; actions
       ; call_data
       ; preconditions
       ; use_full_commitment
       ; implicit_account_creation_fee
       ; may_use_token
       ; authorization_kind
       } :
        Stable.V2.t ) : Mina_base.Account_update.Body.Stable.Latest.t =
    { public_key
    ; token_id
    ; update = Update.to_current update
    ; balance_change
    ; increment_nonce
    ; events
    ; actions
    ; call_data
    ; preconditions
    ; use_full_commitment
    ; implicit_account_creation_fee
    ; may_use_token
    ; authorization_kind
    }
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      ( Body.Stable.V2.t
      , Mina_base.Control.Stable.V2.t )
      Mina_base.Account_update.T.Without_aux.Stable.V1.t
    [@@deriving equal, sexp, yojson]

    let to_latest = Fn.id
  end
end]

let to_current
    ({ body; authorization; aux = () } :
      (_, _, unit) Mina_base.Account_update.Poly.t ) :
    Mina_base.Account_update.Stable.Latest.t =
  { body = Body.to_current body; authorization; aux = () }
