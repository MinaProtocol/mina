open Core_kernel

type t =
  [ `Fee_payer_dec
  | `Fee_receiver_inc
  | `Coinbase_inc
  | `Account_creation_fee_via_payment
  | `Account_creation_fee_via_fee_receiver
  | `Payment_source_dec
  | `Payment_receiver_inc
  | `Fee_payment
  | `Delegate_change
  | `Zkapp_fee_payer_dec
  | `Zkapp_balance_update ]
[@@deriving to_representatives, to_yojson, equal]

let name = function
  | `Fee_payer_dec ->
      "fee_payer_dec"
  | `Fee_receiver_inc ->
      "fee_receiver_inc"
  | `Coinbase_inc ->
      "coinbase_inc"
  | `Account_creation_fee_via_payment ->
      "account_creation_fee_via_payment"
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
  | `Zkapp_fee_payer_dec ->
      "zkapp_fee_payer_dec"
  | `Zkapp_balance_update ->
      "zkapp_balance_update"

let of_name_exn = function
  | "fee_payer_dec" ->
      `Fee_payer_dec
  | "fee_receiver_inc" ->
      `Fee_receiver_inc
  | "coinbase_inc" ->
      `Coinbase_inc
  | "account_creation_fee_via_payment" ->
      `Account_creation_fee_via_payment
  | "account_creation_fee_via_fee_receiver" ->
      `Account_creation_fee_via_fee_receiver
  | "payment_source_dec" ->
      `Payment_source_dec
  | "payment_receiver_inc" ->
      `Payment_receiver_inc
  | "fee_payment" ->
      `Fee_payment
  | "delegate_change" ->
      `Delegate_change
  | "zkapp_fee_payer_dec" ->
      `Zkapp_fee_payer_dec
  | "zkapp_balance_update" ->
      `Zkapp_balance_update
  | _ ->
      failwith "Invalid name"

let of_name op = try Some (of_name_exn op) with _ -> None

let all = to_representatives |> Lazy.map ~f:(List.map ~f:name)
