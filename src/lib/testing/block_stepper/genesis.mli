val create_genesis_breadcrumb :
     logger:Logger.t
  -> precomputed_values:Precomputed_values.t
  -> root_ledger:Mina_ledger.Ledger.Any_ledger.witness
  -> genesis_mode:[ `Simple | `Full ]
  -> (module Block_builder.Keys_S)
  -> unit
  -> Frontier_base.Breadcrumb.t Async.Deferred.Or_error.t
