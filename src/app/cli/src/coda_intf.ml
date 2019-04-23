open Coda_inputs

module type S = sig
  type ledger_proof

  module Make (Init : Init_intf) () : Main_intf
end
