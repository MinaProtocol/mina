[%%import
"../../config.mlh"]

[%%inject
"ledger_depth", ledger_depth]

[%%inject
"fake_accounts_target", fake_accounts_target]

let _ =
  if Base.Int.(fake_accounts_target > pow 2 ledger_depth) then
    failwith "Genesis_ledger: fake_accounts_target >= 2**ledger_depth"

[%%if
defined genesis_ledger]

[%%if
genesis_ledger = "release"]

include Release_ledger

[%%elif
genesis_ledger = "test"]

include Test_ledger

[%%elif
genesis_ledger = "test_split_two_stakers"]

include Test_split_two_stakes_ledger

[%%elif
genesis_ledger = "test_five_even_stakes"]

include Test_five_even_stakes

[%%elif
genesis_ledger = "test_three_even_stakes"]

include Test_three_even_stakes_ledger

[%%elif
genesis_ledger = "test_delegation"]

include Test_delegation_ledger

[%%elif
genesis_ledger = "testnet_postake"]

include Testnet_postake_ledger

[%%elif
genesis_ledger = "testnet_postake_many_proposers"]

include Testnet_postake_ledger_many_proposers

[%%elif
genesis_ledger = "testnet_medium_rare"]

include Testnet_medium_rare_ledger

[%%else]

[%%error
"\"genesis_ledger\" is set to invalid value in config.mlh"]

[%%endif]

[%%else]

[%%error
"\"genesis_ledger\" not set in config.mlh"]

[%%endif]
