(* The zkApp account update of the Berkeley era. It differs from the current
   one only in the length of the zkApp state in its update and its account
   precondition. *)

open Core_kernel
module F = Mina_base.Zkapp_basic.F
module Set_or_keep = Mina_base.Zkapp_basic.Set_or_keep
module Or_ignore = Mina_base.Zkapp_basic.Or_ignore
module Public_key = Signature_lib.Public_key

module Update = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { app_state :
            F.Stable.V1.t Set_or_keep.Stable.V1.t Zkapp_state.V.Stable.V1.t
        ; delegate : Public_key.Compressed.Stable.V1.t Set_or_keep.Stable.V1.t
        ; verification_key :
            Mina_base.Verification_key_wire.Stable.V1.t Set_or_keep.Stable.V1.t
        ; permissions :
            Mina_base.Permissions.Stable.V2.t Set_or_keep.Stable.V1.t
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

  (** The new state elements are left unchanged. *)
  let to_mesa
      ({ app_state
       ; delegate
       ; verification_key
       ; permissions
       ; zkapp_uri
       ; token_symbol
       ; timing
       ; voting_for
       } :
        Stable.V1.t ) : Mina_base.Account_update.Update.Stable.Latest.t =
    { app_state = Zkapp_state.V.to_mesa app_state ~pad:Set_or_keep.Keep
    ; delegate
    ; verification_key
    ; permissions
    ; zkapp_uri
    ; token_symbol
    ; timing
    ; voting_for
    }
end

module Account_precondition = struct
  module Numeric = Mina_base.Zkapp_precondition.Numeric
  module Eq_data = Mina_base.Zkapp_precondition.Eq_data

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { balance : Currency.Balance.Stable.V1.t Numeric.Stable.V1.t
        ; nonce : Mina_numbers.Account_nonce.Stable.V1.t Numeric.Stable.V1.t
        ; receipt_chain_hash :
            Mina_base.Receipt.Chain_hash.Stable.V1.t Eq_data.Stable.V1.t
        ; delegate : Public_key.Compressed.Stable.V1.t Eq_data.Stable.V1.t
        ; state : F.Stable.V1.t Eq_data.Stable.V1.t Zkapp_state.V.Stable.V1.t
        ; action_state : F.Stable.V1.t Eq_data.Stable.V1.t
        ; proved_state : bool Eq_data.Stable.V1.t
        ; is_new : bool Eq_data.Stable.V1.t
        }
      [@@deriving equal, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  (** The new state elements are not checked. *)
  let to_mesa
      ({ balance
       ; nonce
       ; receipt_chain_hash
       ; delegate
       ; state
       ; action_state
       ; proved_state
       ; is_new
       } :
        Stable.V1.t ) :
      Mina_base.Account_update.Account_precondition.Stable.Latest.t =
    { balance
    ; nonce
    ; receipt_chain_hash
    ; delegate
    ; state = Zkapp_state.V.to_mesa state ~pad:Or_ignore.Ignore
    ; action_state
    ; proved_state
    ; is_new
    }
end

module Preconditions = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { network : Mina_base.Zkapp_precondition.Protocol_state.Stable.V1.t
        ; account : Account_precondition.Stable.V1.t
        ; valid_while :
            Mina_numbers.Global_slot_since_genesis.Stable.V1.t
            Mina_base.Zkapp_precondition.Numeric.Stable.V1.t
        }
      [@@deriving equal, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  let to_mesa ({ network; account; valid_while } : Stable.V1.t) :
      Mina_base.Account_update.Preconditions.Stable.Latest.t =
    { network; account = Account_precondition.to_mesa account; valid_while }
end

module Body = struct
  module Events = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          F.Stable.V1.t Mina_stdlib.Bounded_types.ArrayN16.Stable.V1.t list
        [@@deriving equal, sexp, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { public_key : Public_key.Compressed.Stable.V1.t
        ; token_id : Mina_base.Token_id.Stable.V2.t
        ; update : Update.Stable.V1.t
        ; balance_change :
            ( Currency.Amount.Stable.V1.t
            , Sgn.Stable.V1.t )
            Currency.Signed_poly.Stable.V1.t
        ; increment_nonce : bool
        ; events : Events.Stable.V1.t
        ; actions : Events.Stable.V1.t
        ; call_data : F.Stable.V1.t
        ; preconditions : Preconditions.Stable.V1.t
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

  let to_mesa
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
        Stable.V1.t ) : Mina_base.Account_update.Body.Stable.Latest.t =
    { public_key
    ; token_id
    ; update = Update.to_mesa update
    ; balance_change
    ; increment_nonce
    ; events
    ; actions
    ; call_data
    ; preconditions = Preconditions.to_mesa preconditions
    ; use_full_commitment
    ; implicit_account_creation_fee
    ; may_use_token
    ; authorization_kind
    }
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      ( Body.Stable.V1.t
      , Mina_base.Control.Stable.V2.t )
      Mina_base.Account_update.T.Without_aux.Stable.V1.t
    [@@deriving equal, sexp, yojson]

    let to_latest = Fn.id
  end
end]

let to_mesa
    ({ body; authorization; aux = () } :
      (_, _, unit) Mina_base.Account_update.Poly.t ) :
    Mina_base.Account_update.Stable.Latest.t =
  { body = Body.to_mesa body; authorization; aux = () }
