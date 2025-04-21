open Core
open Async
open Signature_lib
module Work = Snark_work_lib

module Rpc = struct
  module Master = struct
    let name = "get_work"

    module T = struct
      type query = unit

      type response = (Work.Selector.Spec.t * Public_key.Compressed.t) option
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
        type query = unit

        type response =
          (Work.Selector.Spec.Stable.V1.t * Public_key.Compressed.Stable.V1.t)
          option

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model : Rpc.Master.Callee.response -> response =
          Option.map ~f:(Tuple2.map_fst ~f:Work.Selector.Spec.materialize)

        let caller_model_of_response : response -> Rpc.Master.Caller.response =
          Option.map
            ~f:
              (Tuple2.map_fst
                 ~f:
                   (Work.Selector.Spec.cache
                      ~proof_cache_db:Proof_cache.cache_db ) )
      end

      include T
      include Rpc.Register (T)
    end

    module Latest = V2
  end]
end
