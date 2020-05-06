[%%import
"/src/config.mlh"]

[%%if
defined genesis_ledger]

[%%inject
"genesis_ledger", genesis_ledger]

include Genesis_ledger.Make ((val Genesis_ledger.fetch_ledger genesis_ledger))

[%%else]

[%%error
"\"genesis_ledger\" not set in config.mlh"]

[%%endif]
