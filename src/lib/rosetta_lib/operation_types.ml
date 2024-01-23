open Core_kernel

type t =
  [ `Fee_payer_dec
  | `Fee_receiver_inc
  | `Coinbase_inc
  | `Account_creation_fee_via_payment
  | `Account_creation_fee_via_fee_payer
  | `Account_creation_fee_via_fee_receiver
  | `Payment_source_dec
  | `Payment_receiver_inc
  | `Fee_payment
  | `Delegate_change
  | `Create_token
  | `Mint_tokens
  | `Zkapp_fee_payer_dec
  | `Zkapp_balance_update ]
[@@deriving to_representatives]

let name = function
  | `Fee_payer_dec ->
      "fee_payer_dec"
  | `Fee_receiver_inc ->
      "fee_receiver_inc"
  | `Coinbase_inc ->
      "coinbase_inc"
  | `Account_creation_fee_via_payment ->
      "account_creation_fee_via_payment"
  | `Account_creation_fee_via_fee_payer ->
      "account_creation_fee_via_fee_payer"
  | `Account_creation_fee_via_fee_receiver ->
      "account_creation_fee_via_fee_receiver"
  | `Payment_source_dec ->
      "payment_source_dec"
  | `Payment_receiver_inc ->
      "payment_receiver_inc"
  | `Fee_payment ->
      "fee_payment"
  | `Delegate_change ->
      "delegate_change"
  | `Create_token ->
      "create_token"
  | `Mint_tokens ->
      "mint_tokens"
  | `Zkapp_fee_payer_dec ->
      "zkapp_fee_payer_dec"
  | `Zkapp_balance_update ->
      "zkapp_balance_update"

let all = to_representatives |> Lazy.map ~f:(List.map ~f:name)
