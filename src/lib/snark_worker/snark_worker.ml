module Prod = Prod
module Intf = Intf
module Inputs = Prod.Inputs
module Events = Events

module Worker = struct
  include Functor.Make

  module Rpcs_versioned = struct
    open Core_kernel
    open Signature_lib
    module Get_work = Rpc_get_work.Stable
    module Submit_work = Rpc_submit_work.Stable

    [%%versioned_rpc
    module Failed_to_generate_snark = struct
      module V2 = struct
        module T = struct
          type query =
            Bounded_types.Wrapped_error.Stable.V1.t
            * ( Transaction_witness.Stable.V2.t
              , Inputs.Ledger_proof.Stable.V2.t )
              Snark_work_lib.Work.Single.Spec.Stable.V2.t
              Snark_work_lib.Work.Spec.Stable.V1.t
            * Public_key.Compressed.Stable.V1.t

          type response = unit

          let query_of_caller_model = Fn.id

          let callee_model_of_query = Fn.id

          let response_of_callee_model = Fn.id

          let caller_model_of_response = Fn.id
        end

        include T
        include Rpcs.Failed_to_generate_snark.Register (T)
      end

      module Latest = V2
    end]
  end

  let command = command_from_rpcs (module Rpcs_versioned)
end

include Worker
