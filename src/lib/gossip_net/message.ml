open Async
open Core_kernel
open Mina_transition
open Network_pool

module Master = struct
  module T = struct
    type msg =
      | New_state of External_transition.t
      | Snark_pool_diff of Snark_pool.Resource_pool.Diff.t
      | Transaction_pool_diff of Transaction_pool.Resource_pool.Diff.t
    [@@deriving sexp, to_yojson]
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

module Latest = V1

[%%define_locally
Latest.(summary)]
