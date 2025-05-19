module Prod = Prod
module Events = Events

module Intf : module type of Intf

include Intf.S with type ledger_proof := Ledger_proof.t
