include Prometheus

let namespace = "Coda"

module Sync_ledger = struct
  let subsystem = "Sync_ledger"

  let created =
    let help = "sync ledgers created" in
    Counter.v ~help ~namespace ~subsystem "created"
end

module Ledger_builder_controller = struct
  let subsystem = "Ledger_builder_controller"

  let transitions_read =
    let help = "transitions read through input pipe" in
    Counter.v ~help ~namespace ~subsystem "transitions_read"
end
