module type Inputs_intf = sig
  module Time : Protocols.Coda_pow.Time_intf

  module Ledger_builder_diff : sig
    type t [@@deriving bin_io, sexp]
  end

  module Genesis_ledger : sig
    val t : Coda_base.Ledger.t
  end

  val proposal_interval : Time.Span.t
end

module Make (Inputs : Inputs_intf) :
  Mechanism.S
  with type Internal_transition.Ledger_builder_diff.t =
              Inputs.Ledger_builder_diff.t
   and type External_transition.Ledger_builder_diff.t =
              Inputs.Ledger_builder_diff.t
