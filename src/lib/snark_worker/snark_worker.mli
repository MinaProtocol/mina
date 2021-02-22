module Intf : module type of Intf

module Prod = Prod

include Intf.S with type ledger_proof := Ledger_proof.t
