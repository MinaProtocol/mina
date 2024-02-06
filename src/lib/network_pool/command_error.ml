open Mina_base

(* IMPORTANT! Do not change the names of these errors as to adjust the
 * to_yojson output without updating Rosetta's construction API to handle the
 * changes *)
type t =
  | Invalid_nonce of
      [ `Expected of Account.Nonce.t
      | `Between of Account.Nonce.t * Account.Nonce.t ]
      * Account.Nonce.t
  | Insufficient_funds of [ `Balance of Currency.Amount.t ] * Currency.Amount.t
  | (* NOTE: don't punish for this, attackers can induce nodes to banlist
        each other that way! *)
      Insufficient_replace_fee of
      [ `Replace_fee of Currency.Fee.t ] * Currency.Fee.t
  | Overflow
  | Bad_token
  | Expired of
      [ `Valid_until of Mina_numbers.Global_slot_since_genesis.t ]
      * [ `Global_slot_since_genesis of Mina_numbers.Global_slot_since_genesis.t
        ]
  | Unwanted_fee_token of Token_id.t
  | After_slot_tx_end
[@@deriving sexp, to_yojson]

let grounds_for_diff_rejection : t -> bool = function
  | Expired _
  | Invalid_nonce _
  | Insufficient_funds _
  | Insufficient_replace_fee _
  | After_slot_tx_end ->
      false
  | Overflow | Bad_token | Unwanted_fee_token _ ->
      true
