module Closed_interval = struct
  module V1 = struct
    type 'a t = { lower : 'a; upper : 'a }
  end
end

module Numeric = struct
  module V1 = struct
    type 'a t = 'a Closed_interval.V1.t Mina_base_zkapp_basic.Or_ignore.V1.t
  end
end

module Protocol_state = struct
  module Epoch_data = struct
    module V1 = struct
      type t =
        ( ( Mina_base_ledger_hash.V1.t Mina_base_zkapp_basic.Or_ignore.V1.t
          , Currency.Amount.V1.t Numeric.V1.t )
          Mina_base_epoch_ledger.Poly.V1.t
        , Snark_params.Tick.Field.t Mina_base_zkapp_basic.Or_ignore.V1.t
        , Data_hash_lib.State_hash.V1.t Mina_base_zkapp_basic.Or_ignore.V1.t
        , Data_hash_lib.State_hash.V1.t Mina_base_zkapp_basic.Or_ignore.V1.t
        , Mina_numbers.Length.V1.t Numeric.V1.t )
        Mina_base_epoch_data.Poly.V1.t
    end
  end

  module Poly = struct
    module V1 = struct
      type ('snarked_ledger_hash, 'length, 'global_slot, 'amount, 'epoch_data) t =
        { snarked_ledger_hash : 'snarked_ledger_hash
        ; blockchain_length : 'length
        ; min_window_density : 'length
        ; total_currency : 'amount
        ; global_slot_since_genesis : 'global_slot
        ; staking_epoch_data : 'epoch_data
        ; next_epoch_data : 'epoch_data
        }
    end
  end

  module V1 = struct
    type t =
      ( Mina_base_ledger_hash.V1.t Mina_base_zkapp_basic.Or_ignore.V1.t
      , Mina_numbers.Length.V1.t Numeric.V1.t
      , Mina_numbers.Global_slot_since_genesis.V1.t Numeric.V1.t
      , Currency.Amount.V1.t Numeric.V1.t
      , Epoch_data.V1.t )
      Poly.V1.t
  end
end

module Valid_while = struct
  module V1 = struct
    type t = Mina_numbers.Global_slot_since_genesis.V1.t Numeric.V1.t
  end
end

module Permissions = struct
  module V2 = struct
    type t =
      { edit_state :
          Mina_base_permissions.Auth_required.V2.t
          Mina_base_zkapp_basic.Or_ignore.V1.t
      ; access :
          Mina_base_permissions.Auth_required.V2.t
          Mina_base_zkapp_basic.Or_ignore.V1.t
      ; send :
          Mina_base_permissions.Auth_required.V2.t
          Mina_base_zkapp_basic.Or_ignore.V1.t
      ; receive :
          Mina_base_permissions.Auth_required.V2.t
          Mina_base_zkapp_basic.Or_ignore.V1.t
      ; set_delegate :
          Mina_base_permissions.Auth_required.V2.t
          Mina_base_zkapp_basic.Or_ignore.V1.t
      ; set_permissions :
          Mina_base_permissions.Auth_required.V2.t
          Mina_base_zkapp_basic.Or_ignore.V1.t
      ; set_verification_key :
          Mina_base_permissions.Auth_required.V2.t
          Mina_base_zkapp_basic.Or_ignore.V1.t
      ; set_zkapp_uri :
          Mina_base_permissions.Auth_required.V2.t
          Mina_base_zkapp_basic.Or_ignore.V1.t
      ; edit_action_state :
          Mina_base_permissions.Auth_required.V2.t
          Mina_base_zkapp_basic.Or_ignore.V1.t
      ; set_token_symbol :
          Mina_base_permissions.Auth_required.V2.t
          Mina_base_zkapp_basic.Or_ignore.V1.t
      ; increment_nonce :
          Mina_base_permissions.Auth_required.V2.t
          Mina_base_zkapp_basic.Or_ignore.V1.t
      ; set_voting_for :
          Mina_base_permissions.Auth_required.V2.t
          Mina_base_zkapp_basic.Or_ignore.V1.t
      ; set_timing :
          Mina_base_permissions.Auth_required.V2.t
          Mina_base_zkapp_basic.Or_ignore.V1.t
      }
  end
end

module Account = struct
  module V2 = struct
    type t =
      { balance : Currency.Balance.V1.t Numeric.V1.t
      ; nonce : Mina_numbers.Account_nonce.V1.t Numeric.V1.t
      ; receipt_chain_hash :
          Snark_params.Tick.Field.t Mina_base_zkapp_basic.Or_ignore.V1.t
      ; delegate :
          Public_key.Compressed.V1.t Mina_base_zkapp_basic.Or_ignore.V1.t
      ; state :
          Snark_params.Tick.Field.t Mina_base_zkapp_basic.Or_ignore.V1.t
          Mina_base_zkapp_state.V.V1.t
      ; action_state :
          Snark_params.Tick.Field.t Mina_base_zkapp_basic.Or_ignore.V1.t
      ; proved_state : bool Mina_base_zkapp_basic.Or_ignore.V1.t
      ; is_new : bool Mina_base_zkapp_basic.Or_ignore.V1.t
      ; permissions : Permissions.V2.t
      }
  end
end
