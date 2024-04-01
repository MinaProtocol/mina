[%%import "/src/config.mlh"]

[%%if defined genesis_ledger]

[%%inject "genesis_ledger", genesis_ledger]

include Genesis_ledger.Make (struct
  include (val Genesis_ledger.fetch_ledger_exn genesis_ledger)

  let directory = `Ephemeral

  let depth = Genesis_constants.Constraint_constants.compiled.ledger_depth

  let omit_set_verification_key_tx_version = false
end)

[%%else]

[%%optcomp.error "\"genesis_ledger\" not set in config.mlh"]

[%%endif]
