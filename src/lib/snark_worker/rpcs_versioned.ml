open Core_kernel
open Signature_lib

(* For versioning of the types here, see:

   - RFC 0013: https://github.com/MinaProtocol/mina/blob/develop/rfcs/0013-rpc-versioning.md
   - https://ocaml.org/p/async_rpc_kernel/v0.14.0/doc/Async_rpc_kernel/Versioned_rpc/index.html
*)

[%%versioned_rpc
module Get_work = struct
  module V2 = struct
    module T = struct
      type query = unit

      type response =
        ( ( Transaction_witness.Stable.V2.t
          , Ledger_proof.Stable.V2.t )
          Snark_work_lib.Work.Single.Spec.Stable.V2.t
          Snark_work_lib.Work.Spec.Stable.V1.t
        * Public_key.Compressed.Stable.V1.t )
        option

      let query_of_caller_model :
          Rpcs_master.Get_work.Master.Callee.query -> query =
        const ()

      let callee_model_of_query :
          query -> Rpcs_master.Get_work.Master.Callee.query =
        const Rpcs_master.Get_work.Master.Callee.V2

      let response_of_callee_model :
          Rpcs_master.Get_work.Master.Callee.response -> response = function
        | Regular { work_spec; public_key } ->
            Some (work_spec, public_key)
        | Nothing ->
            None
        | Zkapp_command_segment _ ->
            failwith "TODO: convert Zkapp_command_segment to old spec"

      let caller_model_of_response :
          response -> Rpcs_master.Get_work.Master.Callee.response = function
        | None ->
            Nothing
        | Some (work_spec, public_key) ->
            Regular { work_spec; public_key }
    end

    include T
    include Rpcs_master.Get_work.Register (T)
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
    include Rpcs_master.Submit_work.Register (T)
  end

  module Latest = V2
end]

[%%versioned_rpc
module Failed_to_generate_snark = struct
  module V2 = struct
    module T = struct
      type query =
        Bounded_types.Wrapped_error.Stable.V1.t
        * ( Transaction_witness.Stable.V2.t
          , Ledger_proof.Stable.V2.t )
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
    include Rpcs_master.Failed_to_generate_snark.Register (T)
  end

  module Latest = V2
end]
