include Genesis_ledger.Make (struct
  include
    (val Genesis_ledger.fetch_ledger_exn Mina_compile_config.genesis_ledger)

  let directory = `Ephemeral

  let depth =
    Mina_compile_config.Genesis_constants.Constraint_constants.compiled
      .ledger_depth
end)
