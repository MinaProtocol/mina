module type Inputs_intf = sig
  module Ledger_builder_diff : sig
    type t [@@deriving bin_io, sexp]
  end
end

module Make (Inputs : Inputs_intf) :
  Mechanism.S
  with type Internal_transition.Ledger_builder_diff.t =
              Inputs.Ledger_builder_diff.t
   and type External_transition.Ledger_builder_diff.t =
              Inputs.Ledger_builder_diff.t
