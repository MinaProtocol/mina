module Authorization_kind = struct
  module V1 = struct
    (* field for Proof is a verification key hash *)
    type t = Signature | Proof of Snark_params.Tick.Field.t | None_given
  end
end

module May_use_token = struct
  module V1 = struct
    type t = No | Parents_own_token | Inherit_from_parent
  end
end

module Update = struct
  module Timing_info = struct
    module V1 = struct
      type t =
        { initial_minimum_balance : Currency.Balance.V1.t
        ; cliff_time : Mina_numbers.Global_slot_since_genesis.V1.t
        ; cliff_amount : Currency.Amount.V1.t
        ; vesting_period : Mina_numbers.Global_slot_span.V1.t
        ; vesting_increment : Currency.Amount.V1.t
        }
    end
  end

  module V1 = struct
    type t =
      { app_state :
          Snark_params.Tick.Field.t Mina_base_zkapp_basic.Set_or_keep.V1.t
          Mina_base_zkapp_state.V.V1.t
      ; delegate :
          Public_key.Compressed.V1.t Mina_base_zkapp_basic.Set_or_keep.V1.t
      ; verification_key :
          Mina_base_verification_key_wire.V1.t
          Mina_base_zkapp_basic.Set_or_keep.V1.t
      ; permissions :
          Mina_base_permissions.V2.t Mina_base_zkapp_basic.Set_or_keep.V1.t
      ; zkapp_uri : string Mina_base_zkapp_basic.Set_or_keep.V1.t
      ; token_symbol :
          Mina_base_account.Token_symbol.V1.t
          Mina_base_zkapp_basic.Set_or_keep.V1.t
      ; timing : Timing_info.V1.t Mina_base_zkapp_basic.Set_or_keep.V1.t
      ; voting_for :
          Data_hash_lib.State_hash.V1.t Mina_base_zkapp_basic.Set_or_keep.V1.t
      }
  end
end

module Account_precondition = struct
  module V1 = struct
    type t =
      | Full of Mina_base_zkapp_precondition.Account.V2.t
      | Nonce of Mina_numbers.Account_nonce.V1.t
      | Accept
  end
end

module Preconditions = struct
  module V1 = struct
    type t =
      { network : Mina_base_zkapp_precondition.Protocol_state.V1.t
      ; account : Account_precondition.V1.t
      ; valid_while : Mina_base_zkapp_precondition.Valid_while.V1.t
      }
  end
end

module Body = struct
  module Fee_payer = struct
    module V1 = struct
      type t =
        { public_key : Public_key.Compressed.V1.t
        ; fee : Currency.Fee.V1.t
        ; valid_until : Mina_numbers.Global_slot_since_genesis.V1.t option
        ; nonce : Mina_numbers.Account_nonce.V1.t
        }
    end
  end

  module Events' = struct
    module V1 = struct
      type t = Snark_params.Tick.Field.t array list
    end
  end

  module V1 = struct
    type t =
      { public_key : Public_key.Compressed.V1.t
      ; token_id : Mina_base_token_id.V2.t
      ; update : Update.V1.t
      ; balance_change :
          (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
      ; increment_nonce : bool
      ; events : Events'.V1.t
      ; actions : Events'.V1.t
      ; call_data : Pickles.Backend.Tick.Field.V1.t
      ; preconditions : Preconditions.V1.t
      ; use_full_commitment : bool
      ; implicit_account_creation_fee : bool
      ; may_use_token : May_use_token.V1.t
      ; authorization_kind : Authorization_kind.V1.t
      }
  end
end

module Fee_payer = struct
  module V1 = struct
    type t =
      { body : Body.Fee_payer.V1.t; authorization : Mina_base_signature.V1.t }
  end
end

module V1 = struct
  type t = { body : Body.V1.t; authorization : Mina_base_control.V2.t }
end
