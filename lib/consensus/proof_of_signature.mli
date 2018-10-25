module type Inputs_intf = sig
  module Time : Coda_spec.Time_intf.S

  module Ledger_builder_diff : sig
    type t [@@deriving bin_io, sexp]
  end

  val proposal_interval : Time.Span.t
end

module Make (Inputs : Inputs_intf) :
  Mechanism.S
  with type Internal_transition.Ledger_builder_diff.t =
              Inputs.Ledger_builder_diff.t
   and type External_transition.Ledger_builder_diff.t =
              Inputs.Ledger_builder_diff.t
   and module Protocol_state.Blockchain_state = Coda_base.Blockchain_state
