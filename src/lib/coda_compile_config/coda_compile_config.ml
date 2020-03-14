[%%import
"/src/config.mlh"]

(*Deepthi: This should only consists of compile time constants that are not in Coda_constants. i.e., all the constants that are defined at compile-time for both tests and production*)
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

[%%inject
"ledger_depth", ledger_depth]

[%%inject
"account_creation_fee_int", account_creation_fee_int]

let coinbase = Currency.Amount.of_int coinbase_int

let account_creation_fee = Currency.Fee.of_int account_creation_fee_int
