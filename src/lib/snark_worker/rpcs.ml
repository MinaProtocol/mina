open Async
open Core_kernel
open Inputs
open Signature_lib
open Snark_work_lib
(* For versioning of the types here, see:

   - RFC 0013: https://github.com/MinaProtocol/mina/blob/develop/rfcs/0013-rpc-versioning.md
   - https://ocaml.org/p/async_rpc_kernel/v0.14.0/doc/Async_rpc_kernel/Versioned_rpc/index.html
*)

(* for each RPC, return the Master module only, and not the versioned modules, because the functor should not
   return types with bin_io; the versioned modules are defined in snark_worker.ml
*)

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
