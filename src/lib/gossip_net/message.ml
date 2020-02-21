open Async
open Core_kernel
open Coda_transition
open Network_pool

module Master = struct
  module T = struct
    type msg_data =
      | New_state of External_transition.t
      | Snark_pool_diff of Snark_pool.Resource_pool.Diff.t
      | Transaction_pool_diff of Transaction_pool.Resource_pool.Diff.t
    [@@deriving sexp, to_yojson]

    type msg =
      { data: msg_data
            (* the first element of this list is the peer who sent the sender the
         message, and the receipt timestamp. *)
      ; path_rev: (Time_ns.t * Network_peer.Peer.Id.t) list }
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
      { data: Master.T.msg_data
      ; path_rev: (Time_ns.t * Network_peer.Peer.Id.t) list }
    [@@deriving bin_io, sexp, version {rpc}]

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

[%%define_locally
V1.(summary)]
