module Update = struct
  module Timing_info = struct
    module V1 = struct
      type t =
        { initial_minimum_balance : Currency.Balance.V1.t
        ; cliff_time : Mina_numbers.Global_slot.V1.t
        ; cliff_amount : Currency.Amount.V1.t
        ; vesting_period : Mina_numbers.Global_slot.V1.t
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
      }
  end
end

module Body = struct
  module Fee_payer = struct
    module V1 = struct
      type t =
        { public_key : Public_key.Compressed.V1.t
        ; fee : Currency.Fee.V1.t
        ; valid_until : Mina_numbers.Global_slot.V1.t option
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
      ; token_id : Mina_base_token_id.V1.t
      ; update : Update.V1.t
      ; balance_change :
          (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
      ; increment_nonce : bool
      ; events : Events'.V1.t
      ; sequence_events : Events'.V1.t
      ; call_data : Pickles.Backend.Tick.Field.V1.t
      ; preconditions : Preconditions.V1.t
      ; use_full_commitment : bool
      ; caller : Mina_base_token_id.V1.t
      }
  end
end

module Fee_payer = struct
  module V1 = struct
    type t =
      { body : Body.Fee_payer.V1.t; authorization : Mina_base_signature.V1.t }
  end
end
