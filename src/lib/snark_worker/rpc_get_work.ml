(* External Libraries *)
open Async
open Core

(* Local Libraries *)
open Signature_lib
module Work = Snark_work_lib
open Worker_proof_cache

(* For versioning of the types here, see:
   - RFC 0013: https://github.com/MinaProtocol/mina/blob/develop/rfcs/0013-rpc-versioning.md
   - https://ocaml.org/p/async_rpc_kernel/v0.14.0/doc/Async_rpc_kernel/Versioned_rpc/index.html
*)

module Master = struct
  let name = "get_work"

  module T = struct
    type query = [ `V2 | `V3 ]

    type response = (Work.Partitioned.Spec.t * Public_key.Compressed.t) option
  end

  module Caller = T
  module Callee = T
end

include Versioned_rpc.Both_convert.Plain.Make (Master)

[%%versioned_rpc
module Stable = struct
  module V3 = struct
    module T = struct
      type query = [ `V2 | `V3 ]

      type response =
        (Work.Partitioned.Spec.Stable.V1.t * Public_key.Compressed.Stable.V1.t)
        option

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model (resp : Master.Callee.response) : response =
        let open Option.Let_syntax in
        let%map spec, key = resp in
        let spec = Work.Partitioned.Spec.Poly.read_all_proofs_from_disk spec in
        (spec, key)

      let caller_model_of_response (resp : response) : Master.Caller.response =
        let open Option.Let_syntax in
        let%map spec, key = resp in
        let spec =
          Work.Partitioned.Spec.Poly.write_all_proofs_to_disk ~proof_cache_db
            spec
        in
        (spec, key)
    end

    include T
    include Register (T)
  end

  module V2 = struct
    module T = struct
      type query = unit

      type response =
        (Work.Selector.Spec.Stable.V1.t * Public_key.Compressed.Stable.V1.t)
        option

      let query_of_caller_model = const ()

      let callee_model_of_query = const `V2

      let response_of_callee_model (resp : Master.Callee.response) : response =
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
                Some (Work.Selector.Spec.read_all_proofs_from_disk spec, key) )
        | None ->
            None

      let caller_model_of_response : response -> Master.Caller.response =
        function
        | Some (spec, key) ->
            let spec =
              Work.Selector.Spec.write_all_proofs_to_disk ~proof_cache_db spec
              |> Work.Partitioned.Spec.of_selector_spec
            in
            Some (spec, key)
        | None ->
            None
    end

    include T
    include Register (T)
  end

  module Latest = V3
end]
