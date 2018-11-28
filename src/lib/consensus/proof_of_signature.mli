module type Inputs_intf = sig
  module Time : Protocols.Coda_pow.Time_intf

  module Genesis_ledger : sig
    val t : Coda_base.Ledger.t
  end

  val proposal_interval : Time.Span.t
end

module Make (Inputs : Inputs_intf) : Intf.S
