open Core
open Async
module Work = Snark_work_lib

module Rpc = struct
  module Master = struct
    let name = "submit_work"

    module T = struct
      type query = Work.Selector.Result.t

      type response = unit
    end

    module Caller = T
    module Callee = T
  end

  include Master.T
  include Versioned_rpc.Both_convert.Plain.Make (Master)
end

module Rpc_stable = struct
  [%%versioned_rpc
  module Get_work = struct
    module V2 = struct
      module T = struct
        type query = Work.Selector.Result.Stable.V1.t

        type response = unit

        let query_of_caller_model : Rpc.Master.Caller.query -> query =
          Work.Selector.Result.materialize

        let callee_model_of_query : query -> Rpc.Master.Callee.query =
          Work.Selector.Result.cache ~proof_cache_db:Proof_cache.cache_db

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      include T
      include Rpc.Register (T)
    end

    module Latest = V2
  end]
end
