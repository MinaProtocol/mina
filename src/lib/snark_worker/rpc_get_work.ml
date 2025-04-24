open Async
open Signature_lib
module Work = Snark_work_lib

module T = struct
  let name = "get_work"

  module T = struct
    type query = unit

    type response = Work.Selector.Spec.t * Public_key.Compressed.t
  end

  module Caller = T
  module Callee = T
end

include Versioned_rpc.Both_convert.Plain.Make (T)
