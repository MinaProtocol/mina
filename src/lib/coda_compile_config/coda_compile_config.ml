[%%import
"/src/config.mlh"]

[%%inject
"proof_level", proof_level]

[%%inject
"coinbase_string", coinbase]

[%%inject
"curve_size", curve_size]

[%%inject
"fake_accounts_target", fake_accounts_target]

[%%inject
"genesis_ledger", genesis_ledger]

[%%inject
"account_creation_fee_string", account_creation_fee_int]

let coinbase = Currency.Amount.of_formatted_string coinbase_string

let account_creation_fee =
  Currency.Fee.of_formatted_string account_creation_fee_string
