open Coda_main

module type S = sig
  type ledger_proof

  module Make (Init : Init_intf) () : Main_intf
end
