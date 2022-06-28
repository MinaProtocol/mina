type ('fee, 'public_key, 'token_id, 'nonce, 'global_slot, 'memo) common_poly =
  { fee : 'fee
  ; fee_token : 'token_id
  ; fee_payer_pk : 'public_key
  ; nonce : 'nonce
  ; valid_until : 'global_slot
  ; memo : 'memo
  }

type common = unit

type t = unit
