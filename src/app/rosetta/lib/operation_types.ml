open Core_kernel

type t =
  [ `Fee_payer_dec
  | `Fee_creator_inc
  | `Coinbase_inc
  | `Account_creation_fee_via_payment
  | `Account_creation_fee_via_fee_payer
  | `Payment_source_dec
  | `Payment_receiver_inc
  | `Delegate_change
  | `Create_token
  | `Mint_tokens ]
[@@deriving to_representatives]

let name = function
  | `Fee_payer_dec ->
      "fee_payer_dec"
  | `Fee_creator_inc ->
      "fee_creator_inc"
  | `Coinbase_inc ->
      "coinbase_inc"
  | `Account_creation_fee_via_payment ->
      "account_creation_fee_via_payment"
  | `Account_creation_fee_via_fee_payer ->
      "account_creation_fee_via_fee_payer"
  | `Payment_source_dec ->
      "payment_source_dec"
  | `Payment_receiver_inc ->
      "payment_receiver_inc"
  | `Delegate_change ->
      "delegate_change"
  | `Create_token ->
      "create_token"
  | `Mint_tokens ->
      "mint_tokens"

let all = to_representatives |> Lazy.map ~f:(List.map ~f:name)
