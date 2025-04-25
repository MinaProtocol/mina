(* External Libraries *)
open Async
open Core

(* Local Libraries *)
open Worker_proof_cache
module Work = Snark_work_lib

(* For versioning of the types here, see:
   - RFC 0013: https://github.com/MinaProtocol/mina/blob/develop/rfcs/0013-rpc-versioning.md
   - https://ocaml.org/p/async_rpc_kernel/v0.14.0/doc/Async_rpc_kernel/Versioned_rpc/index.html
*)

module Master = struct
  let name = "submit_work"

  module T = struct
    type query = Work.Selector.Result.t

    type response = unit
  end

  module Caller = T
  module Callee = T
end

include Versioned_rpc.Both_convert.Plain.Make (Master)

[%%versioned_rpc
module Stable = struct
  module V2 = struct
    module T = struct
      type query = Work.Selector.Result.Stable.V1.t

      type response = unit

      let query_of_caller_model : Master.Caller.query -> query =
        Work.Selector.Result.read_all_proofs_from_disk

      let callee_model_of_query : query -> Master.Callee.query =
        Work.Selector.Result.write_all_proofs_to_disk ~proof_cache_db

      let response_of_callee_model = Fn.id

      let caller_model_of_response = Fn.id
    end

    include T
    include Register (T)
  end

  module Latest = V2
end]
