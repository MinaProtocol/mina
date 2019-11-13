[%%import
"../../config.mlh"]

[%%inject
"proof_level", proof_level]

[%%inject
"coinbase_int", coinbase]

[%%inject
"pending_coinbase_hack", pending_coinbase_hack]

let coinbase = Currency.Amount.of_int coinbase_int
