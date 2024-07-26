include Genesis_ledger.Make (struct
  include (val Genesis_ledger.fetch_ledger_exn Node_config.genesis_ledger)

  let directory = `Ephemeral

  let depth = Genesis_constants.Constraint_constants.compiled.ledger_depth
end)
