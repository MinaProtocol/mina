module Prod = Prod
module Intf = Intf
module Inputs = Prod.Inputs

type Structured_log_events.t += Generating_snark_work_failed
  [@@deriving register_event { msg = "Failed to generate SNARK work" }]

module Worker = struct
  include Functor.Make (Inputs)

  module Rpcs_versioned = struct
    open Core_kernel
    open Signature_lib

    module Work = struct
      type ledger_proof = Inputs.Ledger_proof.t

      include Work
    end

    [%%versioned_rpc
    module Get_work = struct
      module V2 = struct
        module T = struct
          type query = unit

          type response =
            ( ( Transaction_witness.Stable.V2.t
              , Inputs.Ledger_proof.Stable.V2.t )
              Snark_work_lib.Work.Single.Spec.Stable.V2.t
              Snark_work_lib.Work.Spec.Stable.V1.t
            * Public_key.Compressed.Stable.V1.t )
            option

          let query_of_caller_model = Fn.id

          let callee_model_of_query = Fn.id

          let response_of_callee_model :
              Rpcs.Get_work.Master.Callee.response -> response =
            Fn.id

          let caller_model_of_response = Fn.id
        end

        include T
        include Rpcs.Get_work.Register (T)
      end

      module Latest = V2
    end]

    [%%versioned_rpc
    module Submit_work = struct
      module V2 = struct
        module T = struct
          type query =
            ( ( Transaction_witness.Stable.V2.t
              , Ledger_proof.Stable.V2.t )
              Snark_work_lib.Work.Single.Spec.Stable.V2.t
              Snark_work_lib.Work.Spec.Stable.V1.t
            , Ledger_proof.Stable.V2.t )
            Snark_work_lib.Work.Result.Stable.V1.t

          type response = unit

          let query_of_caller_model = Fn.id

          let callee_model_of_query = Fn.id

          let response_of_callee_model = Fn.id

          let caller_model_of_response = Fn.id
        end

        include T
        include Rpcs.Submit_work.Register (T)
      end

      module Latest = V2
    end]

    [%%versioned_rpc
    module Failed_to_generate_snark = struct
      module V2 = struct
        module T = struct
          type query =
            ( Transaction_witness.Stable.V2.t
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
