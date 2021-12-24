open Async
open Core_kernel
open Mina_transition
open Network_pool
open Network_peer

module Master = struct
  module T = struct
    type msg =
      | New_state of External_transition.t
      | Snark_pool_diff of Snark_pool.Resource_pool.Diff.t
      | Transaction_pool_diff of Transaction_pool.Resource_pool.Diff.t
    [@@deriving sexp, to_yojson]

    type state_msg = External_transition.t

    type snark_pool_diff_msg = Snark_pool.Resource_pool.Diff.t

    type transaction_pool_diff_msg = Transaction_pool.Resource_pool.Diff.t
  end

  let name = "message"

  module Caller = T
  module Callee = T
end

include Master.T
include Versioned_rpc.Both_convert.One_way.Make (Master)

module V1 = struct
  module T = struct
    type msg = Master.T.msg =
      | New_state of External_transition.Stable.V1.t
      | Snark_pool_diff of Snark_pool.Diff_versioned.Stable.V1.t
      | Transaction_pool_diff of Transaction_pool.Diff_versioned.Stable.V1.t
    [@@deriving bin_io, sexp, version { rpc }]

    type state_msg = External_transition.Stable.V1.t

    type snark_pool_diff_msg = Snark_pool.Diff_versioned.Stable.V1.t

    type transaction_pool_diff_msg = Transaction_pool.Diff_versioned.Stable.V1.t

    let callee_model_of_msg = Fn.id

    let msg_of_caller_model = Fn.id
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

module Latest = V1

[%%define_locally Latest.(summary)]

type block_sink_msg =
  state_msg Envelope.Incoming.t * Block_time.t * Mina_net2.Validation_callback.t

type tx_sink_msg =
  transaction_pool_diff_msg Envelope.Incoming.t
  * Mina_net2.Validation_callback.t

type snark_sink_msg =
  snark_pool_diff_msg Envelope.Incoming.t * Mina_net2.Validation_callback.t

type 'msg push_modifier = ('msg -> unit Deferred.t) -> 'msg -> unit Deferred.t

module type Sinks = sig
  module Block_sink : Mina_net2.Sink.S with type msg := block_sink_msg

  module Tx_sink : Mina_net2.Sink.S with type msg := tx_sink_msg

  module Snark_sink : Mina_net2.Sink.S with type msg := snark_sink_msg

  type sinks =
    { sink_block : Block_sink.t
    ; sink_tx : Tx_sink.t
    ; sink_snark_work : Snark_sink.t
    }
end

module Wrapped_sinks (S : Sinks) = struct
  module Block_sink = struct
    type t = S.Block_sink.t * block_sink_msg push_modifier

    let push (t, f) = f (S.Block_sink.push t)
  end

  module Tx_sink = struct
    type t = S.Tx_sink.t * tx_sink_msg push_modifier

    let push (t, f) = f (S.Tx_sink.push t)
  end

  module Snark_sink = struct
    type t = S.Snark_sink.t * snark_sink_msg push_modifier

    let push (t, f) = f (S.Snark_sink.push t)
  end

  type sinks =
    { sink_block : Block_sink.t
    ; sink_tx : Tx_sink.t
    ; sink_snark_work : Snark_sink.t
    }

  let wrap ~block_push_modifier ~tx_push_modifier ~snark_push_modifier
      (sinks : S.sinks) =
    { sink_block = (sinks.sink_block, block_push_modifier)
    ; sink_tx = (sinks.sink_tx, tx_push_modifier)
    ; sink_snark_work = (sinks.sink_snark_work, snark_push_modifier)
    }

  let wrap_simple ?block_pre ?tx_pre ?snark_pre ?block_post ?tx_post ?snark_post
      =
    let modifier pre post f msg =
      Option.value ~default:(const Deferred.unit) pre msg
      >>= fun () ->
      f msg >>= fun () -> Option.value ~default:(const Deferred.unit) post msg
    in
    wrap
      ~block_push_modifier:(modifier block_pre block_post)
      ~tx_push_modifier:(modifier tx_pre tx_post)
      ~snark_push_modifier:(modifier snark_pre snark_post)
end
