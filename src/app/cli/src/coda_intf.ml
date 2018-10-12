open Coda_main

module type S = sig
  type ledger_proof

  module Make (Init : Init_intf with type Ledger_proof.t = ledger_proof) () :
    Main_intf
end
