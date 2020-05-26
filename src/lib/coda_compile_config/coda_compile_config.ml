[%%import
"/src/config.mlh"]

[%%ifndef
consensus_mechanism]

module Currency = Currency_nonconsensus.Currency

[%%endif]

(** This file consists of compile-time constants that are not in
    Genesis_constants.
    This file includes all of the constants defined at compile-time for both
    tests and production.
*)

[%%inject
"coinbase_string", coinbase]

[%%inject
"curve_size", curve_size]

[%%inject
"genesis_ledger", genesis_ledger]

[%%inject
"account_creation_fee_string", account_creation_fee_int]

[%%inject
"default_transaction_fee_string", default_transaction_fee]

[%%inject
"default_snark_worker_fee_string", default_snark_worker_fee]

[%%inject
"minimum_user_command_fee_string", minimum_user_command_fee]

let account_creation_fee =
  Currency.Fee.of_formatted_string account_creation_fee_string

let minimum_user_command_fee =
  Currency.Fee.of_formatted_string minimum_user_command_fee_string

let coinbase = Currency.Amount.of_formatted_string coinbase_string

let default_transaction_fee =
  Currency.Fee.of_formatted_string default_transaction_fee_string

let default_snark_worker_fee =
  Currency.Fee.of_formatted_string default_snark_worker_fee_string
