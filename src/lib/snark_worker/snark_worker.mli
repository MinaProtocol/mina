module Intf : module type of Intf

include Intf.S with module Ledger_proof := Ledger_proof.Stable.V1
