open Core
open Async
open Signature_lib
module Work = Snark_work_lib

module Rpc = struct
  module Master = struct
    let name = "failed_to_generate_snark"

    module T = struct
      type query =
        Bounded_types.Wrapped_error.t
        * Work.Selector.Spec.t
        * Public_key.Compressed.t

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
        type query =
          Bounded_types.Wrapped_error.Stable.V1.t
          * Work.Selector.Spec.Stable.V1.t
          * Public_key.Compressed.Stable.V1.t

        type response = unit

        let query_of_caller_model : Rpc.Master.Caller.query -> query =
          Tuple3.map_snd ~f:Work.Selector.Spec.materialize

        let callee_model_of_query =
          Tuple3.map_snd
            ~f:(Work.Selector.Spec.cache ~proof_cache_db:Proof_cache.cache_db)

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      include T
      include Rpc.Register (T)
    end

    module Latest = V2
  end]
end
