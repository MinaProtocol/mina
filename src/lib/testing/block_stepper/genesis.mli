val create_genesis_breadcrumb :
     logger:Logger.t
  -> precomputed_values:Precomputed_values.t
  -> unit
  -> Frontier_base.Breadcrumb.t Async.Deferred.t
