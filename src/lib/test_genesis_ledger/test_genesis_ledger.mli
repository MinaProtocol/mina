open Coda_base

include Intf.S

module Dummy : sig
  val t : Ledger.t Lazy.t
end
