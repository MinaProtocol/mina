[%%import
"../../config.mlh"]

[%%if
defined genesis_ledger]

[%%if
genesis_ledger = "release"]

include Release_ledger

[%%elif
genesis_ledger = "test"]

include Test_ledger

[%%elif
genesis_ledger = "testnet"]

include Testnet_ledger

[%%endif]

[%%else]

(* [%%error "\"genesis_ledger\" not set in config.mlh"] *)

[%%endif]
