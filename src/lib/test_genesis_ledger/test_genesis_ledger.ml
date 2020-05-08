[%%import
"/src/config.mlh"]

[%%if
defined genesis_ledger]

[%%inject
"genesis_ledger", genesis_ledger]

include Genesis_ledger.Make (struct
  include (val Genesis_ledger.fetch_ledger genesis_ledger)

  let directory = `Ephemeral

  let depth = Genesis_constants.ledger_depth_for_unit_tests
end)

[%%else]

[%%error
"\"genesis_ledger\" not set in config.mlh"]

[%%endif]
