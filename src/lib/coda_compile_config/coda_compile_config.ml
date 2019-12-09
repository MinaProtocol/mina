[%%import
"/src/config.mlh"]

[%%inject
"proof_level", proof_level]

[%%inject
"coinbase_int", coinbase]

let coinbase = Currency.Amount.of_int coinbase_int
