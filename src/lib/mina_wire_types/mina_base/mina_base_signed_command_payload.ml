module Common = struct
  module Poly = struct
    type ('fee, 'public_key, 'token_id, 'nonce, 'global_slot, 'memo) t =
      { fee : 'fee
      ; fee_token : 'token_id
      ; fee_payer_pk : 'public_key
      ; nonce : 'nonce
      ; valid_until : 'global_slot
      ; memo : 'memo
      }
  end

  type t =
    ( Currency.Fee.t
    , Public_key.Compressed.t
    , Mina_base_token_id.t
    , Mina_numbers.Account_nonce.t
    , Mina_numbers.Global_slot.t
    , Mina_base_signed_command_memo.t )
    Poly.t
end

module Body = struct
  type t =
    | Payment of Mina_base_payment_payload.t
    | Stake_delegation of Mina_base_stake_delegation.t
    | Create_new_token of Mina_base_new_token_payload.t
    | Create_token_account of Mina_base_new_account_payload.t
    | Mint_tokens of Mina_base_minting_payload.t
end

module Poly = struct
  type ('common, 'body) t = { common : 'common; body : 'body }
end

type t = (Common.t, Body.t) Poly.t
