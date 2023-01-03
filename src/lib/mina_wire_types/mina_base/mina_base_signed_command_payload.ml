module Common = struct
  module Poly = struct
    module V1 = struct
      type ('fee, 'public_key, 'token_id, 'nonce, 'global_slot, 'memo) t =
        { fee : 'fee
        ; fee_token : 'token_id
        ; fee_payer_pk : 'public_key
        ; nonce : 'nonce
        ; valid_until : 'global_slot
        ; memo : 'memo
        }
    end

    module V2 = struct
      type ('fee, 'public_key, 'nonce, 'global_slot, 'memo) t =
        { fee : 'fee
        ; fee_payer_pk : 'public_key
        ; nonce : 'nonce
        ; valid_until : 'global_slot
        ; memo : 'memo
        }
    end
  end

  module V1 = struct
    type t =
      ( Currency.Fee.V1.t
      , Public_key.Compressed.V1.t
      , Mina_base_token_id.V2.t
      , Mina_numbers.Account_nonce.V1.t
      , Mina_numbers.Global_slot.V1.t
      , Mina_base_signed_command_memo.V1.t )
      Poly.V1.t
  end

  module V2 = struct
    type t =
      ( Currency.Fee.V1.t
      , Public_key.Compressed.V1.t
      , Mina_numbers.Account_nonce.V1.t
      , Mina_numbers.Global_slot.V1.t
      , Mina_base_signed_command_memo.V1.t )
      Poly.V2.t
  end
end

module Body = struct
  module V1 = struct
    type t =
      | Payment of Mina_base_payment_payload.V1.t
      | Stake_delegation of Mina_base_stake_delegation.V1.t
      | Create_new_token of Mina_base_new_token_payload.V1.t
      | Create_token_account of Mina_base_new_account_payload.V1.t
      | Mint_tokens of Mina_base_minting_payload.V1.t
  end

  module V2 = struct
    type t =
      | Payment of Mina_base_payment_payload.V2.t
      | Stake_delegation of Mina_base_stake_delegation.V1.t
  end
end

module Poly = struct
  module V1 = struct
    type ('common, 'body) t = { common : 'common; body : 'body }
  end
end

module V1 = struct
  type t = (Common.V1.t, Body.V1.t) Poly.V1.t
end

module V2 = struct
  type t = (Common.V2.t, Body.V2.t) Poly.V1.t
end
