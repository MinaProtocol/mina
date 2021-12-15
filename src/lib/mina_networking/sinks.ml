module Unwrapped = struct
  module Tx_sink = Network_pool.Transaction_pool.Remote_sink
  module Snark_sink = Network_pool.Snark_pool.Remote_sink
  module Block_sink = Network_pool.Block_sink

  type sinks =
    { sink_block : Block_sink.t
    ; sink_tx : Tx_sink.t
    ; sink_snark_work : Snark_sink.t
    }
end

include Gossip_net.Wrapped_sinks (Unwrapped)
