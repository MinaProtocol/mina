open Async
open Core_kernel
open Coda_transition
open Network_pool

module Message_data = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | New_state of External_transition.Stable.V1.t
        | Snark_pool_diff of Snark_pool.Resource_pool.Diff.Stable.V1.t
        | Transaction_pool_diff of
            Transaction_pool.Resource_pool.Diff.Stable.V1.t
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]
end

module Master = struct
  module T = struct
    type msg =
      { data: Message_data.Stable.Latest.t
            (* a list of who has received this message before us, and the time they wrapped the message in an envelope *)
      ; path_rev:
          (Coda_base.Real_time.Stable.V1.t * Network_peer.Peer.Id.t) list }
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
      { data: Message_data.Stable.V1.t
      ; path_rev:
          (Coda_base.Real_time.Stable.V1.t * Network_peer.Peer.Id.Stable.V1.t)
          list }
    [@@deriving bin_io, sexp, to_yojson, version {rpc}]

    let callee_model_of_msg = Fn.id

    let msg_of_caller_model = Fn.id
  end

  let data {data; _} = data

  include Register (T)

  let summary =
    let open Message_data.Stable.V1 in
    function
    | New_state _ ->
        "new state"
    | Snark_pool_diff _ ->
        "snark pool diff"
    | Transaction_pool_diff _ ->
        "transaction pool diff"
end

[%%define_locally
V1.(summary, data, msg_to_yojson)]
