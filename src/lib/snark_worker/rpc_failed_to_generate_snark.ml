(* External Libraries *)
open Async
open Core

(* Local Libraries *)
open Signature_lib
module Work = Snark_work_lib

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

include Versioned_rpc.Both_convert.Plain.Make (Master)
