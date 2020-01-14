[%%import
"/src/config.mlh"]

[%%inject
"proof_level", proof_level]

[%%inject
"coinbase_int", coinbase]

[%%inject
"curve_size", curve_size]

[%%inject
"fake_accounts_target", fake_accounts_target]

[%%inject
"genesis_ledger", genesis_ledger]

let coinbase = Currency.Amount.of_int coinbase_int
