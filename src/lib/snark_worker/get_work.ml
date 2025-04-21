open Core
open Async
open Signature_lib
module Work = Snark_work_lib

module Rpc = struct
  module Master = struct
    let name = "get_work"

    module T = struct
      type query = [ `V2 | `V3 ]

      type response = (Work.Partitioned.Spec.t * Public_key.Compressed.t) option
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
    module V3 = struct
      module T = struct
        type query = [ `V2 | `V3 ]

        type response =
          (Work.Partitioned.Spec.Stable.V1.t * Public_key.Compressed.Stable.V1.t)
          option

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model (resp : Rpc.Master.Callee.response) :
            response =
          let open Option.Let_syntax in
          let%map spec, key = resp in
          let spec = Work.Partitioned.Spec.materialize spec in
          (spec, key)

        let caller_model_of_response (resp : response) :
            Rpc.Master.Caller.response =
          let open Option.Let_syntax in
          let%map spec, key = resp in
          let spec =
            Work.Partitioned.Spec.cache ~proof_cache_db:Proof_cache.cache_db
              spec
          in
          (spec, key)
      end

      include T
      include Rpc.Register (T)
    end

    module V2 = struct
      module T = struct
        type query = unit

        type response =
          (Work.Selector.Spec.Stable.V1.t * Public_key.Compressed.Stable.V1.t)
          option

        let query_of_caller_model = const ()

        let callee_model_of_query = const `V2

        let response_of_callee_model (resp : Rpc.Master.Callee.response) :
            response =
          match resp with
          | Some (spec, key) -> (
              match Work.Partitioned.Spec.to_selector_spec spec with
              | None ->
                  (* WARN: we'd better report to the coordinator we failed rather *)
                  (*          than ignoring the work*)
                  printf
                    "WARN: V2 Worker receving work `Zkapp_command_segment`, \
                     which is out of its capability, work dropped" ;
                  None
              | Some spec ->
                  Some (Work.Selector.Spec.materialize spec, key) )
          | None ->
              None

        let caller_model_of_response : response -> Rpc.Master.Caller.response =
          function
          | Some (spec, key) ->
              let spec =
                Work.Selector.Spec.cache ~proof_cache_db:Proof_cache.cache_db
                  spec
                |> Work.Partitioned.Spec.of_selector_spec
              in
              Some (spec, key)
          | None ->
              None
      end

      include T
      include Rpc.Register (T)
    end

    module Latest = V3
  end]
end
