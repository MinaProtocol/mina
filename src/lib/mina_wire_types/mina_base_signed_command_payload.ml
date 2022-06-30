type ('fee, 'public_key, 'token_id, 'nonce, 'global_slot, 'memo) common_poly =
  { fee : 'fee
  ; fee_token : 'token_id
  ; fee_payer_pk : 'public_key
  ; nonce : 'nonce
  ; valid_until : 'global_slot
  ; memo : 'memo
  }

type common =
  ( Currency.M.fee
  , Public_key.compressed
  , Mina_base_token_id.M.t
  , Mina_numbers.Account_nonce.M.t
  , Mina_numbers.Global_slot.M.t
  , Mina_base_signed_command_memo.M.t )
  common_poly

type body =
  | Payment of Mina_base_payment_payload.t
  | Stake_delegation of Mina_base_stake_delegation.t
  | Create_new_token of Mina_base_new_token_payload.t
  | Create_token_account of Mina_base_new_account_payload.t
  | Mint_tokens of Mina_base_minting_payload.t

type ('common, 'body) poly = { common : 'common; body : 'body }

type t = (common, body) poly
