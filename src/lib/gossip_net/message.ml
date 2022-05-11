open Async
open Core_kernel
open Mina_block
open Network_pool
open Network_peer

module Master = struct
  module T = struct
    type msg =
      | New_state of Mina_block.t
      | Snark_pool_diff of Snark_pool.Resource_pool.Diff.t
      | Transaction_pool_diff of Transaction_pool.Resource_pool.Diff.t
    [@@deriving sexp, to_yojson]

    type state_msg = Mina_block.t

    type snark_pool_diff_msg = Snark_pool.Resource_pool.Diff.t

    type transaction_pool_diff_msg = Transaction_pool.Resource_pool.Diff.t
  end

  let name = "message"

  module Caller = T
  module Callee = T
end

include Master.T
include Versioned_rpc.Both_convert.One_way.Make (Master)

module V2 = struct
  module T = struct
    type msg =
      | New_state of External_transition.Raw.Stable.V2.t
      | Snark_pool_diff of Snark_pool.Diff_versioned.Stable.V2.t
      | Transaction_pool_diff of Transaction_pool.Diff_versioned.Stable.V2.t
    [@@deriving bin_io, sexp, version { rpc }]

    type state_msg = External_transition.Raw.Stable.V2.t

    type snark_pool_diff_msg = Snark_pool.Diff_versioned.Stable.V2.t

    type transaction_pool_diff_msg = Transaction_pool.Diff_versioned.Stable.V2.t

    let callee_model_of_msg msg =
      match msg with
      | New_state state ->
          Master.T.New_state (External_transition.decompose state)
      | Snark_pool_diff diff ->
          Master.T.Snark_pool_diff diff
      | Transaction_pool_diff diff ->
          Master.T.Transaction_pool_diff diff

    let msg_of_caller_model msg =
      match msg with
      | Master.T.New_state state ->
          New_state (External_transition.compose state)
      | Master.T.Snark_pool_diff diff ->
          Snark_pool_diff diff
      | Master.T.Transaction_pool_diff diff ->
          Transaction_pool_diff diff
  end

  include Register (T)

  let summary = function
    | T.New_state _ ->
        "new state"
    | Snark_pool_diff _ ->
        "snark pool diff"
    | Transaction_pool_diff _ ->
        "transaction pool diff"
end

module Latest = V2

[%%define_locally Latest.(summary)]

type block_sink_msg =
  [ `Transition of state_msg Envelope.Incoming.t ]
  * [ `Time_received of Block_time.t ]
  * [ `Valid_cb of Mina_net2.Validation_callback.t ]

type tx_sink_msg =
  transaction_pool_diff_msg Envelope.Incoming.t
  * Mina_net2.Validation_callback.t

type snark_sink_msg =
  snark_pool_diff_msg Envelope.Incoming.t * Mina_net2.Validation_callback.t

type 'msg push_modifier = ('msg -> unit Deferred.t) -> 'msg -> unit Deferred.t

module type Sinks_intf = sig
  module Block_sink : Mina_net2.Sink.S with type msg := block_sink_msg

  module Tx_sink : Mina_net2.Sink.S with type msg := tx_sink_msg

  module Snark_sink : Mina_net2.Sink.S with type msg := snark_sink_msg

  type t = Block_sink.t * Tx_sink.t * Snark_sink.t
end

type ('sink_block, 'sink_tx, 'sink_snark) sinks_impl =
  (module Sinks_intf
     with type Block_sink.t = 'sink_block
      and type Snark_sink.t = 'sink_snark
      and type Tx_sink.t = 'sink_tx)

type sinks = Any_sinks : ('a, 'b, 'c) sinks_impl * ('a * 'b * 'c) -> sinks
