open Async_rpc_kernel
open Core_kernel

module Master = struct
  module T = struct
    type msg = Block_header of Blockchain_snark.Blockchain.t
    [@@deriving sexp]
  end

  let name = "block-header-message"

  module Caller = T
  module Callee = T
end

include Master.T
include Versioned_rpc.Both_convert.One_way.Make (Master)

module V1 = struct
  module T = struct
    type msg = Master.T.msg =
      | Block_header of Blockchain_snark.Blockchain.Stable.V1.t
    [@@deriving bin_io, sexp, version {rpc}]

    let callee_model_of_msg = Fn.id

    let msg_of_caller_model = Fn.id
  end

  include Register (T)
end

module Latest = V1
