module Tx_sink = Network_pool.Transaction_pool.Remote_sink
module Snark_sink = Network_pool.Snark_pool.Remote_sink
module Block_sink = Transition_handler.Block_sink

type t = Block_sink.t * Tx_sink.t * Snark_sink.t
