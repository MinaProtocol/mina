module Prod = Prod
module Intf = Intf
module Inputs = Prod.Inputs

module Worker = struct
  include Functor.Make (Inputs)

  module Rpcs_versioned = struct
    open Core_kernel
    open Signature_lib

    module Work = struct
      type ledger_proof = Inputs.Ledger_proof.t

      include Work
    end
  end

  let command = command_from_rpcs (module Rpcs_versioned)
end

include Worker
