open Core_kernel
open Async
open Signature_lib

module Make (Inputs : Intf.Inputs_intf) = struct
  open Inputs
  open Snark_work_lib

  module Get_work = struct
    module Master = struct
      let name = "get_work"

      module T = struct
        type query = unit

        type response =
          ( ( Transaction_witness.Stable.Latest.t
            , Ledger_proof.t )
            Work.Single.Spec.t
            Work.Spec.t
          * Public_key.Compressed.t )
          option
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    include Versioned_rpc.Both_convert.Plain.Make (Master)
  end

  module Submit_work = struct
    module Master = struct
      let name = "submit_work"

      module T = struct
        type query =
          ( ( Transaction_witness.Stable.Latest.t
            , Ledger_proof.t )
            Work.Single.Spec.t
            Work.Spec.t
          , Ledger_proof.t )
          Work.Result.t

        type response = unit
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    include Versioned_rpc.Both_convert.Plain.Make (Master)
  end

  module Failed_to_generate_snark = struct
    module Master = struct
      let name = "failed_to_generate_snark"

      module T = struct
        type query =
          Error.t
          * ( Transaction_witness.Stable.Latest.t
            , Ledger_proof.t )
            Work.Single.Spec.t
            Work.Spec.t
          * Public_key.Compressed.t

        type response = unit
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    include Versioned_rpc.Both_convert.Plain.Make (Master)
  end
end
