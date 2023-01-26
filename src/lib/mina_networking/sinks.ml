module Tx_sink = Network_pool.Transaction_pool.Remote_sink
module Snark_sink = Network_pool.Snark_pool.Remote_sink
module Block_sink = Network_pool.Block_sink

type t = Block_sink.t * Tx_sink.t * Snark_sink.t
