include Impl

module Logger_id = struct
  let mina : Consumer_registry.id = "default"

  let best_tip_diff = "best_tip_diff"

  let rejected_blocks = "rejected_blocks"

  let oversized_logs = "oversized_logs"
end
