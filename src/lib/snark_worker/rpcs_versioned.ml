open Core_kernel
open Rpcs_types
open Signature_lib
module Work = Snark_work_lib.Work
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment

(* For versioning of the types here, see:

   - RFC 0013: https://github.com/MinaProtocol/mina/blob/develop/rfcs/0013-rpc-versioning.md
   - https://ocaml.org/p/async_rpc_kernel/v0.14.0/doc/Async_rpc_kernel/Versioned_rpc/index.html
*)

[%%versioned_rpc
module Get_work = struct
  module V3 = struct
    module T = struct
      type query = V2 | V3

      type response =
        | Regular of Regular_work.Stable.V1.t
        | Zkapp_command_segment of Zkapp_command_segment_work.Stable.V1.t
        | Nothing

      (* TODO: all these are basically `Fn.id`, maybe there's better way to do it? *)

      let query_of_caller_model = function
        | Rpcs_master.Get_work.V2 ->
            V2
        | V3 ->
            V3

      let callee_model_of_query = function
        | V2 ->
            Rpcs_master.Get_work.V2
        | V3 ->
            V3

      let response_of_callee_model : Rpcs_master.Get_work.response -> response =
        function
        | Regular { work_spec; public_key } ->
            Regular { work_spec; public_key }
        | Zkapp_command_segment { id; statement; witness; spec } ->
            Zkapp_command_segment { id; statement; witness; spec }
        | Nothing ->
            Nothing

      let caller_model_of_response : response -> Rpcs_master.Get_work.response =
        function
        | Regular { work_spec; public_key } ->
            Regular { work_spec; public_key }
        | Zkapp_command_segment { id; statement; witness; spec } ->
            Zkapp_command_segment { id; statement; witness; spec }
        | Nothing ->
            Nothing
    end

    include T
    include Rpcs_master.Get_work.Register (T)
  end

  module V2 = struct
    module T = struct
      type query = unit

      type response =
        (Wire_work.Spec.Stable.V1.t * Public_key.Compressed.Stable.V1.t) option

      let query_of_caller_model = const ()

      let callee_model_of_query = const Rpcs_master.Get_work.V2

      let response_of_callee_model : Rpcs_master.Get_work.response -> response =
        function
        | Regular { work_spec; public_key } ->
            Some (work_spec, public_key)
        | Nothing ->
            None
        | Zkapp_command_segment _ ->
            (* WARN: we'd better report to the coordinator we failed rather than
               ignoring the work*)
            Printf.printf
              "WARN: V2 Worker receving work `Zkapp_command_segment`, which is \
               out of its capability, work dropped" ;
            None

      let caller_model_of_response : response -> Rpcs_master.Get_work.response =
        function
        | None ->
            Nothing
        | Some (work_spec, public_key) ->
            Regular { work_spec; public_key }
    end

    include T
    include Rpcs_master.Get_work.Register (T)
  end

  module Latest = V3
end]

[%%versioned_rpc
module Submit_work = struct
  module V3 = struct
    module T = struct
      type query =
        | Regular of Wire_work.Result.Stable.V1.t
        | Zkapp_command_segment of
            Ledger_proof.Stable.V2.t
            Work.Result_zkapp_command_segment.Stable.V1.t

      type response = unit

      let query_of_caller_model : Rpcs_master.Submit_work.query -> query =
        function
        | Regular result ->
            Regular result
        | Zkapp_command_segment result ->
            Zkapp_command_segment result

      let callee_model_of_query : query -> Rpcs_master.Submit_work.query =
        function
        | Regular result ->
            Regular result
        | Zkapp_command_segment result ->
            Zkapp_command_segment result

      let response_of_callee_model :
          Rpcs_master.Submit_work.response -> response =
        Fn.id

      let caller_model_of_response :
          response -> Rpcs_master.Submit_work.response =
        Fn.id
    end

    include T
    include Rpcs_master.Submit_work.Register (T)
  end

  module V2 = struct
    module T = struct
      type query = Wire_work.Result.Stable.V1.t

      type response = unit

      let query_of_caller_model : Rpcs_master.Submit_work.query -> query =
        function
        | Regular result ->
            result
        | Zkapp_command_segment _ ->
            failwith
              "FATAL: V2 Worker completed a `Zkapp_command_segment` job where \
               the coordinator can't aggregate, this shouldn't happen as the \
               work is issued by the coordinator"

      let callee_model_of_query (result : query) : Rpcs_master.Submit_work.query
          =
        Regular result

      let response_of_callee_model :
          Rpcs_master.Submit_work.response -> response =
        Fn.id

      let caller_model_of_response :
          response -> Rpcs_master.Submit_work.response =
        Fn.id
    end

    include T
    include Rpcs_master.Submit_work.Register (T)
  end

  module Latest = V3
end]

[%%versioned_rpc
module Failed_to_generate_snark = struct
  module V3 = struct
    module T = struct
      type query =
        { error : Bounded_types.Wrapped_error.Stable.V1.t
        ; failed_work : Failed_work.Stable.V1.t
        }

      type response = unit

      let query_of_caller_model :
          Rpcs_master.Failed_to_generate_snark.query -> query = function
        | { error; failed_work } ->
            { error; failed_work }

      let callee_model_of_query :
          query -> Rpcs_master.Failed_to_generate_snark.query = function
        | { error; failed_work } ->
            { error; failed_work }

      let response_of_callee_model :
          Rpcs_master.Failed_to_generate_snark.response -> response =
        Fn.id

      let caller_model_of_response :
          response -> Rpcs_master.Failed_to_generate_snark.response =
        Fn.id
    end

    include T
    include Rpcs_master.Failed_to_generate_snark.Register (T)
  end

  module V2 = struct
    module T = struct
      type query =
        Bounded_types.Wrapped_error.Stable.V1.t
        * Wire_work.Spec.Stable.V1.t
        * Public_key.Compressed.Stable.V1.t

      type response = unit

      let query_of_caller_model :
          Rpcs_master.Failed_to_generate_snark.query -> query = function
        | { error; failed_work = Regular { work_spec; public_key } } ->
            (error, work_spec, public_key)
        | { failed_work = Zkapp_command_segment _; _ } ->
            failwith
              "FATAL: V2 Worker failed on a `Zkapp_command_segment` job where \
               the coordinator can't aggregate, this shouldn't happen as the \
               work is issued by the coordinator"

      let callee_model_of_query :
          query -> Rpcs_master.Failed_to_generate_snark.query =
       fun (error, work_spec, public_key) ->
        { error; failed_work = Regular { work_spec; public_key } }

      let response_of_callee_model :
          Rpcs_master.Failed_to_generate_snark.response -> response =
        Fn.id

      let caller_model_of_response :
          response -> Rpcs_master.Failed_to_generate_snark.response =
        Fn.id
    end

    include T
    include Rpcs_master.Failed_to_generate_snark.Register (T)
  end

  module Latest = V3
end]
